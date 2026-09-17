import { DatabaseSync } from 'node:sqlite';
import { createHash, randomUUID } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

export const products: Record<string, number> = {
  'com.kukjinman.aidetector.credits6': 6,
  'com.kukjinman.aidetector.credits20': 20,
  'com.kukjinman.aidetector.credits50': 50,
};
export class Ledger {
  private db: DatabaseSync;
  constructor(path: string) {
    if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA secure_delete=ON; PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS wallets (id TEXT PRIMARY KEY, secret TEXT UNIQUE, balance INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS purchases (id TEXT PRIMARY KEY, wallet TEXT NOT NULL, credits INTEGER NOT NULL, revoked INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS jobs (wallet TEXT, id TEXT, hash TEXT, state TEXT, result TEXT, created INTEGER, PRIMARY KEY(wallet,id));`);
    // Single server process: refund reservations interrupted by a process crash.
    this.atomic(() => {
      this.db.exec(`UPDATE wallets SET balance=balance+(SELECT COUNT(*) FROM jobs WHERE wallet=wallets.id AND state='pending');
        UPDATE jobs SET state='failed' WHERE state='pending';`);
    });
  }
  private atomic<T>(work: () => T): T {
    this.db.exec('BEGIN IMMEDIATE');
    try { const value = work(); this.db.exec('COMMIT'); return value; }
    catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  wallet(secret: string): { id: string; balance: number } {
    const digest = createHash('sha256').update(secret).digest('hex');
    this.db.prepare('INSERT OR IGNORE INTO wallets(id,secret) VALUES (?,?)').run(randomUUID(), digest);
    return this.db.prepare('SELECT id,balance FROM wallets WHERE secret=?').get(digest) as { id: string; balance: number };
  }
  purgeResults() { this.db.prepare("UPDATE jobs SET result=NULL WHERE created<? AND result IS NOT NULL").run(Date.now()-86_400_000); }
  balance(id: string): number { return (this.db.prepare('SELECT balance FROM wallets WHERE id=?').get(id) as { balance: number }).balance; }
  purchase(id: string, wallet: string, credits: number) {
    return this.atomic(() => {
      const existing = this.db.prepare('SELECT wallet FROM purchases WHERE id=?').get(id);
      if (existing && existing.wallet !== wallet) throw new Error('Transaction belongs to another wallet');
      if (!existing) {
        this.db.prepare('INSERT INTO purchases(id,wallet,credits) VALUES (?,?,?)').run(id,wallet,credits);
        this.db.prepare('UPDATE wallets SET balance=balance+? WHERE id=?').run(credits,wallet);
      }
      return this.balance(wallet);
    });
  }
  revoke(id: string, wallet: string, credits: number) {
    this.atomic(() => {
      // A refund notification may precede the client's first redemption.
      this.db.prepare('INSERT OR IGNORE INTO purchases(id,wallet,credits,revoked) VALUES (?,?,?,1)').run(id,wallet,credits);
      const changed = this.db.prepare('UPDATE purchases SET revoked=1 WHERE id=? AND revoked=0').run(id);
      if (changed.changes) this.db.prepare('UPDATE wallets SET balance=balance-? WHERE id=?').run(credits,wallet);
    });
  }
  reserve(wallet: string, id: string, hash: string): { state: string; result?: string } {
    return this.atomic(() => {
      // Retain idempotency tombstones; remove result payloads after 24 hours.
      this.db.prepare('UPDATE jobs SET result=NULL WHERE created<? AND result IS NOT NULL').run(Date.now()-86_400_000);
      const prior = this.db.prepare('SELECT hash,state,result FROM jobs WHERE wallet=? AND id=?').get(wallet,id);
      if (prior) {
        if (prior.hash !== hash) throw new Error('REQUEST_CONFLICT');
        return { state: String(prior.state), result: prior.result ? String(prior.result) : undefined };
      }
      if (this.balance(wallet) < 1) throw new Error('INSUFFICIENT_CREDITS');
      this.db.prepare('UPDATE wallets SET balance=balance-1 WHERE id=?').run(wallet);
      this.db.prepare("INSERT INTO jobs VALUES (?,?,?,'pending',NULL,?)").run(wallet,id,hash,Date.now());
      return { state: 'new' };
    });
  }
  finish(wallet: string, id: string, result?: unknown) {
    this.atomic(() => {
      const updated = this.db.prepare("UPDATE jobs SET state=?,result=? WHERE wallet=? AND id=? AND state='pending'").run(result ? 'done' : 'failed',result ? JSON.stringify(result) : null,wallet,id);
      if (!result && updated.changes) this.db.prepare('UPDATE wallets SET balance=balance+1 WHERE id=?').run(wallet);
    });
  }
  close() { this.db.close(); }
}

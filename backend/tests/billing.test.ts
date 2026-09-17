import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import Fastify from 'fastify';
import { Ledger } from '../src/billing/ledger.js';
import { registerAnalyzeRoute } from '../src/routes/analyze.js';
import { registerBilling } from '../src/billing/routes.js';
const secret = 'a'.repeat(64);
const payload = { text: 'A paragraph to analyze. '.repeat(20), consent:true };
const headers = { authorization:`Bearer ${secret}`, 'idempotency-key':'11111111-1111-4111-8111-111111111111' };

test('purchase replay, wallet binding, and refund replay cannot create credits', () => {
  const ledger = new Ledger(':memory:');
  try {
    const wallet = ledger.wallet(secret);
    assert.equal(ledger.purchase('tx1',wallet.id,6),6);
    assert.equal(ledger.purchase('tx1',wallet.id,6),6);
    const other = ledger.wallet('b'.repeat(64));
    assert.throws(() => ledger.purchase('tx1',other.id,6));
    ledger.revoke('tx1',wallet.id,6);
    ledger.revoke('tx1',wallet.id,6);
    assert.equal(ledger.balance(wallet.id),0);
    ledger.purchase('tx1',wallet.id,6);
    assert.equal(ledger.balance(wallet.id),0);
    ledger.revoke('tx2',wallet.id,6);
    ledger.purchase('tx2',wallet.id,6);
    assert.equal(ledger.balance(wallet.id),0);
  } finally { ledger.close(); }
});

test('restart preserves successful charges and refunds interrupted reservations', () => {
  const directory = mkdtempSync(join(tmpdir(),'ledger-test-'));
  const path = join(directory,'db.sqlite');
  let ledger = new Ledger(path);
  try {
    const wallet = ledger.wallet(secret);
    ledger.purchase('tx',wallet.id,6);
    ledger.reserve(wallet.id,'finished','hash1');
    ledger.finish(wallet.id,'finished',{ status:'ok' });
    ledger.reserve(wallet.id,'interrupted','hash2');
    assert.equal(ledger.balance(wallet.id),4);
    ledger.close();
    ledger = new Ledger(path);
    assert.equal(ledger.wallet(secret).balance,5);
    assert.equal(ledger.reserve(wallet.id,'finished','hash1').state,'done');
    assert.equal(ledger.reserve(wallet.id,'interrupted','hash2').state,'failed');
    assert.throws(() => ledger.reserve(wallet.id,'finished','changed'));
  } finally { ledger.close(); rmSync(directory,{recursive:true,force:true}); }
});

test('parallel duplicate analysis calls provider once and debits once', async () => {
  const ledger = new Ledger(':memory:');
  const wallet = ledger.wallet(secret);
  ledger.purchase('tx',wallet.id,6);
  let calls = 0;
  let release!: () => void;
  const gate = new Promise<void>(resolve => { release = resolve; });
  let entered!: () => void;
  const started = new Promise<void>(resolve => { entered = resolve; });
  const app = Fastify();
  registerAnalyzeRoute(app,{ name:'mock', async detect() { calls++; entered(); await gate; return { aiProbability:0.75,providerName:'mock' }; } },ledger,true);
  try {
    const pending = app.inject({method:'POST',url:'/v1/analyze',payload,headers}).then(value => value);
    await started;
    assert.equal((await app.inject({method:'POST',url:'/v1/analyze',payload,headers})).statusCode,409);
    release();
    const result = await pending;
    assert.equal(result.statusCode,200);
    const replay = await app.inject({method:'POST',url:'/v1/analyze',payload,headers});
    assert.deepEqual(replay.json(),result.json());
    assert.equal(calls,1);
    assert.equal(ledger.balance(wallet.id),5);
  } finally { release(); await app.close(); ledger.close(); }
});

test('provider failure, missing consent and missing auth never consume credits', async () => {
  const ledger = new Ledger(':memory:');
  const wallet = ledger.wallet(secret);
  ledger.purchase('tx',wallet.id,6);
  const app = Fastify();
  registerAnalyzeRoute(app,{name:'mock',async detect() {throw new Error('provider failed');}},ledger,true);
  try {
    assert.equal((await app.inject({method:'POST',url:'/v1/analyze',payload,headers})).statusCode,502);
    assert.equal(ledger.balance(wallet.id),6);
    assert.equal((await app.inject({method:'POST',url:'/v1/analyze',payload:{...payload,consent:false},headers})).statusCode,400);
    assert.equal((await app.inject({method:'POST',url:'/v1/analyze',payload})).statusCode,401);
    assert.equal(ledger.balance(wallet.id),6);
  } finally { await app.close(); ledger.close(); }
});

test('empty wallet cannot invoke provider and malformed requests are rejected', async () => {
  const ledger = new Ledger(':memory:');
  let calls = 0;
  const app = Fastify();
  registerAnalyzeRoute(app,{name:'mock',async detect() { calls++; return {aiProbability:0.1,providerName:'mock'};}},ledger,true);
  try {
    assert.equal((await app.inject({method:'POST',url:'/v1/analyze',payload,headers})).statusCode,402);
    for (const body of [{url:123},{text:'short'},{text:payload.text,url:'https://www.instagram.com/p/ABC/'},{media:'AAAA',contentType:'image/png'}]) {
      assert.equal((await app.inject({method:'POST',url:'/v1/analyze',payload:body,headers})).statusCode,400);
    }
    assert.equal(calls,0);
  } finally { await app.close(); ledger.close(); }
});

test('demo cannot redeem fabricated purchases', async () => {
  const ledger = new Ledger(':memory:');
  const app = Fastify();
  registerBilling(app,ledger,false);
  try {
    assert.equal((await app.inject({method:'POST',url:'/v1/purchases',payload:{signedTransaction:'fake'},headers})).statusCode,503);
    assert.equal((await app.inject({method:'GET',url:'/v1/wallet',headers})).json().balance,0);
  } finally { await app.close(); ledger.close(); }
});

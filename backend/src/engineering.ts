import { timingSafeEqual } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { Ledger } from './billing/ledger.js';

export function engineeringKey(env = process.env): string | undefined {
  if (env.ENGINEERING_MODE !== 'true') return;
  if (env.NODE_ENV !== 'development' || env.BILLING_ENABLED === 'true') throw new Error('Engineering mode requires isolated development without purchases');
  if (!/^[a-f0-9]{64}$/.test(env.ENGINEERING_KEY ?? '')) throw new Error('Engineering mode requires a strong access key');
  if (!env.BILLING_DB_PATH || env.BILLING_DB_PATH === ':memory:') throw new Error('Engineering mode requires a separate persistent database');
  return env.ENGINEERING_KEY;
}
export function protectEngineering(app: FastifyInstance, key: string) {
  app.addHook('onRequest',async (request,reply) => {
    const received = request.headers.authorization?.replace(/^Bearer /,'') ?? '';
    if (received.length !== key.length || !timingSafeEqual(Buffer.from(received),Buffer.from(key))) {
      return reply.code(401).send({code:'UNAUTHORIZED',message:'테스트 접근 키가 필요합니다.'});
    }
  });
}
export function seedEngineering(ledger: Ledger, key: string) {
  const wallet = ledger.wallet(key);
  ledger.purchase('engineering-initial-20',wallet.id,20);
}

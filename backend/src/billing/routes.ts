import type { FastifyInstance, FastifyRequest } from 'fastify';
import { Ledger, products } from './ledger.js';
import { appleVerifier } from './apple.js';

export function walletFor(request: FastifyRequest, ledger: Ledger) {
  const secret = request.headers.authorization?.replace(/^Bearer /, '') ?? '';
  if (!/^[a-f0-9]{64}$/.test(secret)) throw Object.assign(new Error('앱에서 횟수권 지갑을 연결해 주세요.'), { statusCode: 401 });
  return ledger.wallet(secret);
}
export function registerBilling(app: FastifyInstance, ledger: Ledger, enabled: boolean) {
  const verifier = enabled ? appleVerifier() : undefined;
  app.get('/v1/wallet', async request => ({ ...walletFor(request, ledger), billingEnabled: enabled, products }));
  app.post<{ Body: { signedTransaction?: string } }>('/v1/purchases', async (request, reply) => {
    if (!verifier) return reply.code(503).send({ message: '결제 준비 중입니다. 개발 모드에서는 구매할 수 없습니다.' });
    const wallet = walletFor(request,ledger);
    let tx;
    try { tx = await verifier.verifyAndDecodeTransaction(request.body?.signedTransaction ?? ''); }
    catch { return reply.code(400).send({ message: 'Apple 구매 검증에 실패했습니다.' }); }
    const credits = products[tx.productId ?? ''];
    if (!credits || !tx.transactionId || tx.type !== 'Consumable' || tx.appAccountToken?.toLowerCase() !== wallet.id.toLowerCase() || tx.revocationDate || tx.quantity !== 1) {
      return reply.code(400).send({ message: '이 지갑의 유효한 횟수권 구매가 아닙니다.' });
    }
    try { return { balance: ledger.purchase(tx.transactionId,wallet.id,credits) }; }
    catch { return reply.code(409).send({ message: '이미 다른 지갑에 등록된 구매입니다.' }); }
  });
  app.post<{ Body: { signedPayload?: string } }>('/v1/apple/notifications', async (request,reply) => {
    if (!verifier) return reply.code(503).send();
    try {
      const notification = await verifier.verifyAndDecodeNotification(request.body?.signedPayload ?? '');
      if (notification.notificationType === 'REFUND' || notification.notificationType === 'REVOKE') {
        const tx = await verifier.verifyAndDecodeTransaction(notification.data?.signedTransactionInfo ?? '');
        const credits = products[tx.productId ?? ''];
        if (tx.transactionId && tx.appAccountToken && credits) ledger.revoke(tx.transactionId,tx.appAccountToken.toLowerCase(),credits);
      }
      return { received: true };
    } catch { return reply.code(400).send({ message: 'Invalid Apple notification' }); }
  });
}

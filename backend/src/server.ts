import { engineeringKey, protectEngineering, seedEngineering } from './engineering.js';
import Fastify from 'fastify';
import rateLimit from '@fastify/rate-limit';
import { registerAnalyzeRoute } from './routes/analyze.js';
import { registerLegal, legalFields } from './routes/legal.js';
import { createProvider } from './providers/index.js';
import { Ledger } from './billing/ledger.js';
import { registerBilling } from './billing/routes.js';

export function buildServer() {
  const engineering = engineeringKey();
  const billing = process.env.BILLING_ENABLED === 'true';
  if (process.env.NODE_ENV === 'production' && (!billing || legalFields.some(key => !process.env[key]))) {
    throw new Error('Production requires billing and completed legal configuration');
  }
  const provider = createProvider();
  const localAPI = process.env.NODE_ENV === 'development' && process.env.ALLOW_UNBILLED_LOCAL_API === 'true';
  if (!billing && provider.name !== 'mock' && !localAPI && !engineering) throw new Error('Real API usage requires billing, or explicit local development mode');
  const app = Fastify({ logger: { redact: ['req.headers.authorization'] }, disableRequestLogging: true, bodyLimit: 14_100_000 });
  if (engineering) protectEngineering(app,engineering);
  if (localAPI && !billing && !engineering) app.addHook('onRequest',async (request,reply) => {
    if (!['127.0.0.1','::1','::ffff:127.0.0.1'].includes(request.ip) || request.headers['x-forwarded-for'] || request.headers.forwarded) {
      return reply.code(403).send({ message:'Local development API only' });
    }
  });
  app.register(rateLimit,{ max:30,timeWindow:'1 minute' });
  const ledger = new Ledger(process.env.BILLING_DB_PATH ?? (billing ? './data/billing.sqlite' : ':memory:'));
  if (engineering) seedEngineering(ledger,engineering);
  ledger.purgeResults();
  const cleanup = setInterval(() => ledger.purgeResults(),60_000);
  cleanup.unref();
  app.addHook('onClose',async () => { clearInterval(cleanup); ledger.close(); });
  app.get('/healthz',async () => ({status:'ok'}));
  app.get('/v1/config',async () => ({ engineering:!!engineering, billingEnabled:billing, demo:provider.name === 'mock', mediaProvider:provider.name, videoAvailable:provider.name !== 'illuminarty', textAvailable:provider.name === 'mock' || !!process.env.GPTZERO_API_KEY }));
  registerLegal(app);
  registerBilling(app,ledger,billing);
  registerAnalyzeRoute(app,provider,ledger,billing || !!engineering);
  return app;
}
if (import.meta.url === `file://${process.argv[1]}`) {
  const app = buildServer();
  app.listen({port:Number(process.env.PORT ?? 8787),host:process.env.ENGINEERING_MODE === 'true' ? '127.0.0.1' : process.env.NODE_ENV === 'development' && process.env.ALLOW_UNBILLED_LOCAL_API === 'true' ? '127.0.0.1' : '0.0.0.0'}).catch(error => {app.log.error(error);process.exit(1);});
}

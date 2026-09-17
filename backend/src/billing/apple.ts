import { Environment, SignedDataVerifier } from '@apple/app-store-server-library';
import { readFileSync } from 'node:fs';

export function appleVerifier() {
  const environment = process.env.APPLE_ENVIRONMENT === 'Production' ? Environment.PRODUCTION : Environment.SANDBOX;
  const roots = (process.env.APPLE_ROOT_CA_PATHS ?? '').split(',').filter(Boolean).map(p => readFileSync(p.trim()));
  if (!roots.length) throw new Error('APPLE_ROOT_CA_PATHS is required');
  if (process.env.NODE_ENV === 'production' && !process.env.APPLE_ENVIRONMENT) throw new Error('APPLE_ENVIRONMENT is required');
  return new SignedDataVerifier(roots, true, environment,
    process.env.APPLE_BUNDLE_ID ?? 'com.kukjinman.aidetector.app',
    process.env.APPLE_APP_ID ? Number(process.env.APPLE_APP_ID) : undefined);
}

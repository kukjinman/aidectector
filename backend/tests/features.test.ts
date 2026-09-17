import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildServer } from '../src/server.js';
import { downloadMedia } from '../src/lib/mediaFetch.js';
import { SightengineProvider } from '../src/providers/sightengineProvider.js';
import { IlluminartyProvider } from '../src/providers/illuminartyProvider.js';
import { detectText } from '../src/providers/textProvider.js';

test('text and image uploads produce demo results', async () => {
  const app = buildServer();
  try {
    for (const payload of [{text:'Sample sentence. '.repeat(30)}, {media:Buffer.from([255,216,255,217]).toString('base64'),contentType:'image/jpeg'}]) {
      const response = await app.inject({method:'POST',url:'/v1/analyze',payload});
      assert.equal(response.statusCode,200);
      assert.equal(response.json().provider,'mock');
    }
  } finally { await app.close(); }
});
test('legal pages and configuration available without authentication', async () => {
  const app = buildServer();
  try {
    for (const url of ['/','/privacy','/terms','/support']) {
      const response = await app.inject({method:'GET',url});
      assert.equal(response.statusCode,200);
      assert.match(response.headers['content-type'] ?? '',/text\/html/);
      assert.match(response.body,/검토용 초안/);
    }
    assert.equal((await app.inject({method:'GET',url:'/v1/config'})).json().demo,true);
  } finally { await app.close(); }
});
test('preview downloads reject arbitrary/private hosts before fetching', async () => {
  for (const url of ['http://localhost/photo.jpg','https://127.0.0.1/photo','https://cdninstagram.com.evil.test/photo','https://example.com/photo','https://name:pass@cdninstagram.com/photo']) await assert.rejects(downloadMedia(url));
});
test('Sightengine video averages frame scores and rejects invalid probabilities', async () => {
  const original = globalThis.fetch;
  let invalid = false;
  globalThis.fetch = (async (url: string, init: RequestInit) => {
    assert.match(url,/video\/check-sync.json$/);
    assert.equal((init.body as FormData).get('interval'),'5');
    return Response.json({status:'success',data:{frames:[{type:{ai_generated:invalid ? 2 : 0.4}},{type:{ai_generated:0.8}}]}});
  }) as typeof fetch;
  try {
    const provider = new SightengineProvider('user','secret');
    assert.ok(Math.abs((await provider.detect(Buffer.from('video'),'video/mp4')).aiProbability-0.6)<0.00001);
    invalid = true;
    await assert.rejects(provider.detect(Buffer.from('video'),'video/mp4'));
  } finally { globalThis.fetch = original; }
});
test('Illuminarty returns the probability, rejects invalid scores, and rejects video', async () => {
  const original = globalThis.fetch;
  let invalid = false;
  globalThis.fetch = (async (url: string, init: RequestInit) => {
    assert.equal(url,'https://api.illuminarty.ai/v1/image/classify');
    assert.equal((init.headers as Record<string,string>)['X-API-Key'],'key');
    assert.ok((init.body as FormData).get('file'));
    return Response.json({status:'success',data:{probability: invalid ? 2 : 0.42}});
  }) as typeof fetch;
  try {
    const provider = new IlluminartyProvider('key');
    assert.equal((await provider.detect(Buffer.from('img'),'image/jpeg')).aiProbability,0.42);
    invalid = true;
    await assert.rejects(provider.detect(Buffer.from('img'),'image/jpeg'));
    await assert.rejects(provider.detect(Buffer.from('video'),'video/mp4'));
  } finally { globalThis.fetch = original; }
});
test('GPTZero extracts AI-only score and rejects missing result', async () => {
  const original = globalThis.fetch;
  const key = process.env.GPTZERO_API_KEY;
  process.env.GPTZERO_API_KEY = 'test';
  let missing = false;
  globalThis.fetch = (async () => Response.json(missing ? {} : {documents:[{class_probabilities:{ai:0.7}}]})) as typeof fetch;
  try {
    assert.equal((await detectText('Example')).aiProbability,0.7);
    missing = true;
    await assert.rejects(detectText('Example'));
  } finally { globalThis.fetch = original; if (key === undefined) delete process.env.GPTZERO_API_KEY; else process.env.GPTZERO_API_KEY = key; }
});

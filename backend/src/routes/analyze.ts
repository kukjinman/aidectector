import type { FastifyInstance } from 'fastify';
import { createHash } from 'node:crypto';
import { validateInstagramUrl } from '../lib/validateUrl.js';
import { extractOpenGraphMedia, OgFetchError } from '../lib/ogExtractor.js';
import { downloadMedia } from '../lib/mediaFetch.js';
import { labelForProbability } from '../lib/label.js';
import { validateUpload } from '../lib/upload.js';
import { detectText } from '../providers/textProvider.js';
import type { AIDetectionProvider } from '../providers/AIDetectionProvider.js';
import type { AnalyzeSuccessResponse } from '../types.js';
import { Ledger } from '../billing/ledger.js';
import { walletFor } from '../billing/routes.js';
import { IlluminartyError } from '../providers/illuminartyProvider.js';

interface Body { url?: string; text?: string; media?: string; contentType?: string; consent?: boolean }
export function registerAnalyzeRoute(app: FastifyInstance, provider: AIDetectionProvider, ledger?: Ledger, billing = false) {
  app.post<{ Body: Body }>('/v1/analyze', async (request,reply) => {
    const body = request.body ?? {};
    const fail = (status: number, code: string, message: string) => reply.code(status).send({status:'error',code,message});
    const count = [body.url,body.text,body.media].filter(x => x !== undefined).length;
    if (count !== 1) return fail(400,'INVALID_URL','텍스트, 파일 또는 Instagram 링크 중 하나를 입력해 주세요.');
    if (body.url !== undefined && (typeof body.url !== 'string' || !validateInstagramUrl(body.url))) return fail(400,'INVALID_URL','공개 Instagram 게시물·릴스 링크를 입력해 주세요.');
    if (body.text !== undefined && (typeof body.text !== 'string' || body.text.trim().length < 250 || body.text.length > 10_000)) return fail(400,'INVALID_TEXT','텍스트는 250~10,000자여야 합니다.');
    if ((billing || provider.name !== 'mock') && body.consent !== true) return fail(400,'CONSENT_REQUIRED','외부 AI API 전송에 동의해 주세요.');
    if (body.text !== undefined && provider.name !== 'mock' && !process.env.GPTZERO_API_KEY) return fail(503,'UNAVAILABLE','텍스트 분석을 준비 중입니다. 횟수는 차감되지 않습니다.');
    const authenticatedWallet = billing && ledger ? walletFor(request,ledger).id : undefined;
    if (provider.name === 'illuminarty' && typeof body.contentType === 'string' && body.contentType.startsWith('video/')) return fail(400,'UNSUPPORTED_MEDIA_TYPE','현재 분석 API는 이미지만 지원합니다.');
    let upload;
    if (body.media !== undefined) {
      try { upload = await validateUpload(body.media,body.contentType); }
      catch (error) { return fail(400,'UNSUPPORTED_MEDIA_TYPE',(error as Error).message); }
    }
    let wallet: string | undefined;
    const id = request.headers['idempotency-key'];
    if (billing && ledger) {
      wallet = authenticatedWallet!;
      if (typeof id !== 'string' || !/^[a-zA-Z0-9-]{16,80}$/.test(id)) return fail(400,'INVALID_REQUEST','분석 요청 식별자가 필요합니다.');
      try {
        const job = ledger.reserve(wallet,id,createHash('sha256').update(JSON.stringify(body)).digest('hex'));
        if (job.state === 'done' && job.result) return reply.send(JSON.parse(job.result));
        if (job.state !== 'new') return fail(409,job.state === 'pending' ? 'REQUEST_PENDING' : 'REQUEST_FINISHED',job.state === 'pending' ? '같은 요청을 처리 중입니다. 잠시 후 다시 시도해 주세요.' : '이 요청은 종료되었습니다. 새 분석을 시작해 주세요.');
      } catch (error) {
        return fail((error as Error).message === 'INSUFFICIENT_CREDITS' ? 402 : 409,(error as Error).message,'횟수가 부족하거나 중복된 요청입니다. 횟수권을 확인해 주세요.');
      }
    }
    try {
      let mediaType: AnalyzeSuccessResponse['mediaType'] = 'image';
      let thumbnailUrl = '';
      let detection;
      if (body.text !== undefined) {
        mediaType = 'text';
        detection = provider.name === 'mock' ? await provider.detect(Buffer.from(body.text),'text/plain') : await detectText(body.text);
      } else if (upload) {
        mediaType = upload.contentType.startsWith('video/') ? 'video' : 'image';
        detection = await provider.detect(upload.buffer,upload.contentType);
      } else {
        const og = await extractOpenGraphMedia(body.url!);
        // URL mode explicitly analyzes the public preview, even for reels.
        thumbnailUrl = og.thumbnailUrl;
        const media = await downloadMedia(thumbnailUrl);
        detection = await provider.detect(media.buffer,media.contentType);
      }
      if (!Number.isFinite(detection.aiProbability) || detection.aiProbability < 0 || detection.aiProbability > 1) throw new Error('Invalid provider probability');
      const result: AnalyzeSuccessResponse = { status:'ok', aiProbability:Math.round(detection.aiProbability*1000)/1000,
        label:labelForProbability(detection.aiProbability),mediaType,thumbnailUrl,provider:detection.providerName,analyzedAt:new Date().toISOString() };
      if (wallet && ledger && typeof id === 'string') ledger.finish(wallet,id,result);
      return reply.send(result);
    } catch (error) {
      if (wallet && ledger && typeof id === 'string') ledger.finish(wallet,id);
      // Log only controlled metadata, never credentials, submitted media or upstream bodies.
      request.log.error({
        event: 'analysis_failed', provider: body.text !== undefined ? 'text' : provider.name,
        reason: error instanceof IlluminartyError ? error.reason : error instanceof OgFetchError ? 'preview_failed' : 'analysis_exception',
        ...(error instanceof IlluminartyError ? { upstreamStatus: error.httpStatus, responseBytes: error.responseBytes } : {}),
      }, 'Analysis failed');
      if (error instanceof OgFetchError) return fail(404,error.code,'공개 미리보기를 가져올 수 없습니다. 사진 파일로 분석해 주세요.');
      return fail(502,'PROVIDER_ERROR','분석하지 못했습니다. 횟수는 차감되지 않습니다.');
    }
  });
}

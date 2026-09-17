const MAX_MEDIA_BYTES = 10 * 1024 * 1024;
export class MediaTooLargeError extends Error {}
export class MediaFetchError extends Error {}
export interface DownloadedMedia { buffer: Buffer; contentType: string }
export async function downloadMedia(raw: string): Promise<DownloadedMedia> {
  const url = new URL(raw);
  // Preview URLs are untrusted metadata. Only Instagram/Meta CDN HTTPS is fetched.
  if (url.protocol !== 'https:' || url.username || url.password || (url.port && url.port !== '443') ||
      !['cdninstagram.com','fbcdn.net'].some(domain => url.hostname === domain || url.hostname.endsWith(`.${domain}`))) {
    throw new MediaFetchError('Unsupported preview host');
  }
  const response = await fetch(url.toString(),{ redirect:'error', signal:AbortSignal.timeout(15_000) });
  if (!response.ok || !response.body) throw new MediaFetchError('Preview unavailable');
  if (Number(response.headers.get('content-length')) > MAX_MEDIA_BYTES) { await response.body.cancel(); throw new MediaTooLargeError(); }
  const contentType = response.headers.get('content-type')?.split(';')[0] ?? '';
  if (!['image/jpeg','image/png','image/webp'].includes(contentType)) { await response.body.cancel(); throw new MediaFetchError('Unsupported preview type'); }
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    for (;;) {
      const {done,value} = await reader.read();
      if (done) break;
      total += value.length;
      if (total > MAX_MEDIA_BYTES) throw new MediaTooLargeError();
      chunks.push(value);
    }
  } finally { await reader.cancel(); }
  return {buffer:Buffer.concat(chunks),contentType};
}

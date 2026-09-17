import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
export async function validateUpload(base64: unknown, type: unknown) {
  if (typeof base64 !== 'string' || !base64.length || base64.length > 14_000_000 || !/^[A-Za-z0-9+/]*={0,2}$/.test(base64) || base64.length % 4 !== 0) throw new Error('10MB 이하 파일을 선택해 주세요.');
  if (!['image/jpeg','image/png','image/webp','video/mp4','video/quicktime'].includes(String(type))) throw new Error('JPEG, PNG, WebP, MP4, MOV 파일을 지원합니다.');
  const buffer = Buffer.from(base64,'base64');
  if (buffer.length > 10 * 1024 * 1024) throw new Error('파일은 10MB 이하여야 합니다.');
  const contentType = String(type);
  const matches = contentType === 'image/jpeg' ? buffer.subarray(0,3).equals(Buffer.from([255,216,255]))
    : contentType === 'image/png' ? buffer.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))
    : contentType === 'image/webp' ? buffer.toString('ascii',0,4) === 'RIFF' && buffer.toString('ascii',8,12) === 'WEBP'
    : buffer.toString('ascii',4,8) === 'ftyp';
  if (!matches) throw new Error('파일 형식이 일치하지 않습니다.');
  if (contentType.startsWith('video/')) {
    const directory = await mkdtemp(join(tmpdir(),'aidetect-'));
    try {
      const path = join(directory,'upload.mp4');
      await writeFile(path,buffer,{ mode: 0o600 });
      const { stdout } = await promisify(execFile)('ffprobe',['-v','error','-show_entries','format=duration','-of','json',path],{ timeout: 10_000, maxBuffer: 64_000 });
      const duration = Number(JSON.parse(stdout).format?.duration);
      if (!Number.isFinite(duration) || duration <= 0 || duration > 10) throw new Error('영상은 10초 이하여야 합니다.');
    } catch { throw new Error('10초 이하 영상을 선택해 주세요. 서버의 영상 처리 설정도 확인해 주세요.'); }
    finally { await rm(directory,{recursive:true,force:true}); }
  }
  return { buffer, contentType };
}

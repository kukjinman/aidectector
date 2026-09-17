import * as cheerio from "cheerio";
import type { MediaType } from "../types.js";

const FETCH_TIMEOUT_MS = 5000;
// A descriptive UA that identifies the bot, as opposed to spoofing a browser.
const USER_AGENT = "AIDetectorBot/1.0 (+https://github.com/kukjinman/aidectector)";

export interface OgMedia {
  mediaType: MediaType;
  /** The media Instagram exposes for link-preview purposes (og:video or og:image). */
  mediaUrl: string;
  /** Always an image URL, used as the still we send to the AI detector. */
  thumbnailUrl: string;
}

export class OgFetchError extends Error {
  constructor(
    public code: "PRIVATE_OR_UNAVAILABLE" | "PROVIDER_ERROR",
    message: string,
  ) {
    super(message);
    this.name = "OgFetchError";
  }
}

/**
 * Reads the public Open Graph preview metadata Instagram maintains for link
 * unfurling (Facebook/Twitter/iMessage previews). This is far more stable
 * than scraping the rendered page markup, and requires no authentication.
 */
export async function extractOpenGraphMedia(url: string): Promise<OgMedia> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  let res: Response;
  try {
    res = await fetch(url, {
      headers: {
        "User-Agent": USER_AGENT,
        "Accept-Language": "en-US,en;q=0.9",
      },
      redirect: "error",
      signal: controller.signal,
    });
  } catch {
    throw new OgFetchError(
      "PRIVATE_OR_UNAVAILABLE",
      "Could not reach the post page.",
    );
  } finally {
    clearTimeout(timeout);
  }

  if (res.status === 404 || res.status === 410) {
    throw new OgFetchError("PRIVATE_OR_UNAVAILABLE", "Post not found.");
  }
  if (!res.ok) {
    throw new OgFetchError(
      "PRIVATE_OR_UNAVAILABLE",
      `Post page returned HTTP ${res.status}.`,
    );
  }

  const html = await res.text();
  const $ = cheerio.load(html);

  const ogImage = $('meta[property="og:image"]').attr("content");
  const ogVideo =
    $('meta[property="og:video"]').attr("content") ??
    $('meta[property="og:video:secure_url"]').attr("content");

  if (!ogImage) {
    throw new OgFetchError(
      "PRIVATE_OR_UNAVAILABLE",
      "This post is private, deleted, or has no public preview media.",
    );
  }

  if (ogVideo) {
    return { mediaType: "video", mediaUrl: ogVideo, thumbnailUrl: ogImage };
  }
  return { mediaType: "image", mediaUrl: ogImage, thumbnailUrl: ogImage };
}

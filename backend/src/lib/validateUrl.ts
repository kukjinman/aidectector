const INSTAGRAM_HOSTS = new Set(["instagram.com", "www.instagram.com"]);
const INSTAGRAM_PATH_RE = /^\/(p|reel|tv)\/[^/]+\/?/;

/**
 * Accepts only public Instagram post/reel/tv permalinks.
 * Returns the normalized URL, or null if the input doesn't match.
 */
export function validateInstagramUrl(raw: string): URL | null {
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    return null;
  }

  if (parsed.protocol !== "https:" || parsed.username || parsed.password || (parsed.port && parsed.port !== "443")) return null;
  if (!INSTAGRAM_HOSTS.has(parsed.hostname.toLowerCase())) return null;
  if (!INSTAGRAM_PATH_RE.test(parsed.pathname)) return null;

  return parsed;
}

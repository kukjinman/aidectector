import { test } from "node:test";
import assert from "node:assert/strict";
import { buildServer } from "../src/server.js";

const FAKE_HTML = `<!doctype html><html><head>
<meta property="og:image" content="https://test.cdninstagram.com/thumb.jpg" />
<meta property="og:type" content="instapp:photo" />
</head><body></body></html>`;

const FAKE_IMAGE_BYTES = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);

function installMockFetch() {
  const original = globalThis.fetch;
  globalThis.fetch = (async (input: RequestInfo | URL) => {
    const url = typeof input === "string" ? input : input.toString();
    if (new URL(url).hostname === "www.instagram.com") {
      return new Response(FAKE_HTML, {
        status: 200,
        headers: { "content-type": "text/html" },
      });
    }
    if (url.includes("thumb.jpg")) {
      return new Response(FAKE_IMAGE_BYTES, {
        status: 200,
        headers: { "content-type": "image/jpeg" },
      });
    }
    return new Response("not found", { status: 404 });
  }) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

test("POST /v1/analyze returns a normalized probability for a valid instagram URL", async () => {
  const restore = installMockFetch();
  process.env.AI_PROVIDER = "mock";
  try {
    const app = buildServer();
    const res = await app.inject({
      method: "POST",
      url: "/v1/analyze",
      payload: { url: "https://www.instagram.com/p/ABC123/" },
    });

    assert.equal(res.statusCode, 200);
    const body = res.json();
    assert.equal(body.status, "ok");
    assert.ok(body.aiProbability >= 0 && body.aiProbability <= 1);
    assert.equal(body.mediaType, "image");
    assert.equal(body.thumbnailUrl, "https://test.cdninstagram.com/thumb.jpg");
    assert.equal(body.provider, "mock");
    await app.close();
  } finally {
    restore();
  }
});

test("POST /v1/analyze rejects non-instagram URLs", async () => {
  const app = buildServer();
  const res = await app.inject({
    method: "POST",
    url: "/v1/analyze",
    payload: { url: "https://example.com/foo" },
  });
  assert.equal(res.statusCode, 400);
  assert.equal(res.json().code, "INVALID_URL");
  await app.close();
});

test("POST /v1/analyze rejects missing body", async () => {
  const app = buildServer();
  const res = await app.inject({
    method: "POST",
    url: "/v1/analyze",
    payload: {},
  });
  assert.equal(res.statusCode, 400);
  assert.equal(res.json().code, "INVALID_URL");
  await app.close();
});

test("POST /v1/analyze returns PRIVATE_OR_UNAVAILABLE when no og:image is present", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (async () =>
    new Response("<html><head></head></html>", {
      status: 200,
      headers: { "content-type": "text/html" },
    })) as typeof fetch;

  try {
    const app = buildServer();
    const res = await app.inject({
      method: "POST",
      url: "/v1/analyze",
      payload: { url: "https://www.instagram.com/p/PRIVATE1/" },
    });
    assert.equal(res.statusCode, 404);
    assert.equal(res.json().code, "PRIVATE_OR_UNAVAILABLE");
    await app.close();
  } finally {
    globalThis.fetch = original;
  }
});

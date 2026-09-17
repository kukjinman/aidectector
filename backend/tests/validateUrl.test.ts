import { test } from "node:test";
import assert from "node:assert/strict";
import { validateInstagramUrl } from "../src/lib/validateUrl.js";

test("accepts a standard post URL", () => {
  assert.ok(validateInstagramUrl("https://www.instagram.com/p/ABC123/"));
});

test("accepts reel and tv URLs without a trailing slash", () => {
  assert.ok(validateInstagramUrl("https://instagram.com/reel/ABC123"));
  assert.ok(validateInstagramUrl("https://instagram.com/tv/ABC123"));
});

test("accepts a query string after the permalink", () => {
  assert.ok(
    validateInstagramUrl("https://www.instagram.com/p/ABC123/?utm_source=ig_web"),
  );
});

test("rejects non-instagram hosts", () => {
  assert.equal(validateInstagramUrl("https://evil.com/p/ABC123/"), null);
});

test("rejects instagram profile URLs (no post path)", () => {
  assert.equal(validateInstagramUrl("https://www.instagram.com/someuser/"), null);
});

test("rejects insecure http", () => {
  assert.equal(validateInstagramUrl("http://www.instagram.com/p/ABC123/"), null);
});

test("rejects malformed input", () => {
  assert.equal(validateInstagramUrl("not a url"), null);
});

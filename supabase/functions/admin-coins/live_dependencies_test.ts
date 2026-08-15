import { replaceSignedUploadURLOrigin } from "./live_dependencies.ts";

function assertEquals(actual: unknown, expected: unknown, message: string) {
  if (actual !== expected) {
    throw new Error(`${message}: ${String(actual)} !== ${String(expected)}`);
  }
}

Deno.test("replaces only the signed upload URL origin", () => {
  const signedURL = "http://kong:8000/storage/v1/object/upload/sign/coin-models-free/coins/example/v1/model.usdz?token=signed-token&mode=upload";
  const result = new URL(
    replaceSignedUploadURLOrigin(signedURL, "http://127.0.0.1:54321"),
  );
  const original = new URL(signedURL);

  assertEquals(result.protocol, "http:", "protocol");
  assertEquals(result.host, "127.0.0.1:54321", "host");
  assertEquals(result.pathname, original.pathname, "pathname");
  assertEquals(result.search, original.search, "query");
});

Deno.test("keeps an already public signed upload URL equivalent", () => {
  const signedURL = "https://api.example.invalid/storage/v1/object/upload/sign/coin-previews/coins/example/v1/preview.webp?token=signed-token";

  assertEquals(
    replaceSignedUploadURLOrigin(signedURL, "https://api.example.invalid"),
    signedURL,
    "signed URL",
  );
});

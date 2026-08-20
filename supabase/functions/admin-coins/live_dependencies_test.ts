import {
  ADMIN_MANAGEABLE_COIN_STATUSES,
  mapCoin,
  replaceSignedUploadURLOrigin,
} from "./live_dependencies.ts";

function assertEquals(actual: unknown, expected: unknown, message: string) {
  if (actual !== expected) {
    throw new Error(`${message}: ${String(actual)} !== ${String(expected)}`);
  }
}

Deno.test("lists only draft and published coins for administration", () => {
  assertEquals(
    ADMIN_MANAGEABLE_COIN_STATUSES.join(","),
    "draft,published",
    "manageable statuses",
  );
});

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

Deno.test("maps nested database versions to the admin coin contract", () => {
  const coin = mapCoin({
    id: "10000000-0000-4000-8000-000000000001",
    slug: "example-coin",
    display_name: "Example Coin",
    description: "A test coin",
    sort_order: 4,
    is_featured: true,
    status: "draft",
    active_version_id: null,
    published_at: null,
    coin_versions: [{
      id: "20000000-0000-4000-8000-000000000001",
      coin_id: "10000000-0000-4000-8000-000000000001",
      version_number: 1,
      model_path: "coins/example-coin/v1/model.usdz",
      preview_path: "coins/example-coin/v1/preview.webp",
      model_byte_size: 123,
      model_sha256: "a".repeat(64),
      min_app_version: "1.0.0",
      asset_schema_version: 1,
      status: "draft",
      published_at: null,
    }],
  });

  assertEquals(coin.displayName, "Example Coin", "display name");
  assertEquals(coin.sortOrder, 4, "sort order");
  assertEquals(Array.isArray(coin.versions), true, "versions array");
  assertEquals(coin.versions?.[0]?.coinID, "10000000-0000-4000-8000-000000000001", "coin ID");
  assertEquals(coin.versions?.[0]?.versionNumber, 1, "version number");
  assertEquals(coin.versions?.[0]?.modelPath, "coins/example-coin/v1/model.usdz", "model path");
  assertEquals(coin.versions?.[0]?.previewPath, "coins/example-coin/v1/preview.webp", "preview path");
  assertEquals(coin.versions?.[0]?.modelByteSize, 123, "model byte size");
  assertEquals(coin.versions?.[0]?.modelSHA256, "a".repeat(64), "model SHA-256");
  assertEquals(coin.versions?.[0]?.minAppVersion, "1.0.0", "minimum app version");
  assertEquals(coin.versions?.[0]?.assetSchemaVersion, 1, "asset schema version");
  assertEquals(coin.versions?.[0]?.publishedAt, null, "published at");
  assertEquals("coin_versions" in coin, false, "raw nested versions omitted");
});

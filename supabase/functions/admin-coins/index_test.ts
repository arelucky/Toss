// deno-lint-ignore-file require-await

import {
  type AdminCoinDependencies,
  createAdminCoinsHandler,
} from "./handler.ts";

function assertEquals(actual: unknown, expected: unknown, message = "values differ") {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${message}: ${JSON.stringify(actual)} !== ${JSON.stringify(expected)}`);
  }
}

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

const adminID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const otherID = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const coinID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const versionID = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
const otherVersionID = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";
const sha256 = "a".repeat(64);

function request(body: unknown, token = "valid-jwt") {
  return new Request("http://localhost/admin-coins", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

async function body(response: Response) {
  return await response.json() as Record<string, unknown>;
}

function subject(overrides: Partial<AdminCoinDependencies> = {}) {
  const calls = {
    database: 0,
    storage: 0,
    publish: 0,
    rollback: 0,
    restore: 0,
    deletes: 0,
    createdVersion: null as Record<string, unknown> | null,
  };
  const dependencies: AdminCoinDependencies = {
    authenticate: async (jwt) => {
      if (jwt !== "valid-jwt") throw new Error("raw auth failure: service-role-value");
      return { userID: adminID };
    },
    adminUserID: () => adminID,
    listDrafts: async () => {
      calls.database++;
      return [];
    },
    createCoin: async (input) => {
      calls.database++;
      return { id: coinID, ...input, status: "draft" };
    },
    updateCoin: async (input) => {
      calls.database++;
      return input;
    },
    createVersion: async (input) => {
      calls.database++;
      calls.createdVersion = input as unknown as Record<string, unknown>;
      return { id: versionID, ...input, status: "draft" };
    },
    getCoin: async (id) => ({ id, slug: "classic-gold", status: "draft" }),
    getVersion: async (id) => ({
      id,
      coinID,
      versionNumber: 2,
      status: "draft",
      modelPath: "coins/classic-gold/v2/model.usdz",
      previewPath: "coins/classic-gold/v2/preview.webp",
    }),
    createSignedUploadURL: async () => {
      calls.storage++;
      return "https://storage.example/upload";
    },
    objectExists: async () => {
      calls.storage++;
      return true;
    },
    publishVersion: async () => {
      calls.publish++;
      return { coinID, versionID, coinStatus: "published", versionStatus: "published", activeVersionID: versionID };
    },
    rollbackVersion: async () => {
      calls.rollback++;
      return { coinID, activeVersionID: versionID };
    },
    hideCoin: async () => {
      calls.database++;
      return { coinID, status: "hidden" };
    },
    restoreCoin: async () => {
      calls.restore++;
      return { coinID, status: "published" };
    },
    ...overrides,
  };
  return { handler: createAdminCoinsHandler(dependencies), calls };
}

Deno.test("missing JWT returns 401 before any database access", async () => {
  const test = subject();
  const response = await test.handler(request({ action: "listDrafts" }, ""));
  assertEquals(response.status, 401);
  assertEquals(test.calls.database, 0);
});

Deno.test("valid JWT for a non-admin returns 403", async () => {
  const test = subject({ authenticate: async () => ({ userID: otherID }) });
  const response = await test.handler(request({ action: "listDrafts" }));
  assertEquals(response.status, 403);
  assertEquals(test.calls.database, 0);
});

Deno.test("unknown action returns 400", async () => {
  const test = subject();
  assertEquals((await test.handler(request({ action: "sellCoin" }))).status, 400);
  assertEquals(test.calls.database, 0);
});

Deno.test("validates slug and display name before database access", async () => {
  for (const slug of ["Bad Slug", "../classic", "a", "coin/one"]) {
    const test = subject();
    assertEquals((await test.handler(request({ action: "createCoin", slug, displayName: "Classic" }))).status, 400);
    assertEquals(test.calls.database, 0);
  }
});

Deno.test("validates UUIDs before database or storage access", async () => {
  for (const payload of [
    { action: "updateCoin", coinID: "bad", displayName: "Coin", sortOrder: 0, isFeatured: false },
    { action: "createVersion", coinID: "bad", versionNumber: 1, modelByteSize: 1, modelSHA256: sha256, minAppVersion: "1.0.0" },
    { action: "createUploadURL", versionID: "bad", asset: "model" },
    { action: "publishVersion", coinID, versionID: "bad" },
    { action: "rollbackVersion", coinID: "bad", versionID },
    { action: "hideCoin", coinID: "bad" },
    { action: "restoreCoin", coinID: "bad" },
  ]) {
    const test = subject();
    assertEquals((await test.handler(request(payload))).status, 400);
    assertEquals(test.calls.database + test.calls.storage, 0);
  }
});

Deno.test("validates version number, byte size, SHA-256, and app version", async () => {
  for (const fields of [
    { versionNumber: 0, modelByteSize: 1, modelSHA256: sha256, minAppVersion: "1.0.0" },
    { versionNumber: 1, modelByteSize: 0, modelSHA256: sha256, minAppVersion: "1.0.0" },
    { versionNumber: 1, modelByteSize: 52_428_801, modelSHA256: sha256, minAppVersion: "1.0.0" },
    { versionNumber: 1, modelByteSize: 1, modelSHA256: "ABC", minAppVersion: "1.0.0" },
    { versionNumber: 1, modelByteSize: 1, modelSHA256: sha256, minAppVersion: "latest" },
  ]) {
    const test = subject();
    const response = await test.handler(request({ action: "createVersion", coinID, ...fields }));
    assertEquals(response.status, 400);
    assertEquals(test.calls.database, 0);
  }
});

Deno.test("createVersion derives fixed model and preview paths", async () => {
  const test = subject();
  const response = await test.handler(request({
    action: "createVersion",
    coinID,
    versionNumber: 2,
    modelByteSize: 1024,
    modelSHA256: sha256,
    minAppVersion: "1.0.0",
  }));
  assertEquals(response.status, 200);
  assertEquals(test.calls.createdVersion?.modelPath, "coins/classic-gold/v2/model.usdz");
  assertEquals(test.calls.createdVersion?.previewPath, "coins/classic-gold/v2/preview.webp");
});

Deno.test("rejects a stored version whose paths do not match the fixed convention", async () => {
  const test = subject({
    getVersion: async () => ({
      id: versionID,
      coinID,
      versionNumber: 2,
      status: "draft",
      modelPath: "../model.usdz",
      previewPath: "coins/classic-gold/v2/preview.webp",
    }),
  });
  assertEquals((await test.handler(request({ action: "createUploadURL", versionID, asset: "model" }))).status, 409);
  assertEquals(test.calls.storage, 0);
});

Deno.test("published versions cannot receive replacement upload URLs", async () => {
  const test = subject({
    getVersion: async (id) => ({
      id,
      coinID,
      versionNumber: 2,
      status: "published",
      modelPath: "coins/classic-gold/v2/model.usdz",
      previewPath: "coins/classic-gold/v2/preview.webp",
    }),
  });
  assertEquals((await test.handler(request({ action: "createUploadURL", versionID, asset: "model" }))).status, 409);
  assertEquals(test.calls.storage, 0);
});

Deno.test("publish requires both model and preview objects", async () => {
  let checks = 0;
  const test = subject({ objectExists: async () => ++checks === 1 });
  const response = await test.handler(request({ action: "publishVersion", coinID, versionID }));
  assertEquals(response.status, 409);
  assertEquals(test.calls.publish, 0);
});

Deno.test("publish delegates one atomic state transition", async () => {
  const test = subject();
  const response = await test.handler(request({ action: "publishVersion", coinID, versionID }));
  assertEquals(response.status, 200);
  assertEquals(test.calls.publish, 1);
  assertEquals(await body(response), {
    coinID,
    versionID,
    coinStatus: "published",
    versionStatus: "published",
    activeVersionID: versionID,
  });
});

Deno.test("rollback only accepts a published version belonging to the same coin", async () => {
  for (const version of [
    { id: versionID, coinID: otherID, versionNumber: 1, status: "published", modelPath: "coins/other/v1/model.usdz", previewPath: "coins/other/v1/preview.webp" },
    { id: versionID, coinID, versionNumber: 1, status: "draft", modelPath: "coins/classic-gold/v1/model.usdz", previewPath: "coins/classic-gold/v1/preview.webp" },
  ]) {
    const test = subject({ getVersion: async () => version });
    assertEquals((await test.handler(request({ action: "rollbackVersion", coinID, versionID }))).status, 409);
    assertEquals(test.calls.rollback, 0);
  }
});

Deno.test("rollback delegates one atomic active-version transition", async () => {
  let rollbackCalls = 0;
  const test = subject({
    getVersion: async () => ({
      id: otherVersionID,
      coinID,
      versionNumber: 1,
      status: "published",
      modelPath: "coins/classic-gold/v1/model.usdz",
      previewPath: "coins/classic-gold/v1/preview.webp",
    }),
    rollbackVersion: async () => {
      rollbackCalls++;
      return { coinID, activeVersionID: otherVersionID };
    },
  });
  assertEquals((await test.handler(request({ action: "rollbackVersion", coinID, versionID: otherVersionID }))).status, 200);
  assertEquals(rollbackCalls, 1);
});

Deno.test("only published coins can be hidden and hiding never deletes storage", async () => {
  for (const [status, expectedStatus] of [["published", 200], ["draft", 409], ["hidden", 409]] as const) {
    const test = subject({ getCoin: async (id) => ({ id, slug: "classic-gold", status }) });
    assertEquals((await test.handler(request({ action: "hideCoin", coinID }))).status, expectedStatus);
    assertEquals(test.calls.deletes, 0);
  }
});

Deno.test("only hidden coins can be restored", async () => {
  const hidden = subject({ getCoin: async (id) => ({ id, slug: "classic-gold", status: "hidden" }) });
  assertEquals((await hidden.handler(request({ action: "restoreCoin", coinID }))).status, 200);
  assertEquals(hidden.calls.restore, 1);

  for (const status of ["draft", "published"]) {
    const test = subject({ getCoin: async (id) => ({ id, slug: "classic-gold", status }) });
    assertEquals((await test.handler(request({ action: "restoreCoin", coinID }))).status, 409);
  }
});

Deno.test("responses never leak secrets, JWTs, admin UUIDs, paths, or internal errors", async () => {
  const secret = "service-role-secret";
  const test = subject({ listDrafts: async () => { throw new Error(`${secret} ${adminID} coins/private/model.usdz internal SQL`); } });
  const response = await test.handler(request({ action: "listDrafts" }));
  assertEquals(response.status, 500);
  const serialized = JSON.stringify(await body(response));
  for (const forbidden of [secret, "valid-jwt", adminID, "coins/private", "internal SQL"]) {
    assert(!serialized.includes(forbidden), `response leaked ${forbidden}`);
  }
});

Deno.test("CORS preflight succeeds and error responses retain browser headers", async () => {
  const test = subject();
  const preflight = await test.handler(new Request("http://localhost/admin-coins", { method: "OPTIONS" }));

  assertEquals(preflight.status, 204);
  assert(preflight.headers.has("access-control-allow-origin"), "preflight must allow an origin");
  assert((preflight.headers.get("access-control-allow-methods") ?? "").includes("POST"), "preflight must allow POST");
  const allowedHeaders = (preflight.headers.get("access-control-allow-headers") ?? "").toLowerCase();
  for (const header of ["authorization", "apikey", "content-type", "x-client-info"]) {
    assert(allowedHeaders.includes(header), `preflight must allow ${header}`);
  }

  const unauthenticated = await test.handler(request({ action: "listDrafts" }, ""));
  assert(unauthenticated.headers.has("access-control-allow-origin"), "error response must allow an origin");
});

export type AdminCoinRequest =
  | { action: "listDrafts" }
  | { action: "createCoin"; slug: string; displayName: string; description?: string }
  | { action: "updateCoin"; coinID: string; displayName: string; description?: string; sortOrder: number; isFeatured: boolean }
  | { action: "createVersion"; coinID: string; versionNumber: number; modelByteSize: number; modelSHA256: string; minAppVersion: string }
  | { action: "createUploadURL"; versionID: string; asset: "model" | "preview" }
  | { action: "publishVersion"; coinID: string; versionID: string }
  | { action: "rollbackVersion"; coinID: string; versionID: string }
  | { action: "hideCoin"; coinID: string };

export interface CoinRecord {
  id: string;
  slug: string;
  status: string;
  [key: string]: unknown;
}

export interface CoinVersionRecord {
  id: string;
  coinID: string;
  versionNumber: number;
  status: string;
  modelPath: string;
  previewPath: string;
  [key: string]: unknown;
}

export interface CreateCoinInput {
  slug: string;
  displayName: string;
  description?: string;
}

export interface UpdateCoinInput {
  coinID: string;
  displayName: string;
  description?: string;
  sortOrder: number;
  isFeatured: boolean;
}

export interface CreateVersionInput {
  coinID: string;
  versionNumber: number;
  modelByteSize: number;
  modelSHA256: string;
  minAppVersion: string;
  modelPath: string;
  previewPath: string;
}

export interface AdminCoinDependencies {
  authenticate(jwt: string): Promise<{ userID: string }>;
  adminUserID(): string;
  listDrafts(): Promise<unknown>;
  createCoin(input: CreateCoinInput): Promise<unknown>;
  updateCoin(input: UpdateCoinInput): Promise<unknown>;
  createVersion(input: CreateVersionInput): Promise<unknown>;
  getCoin(coinID: string): Promise<CoinRecord | null>;
  getVersion(versionID: string): Promise<CoinVersionRecord | null>;
  createSignedUploadURL(bucket: "coin-models-free" | "coin-previews", path: string): Promise<string>;
  objectExists(bucket: "coin-models-free" | "coin-previews", path: string): Promise<boolean>;
  publishVersion(coinID: string, versionID: string): Promise<unknown>;
  rollbackVersion(coinID: string, versionID: string): Promise<unknown>;
  hideCoin(coinID: string): Promise<unknown>;
}

export class AdminCoinOperationError extends Error {
  constructor(readonly status: 404 | 409, readonly code: string) {
    super(code);
    this.name = "AdminCoinOperationError";
  }
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SLUG_PATTERN = /^[a-z0-9](?:[a-z0-9-]{1,62}[a-z0-9])$/;
const SHA256_PATTERN = /^[0-9a-f]{64}$/;
const APP_VERSION_PATTERN = /^[0-9]+\.[0-9]+\.[0-9]+$/;
const MAX_MODEL_BYTES = 52_428_800;

function json(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function bearerToken(request: Request) {
  const header = request.headers.get("authorization") ?? "";
  if (!header.startsWith("Bearer ")) return "";
  return header.slice(7).trim();
}

function constantTimeEqual(left: string, right: string) {
  const length = Math.max(left.length, right.length);
  let difference = left.length ^ right.length;
  for (let index = 0; index < length; index++) {
    difference |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }
  return difference === 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasOnlyKeys(value: Record<string, unknown>, allowed: readonly string[]) {
  return Object.keys(value).every((key) => allowed.includes(key));
}

function isUUID(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function isDisplayName(value: unknown): value is string {
  return typeof value === "string" && value === value.trim() && value.length >= 1 && value.length <= 80;
}

function isDescription(value: unknown): value is string | undefined {
  return value === undefined || (typeof value === "string" && value.length <= 500);
}

function isPositiveInteger(value: unknown, maximum = Number.MAX_SAFE_INTEGER): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0 && value <= maximum;
}

function parseRequest(value: unknown): AdminCoinRequest | null {
  if (!isRecord(value) || typeof value.action !== "string") return null;
  switch (value.action) {
    case "listDrafts":
      return hasOnlyKeys(value, ["action"]) ? { action: "listDrafts" } : null;
    case "createCoin":
      if (
        !hasOnlyKeys(value, ["action", "slug", "displayName", "description"]) ||
        typeof value.slug !== "string" || !SLUG_PATTERN.test(value.slug) ||
        !isDisplayName(value.displayName) || !isDescription(value.description)
      ) return null;
      return { action: value.action, slug: value.slug, displayName: value.displayName, ...(value.description === undefined ? {} : { description: value.description }) };
    case "updateCoin":
      if (
        !hasOnlyKeys(value, ["action", "coinID", "displayName", "description", "sortOrder", "isFeatured"]) ||
        !isUUID(value.coinID) || !isDisplayName(value.displayName) || !isDescription(value.description) ||
        typeof value.sortOrder !== "number" || !Number.isSafeInteger(value.sortOrder) ||
        typeof value.isFeatured !== "boolean"
      ) return null;
      return { action: value.action, coinID: value.coinID, displayName: value.displayName, ...(value.description === undefined ? {} : { description: value.description }), sortOrder: value.sortOrder, isFeatured: value.isFeatured };
    case "createVersion":
      if (
        !hasOnlyKeys(value, ["action", "coinID", "versionNumber", "modelByteSize", "modelSHA256", "minAppVersion"]) ||
        !isUUID(value.coinID) || !isPositiveInteger(value.versionNumber) ||
        !isPositiveInteger(value.modelByteSize, MAX_MODEL_BYTES) ||
        typeof value.modelSHA256 !== "string" || !SHA256_PATTERN.test(value.modelSHA256) ||
        typeof value.minAppVersion !== "string" || !APP_VERSION_PATTERN.test(value.minAppVersion)
      ) return null;
      return { action: value.action, coinID: value.coinID, versionNumber: value.versionNumber, modelByteSize: value.modelByteSize, modelSHA256: value.modelSHA256, minAppVersion: value.minAppVersion };
    case "createUploadURL":
      if (!hasOnlyKeys(value, ["action", "versionID", "asset"]) || !isUUID(value.versionID) || (value.asset !== "model" && value.asset !== "preview")) return null;
      return { action: value.action, versionID: value.versionID, asset: value.asset };
    case "publishVersion":
    case "rollbackVersion":
      if (!hasOnlyKeys(value, ["action", "coinID", "versionID"]) || !isUUID(value.coinID) || !isUUID(value.versionID)) return null;
      return { action: value.action, coinID: value.coinID, versionID: value.versionID };
    case "hideCoin":
      if (!hasOnlyKeys(value, ["action", "coinID"]) || !isUUID(value.coinID)) return null;
      return { action: value.action, coinID: value.coinID };
    default:
      return null;
  }
}

function fixedPaths(slug: string, versionNumber: number) {
  return {
    modelPath: `coins/${slug}/v${versionNumber}/model.usdz`,
    previewPath: `coins/${slug}/v${versionNumber}/preview.webp`,
  };
}

function pathsAreFixed(version: CoinVersionRecord, coin: CoinRecord) {
  const expected = fixedPaths(coin.slug, version.versionNumber);
  return version.modelPath === expected.modelPath && version.previewPath === expected.previewPath;
}

async function executeAction(action: AdminCoinRequest, dependencies: AdminCoinDependencies) {
  switch (action.action) {
    case "listDrafts":
      return await dependencies.listDrafts();
    case "createCoin":
      return await dependencies.createCoin(action);
    case "updateCoin":
      return await dependencies.updateCoin(action);
    case "createVersion": {
      const coin = await dependencies.getCoin(action.coinID);
      if (!coin) throw new AdminCoinOperationError(404, "coin_not_found");
      return await dependencies.createVersion({ ...action, ...fixedPaths(coin.slug, action.versionNumber) });
    }
    case "createUploadURL": {
      const version = await dependencies.getVersion(action.versionID);
      if (!version) throw new AdminCoinOperationError(404, "version_not_found");
      const coin = await dependencies.getCoin(version.coinID);
      if (!coin) throw new AdminCoinOperationError(404, "coin_not_found");
      if (version.status !== "draft" || !pathsAreFixed(version, coin)) {
        throw new AdminCoinOperationError(409, "version_not_uploadable");
      }
      const bucket = action.asset === "model" ? "coin-models-free" : "coin-previews";
      const path = action.asset === "model" ? version.modelPath : version.previewPath;
      return { uploadURL: await dependencies.createSignedUploadURL(bucket, path) };
    }
    case "publishVersion": {
      const coin = await dependencies.getCoin(action.coinID);
      const version = await dependencies.getVersion(action.versionID);
      if (!coin || !version) throw new AdminCoinOperationError(404, "resource_not_found");
      if (version.coinID !== coin.id || version.status !== "draft" || !pathsAreFixed(version, coin)) {
        throw new AdminCoinOperationError(409, "version_not_publishable");
      }
      if (!await dependencies.objectExists("coin-models-free", version.modelPath)) {
        throw new AdminCoinOperationError(409, "model_object_missing");
      }
      if (!await dependencies.objectExists("coin-previews", version.previewPath)) {
        throw new AdminCoinOperationError(409, "preview_object_missing");
      }
      return await dependencies.publishVersion(action.coinID, action.versionID);
    }
    case "rollbackVersion": {
      const version = await dependencies.getVersion(action.versionID);
      if (!version) throw new AdminCoinOperationError(404, "version_not_found");
      if (version.coinID !== action.coinID || version.status !== "published") {
        throw new AdminCoinOperationError(409, "version_not_rollbackable");
      }
      return await dependencies.rollbackVersion(action.coinID, action.versionID);
    }
    case "hideCoin":
      return await dependencies.hideCoin(action.coinID);
  }
}

export async function handleAdminCoinRequest(
  request: Request,
  dependencies: AdminCoinDependencies,
): Promise<Response> {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
  const jwt = bearerToken(request);
  if (!jwt) return json(401, { error: "authentication_required" });

  let userID: string;
  try {
    userID = (await dependencies.authenticate(jwt)).userID;
  } catch {
    return json(401, { error: "authentication_required" });
  }

  if (!constantTimeEqual(userID, dependencies.adminUserID())) {
    return json(403, { error: "admin_access_required" });
  }

  let requestBody: unknown;
  try {
    requestBody = await request.json();
  } catch {
    return json(400, { error: "invalid_request" });
  }
  const action = parseRequest(requestBody);
  if (!action) return json(400, { error: "invalid_request" });

  try {
    return json(200, await executeAction(action, dependencies));
  } catch (error) {
    if (error instanceof AdminCoinOperationError) {
      return json(error.status, { error: error.code });
    }
    return json(500, { error: "admin_coin_operation_failed" });
  }
}

export function createAdminCoinsHandler(dependencies: AdminCoinDependencies) {
  return (request: Request) => handleAdminCoinRequest(request, dependencies);
}

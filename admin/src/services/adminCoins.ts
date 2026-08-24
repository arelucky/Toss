import { getSupabaseClient } from "../lib/supabase";

export const MAX_MODEL_BYTES = 52_428_800;
export const MAX_PREVIEW_BYTES = 2_097_152;
const coinSlugPattern = /^[a-z0-9](?:[a-z0-9-]{1,62}[a-z0-9])$/;

export type AdminCoinRequest =
  | { action: "listDrafts" }
  | { action: "createCoin"; slug: string; displayName: string; description?: string }
  | { action: "updateCoin"; coinID: string; displayName: string; description?: string; sortOrder: number; isFeatured: boolean }
  | { action: "createVersion"; coinID: string; versionNumber: number; modelByteSize: number; modelSHA256: string; minAppVersion: string }
  | { action: "createUploadURL"; versionID: string; asset: "model" | "preview" }
  | { action: "publishVersion"; coinID: string; versionID: string }
  | { action: "rollbackVersion"; coinID: string; versionID: string }
  | { action: "hideCoin"; coinID: string };

export interface CoinVersion {
  id: string;
  versionNumber: number;
  status: string;
}

export interface AdminCoin {
  id: string;
  slug?: string;
  displayName: string;
  description?: string;
  sortOrder: number;
  isFeatured: boolean;
  activeVersionID?: string;
  status?: string;
  versions?: CoinVersion[];
  coin_versions?: Array<Record<string, unknown>>;
}

interface InvokeResult { data: unknown; error: { context?: { status?: number }; message?: string } | null }
interface ServiceDependencies {
  invoke(name: string, options: { body: AdminCoinRequest; headers: { Authorization: string } }): Promise<InvokeResult>;
  session(): Promise<{ access_token: string } | null>;
}

export class AdminCoinsError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
    this.name = "AdminCoinsError";
  }
}

function safeMessage(status: number) {
  if (status === 401) return "会话已过期，请重新登录。";
  if (status === 403) return "您无权访问此管理后台。";
  if (status === 409) return "此操作与当前硬币版本冲突。";
  return "管理服务暂时无法完成此操作。";
}

export function createAdminCoinsService(dependencies: ServiceDependencies) {
  async function action<T>(body: AdminCoinRequest): Promise<T> {
    const session = await dependencies.session();
    if (!session) throw new AdminCoinsError(401, safeMessage(401));
    const { data, error } = await dependencies.invoke("admin-coins", {
      body,
      headers: { Authorization: `Bearer ${session.access_token}` },
    });
    if (error) {
      const status = error.context?.status ?? 500;
      throw new AdminCoinsError(status, safeMessage(status));
    }
    return data as T;
  }

  return {
    action,
    listDrafts: () => action<AdminCoin[]>({ action: "listDrafts" }),
  };
}

export const adminCoins = createAdminCoinsService({
  session: async () => {
    const { data } = await getSupabaseClient().auth.getSession();
    return data.session ? { access_token: data.session.access_token } : null;
  },
  invoke: async (name, options) => {
    const result = await getSupabaseClient().functions.invoke(name, options);
    return { data: result.data, error: result.error };
  },
});

type Validation = { ok: true } | { ok: false; error: string };

function validateFile(file: File, extension: string, maximum: number, typeLabel: string): Validation {
  if (!file.name.toLowerCase().endsWith(extension)) return { ok: false, error: `需要 ${typeLabel} 文件` };
  if (file.size <= 0 || file.size > maximum) return { ok: false, error: `${typeLabel} 文件大小无效` };
  return { ok: true };
}

export const validateModelFile = (file: File) => validateFile(file, ".usdz", MAX_MODEL_BYTES, "USDZ");
export const validatePreviewFile = (file: File) => validateFile(file, ".webp", MAX_PREVIEW_BYTES, "WEBP");

export function validateCoinSlug(slug: string): boolean {
  return coinSlugPattern.test(slug);
}

function readBlobAsArrayBuffer(blob: Blob): Promise<ArrayBuffer> {
  const nativeArrayBuffer = (blob as Blob & { arrayBuffer?: () => Promise<ArrayBuffer> }).arrayBuffer;
  if (typeof nativeArrayBuffer === "function") return nativeArrayBuffer.call(blob);

  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      if (reader.result instanceof ArrayBuffer) resolve(reader.result);
      else reject(new Error("无法读取文件数据。"));
    };
    reader.onerror = () => reject(reader.error ?? new Error("无法读取文件数据。"));
    reader.onabort = () => reject(new Error("文件读取已取消。"));
    reader.readAsArrayBuffer(blob);
  });
}

export async function sha256Hex(file: Blob) {
  const sourceBuffer = await readBlobAsArrayBuffer(file);
  const sourceBytes = new Uint8Array(sourceBuffer);
  const digestBytes = new Uint8Array(sourceBytes.byteLength);
  digestBytes.set(sourceBytes);
  const digest = await crypto.subtle.digest("SHA-256", digestBytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

interface UploadInput {
  coinID: string;
  versionNumber: number;
  minAppVersion: string;
  model: File;
  preview: File;
}

interface UploadDependencies {
  action(request: AdminCoinRequest): Promise<unknown>;
  upload(url: string, file: File): Promise<unknown>;
}

export async function uploadVersionAssets(input: UploadInput, dependencies: UploadDependencies) {
  const modelValidation = validateModelFile(input.model);
  if (!modelValidation.ok) throw new Error(modelValidation.error);
  const previewValidation = validatePreviewFile(input.preview);
  if (!previewValidation.ok) throw new Error(previewValidation.error);

  const version = await dependencies.action({
    action: "createVersion",
    coinID: input.coinID,
    versionNumber: input.versionNumber,
    modelByteSize: input.model.size,
    modelSHA256: await sha256Hex(input.model),
    minAppVersion: input.minAppVersion,
  }) as { id: string };
  const modelURL = await dependencies.action({ action: "createUploadURL", versionID: version.id, asset: "model" }) as { uploadURL: string };
  await dependencies.upload(modelURL.uploadURL, input.model);
  const previewURL = await dependencies.action({ action: "createUploadURL", versionID: version.id, asset: "preview" }) as { uploadURL: string };
  await dependencies.upload(previewURL.uploadURL, input.preview);
  return await dependencies.action({ action: "listDrafts" });
}

export async function putSignedFile(url: string, file: File) {
  const response = await fetch(url, { method: "PUT", body: file, headers: { "content-type": file.type || "application/octet-stream" } });
  if (!response.ok) throw new AdminCoinsError(500, safeMessage(500));
}

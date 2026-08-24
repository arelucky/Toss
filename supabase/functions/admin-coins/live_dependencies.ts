import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.49.8";
import {
  AdminCoinOperationError,
  type AdminCoinDependencies,
  type CoinRecord,
  type CoinVersionRecord,
  type CreateCoinInput,
  type CreateVersionInput,
  type UpdateCoinInput,
} from "./handler.ts";

type CoinRow = {
  id: string;
  slug: string;
  display_name?: string;
  description?: string | null;
  sort_order?: number;
  is_featured?: boolean;
  status: string;
  active_version_id?: string | null;
  published_at?: string | null;
  coin_versions?: VersionRow[];
};

type VersionRow = {
  id: string;
  coin_id: string;
  version_number: number;
  model_path: string;
  preview_path: string;
  model_byte_size?: number;
  model_sha256?: string;
  min_app_version?: string;
  asset_schema_version?: number;
  status: string;
  published_at?: string | null;
};

export const ADMIN_MANAGEABLE_COIN_STATUSES = ["draft", "published", "hidden"] as const;

function requiredEnvironment(name: string) {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server configuration: ${name}`);
  return value;
}

export function replaceSignedUploadURLOrigin(
  signedURL: string,
  publicSupabaseURL: string,
) {
  const result = new URL(signedURL);
  const publicURL = new URL(publicSupabaseURL);
  result.protocol = publicURL.protocol;
  result.host = publicURL.host;
  return result.toString();
}

export function mapCoin(row: CoinRow): CoinRecord & { versions: CoinVersionRecord[] } {
  return {
    id: row.id,
    slug: row.slug,
    status: row.status,
    displayName: row.display_name,
    description: row.description,
    sortOrder: row.sort_order,
    isFeatured: row.is_featured,
    activeVersionID: row.active_version_id,
    publishedAt: row.published_at,
    versions: (row.coin_versions ?? []).map(mapVersion),
  };
}

function mapVersion(row: VersionRow): CoinVersionRecord {
  return {
    id: row.id,
    coinID: row.coin_id,
    versionNumber: row.version_number,
    modelPath: row.model_path,
    previewPath: row.preview_path,
    status: row.status,
    modelByteSize: row.model_byte_size,
    modelSHA256: row.model_sha256,
    minAppVersion: row.min_app_version,
    assetSchemaVersion: row.asset_schema_version,
    publishedAt: row.published_at,
  };
}

function conflictOrServer(error: { code?: string } | null) {
  if (error?.code === "23505") throw new AdminCoinOperationError(409, "resource_conflict");
  throw new Error("admin dependency failed");
}

function rpcError(error: { message?: string } | null) {
  const code = error?.message;
  if (code === "coin_not_found" || code === "version_not_found") {
    throw new AdminCoinOperationError(404, "resource_not_found");
  }
  if (
    code === "version_coin_mismatch" || code === "version_not_draft" ||
    code === "version_not_published" || code === "model_object_missing" ||
    code === "preview_object_missing"
  ) {
    throw new AdminCoinOperationError(409, "invalid_version_transition");
  }
  throw new Error("admin dependency failed");
}

async function requireUpdatedCoin(client: SupabaseClient, input: Record<string, unknown>) {
  const { data, error } = await client.from("coins").update(input.values).eq("id", input.id).select("*").maybeSingle<CoinRow>();
  if (error) conflictOrServer(error);
  if (!data) throw new AdminCoinOperationError(404, "coin_not_found");
  return mapCoin(data);
}

export function createLiveDependencies(): AdminCoinDependencies {
  const supabaseURL = requiredEnvironment("SUPABASE_URL");
  const publicSupabaseURL = Deno.env.get("TOSS_PUBLIC_SUPABASE_URL")?.trim() ||
    supabaseURL;
  const publishableKey = requiredEnvironment("SUPABASE_ANON_KEY");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const configuredAdminID = requiredEnvironment("TOSS_ADMIN_USER_ID");
  const authClient = createClient(supabaseURL, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const serviceClient = createClient(supabaseURL, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });

  return {
    authenticate: async (jwt) => {
      const { data, error } = await authClient.auth.getUser(jwt);
      if (error || !data.user) throw new Error("authentication failed");
      return { userID: data.user.id };
    },
    adminUserID: () => configuredAdminID,
    listDrafts: async () => {
      const { data, error } = await serviceClient.from("coins").select("*,coin_versions!coin_versions_coin_id_fkey(*)").in("status", ADMIN_MANAGEABLE_COIN_STATUSES).order("sort_order").order("slug");
      if (error) throw new Error("admin dependency failed");
      return (data ?? []).map(mapCoin);
    },
    createCoin: async (input: CreateCoinInput) => {
      const { data, error } = await serviceClient.from("coins").insert({
        slug: input.slug,
        display_name: input.displayName,
        description: input.description ?? null,
        status: "draft",
      }).select("*").single<CoinRow>();
      if (error) conflictOrServer(error);
      if (!data) throw new Error("admin dependency failed");
      return mapCoin(data);
    },
    updateCoin: async (input: UpdateCoinInput) => await requireUpdatedCoin(serviceClient, {
      id: input.coinID,
      values: {
        display_name: input.displayName,
        description: input.description ?? null,
        sort_order: input.sortOrder,
        is_featured: input.isFeatured,
      },
    }),
    createVersion: async (input: CreateVersionInput) => {
      const { data, error } = await serviceClient.from("coin_versions").insert({
        coin_id: input.coinID,
        version_number: input.versionNumber,
        model_path: input.modelPath,
        preview_path: input.previewPath,
        model_byte_size: input.modelByteSize,
        model_sha256: input.modelSHA256,
        min_app_version: input.minAppVersion,
        status: "draft",
      }).select("*").single<VersionRow>();
      if (error) conflictOrServer(error);
      if (!data) throw new Error("admin dependency failed");
      return mapVersion(data);
    },
    getCoin: async (coinID) => {
      const { data, error } = await serviceClient.from("coins").select("*").eq("id", coinID).maybeSingle<CoinRow>();
      if (error) throw new Error("admin dependency failed");
      return data ? mapCoin(data) : null;
    },
    getVersion: async (versionID) => {
      const { data, error } = await serviceClient.from("coin_versions").select("*").eq("id", versionID).maybeSingle<VersionRow>();
      if (error) throw new Error("admin dependency failed");
      return data ? mapVersion(data) : null;
    },
    createSignedUploadURL: async (bucket, path) => {
      const { data, error } = await serviceClient.storage.from(bucket).createSignedUploadUrl(path, { upsert: false });
      if (error || !data?.signedUrl) throw new Error("admin dependency failed");
      return replaceSignedUploadURLOrigin(data.signedUrl, publicSupabaseURL);
    },
    objectExists: async (bucket, path) => {
      const separator = path.lastIndexOf("/");
      const directory = path.slice(0, separator);
      const filename = path.slice(separator + 1);
      const { data, error } = await serviceClient.storage.from(bucket).list(directory, { limit: 2, search: filename });
      if (error) throw new Error("admin dependency failed");
      return (data ?? []).some((object) => object.name === filename);
    },
    publishVersion: async (coinID, versionID) => {
      const { error } = await serviceClient.rpc("admin_publish_coin_version", { p_coin_id: coinID, p_version_id: versionID });
      if (error) rpcError(error);
      return { coinID, versionID, coinStatus: "published", versionStatus: "published", activeVersionID: versionID };
    },
    rollbackVersion: async (coinID, versionID) => {
      const { error } = await serviceClient.rpc("admin_rollback_coin_version", { p_coin_id: coinID, p_version_id: versionID });
      if (error) rpcError(error);
      return { coinID, activeVersionID: versionID };
    },
    hideCoin: async (coinID) => await requireUpdatedCoin(serviceClient, {
      id: coinID,
      values: { status: "hidden" },
    }),
    restoreCoin: async (coinID) => await requireUpdatedCoin(serviceClient, {
      id: coinID,
      values: { status: "published" },
    }),
  };
}

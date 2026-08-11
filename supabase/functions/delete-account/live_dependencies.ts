import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.49.8";
import {
  createRemoteJWKSet,
  decodeJwt,
  importPKCS8,
  jwtVerify,
  SignJWT,
} from "npm:jose@5.9.6";
import type {
  AccountDeletionDependencies,
  AccountDeletionRequestRecord,
  AppleRevocationStatus,
  VerifiedCaller,
} from "./handler.ts";

type DatabaseRecord = {
  request_id: string;
  status: "requested" | "processing" | "completed";
  requested_at: string;
  completed_at: string | null;
  apple_revocation_status: AppleRevocationStatus;
};

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_TOKEN_URL = `${APPLE_ISSUER}/auth/token`;
const APPLE_REVOKE_URL = `${APPLE_ISSUER}/auth/revoke`;
const APPLE_JWKS = createRemoteJWKSet(new URL(`${APPLE_ISSUER}/auth/keys`));

function requiredEnvironment(name: string) {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server configuration: ${name}`);
  return value;
}

function mapRecord(record: DatabaseRecord): AccountDeletionRequestRecord {
  return {
    requestID: record.request_id,
    status: record.status,
    requestedAt: record.requested_at,
    completedAt: record.completed_at,
    appleRevocationStatus: record.apple_revocation_status,
  };
}

type IdentityCandidate = {
  provider?: unknown;
  identity_data?: Record<string, unknown> | null;
};

export function appleProviderSubjects(identities: readonly IdentityCandidate[] | null | undefined) {
  return (identities ?? []).flatMap((identity) => {
    if (identity.provider !== "apple") return [];
    const subject = identity.identity_data?.sub;
    if (typeof subject !== "string") return [];
    return subject.trim().length > 0 ? [subject] : [];
  });
}

export function matchesAppleProviderSubject(
  providerSubjects: readonly string[],
  tokenSubject: unknown,
) {
  return typeof tokenSubject === "string" && providerSubjects.includes(tokenSubject);
}

async function createAppleClientSecret(now: Date) {
  const teamID = requiredEnvironment("APPLE_TEAM_ID");
  const keyID = requiredEnvironment("APPLE_KEY_ID");
  const clientID = requiredEnvironment("APPLE_CLIENT_ID");
  const privateKey = requiredEnvironment("APPLE_PRIVATE_KEY").replaceAll("\\n", "\n");
  const key = await importPKCS8(privateKey, "ES256");
  const issuedAt = Math.floor(now.getTime() / 1_000);
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyID })
    .setIssuer(teamID)
    .setSubject(clientID)
    .setAudience(APPLE_ISSUER)
    .setIssuedAt(issuedAt)
    .setExpirationTime(issuedAt + 300)
    .sign(key);
}

async function postApple(url: string, values: Record<string, string>) {
  return await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(values),
  });
}

function identityMismatch() {
  return Object.assign(new Error("Apple identity mismatch"), { code: "identity_mismatch" });
}

async function revokeApple(
  authorizationCode: string,
  caller: VerifiedCaller,
  now: Date,
): Promise<AppleRevocationStatus> {
  try {
    const clientID = requiredEnvironment("APPLE_CLIENT_ID");
    const clientSecret = await createAppleClientSecret(now);
    const exchange = await postApple(APPLE_TOKEN_URL, {
      client_id: clientID,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    });
    if (!exchange.ok) {
      const error = await exchange.json().catch(() => ({})) as { error?: string };
      return error.error === "invalid_grant" ? "already_invalid" : "manual_required";
    }
    const token = await exchange.json() as { refresh_token?: string; id_token?: string };
    if (!token.refresh_token || !token.id_token) return "manual_required";
    const verifiedAppleToken = await jwtVerify(token.id_token, APPLE_JWKS, {
      issuer: APPLE_ISSUER,
      audience: clientID,
    });
    const tokenSubject = verifiedAppleToken.payload.sub;
    if (!matchesAppleProviderSubject(caller.appleSubjects, tokenSubject)) throw identityMismatch();
    const revoke = await postApple(APPLE_REVOKE_URL, {
      client_id: clientID,
      client_secret: clientSecret,
      token: token.refresh_token,
      token_type_hint: "refresh_token",
    });
    if (revoke.ok) return "revoked";
    const error = await revoke.json().catch(() => ({})) as { error?: string };
    return error.error === "invalid_token" ? "already_invalid" : "manual_required";
  } catch (error) {
    if (typeof error === "object" && error !== null && "code" in error && error.code === "identity_mismatch") {
      throw error;
    }
    return "manual_required";
  }
}

class SupabaseDeletionRequestStore {
  constructor(private readonly client: SupabaseClient) {}

  async getRequest(requestID: string) {
    const { data, error } = await this.client
      .from("account_deletion_requests")
      .select("request_id,status,requested_at,completed_at,apple_revocation_status")
      .eq("request_id", requestID)
      .maybeSingle<DatabaseRecord>();
    if (error) throw error;
    return data ? mapRecord(data) : null;
  }

  async insertRequested(requestID: string) {
    const { data, error } = await this.client
      .from("account_deletion_requests")
      .upsert({ request_id: requestID }, { onConflict: "request_id", ignoreDuplicates: true })
      .select("request_id,status,requested_at,completed_at,apple_revocation_status")
      .maybeSingle<DatabaseRecord>();
    if (error) throw error;
    return data ? mapRecord(data) : await this.requireRequest(requestID);
  }

  async claimRequest(requestID: string) {
    const { data, error } = await this.client
      .from("account_deletion_requests")
      .update({ status: "processing" })
      .eq("request_id", requestID)
      .eq("status", "requested")
      .select("request_id,status,requested_at,completed_at,apple_revocation_status")
      .maybeSingle<DatabaseRecord>();
    if (error) throw error;
    if (data) return mapRecord(data);
    const existing = await this.getRequest(requestID);
    return existing?.status === "processing" ? existing : null;
  }

  async resetRequest(requestID: string, appleStatus: AppleRevocationStatus) {
    const { error } = await this.client
      .from("account_deletion_requests")
      .update({ status: "requested", completed_at: null, apple_revocation_status: appleStatus })
      .eq("request_id", requestID)
      .eq("status", "processing");
    if (error) throw error;
  }

  async completeRequest(requestID: string, appleStatus: AppleRevocationStatus) {
    const { data, error } = await this.client
      .from("account_deletion_requests")
      .update({ status: "completed", completed_at: new Date().toISOString(), apple_revocation_status: appleStatus })
      .eq("request_id", requestID)
      .eq("status", "processing")
      .select("request_id,status,requested_at,completed_at,apple_revocation_status")
      .maybeSingle<DatabaseRecord>();
    if (error) throw error;
    if (data) return mapRecord(data);
    return await this.requireRequest(requestID);
  }

  private async requireRequest(requestID: string) {
    const record = await this.getRequest(requestID);
    if (!record) throw new Error("Deletion request missing");
    return record;
  }
}

export function createLiveDependencies(): AccountDeletionDependencies {
  const supabaseURL = requiredEnvironment("SUPABASE_URL");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const client = createClient(supabaseURL, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const store = new SupabaseDeletionRequestStore(client);
  return {
    now: () => new Date(),
    authenticate: async (jwt) => {
      const { data, error } = await client.auth.getUser(jwt);
      if (error || !data.user) throw error ?? new Error("Unauthenticated");
      const payload = decodeJwt(jwt);
      if (typeof payload.iat !== "number") throw new Error("Missing issued-at evidence");
      const providers = data.user.app_metadata.providers;
      const hasAppleProvider = data.user.app_metadata.provider === "apple" ||
        (Array.isArray(providers) && providers.includes("apple"));
      if (!hasAppleProvider) throw new Error("Recent Apple authentication required");
      const appleSubjects = appleProviderSubjects(data.user.identities);
      if (appleSubjects.length === 0) throw new Error("Apple identity required");
      return {
        userID: data.user.id,
        appleSubjects,
        authenticatedAt: new Date(payload.iat * 1_000),
      };
    },
    getRequest: (id) => store.getRequest(id),
    insertRequested: (id) => store.insertRequested(id),
    claimRequest: (id) => store.claimRequest(id),
    resetRequest: (id, status) => store.resetRequest(id, status),
    completeRequest: (id, status) => store.completeRequest(id, status),
    revokeApple: (code, caller) => revokeApple(code, caller, new Date()),
    deleteUser: async (userID) => {
      const { error } = await client.auth.admin.deleteUser(userID);
      if (!error) return "deleted";
      const message = error.message.toLowerCase();
      if (message.includes("not found") || message.includes("does not exist")) return "already_absent";
      throw error;
    },
    log: (category, requestID) => console.info(JSON.stringify({ category, requestID })),
  };
}

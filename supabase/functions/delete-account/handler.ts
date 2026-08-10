export type DeletionRequestStatus = "requested" | "processing" | "completed";
export type AppleRevocationStatus = "pending" | "revoked" | "already_invalid" | "manual_required";

export interface AccountDeletionRequestRecord {
  requestID: string;
  status: DeletionRequestStatus;
  requestedAt: string;
  completedAt: string | null;
  appleRevocationStatus: AppleRevocationStatus;
}

export interface VerifiedCaller {
  userID: string;
  appleSubject: string;
  authenticatedAt: Date;
}

export interface AccountDeletionDependencies {
  now(): Date;
  authenticate(jwt: string): Promise<VerifiedCaller>;
  getRequest(requestID: string): Promise<AccountDeletionRequestRecord | null>;
  insertRequested(requestID: string): Promise<AccountDeletionRequestRecord>;
  claimRequest(requestID: string): Promise<AccountDeletionRequestRecord | null>;
  resetRequest(requestID: string, appleStatus: AppleRevocationStatus): Promise<void>;
  completeRequest(requestID: string, appleStatus: AppleRevocationStatus): Promise<AccountDeletionRequestRecord>;
  revokeApple(authorizationCode: string, caller: VerifiedCaller): Promise<AppleRevocationStatus>;
  deleteUser(userID: string): Promise<"deleted" | "already_absent">;
  log(category: string, requestID: string): void;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_REAUTH_AGE_MS = 5 * 60 * 1_000;

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function terminalResponse(record: AccountDeletionRequestRecord) {
  return json(200, {
    deleted: true,
    requestID: record.requestID,
    appleRevocation: record.appleRevocationStatus,
  });
}

function bearerToken(request: Request) {
  const value = request.headers.get("authorization") ?? "";
  return value.startsWith("Bearer ") ? value.slice(7).trim() : "";
}

function isIdentityMismatch(error: unknown) {
  return typeof error === "object" && error !== null && "code" in error && error.code === "identity_mismatch";
}

export function createDeleteAccountHandler(dependencies: AccountDeletionDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") return json(405, { deleted: false, error: "method_not_allowed" });

    let caller: VerifiedCaller;
    try {
      const token = bearerToken(request);
      if (!token) throw new Error("missing authorization");
      caller = await dependencies.authenticate(token);
      const age = dependencies.now().getTime() - caller.authenticatedAt.getTime();
      if (age < 0 || age > MAX_REAUTH_AGE_MS) throw new Error("stale reauthentication");
    } catch {
      return json(401, { deleted: false, error: "recent_authentication_required" });
    }

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return json(400, { deleted: false, error: "invalid_request" });
    }
    const keys = Object.keys(body);
    const requestID = typeof body.requestID === "string" ? body.requestID : "";
    const authorizationCode = typeof body.authorizationCode === "string" ? body.authorizationCode : "";
    if (
      keys.some((key) => key !== "requestID" && key !== "authorizationCode") ||
      !UUID_PATTERN.test(requestID) ||
      authorizationCode.length === 0
    ) {
      return json(400, { deleted: false, error: "invalid_request" });
    }

    try {
      const existing = await dependencies.getRequest(requestID);
      if (existing?.status === "completed") return terminalResponse(existing);
      if (!existing) await dependencies.insertRequested(requestID);
      const claimed = await dependencies.claimRequest(requestID);
      if (!claimed) return json(409, { deleted: false, error: "request_in_progress" });

      let appleStatus: AppleRevocationStatus;
      try {
        appleStatus = await dependencies.revokeApple(authorizationCode, caller);
      } catch (error) {
        if (isIdentityMismatch(error)) {
          await dependencies.resetRequest(requestID, "pending");
          dependencies.log("identity_mismatch", requestID);
          return json(422, { deleted: false, error: "identity_mismatch" });
        }
        appleStatus = "manual_required";
      }

      try {
        await dependencies.deleteUser(caller.userID);
      } catch {
        await dependencies.resetRequest(requestID, appleStatus);
        dependencies.log("data_deletion_failed", requestID);
        return json(500, { deleted: false, error: "data_deletion_failed" });
      }

      const completed = await dependencies.completeRequest(requestID, appleStatus);
      dependencies.log("completed", requestID);
      return terminalResponse(completed);
    } catch {
      dependencies.log("request_state_failed", requestID);
      return json(500, { deleted: false, error: "data_deletion_failed" });
    }
  };
}

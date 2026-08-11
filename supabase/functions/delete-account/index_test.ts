import {
  createDeleteAccountHandler,
  type AccountDeletionDependencies,
  type AccountDeletionRequestRecord,
  type AppleRevocationStatus,
  type VerifiedCaller,
} from "./handler.ts";

const requestID = "90000000-0000-4000-8000-000000000001";
const userID = "90000000-0000-4000-8000-000000000002";

function assert(condition: unknown, message = "assertion failed"): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown, message = "values differ") {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${message}: ${JSON.stringify(actual)} !== ${JSON.stringify(expected)}`);
  }
}

function jsonRequest(
  body: Record<string, unknown> = { requestID, authorizationCode: "fictional-authorization-code" },
  token = "fictional-verified-jwt",
) {
  return new Request("http://localhost/delete-account", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function makeDependencies(overrides: Partial<AccountDeletionDependencies> = {}) {
  const records = new Map<string, AccountDeletionRequestRecord>();
  const calls = { authenticate: 0, apple: 0, deleteUser: 0 };
  const logs: string[] = [];
  const caller: VerifiedCaller = {
    userID,
    appleSubjects: ["fictional-apple-subject"],
    authenticatedAt: new Date("2026-08-10T07:00:00Z"),
  };
  const dependencies: AccountDeletionDependencies = {
    now: () => new Date("2026-08-10T07:03:00Z"),
    authenticate: async () => { calls.authenticate += 1; return caller; },
    getRequest: async (id) => records.get(id) ?? null,
    insertRequested: async (id) => {
      const existing = records.get(id);
      if (existing) return existing;
      const record: AccountDeletionRequestRecord = {
        requestID: id,
        status: "requested",
        requestedAt: "2026-08-10T07:03:00Z",
        completedAt: null,
        appleRevocationStatus: "pending",
      };
      records.set(id, record);
      return record;
    },
    claimRequest: async (id) => {
      const record = records.get(id);
      if (!record || record.status === "completed") return record ?? null;
      const claimed = { ...record, status: "processing" as const };
      records.set(id, claimed);
      return claimed;
    },
    resetRequest: async (id, appleRevocationStatus) => {
      const record = records.get(id)!;
      records.set(id, { ...record, status: "requested", appleRevocationStatus, completedAt: null });
    },
    completeRequest: async (id, appleRevocationStatus) => {
      const record = records.get(id)!;
      const completed = {
        ...record,
        status: "completed" as const,
        completedAt: "2026-08-10T07:03:00Z",
        appleRevocationStatus,
      };
      records.set(id, completed);
      return completed;
    },
    revokeApple: async () => { calls.apple += 1; return "revoked"; },
    deleteUser: async () => { calls.deleteUser += 1; return "deleted"; },
    log: (category, id) => logs.push(`${category}:${id}`),
    ...overrides,
  };
  return { handler: createDeleteAccountHandler(dependencies), dependencies, records, calls, logs, caller };
}

async function responseJSON(response: Response) {
  return await response.json() as Record<string, unknown>;
}

Deno.test("rejects an unauthenticated request", async () => {
  const subject = makeDependencies({ authenticate: async () => { throw new Error("unauthorized"); } });
  const response = await subject.handler(jsonRequest({}, "invalid"));
  assertEquals(response.status, 401);
  assertEquals(subject.calls.apple, 0);
  assertEquals(subject.calls.deleteUser, 0);
});
Deno.test("rejects malformed input and never trusts a client user id", async () => {
  const subject = makeDependencies();
  const malformed = await subject.handler(jsonRequest({ requestID: "not-a-uuid", authorizationCode: "" }));
  assertEquals(malformed.status, 400);
  const injected = await subject.handler(jsonRequest({ requestID, authorizationCode: "code", userID }));
  assertEquals(injected.status, 400);
  assertEquals(subject.calls.apple, 0);
});

Deno.test("rejects stale Apple reauthentication evidence", async () => {
  const subject = makeDependencies({
    authenticate: async () => ({
      userID,
      appleSubjects: ["fictional-apple-subject"],
      authenticatedAt: new Date("2026-08-10T06:00:00Z"),
    }),
  });
  const response = await subject.handler(jsonRequest());
  assertEquals(response.status, 401);
  assertEquals(subject.calls.apple, 0);
});

Deno.test("rejects Apple identity mismatch without deleting data", async () => {
  const subject = makeDependencies({
    revokeApple: async () => { throw Object.assign(new Error("identity mismatch"), { code: "identity_mismatch" }); },
  });
  const response = await subject.handler(jsonRequest());
  assertEquals(response.status, 422);
  assertEquals(subject.calls.deleteUser, 0);
  assertEquals(subject.records.get(requestID)?.status, "requested");
  assertEquals(subject.records.get(requestID)?.appleRevocationStatus, "pending");
  assertEquals(subject.records.get(requestID)?.completedAt, null);
});

Deno.test("revokes Apple and completes Toss deletion", async () => {
  const subject = makeDependencies();
  const response = await subject.handler(jsonRequest());
  assertEquals(response.status, 200);
  assertEquals(await responseJSON(response), { deleted: true, requestID, appleRevocation: "revoked" });
  assertEquals(subject.calls.apple, 1);
  assertEquals(subject.calls.deleteUser, 1);
  assertEquals(subject.records.get(requestID)?.status, "completed");
});

Deno.test("Apple exchange or revoke outage still deletes Toss data", async () => {
  const subject = makeDependencies({ revokeApple: async () => "manual_required" });
  const response = await subject.handler(jsonRequest());
  assertEquals(response.status, 200);
  assertEquals(await responseJSON(response), { deleted: true, requestID, appleRevocation: "manual_required" });
  assertEquals(subject.calls.deleteUser, 1);
});

Deno.test("already invalid Apple authorization still completes Toss deletion", async () => {
  const subject = makeDependencies({ revokeApple: async () => "already_invalid" });
  const response = await subject.handler(jsonRequest());
  assertEquals(response.status, 200);
  assertEquals((await responseJSON(response)).appleRevocation, "already_invalid");
  assertEquals(subject.calls.deleteUser, 1);
});

Deno.test("Toss deletion failure cannot return deleted true and remains retryable", async () => {
  const subject = makeDependencies({ deleteUser: async () => { throw new Error("database unavailable"); } });
  const response = await subject.handler(jsonRequest());
  assertEquals(response.status, 500);
  assertEquals((await responseJSON(response)).deleted, false);
  assertEquals(subject.records.get(requestID)?.status, "requested");
  assertEquals(subject.records.get(requestID)?.appleRevocationStatus, "revoked");
});

Deno.test("an already absent Auth user is an idempotent data deletion success", async () => {
  const subject = makeDependencies({ deleteUser: async () => "already_absent" });
  const response = await subject.handler(jsonRequest());
  assertEquals(response.status, 200);
  assertEquals((await responseJSON(response)).deleted, true);
  assertEquals(subject.records.get(requestID)?.status, "completed");
});

Deno.test("same request id retries requested work and completed replay skips side effects", async () => {
  let deleteAttempts = 0;
  const subject = makeDependencies({
    deleteUser: async () => {
      deleteAttempts += 1;
      if (deleteAttempts === 1) throw new Error("temporary failure");
      return "deleted";
    },
  });
  assertEquals((await subject.handler(jsonRequest())).status, 500);
  assertEquals((await subject.handler(jsonRequest())).status, 200);
  const appleCallsAfterCompletion = subject.calls.apple;
  const deleteCallsAfterCompletion = subject.calls.deleteUser;
  const replay = await subject.handler(jsonRequest());
  assertEquals(replay.status, 200);
  assertEquals(subject.calls.apple, appleCallsAfterCompletion);
  assertEquals(subject.calls.deleteUser, deleteCallsAfterCompletion);
});

Deno.test("request persistence and logs contain no authorization code or identity", async () => {
  const subject = makeDependencies();
  await subject.handler(jsonRequest());
  const persisted = JSON.stringify(subject.records.get(requestID));
  const logged = subject.logs.join(" ");
  for (const secret of ["fictional-authorization-code", "fictional-apple-subject", userID, "fictional-verified-jwt"]) {
    assert(!persisted.includes(secret), "sensitive value persisted");
    assert(!logged.includes(secret), "sensitive value logged");
  }
  assert(subject.logs.every((entry) => entry.includes(requestID)), "logs contain request id category only");
});

import {
  appleProviderSubjects,
  matchesAppleProviderSubject,
} from "./live_dependencies.ts";

function assertEquals(
  actual: unknown,
  expected: unknown,
  message = "values differ",
) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `${message}: ${JSON.stringify(actual)} !== ${JSON.stringify(expected)}`,
    );
  }
}

const internalIdentityID = "90000000-0000-4000-8000-000000000001";
const providerSubject = "fictional-apple-provider-subject";

Deno.test("matches Apple token subject through identity data rather than identity id", () => {
  const identities = [{
    provider: "apple",
    identity_id: internalIdentityID,
    identity_data: { sub: providerSubject },
  }];

  const subjects = appleProviderSubjects(identities);
  assertEquals(subjects, [providerSubject]);
  assertEquals(matchesAppleProviderSubject(subjects, providerSubject), true);
  assertEquals(
    matchesAppleProviderSubject(subjects, internalIdentityID),
    false,
  );
});

Deno.test("matches any valid Apple provider subject and ignores non Apple identities", () => {
  const identities = [
    { provider: "google", identity_data: { sub: providerSubject } },
    {
      provider: "apple",
      identity_data: { sub: "first-fictional-apple-subject" },
    },
    { provider: "apple", identity_data: { sub: providerSubject } },
  ];

  assertEquals(
    matchesAppleProviderSubject(
      appleProviderSubjects(identities),
      providerSubject,
    ),
    true,
  );
});

Deno.test("rejects missing or invalid Apple provider subjects without identity id fallback", () => {
  const identities = [
    { provider: "apple", identity_id: providerSubject },
    { provider: "apple", identity_data: { sub: "   " } },
    { provider: "apple", identity_data: { sub: 42 } },
  ];

  assertEquals(appleProviderSubjects(identities), []);
  assertEquals(
    matchesAppleProviderSubject(
      appleProviderSubjects(identities),
      providerSubject,
    ),
    false,
  );
});

Deno.test("rejects when every valid Apple provider subject differs", () => {
  const identities = [
    {
      provider: "apple",
      identity_data: { sub: "first-fictional-apple-subject" },
    },
    {
      provider: "apple",
      identity_data: { sub: "second-fictional-apple-subject" },
    },
  ];

  assertEquals(
    matchesAppleProviderSubject(
      appleProviderSubjects(identities),
      providerSubject,
    ),
    false,
  );
});

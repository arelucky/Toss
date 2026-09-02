# Toss Mainland China Release Implementation Plan

> **Superseded on 2026-09-02.** This domestic-cloud deployment plan is no longer active. Mainland launch now uses the offline Classic-only scope documented in `2026-09-02-mainland-classic-only-launch.md`; do not provision or deploy the services described below unless a later approved plan replaces that scope.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Release Toss in China mainland with isolated domestic accounts, APIs, assets, and administration while keeping the existing overseas service unchanged.

**Architecture:** The one App Store binary resolves its service environment on first launch. China mainland storefronts use self-hosted Supabase on Alibaba Cloud ECS plus OSS/CDN assets. All other storefronts use the existing service. The two environments share application behavior but never user data, authentication sessions, or disk caches.

**Tech Stack:** SwiftUI, StoreKit Storefront, Supabase Swift, self-hosted Supabase, Alibaba Cloud ECS, OSS, CDN, Nginx, Docker Compose, PostgreSQL, Deno Edge Functions, Vue/Vite.

**Spec:** docs/superpowers/specs/2026-08-31-toss-mainland-release-design.md

## Global Constraints

- Minimum iOS version: 17. Use SwiftUI and MVVM; add no third-party iOS dependency.
- Never store server-role keys, Apple private keys, passwords, OSS credentials, or CDN credentials in Git, the App, the Vue bundle, logs, or screenshots.
- Do not change the overseas Supabase project, its users, TestFlight build, or App Store availability.
- Mainland and overseas accounts, preferences, selected coins, catalog caches, preview caches, and USDZ files must not cross environments.
- Classic remains fully usable offline when all network services fail.
- Make an English Git commit after every independently testable code/configuration task.
- Ask immediately before cloud purchases, DNS changes, certificate requests, external uploads, App filing submission, and App Store territory changes.

---

## File Structure

| Path | Responsibility |
|---|---|
| docs/operations/mainland-release-runbook.md | Secret-free resource, recovery, filing, and verification record. |
| deploy/mainland/.env.example | Required server variable names without values. |
| deploy/mainland/docker-compose.yml | Domestic Supabase service stack. |
| deploy/mainland/nginx.conf | HTTPS proxy for api.largemuscles.com. |
| admin/.env.mainland.example | Mainland Vite variable names without values. |
| Toss/Configuration/ServiceEnvironment.swift | Environment identity plus cache/session namespaces. |
| Toss/Configuration/ServiceEnvironmentStore.swift | Testable persistent environment selection. |
| Toss/Configuration/ServiceEnvironmentResolver.swift | Storefront resolution and one-time manual fallback. |
| Toss/App/AppEnvironment.swift | Environment-specific Supabase client creation. |
| Toss/App/AppDependencies.swift | Dependency graph built only after resolution. |
| Toss/Views/AppRootView.swift | Resolves before online services start. |
| Toss/Views/ServiceEnvironmentChoiceView.swift | Accessible fallback picker. |
| Toss/Services/Coins/CoinCatalogCache.swift | Environment-specific catalog directory. |
| Toss/Services/Coins/CoinAssetCache.swift | Environment-specific model directory. |
| TossTests/Configuration/ServiceEnvironmentResolverTests.swift | Resolver behavior. |
| TossTests/Configuration/SupabaseConfigurationTests.swift | Configuration-pair validation. |
| TossTests/Coins/CoinCatalogCacheTests.swift | Catalog isolation. |
| TossTests/Coins/CoinAssetCacheTests.swift | Asset isolation. |

---

### Task 1: Create the mainland runbook and secret boundary

**Files:**
- Create: docs/operations/mainland-release-runbook.md
- Create: deploy/mainland/.env.example
- Create: admin/.env.mainland.example

**Interfaces:**
- Consumes: Existing migrations, Edge Functions, and admin app.
- Produces: A secret-free list of exact resources, actual domains, backups, recovery, and App filing inputs.

- [ ] **Step 1: Write the failing documentation review checklist**

Add:

~~~markdown
- [ ] No private key, password, token, database connection string, OSS key, or CDN credential is present.
- [ ] api.largemuscles.com, assets.largemuscles.com, and admin.largemuscles.com are mainland-only domains.
- [ ] The overseas Supabase project is not a mainland runtime dependency.
- [ ] Classic offline toss is the availability fallback.
~~~

- [ ] **Step 2: Verify RED**

Run:

~~~bash
test -f docs/operations/mainland-release-runbook.md
~~~

Expected: fail because the runbook does not exist.

- [ ] **Step 3: Create the runbook and environment templates**

Document these ordered gates:

~~~markdown
1. Approve each Alibaba Cloud purchase.
2. Provision a filing-eligible China mainland ECS instance.
3. Create an OSS bucket, CDN distribution, backups, and public HTTPS domains.
4. Deploy domestic schema, functions, and public buckets.
5. Verify API, admin, assets, TLS, backup restoration, and offline Classic.
6. Submit truthful App filing data.
7. After filing approval, add the ICP number in App Store Connect and request approval before enabling China mainland.
~~~

The server template must contain names only:

~~~dotenv
POSTGRES_PASSWORD=
JWT_SECRET=
ANON_KEY=
SERVICE_ROLE_KEY=
SITE_URL=https://admin.largemuscles.com
API_EXTERNAL_URL=https://api.largemuscles.com
APPLE_TEAM_ID=
APPLE_KEY_ID=
APPLE_PRIVATE_KEY_PATH=
~~~

The admin template must contain:

~~~dotenv
VITE_SUPABASE_URL=https://api.largemuscles.com
VITE_SUPABASE_PUBLISHABLE_KEY=
~~~

- [ ] **Step 4: Verify GREEN**

Run:

~~~bash
rg -n '(BEGIN PRIVATE KEY|postgres://|AKIA|LTAI|sb_secret_)' docs/operations/mainland-release-runbook.md deploy/mainland/.env.example admin/.env.mainland.example
~~~

Expected: no secret value.

- [ ] **Step 5: Commit**

~~~bash
git add docs/operations/mainland-release-runbook.md deploy/mainland/.env.example admin/.env.mainland.example
git diff --cached --check
git commit -m 'docs: add mainland deployment runbook'
~~~

### Task 2: Provision China mainland resources and domains

**Files:**
- Modify: docs/operations/mainland-release-runbook.md

**Interfaces:**
- Consumes: Task 1 and action-time user approval for paid resources and DNS.
- Produces: Filing-eligible ECS, OSS/CDN, backup destination, and HTTPS domains.

- [ ] **Step 1: Request action-time purchase approval**

Ask for permission to purchase China mainland ECS, OSS storage, CDN traffic, certificates, and bandwidth. Make no purchase before approval.

- [ ] **Step 2: Provision the small production baseline**

Create in one Alibaba Cloud China mainland region:

~~~text
ECS: 4 vCPU, 8 GiB RAM, Linux, public IPv4.
Security group: inbound 80 and 443 only.
OSS: private bucket toss-cn-assets-prod, CDN-only public delivery.
CDN: HTTPS distribution with the OSS bucket as origin.
Backup: daily encrypted database archive in a distinct OSS path; keep seven daily copies.
~~~

Do not expose PostgreSQL, Supabase Studio, or Docker ports to the public internet.

- [ ] **Step 3: Add DNS after confirming provider targets**

Create only:

~~~text
api.largemuscles.com    A or CNAME to ECS HTTPS endpoint
assets.largemuscles.com CNAME to Alibaba CDN hostname
admin.largemuscles.com  A or CNAME to ECS HTTPS endpoint
~~~

Leave largemuscles.com and toss.largemuscles.com unchanged.

- [ ] **Step 4: Verify TLS and public boundary**

Run:

~~~bash
curl --fail --silent --show-error --head https://api.largemuscles.com/auth/v1/health
curl --fail --silent --show-error --head https://assets.largemuscles.com/
curl --fail --silent --show-error --head https://admin.largemuscles.com/
~~~

Expected: valid HTTPS and no publicly reachable database.

- [ ] **Step 5: Record non-sensitive resource facts and commit**

Record region, ECS label, OSS bucket, public domains, backup location, and certificate validation date.

~~~bash
git add docs/operations/mainland-release-runbook.md
git diff --cached --check
git commit -m 'docs: record mainland service baseline'
~~~

### Task 3: Deploy isolated domestic Supabase

**Files:**
- Create: deploy/mainland/docker-compose.yml
- Create: deploy/mainland/nginx.conf
- Modify: docs/operations/mainland-release-runbook.md

**Interfaces:**
- Consumes: Task 2 ECS, current supabase/migrations, and existing admin-coins/delete-account functions.
- Produces: Domestic API at api.largemuscles.com with no overseas-project dependency.

- [ ] **Step 1: Write health acceptance checks**

Add:

~~~bash
curl --fail --silent --show-error https://api.largemuscles.com/auth/v1/health
curl --fail --silent --show-error https://api.largemuscles.com/rest/v1/
~~~

Expected after deployment: healthy Auth and an authenticated REST response, never the overseas hostname.

- [ ] **Step 2: Create the Compose topology**

Create these internal-only services behind Nginx:

~~~yaml
services:
  db:        # PostgreSQL with Supabase extensions
  auth:      # GoTrue; Apple provider reads server-only settings
  rest:      # PostgREST
  realtime:  # Supabase Realtime
  storage:   # S3-compatible adapter using domestic OSS
  functions: # Edge Runtime: delete-account and admin-coins
  gateway:   # Routes auth, rest, storage, realtime, functions
  nginx:     # only public listener
~~~

Use named volumes for database state and bind all non-Nginx ports to the Docker network only.

- [ ] **Step 3: Configure credentials only on ECS**

Create an untracked owner-readable environment file containing Apple Team ID, Key ID, private-key path, JWT secrets, and database password. Check its mode without reading content:

~~~bash
stat -f '%Sp %N' /opt/toss-mainland/.env
~~~

Expected: owner-only read/write.

- [ ] **Step 4: Apply current schema and functions**

Apply every file in supabase/migrations in chronological order, then deploy only:

~~~text
supabase/functions/admin-coins
supabase/functions/delete-account
~~~

Run existing database and Edge Function suites against the domestic environment with credentials provided outside Git.

- [ ] **Step 5: Verify isolation**

Run:

~~~bash
curl --fail --silent --show-error https://api.largemuscles.com/auth/v1/health
curl --fail --silent --show-error 'https://api.largemuscles.com/rest/v1/coins?select=id,slug,status'
~~~

Expected: health succeeds; catalog is empty before Task 5; no redirect or response references the overseas project.

- [ ] **Step 6: Commit**

~~~bash
git add deploy/mainland/docker-compose.yml deploy/mainland/nginx.conf docs/operations/mainland-release-runbook.md
git diff --cached --check
git commit -m 'feat: add mainland Supabase deployment'
~~~

### Task 4: Configure domestic OSS/CDN and administrator site

**Files:**
- Modify: admin/src/lib/supabase.ts
- Modify: admin/vite.config.ts
- Modify: docs/operations/mainland-release-runbook.md
- Test: admin/src/services/adminCoins.test.ts

**Interfaces:**
- Consumes: Tasks 2–3.
- Produces: admin.largemuscles.com targeting only domestic API and assets.largemuscles.com delivery.

- [ ] **Step 1: Write failing mainland admin configuration test**

Add:

~~~ts
expect(clientUrl).toBe('https://api.largemuscles.com')
expect(clientUrl).not.toContain('supabase.co')
~~~

- [ ] **Step 2: Verify RED**

Run:

~~~bash
npm --prefix admin test -- admin/src/services/adminCoins.test.ts
~~~

Expected: fail because the existing client has no mainland configuration contract.

- [ ] **Step 3: Implement explicit configuration**

Use no overseas fallback:

~~~ts
const url = import.meta.env.VITE_SUPABASE_URL
const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY

if (!url || !publishableKey) {
  throw new Error('Missing admin backend configuration')
}
~~~

Build from a deployment-only mainland environment file, publish behind admin.largemuscles.com, and allow that origin plus local development in admin-coins CORS.

- [ ] **Step 4: Verify GREEN**

Run:

~~~bash
npm --prefix admin test -- admin/src/services/adminCoins.test.ts
npm --prefix admin run build
~~~

Expected: tests pass and the mainland build has no overseas hostname.

- [ ] **Step 5: Verify one non-production object through CDN**

Run:

~~~bash
curl --fail --silent --show-error --head https://assets.largemuscles.com/coins/<slug>/v1/model.usdz
curl --fail --silent --show-error --head https://assets.largemuscles.com/coins/<slug>/v1/preview.webp
~~~

Expected: HTTPS 200, recorded size matches model content length, and preview has an image content type.

- [ ] **Step 6: Commit**

~~~bash
git add admin/src/lib/supabase.ts admin/src/services/adminCoins.test.ts admin/vite.config.ts admin/.env.mainland.example docs/operations/mainland-release-runbook.md
git diff --cached --check
git commit -m 'feat: configure mainland admin delivery'
~~~

### Task 5: Seed domestic catalog and verify asset integrity

**Files:**
- Modify: docs/operations/mainland-release-runbook.md
- Test: supabase/tests/database/free_coin_catalog.test.sql
- Test: supabase/functions/admin-coins/index_test.ts

**Interfaces:**
- Consumes: Tasks 3–4.
- Produces: Initial domestic free-coin catalog with verified USDZ/WEBP; no user-data migration.

- [ ] **Step 1: Prepare a public content manifest**

Use only:

~~~text
slug, display_name, version_number, model_path, preview_path,
model_byte_size, model_sha256, min_app_version, asset_schema_version
~~~

- [ ] **Step 2: Verify every model before upload**

Run:

~~~bash
shasum -a 256 <model.usdz>
wc -c <model.usdz>
~~~

Expected: SHA-256 and byte count equal manifest.

- [ ] **Step 3: Publish one test coin and run RED/GREEN checks**

Run existing catalog tests against empty domestic catalog; publish the test coin; rerun:

~~~bash
supabase test db --linked
deno test --allow-env --allow-net supabase/functions/admin-coins/index_test.ts
~~~

Expected: only published coin/version pairs appear; hidden entries do not return.

- [ ] **Step 4: Publish approved initial assets**

Upload current USDZ/WEBP through domestic admin. Before each publish, verify remote content length and downloaded SHA-256 match the manifest.

- [ ] **Step 5: Verify URL isolation and commit evidence**

Read domestic catalog. Assert every client-facing model and preview URL resolves under assets.largemuscles.com and no metadata contains supabase.co.

~~~bash
git add docs/operations/mainland-release-runbook.md
git diff --cached --check
git commit -m 'docs: record mainland catalog verification'
~~~

### Task 6: Add iOS service-environment resolver

**Files:**
- Create: Toss/Configuration/ServiceEnvironment.swift
- Create: Toss/Configuration/ServiceEnvironmentStore.swift
- Create: Toss/Configuration/ServiceEnvironmentResolver.swift
- Modify: Toss/Configuration/SupabaseConfiguration.swift
- Modify: Toss/Info.plist
- Modify: Configurations/Debug.xcconfig
- Modify: Configurations/Release.xcconfig
- Modify: Configurations/LocalSecrets.xcconfig.example
- Test: TossTests/Configuration/ServiceEnvironmentResolverTests.swift
- Test: TossTests/Configuration/SupabaseConfigurationTests.swift

**Interfaces:**
- Consumes: Task 3 public domestic API and anonymous key; existing overseas configuration.
- Produces: Public configuration pair and persistent environment choice before online services start.

- [ ] **Step 1: Write failing resolver tests**

Define:

~~~swift
enum ServiceEnvironment: String, CaseIterable, Equatable, Sendable {
    case international
    case mainlandChina

    var cacheNamespace: String { rawValue }
    var authStorageKey: String { "com.zhaoheng.Toss.\(rawValue).auth.session" }
}

protocol ServiceEnvironmentPersisting {
    func load() -> ServiceEnvironment?
    func save(_ environment: ServiceEnvironment)
}

protocol StorefrontProviding {
    func storefrontCountryCode() async -> String?
}
~~~

Cover CHN to mainlandChina, USA to international, saved choice wins over later storefront change, and unavailable storefront returns needsUserChoice without writing.

- [ ] **Step 2: Verify RED**

Run:

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests/ServiceEnvironmentResolverTests
~~~

Expected: fail because types/resolver do not exist.

- [ ] **Step 3: Implement resolver/configuration pair**

Use Storefront only during the first unresolved launch:

~~~swift
enum ServiceEnvironmentResolution: Equatable {
    case resolved(ServiceEnvironment)
    case needsUserChoice
}

final class ServiceEnvironmentResolver {
    init(store: any ServiceEnvironmentPersisting, storefront: any StorefrontProviding)

    func resolve() async -> ServiceEnvironmentResolution {
        if let saved = store.load() { return .resolved(saved) }
        guard let code = await storefront.storefrontCountryCode() else {
            return .needsUserChoice
        }
        let environment: ServiceEnvironment = code == "CHN" ? .mainlandChina : .international
        store.save(environment)
        return .resolved(environment)
    }

    func select(_ environment: ServiceEnvironment) {
        store.save(environment)
    }
}
~~~

Extend SupabaseConfiguration with load(for:from:) for separate pairs. Info.plist references build settings only; it embeds neither URL nor key literal.

- [ ] **Step 4: Verify GREEN and commit**

Run:

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests/ServiceEnvironmentResolverTests -only-testing:TossTests/SupabaseConfigurationTests
~~~

Expected: pass; saved choice cannot change automatically; blank, malformed, and secret values remain rejected.

~~~bash
git add Toss/Configuration/ServiceEnvironment.swift Toss/Configuration/ServiceEnvironmentStore.swift Toss/Configuration/ServiceEnvironmentResolver.swift Toss/Configuration/SupabaseConfiguration.swift Toss/Info.plist Configurations/Debug.xcconfig Configurations/Release.xcconfig Configurations/LocalSecrets.xcconfig.example TossTests/Configuration/ServiceEnvironmentResolverTests.swift TossTests/Configuration/SupabaseConfigurationTests.swift
git diff --cached --check
git commit -m 'feat: resolve Toss service environment'
~~~

### Task 7: Bind dependencies, sessions, and caches to the selected environment

**Files:**
- Modify: Toss/App/AppEnvironment.swift
- Modify: Toss/App/AppDependencies.swift
- Modify: Toss/Views/AppRootView.swift
- Create: Toss/Views/ServiceEnvironmentChoiceView.swift
- Modify: Toss/Services/Coins/CoinCatalogCache.swift
- Modify: Toss/Services/Coins/CoinAssetCache.swift
- Test: TossTests/Account/AccountStoreTests.swift
- Test: TossTests/Coins/CoinCatalogCacheTests.swift
- Test: TossTests/Coins/CoinAssetCacheTests.swift
- Test: TossTests/TossTests.swift

**Interfaces:**
- Consumes: Task 6 ServiceEnvironment and resolver.
- Produces: One resolved environment shared by online dependencies, separate Keychain/disk caches, and accessible fallback UI.

- [ ] **Step 1: Write failing isolation tests**

Add:

~~~swift
XCTAssertNotEqual(ServiceEnvironment.international.authStorageKey,
                  ServiceEnvironment.mainlandChina.authStorageKey)
XCTAssertNotEqual(internationalCatalogURL, mainlandCatalogURL)
XCTAssertNotEqual(internationalModelURL, mainlandModelURL)
~~~

Add an AppRootView test that no account restore or catalog request starts before resolution and that the choice view disappears after persistence.

- [ ] **Step 2: Verify RED**

Run:

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests/AccountStoreTests -only-testing:TossTests/CoinCatalogCacheTests -only-testing:TossTests/CoinAssetCacheTests
~~~

Expected: fail because current client key/cache directories are shared.

- [ ] **Step 3: Implement the shared environment boundary**

Use:

~~~swift
final class AppEnvironment {
    let serviceEnvironment: ServiceEnvironment
    let authStorageKey: String

    init(serviceEnvironment: ServiceEnvironment, configuration: SupabaseConfiguration) {
        self.serviceEnvironment = serviceEnvironment
        authStorageKey = serviceEnvironment.authStorageKey
        // Build the generation provider with authStorageKey.
    }
}

static func live(
    serviceEnvironment: ServiceEnvironment,
    configuration: SupabaseConfiguration?
) -> Self
~~~

Require ServiceEnvironment in CoinCatalogCache and CoinAssetCache. Append cacheNamespace between current root and file name. AppRootView creates online dependencies only after resolution; Classic remains usable while unresolved. The fallback picker has Chinese mainland and other-region buttons, each saves selection before dependencies start, and an accessibility explanation.

- [ ] **Step 4: Verify GREEN/build and commit**

Run:

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests/AccountStoreTests -only-testing:TossTests/CoinCatalogCacheTests -only-testing:TossTests/CoinAssetCacheTests -only-testing:TossTests
xcodebuild build -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'
~~~

Expected: pass/build succeeds. With storefront unavailable, choose each option, relaunch, and confirm the prompt does not return and Classic works before online content.

~~~bash
git add Toss/App/AppEnvironment.swift Toss/App/AppDependencies.swift Toss/Views/AppRootView.swift Toss/Views/ServiceEnvironmentChoiceView.swift Toss/Services/Coins/CoinCatalogCache.swift Toss/Services/Coins/CoinAssetCache.swift TossTests/Account/AccountStoreTests.swift TossTests/Coins/CoinCatalogCacheTests.swift TossTests/Coins/CoinAssetCacheTests.swift TossTests/TossTests.swift
git diff --cached --check
git commit -m 'feat: isolate mainland Toss services'
~~~

### Task 8: Device validation, filing, and territory rollout

**Files:**
- Modify: docs/operations/mainland-release-runbook.md
- Modify: SPRINTS.md
- Modify: DECISIONS.md

**Interfaces:**
- Consumes: Tasks 2–7.
- Produces: Evidence of regional isolation and a truthful, ready-to-submit App filing package.

- [ ] **Step 1: Prepare two clean-install device cases**

~~~text
Case A: injected mainland storefront; China API/auth/catalog/assets only.
Case B: injected international storefront; current overseas URLs only.
~~~

Do not use VPN/IP as selector test. Capture redacted hostnames only.

- [ ] **Step 2: Execute mainland acceptance**

Verify:

~~~text
Cold launch → resolves once → Classic works → Coin Library loads
→ WebP from assets.largemuscles.com → USDZ download completes
→ SHA/RealityKit pass → dynamic coin renders
→ Sign in with Apple → preference persists → delete account completes.
~~~

Expected: no overseas request; forced network failure leaves Classic usable.

- [ ] **Step 3: Execute overseas regression and backup restore**

Repeat core flow internationally. Expected: no mainland request. Restore latest domestic backup into isolated non-production database, query catalog, run account/RLS tests, and confirm production untouched.

- [ ] **Step 4: Build App filing data from deployed values**

Record actual App name, icon, bundle ID, domestic backend domains, third-party SDKs (Supabase Swift and Sign in with Apple), responsible person, and content classification. Never invent a domain that the App does not call.

- [ ] **Step 5: Request confirmation before filing and after approval**

Ask immediately before submitting App identity, responsible-person contact data, actual service domains, and server details to Alibaba Cloud ICP filing. After approval, put the ICP number/metadata into App Store Connect exactly as filed, and request separate confirmation before enabling China mainland; do not alter overseas availability.

- [ ] **Step 6: Record evidence and commit**

~~~bash
git add docs/operations/mainland-release-runbook.md SPRINTS.md DECISIONS.md
git diff --cached --check
git commit -m 'docs: record mainland release readiness'
~~~

## Plan Self-Review

### Spec coverage

- Independent data/environment: Tasks 3, 6, and 7.
- Same App Store binary and stable environment selection: Tasks 6–7.
- Domestic API, assets, and admin: Tasks 2–4.
- Seeded free coins with SHA/byte checks: Task 5.
- Offline Classic, regression, backup, App filing: Task 8.
- No automatic cross-border synchronization or paid features: global constraints and Tasks 5/8.

### Placeholder scan

The plan contains no unresolved markers or secrets. Credentials and filing identities are supplied only in the user-controlled deployment environment.

### Type consistency

ServiceEnvironment, ServiceEnvironmentResolver, ServiceEnvironmentPersisting, StorefrontProviding, AppEnvironment, and cacheNamespace are defined in Task 6 and consumed consistently in Task 7.

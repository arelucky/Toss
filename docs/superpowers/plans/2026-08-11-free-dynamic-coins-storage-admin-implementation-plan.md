# Toss 免费动态硬币、Storage 与管理后台实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不引入 StoreKit 的前提下，让 Toss 可以从 Supabase 获取已发布免费硬币目录、按需下载并安全缓存 USDZ、在全屏硬币库中切换硬币，并由单管理员通过最小 Vue 3 后台管理草稿、上传、发布和回滚。

**Architecture:** PostgreSQL 只保存中立的硬币目录与不可变资源版本；`coin-previews` 和 `coin-models-free` 提供公开只读素材，管理写入全部经受保护的 Edge Function。iOS 启动始终先使用内置 `Classic Toss` 或已验证缓存，远程目录和下载均在后台完成；登录用户同步所选硬币，Guest 仅保存在本机。管理后台是独立 Vue 3 SPA，不持有 `service_role`。

**Tech Stack:** iOS 17、SwiftUI、RealityKit、CryptoKit、Supabase Swift 2.49.0、Supabase PostgreSQL/RLS/Storage/Edge Functions、Deno/TypeScript、Vue 3、TypeScript、Vite、Element Plus、Supabase JS。

## Global Constraints

- 当前阶段只支持免费硬币；不得新增 StoreKit、价格、Product ID、购买记录、付费权限或私有付费素材。
- 不实现 Cover to Reveal、订阅、手机号登录、Storage 迁移、复杂 DRM 或多管理员角色系统。
- 内置 `Classic Toss` 永远可离线使用，网络、目录或下载失败不得阻塞 Toss 首页。
- 远程 USDZ 使用不可变版本路径，已发布文件不得覆盖。
- iOS 只接受 HTTPS hosted Supabase URL，不记录 URL、JWT、用户资料或素材签名值。
- `service_role` 只允许存在于 Edge Function 环境，禁止进入 iOS、Vue、Info.plist、Git 或浏览器构建产物。
- 保持 Supabase Swift `2.49.0` 与 xctest-dynamic-overlay `1.9.0` 不变。
- 所有功能按 RED→GREEN 实施；单任务只跑聚焦测试，全量门禁集中在阶段末，避免重复耗时。
- UI Tests 不纳入自动门禁；沿用 Xcode 15.4 runner teardown/materialization 已知问题，改为单次模拟器与真机验收。

---

## 文件结构

### 数据库与 Edge Function

- Create: `supabase/migrations/20260811100000_create_free_coin_catalog.sql` — `coins`、`coin_versions`、约束、RLS、公开读取策略。
- Create: `supabase/migrations/20260811100500_create_free_coin_storage.sql` — 创建三个 Bucket 与对象写入策略。
- Create: `supabase/migrations/20260811101000_add_selected_coin_preference.sql` — 为账户偏好增加可空的 `selected_coin_id`。
- Create: `supabase/tests/database/free_coin_catalog.test.sql` — 目录、版本、RLS、权限和发布约束 pgTAP。
- Create: `supabase/functions/admin-coins/index.ts` — HTTP 入口和统一响应。
- Create: `supabase/functions/admin-coins/handler.ts` — 管理动作状态机。
- Create: `supabase/functions/admin-coins/live_dependencies.ts` — JWT 管理员校验、数据库和 Storage 依赖。
- Create: `supabase/functions/admin-coins/index_test.ts` — 管理 API 单元测试。

### iOS

- Create: `Toss/Models/CoinCatalogItem.swift` — 目录与版本值类型。
- Create: `Toss/Services/Coins/CoinCatalogServicing.swift` — 目录协议。
- Create: `Toss/Services/Coins/SupabaseCoinCatalogRepository.swift` — 远程目录读取。
- Create: `Toss/Services/Coins/CoinCatalogCache.swift` — 最后成功目录 JSON 缓存。
- Create: `Toss/Services/Coins/CoinAssetCaching.swift` — 素材缓存协议。
- Create: `Toss/Services/Coins/CoinAssetCache.swift` — 下载、校验、RealityKit 预检、原子发布。
- Create: `Toss/Services/Coins/CoinSelectionStore.swift` — Guest/账户选择规则。
- Create: `Toss/Services/Coins/SelectedCoinPreferenceServicing.swift` — 登录账户所选硬币读写协议。
- Create: `Toss/Services/Coins/SupabaseSelectedCoinPreferenceRepository.swift` — 独立读写 `selected_coin_id`。
- Create: `Toss/ViewModels/CoinLibraryViewModel.swift` — 页面状态与操作。
- Create: `Toss/Views/CoinLibrary/CoinLibraryView.swift` — 全屏硬币库。
- Create: `Toss/Views/CoinLibrary/CoinLibraryCard.swift` — 卡片、下载状态与选中状态。
- Modify: `Toss/App/AppDependencies.swift` — 注入目录、缓存和选择服务。
- Modify: `Toss/Views/ContentView.swift` — 左上角 44pt 入口和动态模型切换。
- Modify: `Toss.xcodeproj/project.pbxproj` — 仅加入新 Swift 文件引用。
- Test: `TossTests/Coins/*.swift` — 目录、缓存、校验、选择和 ViewModel 测试。

### 管理后台

- Create: `admin/package.json` — Vue/Vite/TypeScript/Element Plus/Supabase JS 依赖与脚本。
- Create: `admin/src/lib/supabase.ts` — 公开客户端初始化。
- Create: `admin/src/services/adminCoins.ts` — Edge Function API。
- Create: `admin/src/router/index.ts` — 登录和管理路由守卫。
- Create: `admin/src/views/LoginView.vue` — 单管理员邮箱 OTP 登录。
- Create: `admin/src/views/CoinsView.vue` — 硬币列表、草稿和发布入口。
- Create: `admin/src/views/CoinEditorView.vue` — 元数据、版本上传、发布和回滚。
- Create: `admin/src/components/AssetUploadPanel.vue` — 文件校验与上传进度。
- Test: `admin/src/**/*.test.ts` — Vitest 服务与页面状态测试。

---

### Task 0: 创建隔离分支并完成只读基线门禁

**Files:**
- Inspect only: repository root、`Toss/`、`TossTests/`、`supabase/`、`Package.resolved`

**Interfaces:**
- Consumes: 当前干净的 `main` 与已部署四项 Supabase migration。
- Produces: `feature/free-dynamic-coins` 分支及实际 scheme、模拟器 destination、现有 USDZ 路径清单。

- [ ] **Step 1: 验证工作区与远程同步状态**

```bash
git status --short
git branch --show-current
git rev-list --left-right --count origin/main...main
```

Expected: `git status --short` 无输出，当前为 `main`，ahead/behind 为 `0 0`。任一不符即停止，不创建分支。

- [ ] **Step 2: 创建工作分支**

```bash
git switch -c feature/free-dynamic-coins
```

- [ ] **Step 3: 定位现有工程入口和 USDZ，不修改文件**

```bash
rg --files Toss TossTests | sort
rg --files -g '*.usdz' -g '*.reality' -g '*.swift' Toss | sort
rg -n "Coin3DView|Model3D|Entity\(|loadModel|loadAsync|selectedCoin" Toss TossTests
```

Expected: 能确定首页、RealityKit 加载入口、依赖注入位置和内置硬币资源；若无法确定，停止并报告，不猜测文件路径。

- [ ] **Step 4: 记录一次基线而不重复跑完整门禁**

```bash
git status --short
git log -1 --oneline
```

本任务不运行测试和构建；复用上一阶段 `154/154 TossTests` 与 Debug/Release 成功证据。

---

### Task 1: 建立免费硬币目录与不可变版本模型

**Files:**
- Create: `supabase/migrations/20260811100000_create_free_coin_catalog.sql`
- Create: `supabase/tests/database/free_coin_catalog.test.sql`

**Interfaces:**
- Consumes: 现有 Supabase migration 与 pgTAP 运行方式。
- Produces: `public.coins`、`public.coin_versions`，以及公开读取已发布目录的 RLS 规则。

- [ ] **Step 1: 写 RED 数据库测试**

测试必须断言：

```sql
select has_table('public', 'coins');
select has_table('public', 'coin_versions');
select col_is_unique('public', 'coins', 'slug');
select policies_are('public', 'coins', array['published coins are publicly readable']);
select policies_are('public', 'coin_versions', array['active published versions are publicly readable']);
```

并覆盖以下行为：匿名用户只能看到 `published` 硬币及其 `active_version_id`；不能读取草稿/隐藏版本；不能 INSERT/UPDATE/DELETE；同一硬币版本号唯一；SHA-256 必须是 64 位小写十六进制；文件大小大于 0。

- [ ] **Step 2: 运行聚焦 pgTAP，确认 RED**

```bash
supabase start
supabase db reset
supabase test db supabase/tests/database/free_coin_catalog.test.sql
```

Expected: 因表不存在而失败。不要运行全部 pgTAP。

- [ ] **Step 3: 编写最小 migration**

`coins` 使用：

```sql
id uuid primary key default gen_random_uuid(),
slug text not null unique,
display_name text not null,
description text,
sort_order integer not null default 0,
is_featured boolean not null default false,
status text not null check (status in ('draft','published','hidden','retired')),
active_version_id uuid,
published_at timestamptz,
created_at timestamptz not null default now(),
updated_at timestamptz not null default now()
```

`coin_versions` 使用：

```sql
id uuid primary key default gen_random_uuid(),
coin_id uuid not null references public.coins(id) on delete restrict,
version_number integer not null check (version_number > 0),
model_path text not null,
preview_path text not null,
model_byte_size bigint not null check (model_byte_size > 0),
model_sha256 text not null check (model_sha256 ~ '^[0-9a-f]{64}$'),
min_app_version text not null,
asset_schema_version integer not null default 1 check (asset_schema_version > 0),
status text not null check (status in ('draft','published','deprecated')),
created_at timestamptz not null default now(),
published_at timestamptz,
unique (coin_id, version_number),
unique (model_path),
unique (preview_path)
```

添加延迟外键 `coins.active_version_id -> coin_versions.id`，并通过约束触发器保证 active version 属于同一 coin 且状态为 `published`。启用并强制 RLS；仅允许客户端 SELECT 已发布记录，不授予客户端写权限。

- [ ] **Step 4: 运行聚焦 pgTAP，确认 GREEN**

```bash
supabase db reset
supabase test db supabase/tests/database/free_coin_catalog.test.sql
```

Expected: 全部通过。

- [ ] **Step 5: 静态检查并提交**

```bash
supabase db lint --local
git diff --check
git add supabase/migrations supabase/tests/database/free_coin_catalog.test.sql
git commit -m "feat: add free coin catalog schema"
```

---

### Task 2: 建立免费素材 Storage 边界

**Files:**
- Create: `supabase/migrations/20260811100500_create_free_coin_storage.sql`
- Modify: `supabase/tests/database/free_coin_catalog.test.sql`

**Interfaces:**
- Consumes: `coins.slug`、`coin_versions.version_number`。
- Produces: `coin-previews`、`coin-models-free`、`coin-staging` Bucket 与最小权限。

- [ ] **Step 1: 写 RED 权限测试**

断言三个 Bucket 存在；`coin-previews` 与 `coin-models-free` 为 public；`coin-staging` 为 private；`anon`/`authenticated` 无对象 INSERT/UPDATE/DELETE；普通用户不能写任何上述 Bucket。

- [ ] **Step 2: 运行聚焦 pgTAP，确认 RED**

```bash
supabase test db supabase/tests/database/free_coin_catalog.test.sql
```

- [ ] **Step 3: 创建 Bucket 与对象策略**

固定路径：

```text
coins/{coin-slug}/v{version_number}/preview.webp
coins/{coin-slug}/v{version_number}/model.usdz
```

迁移只创建 Bucket 和公开读取策略；客户端不得写。管理上传在 Task 9 通过 Edge Function service client 完成。USDZ 最大文件尺寸固定为 52,428,800 bytes（50 MiB）；预览图最大尺寸固定为 2,097,152 bytes（2 MiB）。

- [ ] **Step 4: 运行聚焦测试和 lint**

```bash
supabase test db supabase/tests/database/free_coin_catalog.test.sql
supabase db lint --local
```

- [ ] **Step 5: 提交**

```bash
git add supabase/migrations supabase/tests/database/free_coin_catalog.test.sql
git commit -m "feat: add free coin storage buckets"
```

---

### Task 3: 为登录账户增加所选硬币同步字段

**Files:**
- Create: `supabase/migrations/20260811101000_add_selected_coin_preference.sql`
- Create: `supabase/tests/database/selected_coin_preference.test.sql`
- Create: `Toss/Services/Coins/SelectedCoinPreferenceServicing.swift`
- Create: `Toss/Services/Coins/SupabaseSelectedCoinPreferenceRepository.swift`
- Create: `TossTests/Coins/SelectedCoinPreferenceRepositoryTests.swift`
- Modify: `Toss/App/AppDependencies.swift`
- Modify: `Toss.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `public.user_preferences`、`public.coins.id`。
- Produces: 可空 `selected_coin_id: UUID?`，未选择或远程硬币不可用时为 `nil`。

- [ ] **Step 1: 写数据库和 Swift RED 测试**

数据库断言字段存在、外键存在、用户只能读写自己的选择。Swift 断言 `nil` 与 UUID 正确映射、请求携带当前 generation，并保持现有声音/触觉 Repository 完全不变。

- [ ] **Step 2: 分别运行聚焦测试确认 RED**

```bash
supabase test db supabase/tests/database/selected_coin_preference.test.sql
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests/SelectedCoinPreferenceRepositoryTests
```

- [ ] **Step 3: 实现最小字段和模型映射**

数据库：

```sql
alter table public.user_preferences
add column selected_coin_id uuid null references public.coins(id) on delete set null;
```

Swift 协议固定为：

```swift
protocol SelectedCoinPreferenceServicing: Sendable {
    func fetchSelectedCoinID(for userID: UUID, generationID: UUID) async throws -> UUID?
    func updateSelectedCoinID(_ coinID: UUID?, for userID: UUID, generationID: UUID) async throws
}
```

Repository 仅更新 `selected_coin_id`，不得覆盖声音或触觉列。Guest 偏好不调用此 Repository；generation 是否仍有效由调用方在接受结果前再次检查。

- [ ] **Step 4: 运行同一组聚焦测试确认 GREEN**

- [ ] **Step 5: 提交**

```bash
git add supabase/migrations/20260811101000_add_selected_coin_preference.sql supabase/tests/database/selected_coin_preference.test.sql Toss/Services/Coins Toss/App/AppDependencies.swift TossTests/Coins Toss.xcodeproj/project.pbxproj
git commit -m "feat: sync selected coin preference"
```

---

### Task 4: 实现 iOS 目录模型、远程 Repository 与目录缓存

**Files:**
- Create: `Toss/Models/CoinCatalogItem.swift`
- Create: `Toss/Services/Coins/CoinCatalogServicing.swift`
- Create: `Toss/Services/Coins/SupabaseCoinCatalogRepository.swift`
- Create: `Toss/Services/Coins/CoinCatalogCache.swift`
- Create: `TossTests/Coins/CoinCatalogRepositoryTests.swift`
- Create: `TossTests/Coins/CoinCatalogCacheTests.swift`
- Modify: `Toss/App/AppDependencies.swift`
- Modify: `Toss.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces:

```swift
struct CoinCatalogItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let slug: String
    let displayName: String
    let description: String?
    let sortOrder: Int
    let isFeatured: Bool
    let version: CoinAssetVersion
}

struct CoinAssetVersion: Codable, Equatable, Sendable {
    let id: UUID
    let versionNumber: Int
    let modelURL: URL
    let previewURL: URL
    let modelByteSize: Int64
    let modelSHA256: String
    let minAppVersion: String
    let assetSchemaVersion: Int
}

protocol CoinCatalogServicing: Sendable {
    func fetchPublishedCatalog() async throws -> [CoinCatalogItem]
}
```

- [ ] **Step 1: 写 RED 测试**

覆盖：只映射 active published version；按 `sort_order` 后 `slug` 排序；拒绝非 HTTPS、错误 SHA、非正尺寸；远程失败时读取最后成功 JSON；损坏缓存返回空目录而不是崩溃。

- [ ] **Step 2: 运行两个聚焦测试类确认 RED**

- [ ] **Step 3: 实现最小 Repository 和原子 JSON 缓存**

缓存路径固定在 `Application Support/CoinCatalog/catalog-v1.json`；写入临时文件后使用 `FileManager.replaceItemAt` 原子替换。Repository 不订阅 realtime，不在每次 Toss 时请求。

- [ ] **Step 4: 运行同一组聚焦测试确认 GREEN**

- [ ] **Step 5: 提交**

```bash
git add Toss/Models Toss/Services/Coins Toss/App/AppDependencies.swift TossTests/Coins Toss.xcodeproj/project.pbxproj
git commit -m "feat: load and cache free coin catalog"
```

---

### Task 5: 实现安全 USDZ 下载、校验与缓存

**Files:**
- Create: `Toss/Services/Coins/CoinAssetCaching.swift`
- Create: `Toss/Services/Coins/CoinAssetCache.swift`
- Create: `TossTests/Coins/CoinAssetCacheTests.swift`

**Interfaces:**
- Consumes: `CoinCatalogItem`。
- Produces:

```swift
protocol CoinAssetCaching: Sendable {
    func cachedModelURL(for item: CoinCatalogItem) async -> URL?
    func downloadAndValidate(_ item: CoinCatalogItem) async throws -> URL
    func removeUnreferencedAssets(keeping items: [CoinCatalogItem]) async throws
}
```

- [ ] **Step 1: 写 RED 测试**

覆盖：缓存命中不重复下载；HTTP/HTTPS 校验；临时文件下载；字节数不符拒绝；SHA-256 不符拒绝；RealityKit 无法加载时拒绝；成功后原子发布；失败时旧版本仍在；并发请求同一版本只下载一次。

- [ ] **Step 2: 运行聚焦测试确认 RED**

- [ ] **Step 3: 实现最小缓存状态机**

正式路径：

```text
Application Support/CoinAssets/{coin-id}/v{version_number}/model.usdz
```

流程固定为：下载 `.partial` → 校验 URL/状态码/大小/SHA-256 → `Entity.load(contentsOf:)` 预检 → 原子移动 → 返回正式 URL。不得在主线程计算 SHA 或加载预检。

- [ ] **Step 4: 运行聚焦测试确认 GREEN**

- [ ] **Step 5: 提交**

```bash
git add Toss/Services/Coins TossTests/Coins Toss.xcodeproj/project.pbxproj
git commit -m "feat: safely cache dynamic coin assets"
```

---

### Task 6: 实现 Guest/账户选择规则与 generation 隔离

**Files:**
- Create: `Toss/Services/Coins/CoinSelectionStore.swift`
- Create: `TossTests/Coins/CoinSelectionStoreTests.swift`
- Modify: `Toss/Stores/AccountStore.swift`
- Modify: `TossTests/Account/AccountStoreTests.swift`

**Interfaces:**
- Consumes: `CoinCatalogServicing`、`CoinAssetCaching`、账户 operation ID 与 generation ID。
- Produces:

```swift
enum SelectedCoin: Equatable, Sendable {
    case bundledClassic
    case downloaded(CoinCatalogItem, localModelURL: URL)
}
```

- [ ] **Step 1: 写 RED 测试**

覆盖：Guest 选择只写本地；登录后服务器选择存在且已缓存则采用；服务器选择未缓存时先显示 Guest/Classic，后台下载后切换；旧 generation 的选择结果被丢弃；登出恢复 Guest 选择；隐藏或损坏硬币回退 Classic；Toss 过程中不热替换模型。

- [ ] **Step 2: 运行聚焦账户与选择测试确认 RED**

- [ ] **Step 3: 实现最小选择状态机**

仅在硬币处于 idle 时发布新选择。选择写入使用 Task 3 的专用字段 Repository，但沿用现有 `AccountStore` operation/generation 门禁，不新建第二套账户观察器，也不修改声音/触觉同步协调器。

- [ ] **Step 4: 运行同一组聚焦测试确认 GREEN**

- [ ] **Step 5: 提交**

```bash
git add Toss/Services/Coins TossTests/Coins Toss/Stores/AccountStore.swift TossTests/Account/AccountStoreTests.swift
git commit -m "feat: persist dynamic coin selection"
```

---

### Task 7: 实现全屏硬币库 UI 与首页入口

**Files:**
- Create: `Toss/ViewModels/CoinLibraryViewModel.swift`
- Create: `Toss/Views/CoinLibrary/CoinLibraryView.swift`
- Create: `Toss/Views/CoinLibrary/CoinLibraryCard.swift`
- Create: `TossTests/Coins/CoinLibraryViewModelTests.swift`
- Modify: `Toss/Views/ContentView.swift`
- Modify: `Toss/App/AppDependencies.swift`
- Modify: `Toss.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Tasks 4–6。
- Produces: 首页左上角 44pt 圆形硬币入口、全屏双列硬币库、下载/选择/离线状态。

- [ ] **Step 1: 写 ViewModel RED 测试**

覆盖：启动立即显示 Classic；缓存目录先显示；后台刷新合并；未缓存离线卡片禁用；下载中防重复点击；下载成功后选择；失败显示非阻断提示；刷新不改变当前 Toss 状态。

- [ ] **Step 2: 运行聚焦 ViewModel 测试确认 RED**

- [ ] **Step 3: 实现 UI**

固定交互：

- 首页左上角 44×44 圆形硬币图标，与右上角账户按钮对称。
- 点击以 `fullScreenCover` 打开 `CoinLibraryView`。
- 页面使用 `NavigationStack`，标题 `Coins`，右上角 `Done`。
- `LazyVGrid` 双列卡片；Classic 永远第一张；已选显示勾选；未下载显示下载图标；下载中显示进度；离线且未缓存时禁用。
- 不增加价格、锁、购物车、Premium、Product ID 或恢复购买入口。
- 首页按钮和硬币库手势不得覆盖现有硬币 Toss 交互区域。

- [ ] **Step 4: 运行聚焦测试和一次 Debug 构建**

```bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests/CoinLibraryViewModelTests
xcodebuild build -project Toss.xcodeproj -scheme Toss -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'
```

- [ ] **Step 5: 模拟器人工检查**

只检查：首页按钮尺寸/位置、全屏打开关闭、Classic 选择、下载状态、离线状态、账户按钮仍可用、Toss 手势未受影响。

- [ ] **Step 6: 提交**

```bash
git add Toss TossTests Toss.xcodeproj/project.pbxproj
git commit -m "feat: add dynamic coin library"
```

---

### Task 8: iOS 阶段总门禁

**Files:**
- No implementation changes allowed.

**Interfaces:**
- Consumes: Tasks 3–7。
- Produces: 一次性 iOS 全量验证证据。

- [ ] **Step 1: 运行全部 TossTests 一次**

```bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests
```

- [ ] **Step 2: 运行 Debug 构建一次**

```bash
xcodebuild build -project Toss.xcodeproj -scheme Toss -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'
```

- [ ] **Step 3: 静态与敏感信息检查**

```bash
git diff --check
rg -n "service_role|sb_secret_|BEGIN PRIVATE KEY|StoreKit|Product\.products|purchase\(" Toss TossTests supabase admin || true
git status --short
```

Expected: StoreKit 匹配只允许出现在既有文档；新增生产代码不得包含商业化实现。失败时停止并报告，不修改代码绕过测试。

---

### Task 9: 实现单管理员 Edge Function

**Files:**
- Prerequisite: `supabase/migrations/20260811101500_add_admin_coin_version_rpcs.sql`
- Prerequisite test: `supabase/tests/database/admin_coin_version_transitions.test.sql`
- Create: `supabase/functions/admin-coins/index.ts`
- Create: `supabase/functions/admin-coins/handler.ts`
- Create: `supabase/functions/admin-coins/live_dependencies.ts`
- Create: `supabase/functions/admin-coins/index_test.ts`

**Interfaces:**
- Consumes: `TOSS_ADMIN_USER_ID` secret、Task 1/2 schema 与 buckets，以及原子 `admin_publish_coin_version` / `admin_rollback_coin_version` RPC prerequisite。
- Produces: `listDrafts`、`createCoin`、`updateCoin`、`createVersion`、`createUploadURL`、`publishVersion`、`rollbackVersion`、`hideCoin` 动作。

- [ ] **Step 1: 写 RED Edge 测试**

覆盖：无 JWT 401；非管理员 403；未知动作 400；slug/版本/路径校验；已发布版本不可覆盖；发布必须拥有 USDZ 和预览对象；publish 原子更新版本和 active pointer；rollback 只能指向同一硬币已发布版本；hide 不删除文件；响应不包含 service key 或内部错误正文。

- [ ] **Step 2: 运行聚焦测试确认 RED**

```bash
deno test supabase/functions/admin-coins/index_test.ts --allow-env
```

- [ ] **Step 3: 实现最小 handler**

请求统一为：

```typescript
type AdminCoinRequest =
  | { action: "listDrafts" }
  | { action: "createCoin"; slug: string; displayName: string; description?: string }
  | { action: "updateCoin"; coinID: string; displayName: string; description?: string; sortOrder: number; isFeatured: boolean }
  | { action: "createVersion"; coinID: string; versionNumber: number; modelByteSize: number; modelSHA256: string; minAppVersion: string }
  | { action: "createUploadURL"; versionID: string; asset: "model" | "preview" }
  | { action: "publishVersion"; coinID: string; versionID: string }
  | { action: "rollbackVersion"; coinID: string; versionID: string }
  | { action: "hideCoin"; coinID: string };
```

管理员验证顺序：验证 Supabase JWT → 取得用户 UUID → 与 `TOSS_ADMIN_USER_ID` 常量时间比较 → 执行动作。发布与回滚使用单个数据库 RPC/事务，禁止两次独立更新产生中间状态。

- [ ] **Step 4: 运行全部 admin-coins 测试、类型检查和 lint**

```bash
deno test supabase/functions/admin-coins/index_test.ts --allow-env
deno check supabase/functions/admin-coins/index.ts
deno lint supabase/functions/admin-coins
```

- [ ] **Step 5: 提交，不部署**

```bash
git add supabase/functions/admin-coins
git commit -m "feat: add free coin admin API"
```

---

### Task 10: 创建最小 Vue 3 管理后台

**Files:**
- Create: `admin/` 下列出的全部文件

**Interfaces:**
- Consumes: Task 9 Edge Function；浏览器只使用 Supabase URL 和 publishable key。
- Produces: 单管理员登录、硬币草稿、版本上传、发布、隐藏和回滚 UI。

- [ ] **Step 1: 初始化固定依赖并写 RED 测试**

仅加入 Vue 3、Vite、TypeScript、Vue Router、Element Plus、Supabase JS、Vitest。测试覆盖：未登录跳转 Login；非管理员 403 显示无权限；文件扩展名/大小/SHA 本地校验；重复提交禁用；发布二次确认；API 失败不丢失表单；不得渲染价格或付费字段。

- [ ] **Step 2: 运行聚焦测试确认 RED**

```bash
cd admin
npm test -- --run
```

- [ ] **Step 3: 实现最小后台页面**

页面仅包含：

```text
/login
/coins
/coins/:id
```

不实现仪表盘统计、用户管理、交易、权益、角色管理或审计搜索。上传前浏览器计算 SHA-256；调用 `createUploadURL` 后直传 Storage；上传完成后创建/刷新版本；发布和回滚必须二次确认。

- [ ] **Step 4: 运行测试和生产构建各一次**

```bash
npm test -- --run
npm run build
```

- [ ] **Step 5: 检查浏览器产物不含秘密**

```bash
rg -n "service_role|sb_secret_|BEGIN PRIVATE KEY|TOSS_ADMIN_USER_ID" admin/dist admin/src || true
```

Expected: 无匹配。

- [ ] **Step 6: 提交**

```bash
git add admin
git commit -m "feat: add free coin admin console"
```

---

### Task 11: 本地端到端验收与一次性总门禁

**Files:**
- No implementation changes allowed during verification.

**Interfaces:**
- Consumes: Tasks 1–10。
- Produces: 本地发布→iOS 发现→下载→切换→离线使用→回滚的完整证据。

- [ ] **Step 1: 从空库重放迁移并运行全部 pgTAP 一次**

```bash
supabase db reset
supabase test db
supabase db lint --local
```

- [ ] **Step 2: 运行全部 Edge Function 测试一次**

```bash
deno test supabase/functions --allow-env
deno check supabase/functions/admin-coins/index.ts
deno lint supabase/functions/admin-coins
```

- [ ] **Step 3: 运行全部 TossTests 和 Debug 构建一次**

使用 Task 8 的两条命令；若 Task 8 之后没有 iOS 改动，可直接复用 Task 8 证据，不重复执行。

- [ ] **Step 4: 本地端到端人工验收**

使用本地 Supabase 和管理员账号完成：创建草稿 → 上传真实测试 USDZ/WEBP → 发布 → App 刷新出现 → 下载并选择 → 断网重启仍可用 → 发布坏 hash 新版本被 App 拒绝且旧版本保留 → 后台回滚 → App 下次刷新恢复旧版本。

- [ ] **Step 5: 停止本地 Supabase 并确认无端口残留**

```bash
supabase stop
lsof -nP -iTCP:54321 -sTCP:LISTEN
lsof -nP -iTCP:54322 -sTCP:LISTEN
```

Expected: 两个端口均无监听。

- [ ] **Step 6: 范围检查**

```bash
git diff main...HEAD --stat
git diff main...HEAD --name-only
git diff --check
git status --short
```

确认没有 StoreKit、价格、购买、权益、Cover to Reveal、手机号、付费 Bucket 或阶段外功能。

---

### Task 12: 分阶段部署与真机验收

**Files:**
- No code changes unless a verified defect requires a separate RED→GREEN fix commit.

**Interfaces:**
- Consumes: Task 11 全部通过。
- Produces: hosted schema、Storage、admin-coins Function 和真机动态硬币证据。

- [ ] **Step 1: 只读部署门禁**

确认分支干净、Supabase link 指向 Toss 开发项目、dry-run 只包含本阶段迁移、`TOSS_ADMIN_USER_ID` 名称存在且不读取值。

- [ ] **Step 2: 获得明确部署授权后再执行数据库 push**

```bash
supabase db push
```

- [ ] **Step 3: 部署 admin-coins，保持 JWT 验证开启**

```bash
supabase functions deploy admin-coins
```

不得使用 `--no-verify-jwt`。

- [ ] **Step 4: 通过后台发布一枚真实免费测试硬币**

不使用生产密钥，不上传未授权素材；记录 coin slug、版本号、文件大小和 hash 是否匹配，但不输出 JWT 或管理员 UUID。

- [ ] **Step 5: 真机验收**

验证：Guest 浏览/下载/选择；断网重启；Toss 动画和声音/触觉；登录后选择同步；另一设备登录后下载并恢复选择；登出恢复 Guest 选择；账户页和删除账户流程未回归。

- [ ] **Step 6: 部署后只读检查**

确认 migration history 一致、Function ACTIVE/JWT 开启、公开用户无写权限、Bucket 路径不可覆盖、`git status --short` 干净。

- [ ] **Step 7: 文档与阶段提交**

仅在所有证据明确后更新 `README.md`、`DECISIONS.md`、`SPRINTS.md`，记录 StoreKit 仍未开始；独立提交文档，然后走只读合并检查、fast-forward 合并和普通 push。

---

## 验收标准

- App 无网络、Supabase 故障或目录损坏时仍立即显示内置 Classic 并完成 Toss。
- 后台发布新免费硬币后，App 无需更新即可发现、下载、校验并切换。
- 下载中断、大小/hash 错误、RealityKit 加载失败均不会替换旧缓存。
- 已发布资源路径不可覆盖，新版本只能使用新路径。
- Guest 本机选择与登录账户云端选择相互隔离；旧 generation 结果不能覆盖新 Session。
- 首页左上角 44pt 入口与账户按钮对称，不侵入硬币手势区域。
- 管理后台和 iOS 均不含 service key；普通客户端无法写目录或 Storage。
- 当前阶段没有 StoreKit、Product ID、价格、交易或权益结构。

## 额度与时间控制

- Task 1–7、9–10 只运行本任务聚焦测试。
- 全部 pgTAP、全部 Edge 测试、全部 TossTests 各最多运行一次；仅在相应代码后续发生变化时才重跑。
- Debug 构建在 UI 集成完成后运行一次；最终门禁若无 iOS 变更直接复用。
- UI Tests 不运行；使用一次模拟器和一次真机主流程验收。
- 数据库部署、Function 部署、真实上传和跨设备验收都需要单独授权，不与本地实现混跑。
- 任何门禁失败先停止并报告；不得通过扩大改动范围或重复全量测试来碰运气。

## 自检结果

- Spec coverage：免费目录、Storage、不可变版本、iOS 缓存、离线回退、选择同步、全屏 UI、单管理员后台、部署与真机验收均有对应任务。
- Scope exclusions：StoreKit、价格、Product ID、购买记录、权益、Cover to Reveal、手机号、多角色管理均明确排除。
- Type consistency：目录、版本、缓存、选择和管理 API 的名称在前后任务一致。
- Placeholder scan：三项 migration 使用确定且有序的版本号；新增文件、测试类和命令均已明确。Task 0 只负责确认现有工程入口，若实际旧文件布局与计划不一致则停止报告，不静默猜测或扩大重构。

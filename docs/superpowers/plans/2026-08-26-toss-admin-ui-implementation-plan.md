# Toss 管理后台 UI 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 按已确认的深色后台视觉稿和设计说明，重做 `/coins` 与 `/coins/:id` 的可扫描、响应式管理界面，同时保持所有现有免费硬币管理行为不变。

**架构：** 继续由 `adminCoins` 调用既有 `admin-coins` Function；新增纯展示辅助函数把已有硬币和版本响应转换为状态标签、资产语义与可读文本。Vue View 只消费这些已有数据和既有操作，不创建新的 API、数据字段、路由或本地持久化状态。

**技术栈：** Vue 3、TypeScript、Vue Router、Vitest、Vue Test Utils、Vite、现有 Supabase JavaScript SDK。

**设计依据：** `docs/superpowers/specs/2026-08-26-toss-admin-ui-design.md`

## 全局约束

- 只修改 `admin/`、最终的 `SPRINTS.md` 与本计划；禁止修改 iOS、Supabase migration、Storage policy、Edge Function、CDN 或部署配置。
- 只消费既有 actions：`listDrafts`、`createCoin`、`updateCoin`、`createVersion`、`createUploadURL`、`publishVersion`、`rollbackVersion`、`hideCoin`、`restoreCoin`。
- 禁止新增价格、StoreKit、Premium、订阅、购物车、用户管理、多管理员、统计、审计、批量操作、删除、拖放排序、版本覆盖上传、路径编辑、SHA 编辑或 signed URL 展示。
- 使用中文管理后台文案；不得在错误、日志或页面中暴露 JWT、管理员 ID、service-role key、SQL、堆栈、signed URL、本地路径或 Function 内部细节。
- 仅在 `activeVersionID` 指向且状态为 `published` 的版本具备模型/预览路径时显示“已就绪”；草稿或无法验证的资源只能显示“待上传”。
- WebP 预览只使用已有公开 `previewPath` 生成公共读取 URL；不得请求 signed URL。Classic 不伪造为动态资源。
- 每个任务先做聚焦 RED→GREEN；失败立即停止。完整后台测试与生产构建仅在 Task 5 运行一次。
- 每个任务必须先完成人工视觉门禁，再运行 `git diff --check` 与提交。

---

## 文件结构

| 文件 | 职责 |
| --- | --- |
| `admin/src/services/adminCoins.ts` | 扩充前端只读 `AdminCoin` / `CoinVersion` 类型，使其准确承载既有 Function 返回字段。 |
| `admin/src/presentation/coinPresentation.ts` | 纯函数：硬币/版本状态、active version、资源语义、格式化字节数与安全公开预览 URL。 |
| `admin/src/presentation/coinPresentation.test.ts` | 展示语义的单元测试。 |
| `admin/src/App.vue` | 深色全局设计 Token、可访问的默认焦点态与响应式壳层。 |
| `admin/src/views/CoinsView.vue` | `/coins` 头部、创建区、筛选、列表/窄屏卡片、加载/空态/错误及既有隐藏恢复操作。 |
| `admin/src/views/CoinsView.test.ts` | 列表筛选、状态、资源语义、空态、错误和现有操作测试。 |
| `admin/src/views/CoinEditorView.vue` | `/coins/:id` 页面头部、基本信息、当前版本、资源、版本历史和既有发布/回滚操作。 |
| `admin/src/views/CoinEditorView.test.ts` | 编辑器展示、版本目标、busy、成功/安全错误的聚焦测试。 |
| `admin/src/components/AssetUploadPanel.vue` | 不改变上传顺序的资源选择、进度和安全错误视觉。 |
| `admin/src/components/AssetUploadPanel.test.ts` | 上传控件可访问性、选择状态及既有格式/大小保护测试。 |
| `SPRINTS.md` | 所有验收通过后追加后台 UI Sprint 记录。 |

---

### Task 1：目录展示语义与深色视觉基础

**文件：**
- 修改：`admin/src/services/adminCoins.ts`
- 新建：`admin/src/presentation/coinPresentation.ts`
- 新建：`admin/src/presentation/coinPresentation.test.ts`
- 修改：`admin/src/App.vue`

**接口：**
- `CoinVersion` 必须包含既有 Function 返回的 `modelPath`、`previewPath`、`modelByteSize`、`modelSHA256`、`minAppVersion`、`assetSchemaVersion`、`publishedAt`（均可选）以及现有 `id`、`versionNumber`、`status`。
- `AdminCoin` 必须包含既有 `publishedAt`，并继续使用 `activeVersionID` 与 `versions`；不得新增 `updatedAt`、对象存在性或任何后端字段。
- 新增 `coinPresentation.ts`：

```ts
export type CoinAssetState = "ready" | "incomplete";

export function activeVersion(coin: AdminCoin): CoinVersion | undefined;
export function coinStatusLabel(status: string | undefined): string;
export function versionStatusLabel(status: string | undefined): string;
export function assetState(coin: AdminCoin): CoinAssetState;
export function assetStateLabel(state: CoinAssetState): "已就绪" | "待上传";
export function formatBytes(value: number | undefined): string;
export function publicPreviewURL(
  previewPath: string | undefined,
  makePublicURL: (path: string) => string,
): string | undefined;
```

- `assetState` 仅在 active version 为 `published` 且同时存在 `modelPath`、`previewPath` 时返回 `ready`。不能推断 Storage 对象是否存在。

- [ ] **Step 1：写失败测试**

创建 `admin/src/presentation/coinPresentation.test.ts`：

```ts
import {
  activeVersion,
  assetState,
  assetStateLabel,
  coinStatusLabel,
  formatBytes,
  publicPreviewURL,
} from "./coinPresentation";

const publishedCoin = {
  id: "coin-1",
  displayName: "美丽梦境",
  sortOrder: 10,
  isFeatured: true,
  status: "published",
  activeVersionID: "version-2",
  versions: [
    { id: "version-1", versionNumber: 1, status: "published" },
    {
      id: "version-2", versionNumber: 2, status: "published",
      modelPath: "coins/dream/v2/model.usdz",
      previewPath: "coins/dream/v2/preview.webp",
      modelByteSize: 1_572_864,
    },
  ],
};

it("only calls an active published version with both paths ready", () => {
  expect(activeVersion(publishedCoin)?.id).toBe("version-2");
  expect(assetState(publishedCoin)).toBe("ready");
  expect(assetStateLabel(assetState(publishedCoin))).toBe("已就绪");
  expect(assetState({ ...publishedCoin, activeVersionID: undefined })).toBe("incomplete");
  expect(assetState({ ...publishedCoin, versions: [{ ...publishedCoin.versions[1], previewPath: undefined }] })).toBe("incomplete");
});

it("formats only known values and never invents a public preview path", () => {
  expect(coinStatusLabel("hidden")).toBe("已隐藏");
  expect(formatBytes(1_572_864)).toBe("1.5 MB");
  expect(formatBytes(undefined)).toBe("—");
  expect(publicPreviewURL(undefined, (path) => `https://example.test/${path}`)).toBeUndefined();
  expect(publicPreviewURL("coins/dream/v2/preview.webp", (path) => `https://example.test/${path}`))
    .toBe("https://example.test/coins/dream/v2/preview.webp");
});
```

- [ ] **Step 2：运行 RED 门禁**

在 `admin/` 目录运行：

```bash
npm test -- --run src/presentation/coinPresentation.test.ts
```

预期：仅因 `coinPresentation.ts` 和其导出接口不存在而失败。

- [ ] **Step 3：实现类型、纯展示函数与全局 Token**

1. 扩充 `adminCoins.ts` 的现有 TypeScript 类型，不改变 `AdminCoinRequest`、调用参数、上传逻辑或错误映射。
2. 创建 `coinPresentation.ts`，以严格的 `activeVersionID` 查找版本；未知状态返回 `未知`；`formatBytes` 仅格式化有限正数，其他值返回 `—`；`publicPreviewURL` 在没有路径时返回 `undefined`。
3. 在 `App.vue` 将浅色全局样式替换为深色 Token：炭黑页面、暖象牙文字、香槟金强调、低对比分隔线、显式 `:focus-visible`。移除 `body { min-width: 960px; }`，使窄屏布局可工作。
4. 不在此 Task 修改列表或编辑器模板；Token 只能提供全局背景、字体和表单默认外观。

- [ ] **Step 4：运行 GREEN 门禁**

运行 Step 2 命令。预期：全部展示语义测试通过。

- [ ] **Step 5：人工视觉门禁与提交**

启动现有后台开发服务，确认登录页的深色底色、输入框、焦点态和错误文字仍可读；不发送 OTP，不调用管理 API。

```bash
git diff --check
git add admin/src/App.vue admin/src/services/adminCoins.ts admin/src/presentation/coinPresentation.ts admin/src/presentation/coinPresentation.test.ts
git commit -m "feat: add admin display foundations"
```

停止，等待审核。

---

### Task 2：硬币目录桌面表格、筛选与窄屏列表

**文件：**
- 修改：`admin/src/views/CoinsView.vue`
- 修改：`admin/src/views/CoinsView.test.ts`
- 必要时修改：`admin/src/presentation/coinPresentation.ts`
- 必要时修改：`admin/src/presentation/coinPresentation.test.ts`

**接口：**
- 使用 Task 1 的 `activeVersion`、`assetState`、`assetStateLabel`、`coinStatusLabel` 与 `publicPreviewURL`。
- 列表本地状态新增：`selectedStatus: "all" | "draft" | "published" | "hidden"`。
- `filteredCoins` 仅从成功加载的 `coins` 计算；筛选不得再次调用 `listDrafts`。
- `reload()` 复用现有 `load()`；失败时不得清空上一次成功的 `coins`。

- [ ] **Step 1：写失败测试**

在 `CoinsView.test.ts` 添加固定目录 fixture，并添加：

```ts
it("filters the loaded catalog locally and keeps hidden coins recoverable", async () => {
  const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([
    publishedCoin, draftCoin, hiddenCoin,
  ]) } });
  await flushPromises();

  await wrapper.get('[data-test="status-filter-hidden"]').trigger("click");
  expect(wrapper.text()).toContain("隐藏硬币");
  expect(wrapper.text()).toContain("恢复");
  expect(wrapper.text()).not.toContain("发布硬币");
});

it("renders only honest active-version asset states", async () => {
  const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockResolvedValue([
    publishedCoin, draftCoin,
  ]) } });
  await flushPromises();
  expect(wrapper.text()).toContain("已就绪");
  expect(wrapper.text()).toContain("待上传");
  expect(wrapper.text()).not.toMatch(/缺少模型|缺少预览/);
});

it("keeps a loaded catalog visible when reload fails", async () => {
  const loadCoins = vi.fn()
    .mockResolvedValueOnce([publishedCoin])
    .mockRejectedValueOnce(new AdminCoinsError(500, "管理服务暂时无法完成此操作。"));
  const wrapper = mount(CoinsView, { props: { loadCoins } });
  await flushPromises();
  await wrapper.get('[data-test="reload-coins"]').trigger("click");
  await flushPromises();
  expect(wrapper.text()).toContain("发布硬币");
  expect(wrapper.text()).toContain("管理服务暂时无法完成此操作。");
});
```

- [ ] **Step 2：运行 RED 门禁**

```bash
npm test -- --run src/views/CoinsView.test.ts
```

预期：仅因筛选、资源状态列、重新加载入口或保留列表错误态尚未实现而失败。

- [ ] **Step 3：实现目录页面**

1. 依设计说明重构页面头部：eyebrow `Toss 管理后台`、标题 `硬币`、右侧 `创建硬币` 主按钮。主按钮展开/收起现有 slug 与 display name 内联表单；提交成功仍跳转既有编辑页。
2. 增加“全部 / 草稿 / 已发布 / 已隐藏”本地 segmented control，带 `data-test="status-filter-all|draft|published|hidden"`。隐藏项在“全部”和“已隐藏”中可见，只有恢复动作；草稿不显示隐藏/恢复。
3. 桌面使用横向滚动容器中的语义化表格，显示 Preview、名称、Slug、状态、当前版本、资源、排序、精选、操作。每个状态有文字与视觉边界；slug/path 使用等宽字体；Preview 只在公开 `previewPath` 已知时通过现有 SDK 的 `getSupabaseClient().storage.from("coin-previews").getPublicUrl(path).data.publicUrl` 生成公共读取 URL，再传入 `publicPreviewURL`。不得调用 `createUploadURL` 或显示任何 signed URL。
4. 加载时显示 5 行以上的 skeleton；空筛选显示“此状态下暂无硬币。”；总空态显示创建引导；错误面板提供 `data-test="reload-coins"`，但不清空旧列表。
5. 宽度低于 760px 用 CSS 切换为两行密度列表，保留名称、状态、slug、版本、资源与文字操作。不得加入分页、下拉筛选、汉堡菜单或省略号菜单。
6. 保留创建、编辑、隐藏、恢复的当前调用、确认文案和安全错误文案；行级忙碌仅禁用同一行重复操作。

- [ ] **Step 4：运行 GREEN 门禁**

运行 Step 2 命令。预期：现有及新增 `CoinsView` 测试全部通过。

- [ ] **Step 5：人工视觉门禁与提交**

用已登录后台在一次加载的目录上检查：桌面列清晰、隐藏可恢复、草稿资源不会被写成“已就绪”、窄屏不遮挡操作。不得创建、隐藏或恢复硬币。

```bash
git diff --check
git add admin/src/views/CoinsView.vue admin/src/views/CoinsView.test.ts admin/src/presentation/coinPresentation.ts admin/src/presentation/coinPresentation.test.ts
git commit -m "feat: redesign admin coin catalog"
```

停止，等待审核。

---

### Task 3：硬币编辑器的信息层级、资源与版本历史

**文件：**
- 修改：`admin/src/views/CoinEditorView.vue`
- 修改：`admin/src/views/CoinEditorView.test.ts`
- 修改：`admin/src/components/AssetUploadPanel.vue`
- 修改：`admin/src/components/AssetUploadPanel.test.ts`
- 必要时修改：`admin/src/presentation/coinPresentation.ts`
- 必要时修改：`admin/src/presentation/coinPresentation.test.ts`

**接口：**
- 编辑器继续从既有 `AdminCoin.versions` 计算 `targetVersion(action, coin)`；只允许最高版本号 draft 发布、最高版本号的非 active published 回滚。
- 新增只读呈现函数：`versionsDescending(coin: AdminCoin): CoinVersion[]`，按 `versionNumber` 降序，不能改变原数组或依赖 API 返回顺序。
- AssetUploadPanel 的 `completed` 事件与上传顺序不变：createVersion → model signed PUT → preview signed PUT → listDrafts。

- [ ] **Step 1：写失败测试**

在 `CoinEditorView.test.ts` 添加有完整版本字段的 fixture，并添加：

```ts
it("renders only known current-version and asset facts", () => {
  const wrapper = mount(CoinEditorView, { props: { coin: publishedCoin } });
  expect(wrapper.text()).toContain("当前版本");
  expect(wrapper.text()).toContain("v2");
  expect(wrapper.text()).toContain("已就绪");
  expect(wrapper.text()).toContain("model.usdz");
  expect(wrapper.text()).toContain("preview.webp");
  expect(wrapper.text()).toContain("1.5 MB");
  expect(wrapper.text()).not.toMatch(/signed|https:\/\/.*token/i);
});

it("lists versions in descending order without changing publish and rollback targets", () => {
  const wrapper = mount(CoinEditorView, { props: { coin: versionsInUnsortedOrder } });
  const versionLabels = wrapper.findAll('[data-test="version-history-row"]')
    .map((row) => row.attributes("data-version"));
  expect(versionLabels).toEqual(["3", "2", "1"]);
});
```

在 `AssetUploadPanel.test.ts` 添加：

```ts
it("keeps selected USDZ and WEBP file names visible while upload is pending", async () => {
  let finish!: () => void;
  const wrapper = mount(AssetUploadPanel, {
    props: { upload: () => new Promise<void>((resolve) => { finish = resolve; }) },
  });
  await chooseFiles(wrapper, file("coin.usdz"), file("preview.webp"));
  await wrapper.get("form").trigger("submit");
  expect(wrapper.text()).toContain("coin.usdz");
  expect(wrapper.text()).toContain("preview.webp");
  finish();
});
```

- [ ] **Step 2：运行 RED 门禁**

```bash
npm test -- --run src/views/CoinEditorView.test.ts src/components/AssetUploadPanel.test.ts
```

预期：仅因当前版本面板、资源事实、版本历史或选择文件可见性尚未实现而失败。

- [ ] **Step 3：实现编辑器与上传区视觉**

1. 重构头部为返回 `硬币`、display name、只读 monospace slug、硬币状态 badge 与保存状态；保留既有 `保存更改`、安全错误和 `role="status"` 发布成功提示。
2. 宽屏使用“基本信息 / 当前版本”双列，上方以下方放置全宽“资源 / 版本历史”；小于 760px 变单列。不得增加不存在的 Edit、删除或路径编辑操作。
3. 当前版本只显示 active version 的真实字段：版本、状态、发布日期（有值才显示）、已就绪/待上传、现有发布或回滚按钮。没有 active version 显示 `—`。
4. 资源区只读显示公开 WebP（路径已知时）、模型/预览文件名、可读 byte size、截断 SHA、最低 App 版本、asset schema version 和固定 bucket/path 摘要。不得显示 signed URL，空路径不得拼接。
5. 版本历史按降序显示版本号、状态、active 标记、路径摘要、大小、最低 App 版本、发布日期和已有可用操作。隐藏硬币仍显示只读历史及恢复后的管理上下文。
6. 保留上传流程与字段；将文件选择改成清晰的资源选择区，上传中显示文件名、进度、忙碌状态及安全错误。不得增加重新上传同一版本或覆盖上传。

- [ ] **Step 4：运行 GREEN 门禁**

运行 Step 2 命令。预期：现有及新增编辑器/上传测试全部通过。

- [ ] **Step 5：人工视觉门禁与提交**

用已有草稿或已发布硬币只读打开编辑页：检查 desktop 双列和窄屏单列，验证发布/回滚目标按钮、版本历史和只读资源信息清晰。不得上传、发布、回滚、隐藏或恢复。

```bash
git diff --check
git add admin/src/views/CoinEditorView.vue admin/src/views/CoinEditorView.test.ts admin/src/components/AssetUploadPanel.vue admin/src/components/AssetUploadPanel.test.ts admin/src/presentation/coinPresentation.ts admin/src/presentation/coinPresentation.test.ts
git commit -m "feat: redesign admin coin editor"
```

停止，等待审核。

---

### Task 4：目录与编辑器的可访问性、忙碌态和窄屏收口

**文件：**
- 修改：`admin/src/views/CoinsView.vue`
- 修改：`admin/src/views/CoinsView.test.ts`
- 修改：`admin/src/views/CoinEditorView.vue`
- 修改：`admin/src/views/CoinEditorView.test.ts`
- 修改：`admin/src/components/AssetUploadPanel.vue`
- 修改：`admin/src/components/AssetUploadPanel.test.ts`
- 必要时修改：`admin/src/App.vue`

**接口：**
- 继续使用既有 `busy`、`creating`、`uploading` 与安全 `errorMessage`；不得创建全局 loading store。
- 成功信息继续使用 `role="status"`；列表加载失败的重新加载按钮用 `aria-label="重新加载硬币目录"`；筛选控件使用真实 `<button>` 且有 `aria-pressed`。

- [ ] **Step 1：写失败测试**

在 `CoinsView.test.ts` 添加：

```ts
it("exposes filter state and an accessible reload action", async () => {
  const wrapper = mount(CoinsView, { props: { loadCoins: vi.fn().mockRejectedValue(new Error("failed")) } });
  await flushPromises();
  expect(wrapper.get('[data-test="status-filter-all"]').attributes("aria-pressed")).toBe("true");
  expect(wrapper.get('[aria-label="重新加载硬币目录"]').exists()).toBe(true);
});
```

在 `CoinEditorView.test.ts` 添加：

```ts
it("announces save state and keeps transition controls disabled while busy", async () => {
  let finish!: () => void;
  const wrapper = mount(CoinEditorView, {
    props: { coin, saveCoin: () => new Promise<void>((resolve) => { finish = resolve; }) },
  });
  await wrapper.get("form").trigger("submit");
  expect(wrapper.get('[data-test="publish"]').attributes("disabled")).toBeDefined();
  finish();
});
```

在 `AssetUploadPanel.test.ts` 添加：

```ts
it("exposes upload progress with an accessible status message", async () => {
  let finish!: () => void;
  const wrapper = mount(AssetUploadPanel, {
    props: { upload: () => new Promise<void>((resolve) => { finish = resolve; }) },
  });
  await chooseFiles(wrapper, file("coin.usdz"), file("preview.webp"));
  await wrapper.get("form").trigger("submit");
  expect(wrapper.get('[role="status"]').text()).toContain("正在上传");
  finish();
});
```

- [ ] **Step 2：运行 RED 门禁**

```bash
npm test -- --run src/views/CoinsView.test.ts src/views/CoinEditorView.test.ts src/components/AssetUploadPanel.test.ts
```

预期：仅因 aria 状态、保存忙碌态或上传状态语义尚未实现而失败。

- [ ] **Step 3：实现可访问性与响应式收口**

1. 为筛选、重新加载、创建、保存、上传、发布、回滚、隐藏和恢复补足语义化忙碌/禁用态；同一行/同一操作只禁用重复动作，不能冻结其它硬币。
2. 为已保存、发布成功、上传中和安全错误提供 `role="status"` 或已有安全错误区域，保留中文文案且不泄露内部信息。
3. 用浏览器 1440px、1024px、760px、390px 四个宽度检查列表与编辑器：不得横向裁切主要操作；桌面表格在中宽可横滚；窄屏切到信息堆叠；表单和资源区单列；任何底部内容均可滚动到达。
4. 不添加图中的分页、窄屏省略号菜单、虚假同步/对象状态或新的管理功能。

- [ ] **Step 4：运行 GREEN 门禁**

运行 Step 2 命令。预期：现有及新增测试全部通过。

- [ ] **Step 5：人工视觉门禁与提交**

用已登录后台在四个宽度检查 `/coins` 与已有硬币编辑页；只读检查 loading、空态、错误态、已隐藏、草稿、已发布和版本历史。不得触发创建、上传、发布、回滚、隐藏或恢复。

```bash
git diff --check
git add admin/src/App.vue admin/src/views/CoinsView.vue admin/src/views/CoinsView.test.ts admin/src/views/CoinEditorView.vue admin/src/views/CoinEditorView.test.ts admin/src/components/AssetUploadPanel.vue admin/src/components/AssetUploadPanel.test.ts
git commit -m "feat: polish admin console accessibility"
```

停止，等待审核。

---

### Task 5：后台总门禁与最终视觉验收

**文件：**
- 修改：`SPRINTS.md`

**前置：** Tasks 1–4 均已审核、提交，工作区干净。

- [ ] **Step 1：运行一次完整后台自动门禁**

在 `admin/` 目录运行：

```bash
npm test -- --run
npm run build
```

预期：全部后台测试通过，生产构建成功。任何失败立即停止，不修改代码。

- [ ] **Step 2：安全与范围检查**

在仓库根目录运行：

```bash
rg -n --glob '!node_modules/**' --glob '!dist/**' 'service_role|SUPABASE_SERVICE_ROLE_KEY|sb_secret_|BEGIN PRIVATE KEY|signedUrl|signed URL|StoreKit|purchase\(|Product\.products|Premium|price|subscription|cart' admin
```

预期：不得有真实秘密、私钥、签名 URL 页面展示或付费功能；`service_role` / `SUPABASE_SERVICE_ROLE_KEY` 若只存在于拒绝逻辑、测试或注释，逐项记录性质。结果不符合即停止。

- [ ] **Step 3：最终浏览器视觉验收**

在已登录的本地后台，不执行任何写操作，检查：

1. `/coins` 桌面、1024px 和窄屏布局；表格、筛选、空态、错误态、隐藏项、恢复入口和 Preview 均符合设计说明。
2. `/coins/:id` 的已发布/草稿/隐藏三种既有记录都呈现诚实资产语义；基本信息、当前版本、资源和版本历史层级清楚。
3. Create、Save、Upload、Publish、Rollback、Hide、Restore 的按钮可见性、禁用态和中文安全提示正确；只检查，不确认任何写操作。
4. 无价格、Premium、用户统计、假邮箱/同步状态、批量功能、删除、路径编辑、SHA 编辑或 signed URL。

任一项失败立即停止，不更新 Sprint。

- [ ] **Step 4：记录 Sprint 并提交**

在 `SPRINTS.md` 末尾追加本轮后台 UI：深色视觉 Token、目录筛选/状态、编辑器/版本历史、响应式/无障碍、测试与浏览器验收。不得改写历史记录。

```bash
git diff --check
git add SPRINTS.md
git commit -m "docs: record admin console redesign"
```

停止并报告最终状态；不部署、不推送、不触发 Supabase 写操作。

---

## 计划自检

- 设计说明的桌面列表、窄屏列表、编辑器信息层级、状态语义、上传区、版本历史、无障碍与最终验收分别由 Tasks 1–5 覆盖。
- `Ready` 只使用 API 已知的 active published version 与两个路径；不存在 Storage 检查结果时永远不显示 Missing model / Missing preview。
- 所有硬币与版本操作仍经现有 `adminCoins` 请求；本计划没有新增后端 action、字段、对象路径或权限。
- Task 5 是唯一运行完整后台测试与生产构建的任务；前四项只运行相关聚焦测试。

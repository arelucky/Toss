# Toss App「静谧」视觉重设计实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 在不改变 Toss 核心能力的前提下，完成首页、硬币库和账户弹出页的「静谧」视觉重设计，并将硬币库改为预选后通过底部确认按钮应用。

**架构：** 保持 `ContentView`、`CoinLibraryViewModel`、`AccountViewModel` 的状态职责。新增小型 SwiftUI 视觉 Token；硬币库拆分“已应用选择”和“预选选择”，只有确认动作调用既有持久化选择服务。

**技术栈：** Swift 5、SwiftUI、RealityKit、XCTest、iOS 17。

**设计依据：** `docs/superpowers/specs/2026-08-25-toss-app-stillness-redesign-design.md`

## 全局约束

- 只使用 SwiftUI、现有 RealityKit 和 Apple 框架；不引入 UIKit 或第三方依赖。
- 只改 App 用户端；禁止修改 `admin/`、Supabase migration、Storage、Edge Function、CDN 或下载实现。
- 保留现有英文 App 文案；不实施本地化。
- 首页的 Toss 手势、3D 模型来源、动态硬币原始材质、缓存、声音和触觉不得变化。
- 硬币库保持全屏双列圆形缩略图；禁止价格、Premium、锁、付费和缩略图卡片背景。
- 所有主交互至少 44×44pt；金色不作为唯一状态信号。
- 每个 Task 执行聚焦 RED→GREEN；失败立即停止。完整 `TossTests` 只在 Task 5 运行一次。
- 每个 Task 通过人工门禁后才运行 `git diff --check` 和提交。

---

## 文件结构

| 文件 | 职责 |
| --- | --- |
| `Toss/Components/TossVisualStyle.swift`（新建） | 静谧色彩、间距、圆角、44pt 控制尺寸。 |
| `Toss/Components/TossBackground.swift` | 使用静谧背景色，保留现有背景层级。 |
| `Toss/Views/ContentView.swift` | 首页视觉、空闲手势提示、硬币库入口。 |
| `Toss/Views/AppRootView.swift` | 账户入口视觉，保持 sheet 逻辑。 |
| `Toss/ViewModels/CoinLibraryViewModel.swift` | 预选、下载后预选和确认应用。 |
| `Toss/Views/CoinLibrary/CoinLibraryView.swift` | 主展示、网格和固定确认按钮。 |
| `Toss/Views/CoinLibrary/CoinLibraryCard.swift` | 缩略图、选中环、下载状态样式。 |
| `Toss/Views/AccountSheetView.swift`、`GuestAccountView.swift`、`AuthenticatedAccountView.swift` | 三种账户状态的自定义深色分组布局。 |
| `TossTests/Components/TossVisualStyleTests.swift`（新建） | Token 尺寸与对比度约束。 |
| `TossTests/Coins/CoinLibraryViewModelTests.swift` | 预选/确认/下载失败/隐藏回退。 |
| `TossTests/Account/AccountViewModelTests.swift`、`TossTests/TossTests.swift` | 账户与首页行为回归。 |
| `Toss.xcodeproj/project.pbxproj` | 新增 Swift 文件 target 归属。 |
| `SPRINTS.md` | 最终验收后追加 Sprint。 |

---

### Task 1：硬币库预选与确认应用

**文件：**
- 修改：`Toss/ViewModels/CoinLibraryViewModel.swift`
- 修改：`TossTests/Coins/CoinLibraryViewModelTests.swift`

**接口：**
- 新增 `@Published private(set) var preselectedID: CoinLibraryItemID`。
- 新增 `@Published private(set) var preselectedModelSource: CoinModelSource`。
- 新增 `var canApplyPreselection: Bool`，仅在预选项已缓存且不在下载中时为真。
- 新增 `func preselect(_ id: CoinLibraryItemID) async`，可下载但绝不调用 `CoinSelecting`。
- 新增 `func applyPreselection() async`，唯一允许调用 `CoinSelecting` 的用户确认入口。
- Task 3 改写 View 前必须保留 `func select(_ id: CoinLibraryItemID) async` 作为兼容入口；它顺序调用 `preselect(id)` 和 `applyPreselection()`，维持当前 UI 的立即应用语义。
- `selectedID`、`selectedModelSource` 保持为首页已应用硬币；`ContentView` 继续读取 `selectedModelSource`。

- [ ] **Step 1：写失败测试**

在 `CoinLibraryViewModelTests` 添加以下两个测试，并添加“下载成功只预选”“下载失败保留原预选”两个同类测试：

~~~swift
func testPreselectingCachedCoinDoesNotPersistOrChangeAppliedSource() async {
    let coin = makeItem()
    let subject = Subject(cached: [coin], cachedAssetIDs: [coin.id])
    await subject.viewModel.updateAvailability()

    await subject.viewModel.preselect(.coin(coin.id))

    XCTAssertEqual(subject.viewModel.preselectedID, .coin(coin.id))
    XCTAssertEqual(subject.viewModel.selectedID, .classic)
    XCTAssertEqual(subject.viewModel.selectedModelSource, .bundledClassic)
    XCTAssertTrue(subject.selection.selectedItems.isEmpty)
    XCTAssertTrue(subject.viewModel.canApplyPreselection)
}

func testApplyPreselectionPersistsAndUpdatesHomeSource() async {
    let coin = makeItem()
    let subject = Subject(cached: [coin], cachedAssetIDs: [coin.id])
    await subject.viewModel.updateAvailability()
    await subject.viewModel.preselect(.coin(coin.id))

    await subject.viewModel.applyPreselection()

    XCTAssertEqual(subject.selection.selectedItems, [coin.id])
    XCTAssertEqual(subject.viewModel.selectedID, .coin(coin.id))
    XCTAssertEqual(subject.viewModel.selectedModelSource, .downloaded(subject.assets.localURL(for: coin)))
}
~~~

- [ ] **Step 2：运行 RED 门禁**

运行：

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests/CoinLibraryViewModelTests
~~~

预期：仅因 `preselect`、`applyPreselection`、`preselectedID`、`preselectedModelSource` 或 `canApplyPreselection` 不存在而编译失败。

- [ ] **Step 3：实现最小状态拆分**

把当前 `select(_:) ` 的查找/下载/本地 URL 部分移入 `preselect(_:) `。Classic 只更新预选状态；动态硬币下载成功后只更新预选状态。实现：

~~~swift
func applyPreselection() async {
    guard canApplyPreselection else { return }
    // Classic 调用 selection.selectClassic；动态项调用 selection.select。
    // 只在这里更新 selectedID 和 selectedModelSource。
}
~~~

当 `refresh()` 发现已应用硬币已隐藏时，继续现有 Classic 回退，同时重置已应用和预选状态。失败下载不得覆盖原预选项。

保留兼容入口，避免本 Task 改动 View 前破坏当前硬币库：

~~~swift
func select(_ id: CoinLibraryItemID) async {
    await preselect(id)
    await applyPreselection()
}
~~~

- [ ] **Step 4：运行 GREEN 门禁**

运行 Step 2 命令。预期：全部 `CoinLibraryViewModelTests` 通过，证明预选不持久化、确认才持久化、下载成功不自动应用、失败保留原预选、隐藏硬币回退 Classic。

- [ ] **Step 5：静态检查与提交**

确认 `ContentView.displayedCoinModelSource` 仍读 `selectedModelSource`，且 `CoinSelecting` 只由 `applyPreselection()` 和既有隐藏回退调用。

~~~bash
git diff --check
git status --short
git add Toss/ViewModels/CoinLibraryViewModel.swift TossTests/Coins/CoinLibraryViewModelTests.swift
git commit -m "feat: confirm coin library selection"
~~~

预期：提交范围仅两个文件。停止，等待审核。

---

### Task 2：首页静谧视觉基础

**文件：**
- 新建：`Toss/Components/TossVisualStyle.swift`
- 修改：`Toss/Components/TossBackground.swift`
- 修改：`Toss/Views/ContentView.swift`
- 修改：`Toss/Views/AppRootView.swift`
- 新建：`TossTests/Components/TossVisualStyleTests.swift`
- 修改：`TossTests/TossTests.swift`
- 修改：`Toss.xcodeproj/project.pbxproj`

**接口：**
- 新增 `struct TossVisualColor`（`red`、`green`、`blue`、`opacity` 与 `swiftUIColor`）和 `enum TossVisualStyle`：`controlSize = 44`、`pageHorizontalInset = 16`、`selectionGold`、`primaryText`、`secondaryText`、`surfaceOpacity`。
- 新增 `ContentView.idleTossAffordanceOpacity`：只在 `.idle` 且没有活跃拖动时为 `1`，其余为 `0`。

- [ ] **Step 1：写失败测试**

~~~swift
func testStillnessControlsMeetMinimumTouchTarget() {
    XCTAssertEqual(TossVisualStyle.controlSize, 44)
}

func testStillnessPaletteUsesWarmGoldOnlyAsAccent() {
    XCTAssertGreaterThan(TossVisualStyle.selectionGold.red, TossVisualStyle.selectionGold.blue)
    XCTAssertGreaterThan(TossVisualStyle.primaryText.opacity, TossVisualStyle.secondaryText.opacity)
}
~~~

在 `TossTests` 添加空闲提示测试，分别断言 idle 为 `1`、tossing 为 `0`；不得使用 `sleep`。

- [ ] **Step 2：运行 RED 门禁**

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests/TossVisualStyleTests -only-testing:TossTests/TossTests
~~~

预期：仅因 Token 或空闲提示 API 不存在而失败。

- [ ] **Step 3：实现视觉 Token 与首页**

创建值类型 `TossVisualColor` 与 `TossVisualStyle`，以 `TossVisualColor.swiftUIColor` 供 View 使用，以数值分量供 XCTest 验证。让 `TossBackgroundStyle.defaultDisplay` 使用炭黑和暖色中心提亮，但保留线性渐变、径向光和地面阴影三层结构。

在 `ContentView` 中保留左右入口、action、accessibility、`tossGesture`、`handleToss`、`CoinDisplayLayer` 参数和 Toss 动画；只通过 Token 调整入口外观，并在不拦截手势的区域增加低调向上提示。提示使用 `idleTossAffordanceOpacity`。

在 `AppRootView` 只调整账户入口外观；不改 sheet、账户创建或状态。

- [ ] **Step 4：运行 GREEN 门禁**

运行 Step 2 命令。预期：新增测试和现有 `TossTests` 全部通过。

- [ ] **Step 5：Debug 构建、视觉门禁与提交**

~~~bash
xcodebuild build -project Toss.xcodeproj -scheme Toss -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'
~~~

检查：首页硬币完整可见；两个 44pt 入口对称；空闲提示克制且拖动/Toss 时隐藏；Toss、声音、触觉无回归。

~~~bash
git diff --check
git add Toss/Components/TossVisualStyle.swift Toss/Components/TossBackground.swift Toss/Views/ContentView.swift Toss/Views/AppRootView.swift TossTests/Components/TossVisualStyleTests.swift TossTests/TossTests.swift Toss.xcodeproj/project.pbxproj
git commit -m "feat: restyle toss home screen"
~~~

停止，等待审核。

---

### Task 3：硬币库静谧布局与底部确认按钮

**文件：**
- 修改：`Toss/Views/CoinLibrary/CoinLibraryView.swift`
- 修改：`Toss/Views/CoinLibrary/CoinLibraryCard.swift`
- 修改：`TossTests/Coins/CoinLibraryViewModelTests.swift`

**接口：**
- 主展示和网格选中态读取 `preselectedModelSource`、`preselectedID`。
- 网格按钮调用 `Task { await viewModel.preselect(item.id) }`。
- 底部按钮仅在 `canApplyPreselection` 为真时调用 `applyPreselection()` 并关闭页面。

- [ ] **Step 1：写失败测试**

~~~swift
func testApplyIsDisabledWhileUncachedPreselectionDownloads() async {
    let coin = makeItem()
    let subject = Subject(cached: [coin], suspendDownload: true)
    let task = Task { await subject.viewModel.preselect(.coin(coin.id)) }
    await subject.assets.waitForDownload()

    XCTAssertFalse(subject.viewModel.canApplyPreselection)
    XCTAssertEqual(subject.viewModel.selectedID, .classic)

    subject.assets.completeDownload()
    await task.value
    XCTAssertTrue(subject.viewModel.canApplyPreselection)
}
~~~

再添加测试：预选缓存动态硬币时，`preselectedModelSource` 是下载 URL，但新建 `ContentView` 的 `displayedCoinModelSource` 仍为 Classic。

- [ ] **Step 2：运行 RED 门禁**

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests/CoinLibraryViewModelTests
~~~

预期：新增测试先失败于 Task 3 需要的分离预选来源断言；若 Task 1 已完整实现且测试直接通过，将该结果记录为复用 GREEN，不重复人为制造失败。

- [ ] **Step 3：实现库内视觉与确认交互**

在 `CoinLibraryView` 通过 `.safeAreaInset(edge: .bottom)` 放置固定香槟金「Use This Coin」按钮；网格底部为按钮预留按钮高度加 24pt。按钮不可用时不得关闭页面。

主展示改读 `preselectedModelSource`，选中环改读 `preselectedID`；保留 3D 拖动、惯性、模型/预览缓存和现有加载指示。保持返回按钮、双列 `LazyVGrid`、无卡片缩略图背景和下载进度。

`CoinLibraryCard` 使用 `TossVisualStyle`，保留圆形 WebP、Classic 本地预览和下载状态；不增加锁、价格或付费标记。

- [ ] **Step 4：运行 GREEN 门禁**

运行 Step 2 命令。预期：全部硬币库测试通过。

- [ ] **Step 5：Debug 构建、视觉门禁与提交**

~~~bash
xcodebuild build -project Toss.xcodeproj -scheme Toss -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'
~~~

检查：Classic 初始预选；点击缩略图只更新主展示；可用项确认后才返回首页并改变硬币；下载状态和失败提示正常；无付费元素。

~~~bash
git diff --check
git add Toss/Views/CoinLibrary/CoinLibraryView.swift Toss/Views/CoinLibrary/CoinLibraryCard.swift TossTests/Coins/CoinLibraryViewModelTests.swift
git commit -m "feat: refine coin library selection"
~~~

停止，等待审核。

---

### Task 4：账户弹出页静谧分组布局

**文件：**
- 修改：`Toss/Views/AccountSheetView.swift`
- 修改：`Toss/Views/GuestAccountView.swift`
- 修改：`Toss/Views/AuthenticatedAccountView.swift`
- 修改：`TossTests/Account/AccountViewModelTests.swift`（仅当现有断言无法表达保留行为时）

**接口：**
- 继续由 `AccountPresentation` 分发 Guest、恢复中、登录态。
- 继续使用 `viewModel.signIn()`、`setSoundEnabled(_:)`、`setHapticEnabled(_:)`、`signOut()`、`requestAccountDeletion()`、`confirmAccountDeletion()`、`cancelAccountDeletion()`。
- 不新增资料字段、头像上传、资料编辑或新导航。

- [ ] **Step 1：运行账户行为基线**

本 Task 为纯视图层改造，不新增脆弱的 SwiftUI 结构测试：

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests/AccountViewModelTests
~~~

预期：通过。若失败立即停止，禁止开始样式调整。

- [ ] **Step 2：实现自定义分组账户界面**

去除默认 `Form` 外观，使用 `ScrollView`、`VStack`、局部 Section 与 `TossVisualStyle`：

- Guest 顶部说明登录价值，保留现有 Apple 登录按钮、覆盖 Button 和无障碍标签。
- 登录态展示已有显示名，不新增头像；声音与触觉保留原 Binding 和异步写入。
- 退出和删除仍使用 destructive role、既有确认弹窗和既有 loading 状态；危险操作独立分组。
- 保留 sheet detent、Done、dismiss、恢复中 `ProgressView` 和 `notice`。

- [ ] **Step 3：运行 GREEN 门禁**

运行 Step 1 命令。预期：全部 `AccountViewModelTests` 通过。

- [ ] **Step 4：Debug 构建、视觉门禁与提交**

~~~bash
xcodebuild build -project Toss.xcodeproj -scheme Toss -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'
~~~

检查：Guest、恢复中、登录态均完整可滚动；开关、Apple 登录、Done、退出和删除可达；确认弹窗仍存在；无新页面或 Tab。

~~~bash
git diff --check
git status --short
~~~

仅暂存改动的账户文件，然后：

~~~bash
git commit -m "feat: restyle account settings"
~~~

停止，等待审核。

---

### Task 5：iOS 总门禁与 iPhone15pm 验收

**文件：**
- 修改：`SPRINTS.md`

**前置：** Tasks 1–4 已审核、提交且工作区干净。

- [ ] **Step 1：运行一次完整 iOS 自动门禁**

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' -only-testing:TossTests
~~~

预期：全部 `TossTests` 通过。失败立即停止，报告首个失败。

- [ ] **Step 2：构建 iPhone15pm 真机包**

~~~bash
xcodebuild build -project Toss.xcodeproj -scheme Toss -configuration Debug -destination 'platform=iOS,id=00008130-000444A80AC3001C'
~~~

预期：完整 `Toss.app` 生成。失败不得改用 iPhone11。

- [ ] **Step 3：iPhone15pm 人工验收**

依次验收：

1. 首页：3D 硬币完整，左右入口均为 44pt，空闲提示克制；上滑 Toss、声音、触觉和结果无回归。
2. 硬币库：当前应用硬币初始预选；点击缩略图不改首页；点击「Use This Coin」才应用；动态下载进度/失败/重试正常；关闭重开后 3D/WebP 缓存仍即时可用。
3. 账户：Guest 与登录态可用；声音/触觉可切换；Apple 登录、Done、退出和删除确认入口存在。
4. 视觉：无价格、Premium、锁、购物车、付费 UI、旧版 2D 绘制硬币或新导航；Classic 金色，动态硬币保留 USDZ 原始材质。

任一项不通过立即停止，不提交。

- [ ] **Step 4：记录 Sprint 并提交**

在 `SPRINTS.md` 末尾追加新的 Sprint，记录静谧视觉系统、首页、硬币库预选确认、账户分组、测试和 iPhone15pm 验收；不得改写历史记录。

~~~bash
git diff --check
git add SPRINTS.md
git commit -m "docs: record stillness app redesign"
~~~

停止并报告最终状态；不部署、不推送、不进入后台 UI 任务。

---

## 计划自检

- 首页、硬币库预选确认、账户三态、视觉系统、无障碍、聚焦测试和 iPhone15pm 验收分别由 Task 1–5 覆盖。
- 所有数据层、动态资源下载、后台和付费能力均在范围外。
- `selectedID`/ `selectedModelSource` 始终表示已应用项；`preselectedID`/ `preselectedModelSource` 仅用于硬币库；只有 `applyPreselection()` 写入选择。
- 每个 Task 只跑相关测试；完整自动门禁仅 Task 5 一次。

# SPRINTS

> 本文档用于记录 Toss 项目的 Sprint 开发进度。
>
> 每完成一个 Sprint，即新增一条记录。
> 不修改历史记录，仅追加新的 Sprint。

---

# Sprint 1

## 状态

✅ 已完成

## 目标

* 建立项目基础结构
* 完成 SwiftUI 项目初始化
* 建立 MVVM 架构
* 屏幕中央显示默认硬币
* 为后续动画预留扩展能力

## 完成内容

* 完成项目初始化
* 完成目录结构整理
* 建立基础组件
* 中央显示默认硬币
* 保持项目可正常编译运行

## Git Commit

```text
3cafb6f
refactor: organize project structure
```

---

# Sprint 2

## 状态

✅ 已完成

## 开发目标

### Task 2-1（已完成）

**默认硬币组件**

完成内容：

* 新增可复用 `CoinView`
* 拆分 `CoinFront`
* 拆分 `CoinBack`
* 拆分 `CoinMaterial`
* 拆分 `CoinShadow`
* 拆分 `CoinTheme`
* 首页使用默认金色硬币
* 新增默认主题测试

Git Commit：

```text
5a92762
feat: add default coin component
```

---

### Task 2-2（已完成）

**视觉精修（Coin Polish）**

内容：

- 优化金属质感
- 优化 T Monogram
- 优化浮雕效果
- 优化光影层次
- 优化边框比例
- 优化背面同心圆


完成内容：

- 优化默认金色硬币材质层次
- 降低强高光，增加暖金属反射与轻微冷白反射
- 优化右上光源与左下暗部方向感
- 优化品牌化 T Monogram，增加扩肩、切角与浮雕质感
- 外圈边框略微减弱，中心区域比例增强
- 背面同心圆增加粗细层次，并加入中心小圆盘
- 降低外阴影，保持克制的 Apple 风格

Git Commit：

```text
feat: polish coin visual design
```

---

### Task 2-3（已完成）

**上滑交互**

目标：

* DragGesture
* 判断向上滑
* Toss 手势触发

完成内容：

* 新增 `idle` / `tossing` 基础状态
* 新增上滑阈值判断
* 上滑超过阈值后触发 Toss
* 硬币产生基础向上位移动画
* 为后续旋转动画预留状态接口
* 新增 Toss 手势状态测试

Git Commit：

```text
feat: add coin toss gesture
```

---

### Task 2-4（已完成）

**Coin Animation Rendering Strategy**

目标：

* 评估硬币旋转动画渲染方案
* 停止继续投入 SwiftUI 3D Coin Rotation
* 确认后续硬币动画技术路线

状态：

✅ Architecture decision completed

完成内容：

* 验证 SwiftUI `rotation3DEffect` 无法稳定模拟高质量双面金属硬币翻转
* 确认主要问题：
  * 双面遮挡不稳定
  * 侧边厚度表现不足
  * 旋转动画一致性不足
* 对比 SceneKit、RealityKit、序列帧动画方案
* 最终确认采用预渲染 PNG 序列帧动画
* 确认 `CoinView` 继续负责静态硬币展示
* 确认 Toss 阶段后续由 `CoinAnimationView` 播放序列帧
* 确认 SwiftUI 继续负责手势、状态、位移、缩放、阴影与帧播放控制

Git Commit：

```text
feat: add coin rotation animation
fix: improve coin 3d flip rotation
```

---

### Task 2-5（不再实施）

**Coin Animation Player**

目标：

* 创建序列帧动画播放框架
* 为 Toss 阶段播放硬币旋转动画
* 为 Sprint 3 无限旋转与后续 Reveal 停止帧预留接口

限制：

* 暂不接入最终 3D 资源
* 使用 placeholder frame 验证播放流程
* 不修改最终硬币视觉设计
* 不新增随机结果
* 不进入 Reveal

状态：

⏹️ 已由 RealityKit + USDZ 技术路线替代

---

### Task 2-7A（已完成）

**RealityKit 3D Coin Model Loading Test**

目标：

* 验证 `TossCoin.usdz` 能否通过 RealityKit 在 iOS App 中加载和显示
* 新增独立 `Coin3DView`
* 保留现有 SwiftUI `CoinView`，不替换首页硬币

完成内容：

* 新增 `Coin3DView`
* 通过 RealityKit 加载 `Toss/Resources/Models/TossCoin.usdz`
* 新增 `-showCoin3D` Debug 启动参数测试入口
* 完成模型居中、基础缩放、相机与灯光设置
* 保持现有投掷业务逻辑不变

状态：

✅ Completed

---

### Task 2-7B（已完成）

**Coin3DView Visual Tuning**

目标：

* 优化 3D 硬币测试视图，使其达到首页展示可评估状态

完成内容：

* 放大 3D 硬币显示尺寸
* 调整初始角度，让 T 正面更清楚，同时保留侧边厚度与锯齿边
* 优化 RealityKit 暖主光、冷补光与边缘金属反射
* 降低测试自动旋转速度，方便静态视觉评估

状态：

✅ Completed

---

### Task 2-7C（已完成）

**Coin3DView Final Presentation Polish**

目标：

* 对 RealityKit 3D 硬币测试视图做最终首页展示微调

完成内容：

* 硬币尺寸继续放大约 12%
* 初始角度进一步转向正面
* 保留少量侧面厚度与 Fine Reeded Edge 视觉信息
* 增强正面与 T Monogram 浮雕高光
* 保持 `CoinView` 作为现有 SwiftUI 首页硬币，不替换业务入口

Git Commit：

```text
feat: add RealityKit 3D coin preview
```

状态：

✅ Completed

---

### Task 2-8（已完成）

**3D Coin Home Integration**

目标：

* 将 `Coin3DView` 整理为正式可复用组件
* 优化首页硬币展示层结构
* 支持 RealityKit 3D 硬币与旧 SwiftUI `CoinView` 切换
* 为后续抛掷动画保留首页布局空间

完成内容：

* 新增 `CoinDisplayLayer`
* 新增 `CoinDisplayMode`
* 默认首页展示方案切换为 RealityKit 3D Coin
* 保留 Debug 参数 `-showCoin3D` / `-showSwiftUICoin` 用于视觉验证与回退查看
* `Coin3DView` 改为可复用组件，不再承担全屏测试页职责
* 保留旧 SwiftUI `CoinView` 分支，不删除旧代码

状态：

✅ Completed

---

### Task 2-9（已完成）

**Interactive 3D Coin Toss Experience**

完成内容：

* 支持触摸拖动 3D 硬币预览
* 支持松手后的惯性旋转
* 完成上滑 Toss 手势判断
* 根据手势距离与速度计算抛掷轨迹
* 完成 RealityKit 硬币旋转、位移、缩放与落地表现
* 随机生成 heads / tails 结果
* 结果保持后可再次上滑 Toss

状态：

✅ Completed

---

### Task 2-10（已完成）

**Toss Feedback and Display Environment**

完成内容：

* 新增通用 `TossBackground`
* 新增拖动、起抛、飞行与落地 Haptic 反馈
* 新增抛出和空中旋转音效
* 保持默认硬币离线可用

状态：

✅ Completed

---

### Task 2-11（已完成）

**SwiftUI Fallback Coin Polish**

完成内容：

* 精修品牌 T 正面造型与浮雕层次
* 精修同心圆背面、边缘、阴影与高光
* 更新香槟金主题材质
* 保留 `CoinView` 作为开发回退与兼容展示层

状态：

✅ Completed

---

### Task 2-12（已完成）

**Build and Test Verification**

完成内容：

* Debug 模拟器构建成功
* 完整测试套件 39 项通过

状态：

✅ Completed

---

# Sprint 3

## 状态

⏳ 未开始

规划内容：

* 无限旋转
* 等待揭晓

---

# Sprint 4

## 状态

🚧 开发中

已完成：

* 随机结果
* Haptic Feedback
* 结果保持与再次 Toss

待完成：

* Cover to Reveal
* 遮挡检测
* Reveal 动画

---

# Sprint 5

## 状态

🚧 开发中

已完成：

* 金属材质优化
* 音效
* 细节打磨

待完成：

* 光影动画

---

# Sprint 6

## 状态

🚧 开发中

已完成：

* 账户入口与设置页面
* 声音和触觉偏好开关
* Apple 登录、登出与删除账户交互

待完成：

* 完整 UI
* App Icon
* 发布准备

---

# 后台阶段

## 状态

✅ 阶段 1 已完成

### 阶段 1：Supabase Foundation

完成内容：

* 建立 Supabase 本地环境、构建配置和密钥边界
* 创建账户资料、偏好、生命周期与删除请求迁移
* 完成 RLS、列级授权、函数 ACL 和服务端最小权限
* 接入 Supabase Swift 2.49.0 与共享 Client Generation 架构
* 完成原生 Sign in with Apple、Session 恢复和安全登出
* 完成用户资料、guest/账户偏好同步及声音、触觉开关
* 完成首页账户入口、账户设置和删除账户流程
* 部署四项数据库迁移和 `delete-account` Edge Function 到开发项目
* 修正 Apple provider subject 比较，使用 Apple identity 的 `identity_data.sub`
* 真机验证登录、恢复、偏好、离线 Toss、登出和安全删除
* 最终删除请求为 completed，Apple 撤销为 revoked，账户关联数据已清除
* 冷启动保持 Guest，Guest Toss 正常

验证结果：

* 154 项 TossTests 通过
* 174 项数据库 pgTAP 通过
* 15 项 Edge Function 测试通过
* Debug 模拟器构建成功
* 无签名 Release 编译成功
* 数据库 lint 无错误

验证限制：

* Xcode 15.4 存在 UI Test runner teardown/materialization 卡住问题，本轮未重复运行 UI Tests
* 跨两台真机的偏好同步留待发布前验收

### 后续阶段

状态：⏳ 未开始

* Cover to Reveal
* 动态硬币目录与 USDZ 下载
* StoreKit 非消耗型购买
* Storage 正式资源系统
* Vue 管理后台
* 生产项目与 App 发布

---

# Stillness App 端视觉阶段

## 状态

✅ 真机验收通过

完成内容：

* Task 5 自动门禁实际执行 242 项 XCTest，全部成功
* Task 5B 完成 Stillness 真机视觉布局修正
* 首页 3D Coin 与 Toss affordance 布局完成真机验收
* Coin Library Hero 比例完成调整
* Coin Library ScrollView 与 BottomActionBar 布局边界完成修复
* 网格末项不再被底栏遮挡
* `Use This Coin` disabled 状态完成视觉修正
* Account 已完成登录态真机验收
* Stillness 当前 App 端 UI 阶段真机验收通过

---

# 管理后台 UI 重设计阶段

## 状态

✅ 人工浏览器验收通过

完成内容：

* 建立炭黑、暖象牙与香槟金的深色视觉 Token
* 完成硬币目录筛选、诚实资源状态、桌面表格与窄屏卡片布局
* 完成硬币编辑器、资源区与版本历史的信息层级重组
* 补齐可访问状态、中文安全错误、局部忙碌态与窄屏收口

验证结果：

* 完整后台测试 43/43 通过
* 管理后台生产构建通过
* 人工浏览器只读验收通过

---

# Classic 月亮硬币资源阶段

## 状态

✅ 真机验收通过

完成内容：

* Classic 内置硬币替换为月亮 USDZ 与月亮预览图
* Classic 现在保留 USDZ 原始材质

验证结果：

* 聚焦材质策略测试 1/1 通过
* iPhone15pm Debug 构建、安装启动与真机视觉/交互验收通过

---

# 深色启动页阶段

## 状态

✅ 模拟器冷启动验收通过

完成内容：

* 系统启动页改用与首页一致的深炭黑背景
* 消除从后台重新打开 App 时的默认白色启动页闪烁

验证结果：

* 启动页配置聚焦检查通过
* Debug 模拟器构建、安装和冷启动录制通过

---

# 双语静态启动页阶段

## 状态

✅ 模拟器冷启动验收通过

完成内容：

* 启动页保留深炭黑背景
* 居中静态显示“命运的一掷”与“A toss of fate”
* 不引入启动页运行代码、动画或额外等待

验证结果：

* 启动页配置聚焦检查通过
* Debug 模拟器构建、安装与冷启动录制通过

---

# 中国大陆 Classic-only 首发档案

## 状态

✅ 真机双档案验收通过

## 完成内容

* 首次启动按 App Store Storefront 解析并持久化大陆/全球档案；已保存的选择优先。
* 大陆档案仅提供内置 Classic、掷硬币、声音与触觉设置，不初始化账户、硬币库或在线服务。
* 全球档案保留账户入口、硬币库和动态硬币能力。
* 旧的国内云服务部署计划已标记为失效；本首发不采购、不部署国内云资源。
* 真机验收时使用的 Debug 档案选择器已完整移除，不会进入 TestFlight 或正式版本。

## 验证结果

* Storefront 解析、离线根视图和本地设置的聚焦测试通过。
* 完整 TossTests 与 Debug 模拟器构建通过。
* iPhone15pm 真机验收：大陆档案离线可用且不显示账户/硬币库；全球档案仍显示账户与硬币库入口。

## Git Commits

```text
6a37bac feat: resolve mainland launch profile
51c0d8d feat: add mainland offline app root
abd19a7 feat: limit mainland app to Classic
```

---

# 启动档案静态过渡页

## 状态

✅ iPhone15pm 真机首次启动验收通过

## 完成内容

* 启动时由 App 级协调器优先读取已保存的发行档案，避免不必要的异步等待。
* 首次启动解析 Storefront 期间，继续显示与系统启动页一致的深色双语静态页面。
* 档案解析完成后才切换至大陆 Classic-only 或全球在线根视图，全程不显示白屏。

## 验证结果

* 启动档案与静态过渡页聚焦测试通过。
* iPhone15pm Debug 构建、重新安装与首次启动视觉验收通过；未见白屏。

---

# 大陆首发版本准备

## 状态

✅ 本地 Release 构建验证通过

## 完成内容

* 发布版本调整为 1.0.2（1），用于包含大陆 Classic-only 档案与备案号展示的首次更新。
* 保持同一 Bundle ID，后续由 App Store Connect 的中国大陆销售范围决定可下载地区。

---

# 大陆版 App 备案号展示

## 状态

✅ 模拟器双档案验收通过

## 完成内容

* 大陆 Classic 设置页展示已核发的备案号“苏ICP备2026011580号-2A”。
* 提供“备案查询”入口，跳转至工信部备案查询页面。
* 全球在线档案不展示大陆备案信息。

## 验证结果

* 备案号与查询地址的回归测试通过。
* 完整 TossTests 256 项通过，Debug 模拟器构建通过。
* 模拟器双档案验收：大陆设置页显示备案信息；全球设置页不显示备案信息。

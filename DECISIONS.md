# DECISIONS

> 本文档用于记录 Toss 项目所有重要设计决策。
>
> 每一项 Decision 一经确认，不轻易修改。如需调整，应新增新的 Decision，而不是覆盖历史记录。

---

# Decision 001：产品定位

## 日期

2026-07-10

## 决策

Toss 不是一款普通的掷硬币工具，而是一款具有仪式感的决策应用。

用户完成一次完整的交互流程：

> 抛出 → 等待 → 揭晓

而不是：

> 点击 → 得到结果

所有功能设计均应围绕"等待命运揭晓"这一核心体验展开。

---

# Decision 002：默认硬币视觉设计

## 日期

2026-07-10

## 设计目标

默认硬币是 Toss 的品牌核心视觉，也是整个产品体验的主角。

它不仅用于当前版本，还将作为未来所有主题硬币的基础结构。

设计原则：

* 极简
* 克制
* 高级
* 具有金属质感
* 强品牌识别度
* 为动画与光影效果而设计

---

## 整体造型

采用 **Embossed Metal（浮雕金属）** 风格。

通过真实金属的层次、阴影和高光塑造立体感，而不是扁平化图标。

中心区域略微凸起，形成浮雕效果。

---

## 中心图案（正面）

正面采用品牌专属 **T（Toss）Monogram**。

要求：

* 不直接使用系统字体。
* 设计专属品牌字母。
* 简洁、现代、易识别。
* 保持缩放后的清晰辨识度。
* 为后续品牌 Logo 统一视觉语言。

T 不只是一个字母，而是 Toss 的品牌符号。

---

## 背面设计

背面不使用：

* Heads
* Tails
* Yes
* No

也不采用真实货币设计。

背面采用：

**Concentric Circle（同心圆）**

特点：

* 无文字
* 无数字
* 无国家元素
* 无复杂装饰

利用不同粗细的同心圆形成金属纹理。

当硬币旋转时，同心圆能够产生更加自然、舒适的动态视觉效果。

背面的意义不是表达结果，而是代表"未知"，真正的答案将在揭晓动画中呈现。

---

## 边缘设计

采用：

**Smooth Edge（光滑边缘）**

不使用真实硬币的齿纹。

整体结构：

* 外圈金属边框
* 双层边框（Double Ring）
* 同心圆主体
* 中心浮雕区域

形成简洁、有层次的工业设计风格。

---

## 硬币结构（Coin Architecture）

未来所有主题硬币均遵循统一结构：

* Smooth Edge
* Double Ring
* Concentric Core
* Raised Center
* Symbol Mark

仅替换：

* 材质
* 配色
* 中心图案

保证整个 Toss 品牌视觉统一。

---

## 后续扩展

未来可在统一结构基础上推出不同主题：

* Gold Coin（默认）
* Silver Coin
* Bronze Coin
* Lunar Edition
* Aurora Edition

新增主题不得改变基础结构，仅调整视觉表现。

---

# Decision 003：结果展示方式

## 日期

2026-07-10

## 决策

硬币本身不承载最终结果。

用户在旋转过程中看到的是品牌硬币，而不是"Heads"或"Tails"。

真正的随机结果将在揭晓阶段通过动画、翻面、光影和交互呈现。

这样能够强化 Toss 的核心体验：

> 等待命运揭晓，而不是提前看到答案。

因此：

* 正反面均不显示 Heads / Tails。
* 不显示 Yes / No。
* 不显示任何结果文字。

结果属于交互流程，而不是硬币设计的一部分。

---

# Decision 004：开发优先级调整

## 日期

2026-07-10

## 决策

在进入 Sprint 2 动画开发之前，优先完成默认硬币的视觉设计。

开发顺序调整为：

1. 完成默认硬币设计。
2. 完成硬币资源制作（支持后续动画）。
3. 集成至项目并确认视觉效果。
4. 开始开发上滑抛出、飞行动画和旋转动画。

原因：

硬币是 Toss 的核心视觉资产，所有动画、材质、光影和品牌识别均围绕该设计展开。优先完成视觉设计，有助于后续交互实现保持一致的设计语言。

---

# 当前确认内容

## 产品

* 仪式感优先。
* 体验高于功能。
* 品牌化而非工具化。

## 默认硬币

* 浮雕金属
* 光滑边缘
* 双层边框
* 同心圆结构
* 中心品牌 T Monogram
* 背面同心圆
* 不使用真实货币元素

## 品牌方向

未来所有主题硬币均继承统一的 Coin Architecture，仅更换材质与中心图案，形成一致且可持续扩展的 Toss 品牌视觉体系。


## Coin Animation Strategy

由于 SwiftUI rotation3DEffect
无法稳定模拟高质量双面硬币翻转，

采用：
预渲染硬币动画资源 + SwiftUI 状态控制。

原因：
- 保证视觉质量
- 降低开发复杂度
- 降低维护成本
- 节省开发资源

---

## Coin Animation Rendering Strategy

原方案：

SwiftUI `rotation3DEffect` 实现硬币真实 3D 翻转。

测试结果：

SwiftUI View 层级无法稳定模拟高质量双面金属硬币翻转：

- 双面遮挡问题
- 厚度表现不足
- 动画一致性不足

最终方案：

采用预渲染序列帧动画。

设计：

- `CoinView` 保留静态硬币展示。
- Toss 阶段使用 `CoinAnimationView` 播放序列帧。
- SwiftUI 负责：
  - 手势
  - 动画状态
  - 位移
  - 缩放
  - 阴影
  - 帧播放控制

动画资源：

Blender / AI 制作硬币 3D 资产，输出 PNG 序列帧。

规格：

- 36 frames
- 30fps
- 约 1.2 秒
- 正面 T Monogram
- 背面同心圆
- 香槟金材质
- Fine Reeded Edge

---

## Coin Homepage Rendering Direction

日期：

2026-07-28

背景：

Task 2-7A / 2-7B / 2-7C 验证了 `TossCoin.usdz` 可以通过 RealityKit 在 iOS App 中稳定加载，并能够通过独立 `Coin3DView` 达到首页静态展示的可评估视觉状态。

决策：

首页主视觉方向转向：

- RealityKit
- USDZ 3D Coin Asset
- SwiftUI 测试入口与状态承载

当前实现：

- `Coin3DView` 负责加载和展示 `TossCoin.usdz`。
- `ContentView` 通过 Debug 启动参数 `-showCoin3D` 进入 3D 硬币测试视图。
- 现有 SwiftUI `CoinView` 暂不替换，继续作为旧方案与回退参考。

原因：

- USDZ 资产能呈现真实厚度、倒角、金属边缘与 Fine Reeded Edge。
- RealityKit 对 3D 金属材质、灯光和相机表现更稳定。
- 相比 SwiftUI 纯 View 结构，3D 模型更接近最终产品主视觉要求。

后续原则：

- 在视觉确认完成前，不直接替换首页正式 `CoinView`。
- SwiftUI `CoinView` 保持可运行，作为快速预览、旧方案和回退参考。
- 后续若进入正式首页替换，应作为独立 Task 完成并单独验证。

---

# Decision 005：Supabase Foundation 与账户边界

## 日期

2026-08-11

## 决策

Toss 采用 guest-first 账户体验：默认硬币和完整 Toss 流程无需登录，App 启动不等待 Supabase、Session 恢复或网络结果。账户服务不可用时只影响账户区域，不影响 RealityKit、手势、动画、结果、Haptic 和音效。

阶段 1 后台使用：

- Supabase Auth
- Supabase PostgreSQL
- Supabase Edge Functions
- Supabase Swift 2.49.0

`auth.users.id` 是业务表唯一用户标识。Apple 身份由 Supabase Auth identities 管理，`user_profiles` 不重复保存 Apple subject。用户偏好在阶段 1 仅同步声音和触觉；动态硬币相关字段留到后续阶段。

账户数据通过 RLS、列级授权和服务端函数边界保护：客户端只能读取自己的资料和偏好，并只能更新允许的字段。账户删除请求表仅向受信任服务端开放最小 CRUD 权限。

删除账户必须先完成近期 Apple 重新认证。Edge Function 在服务端生成短期 Apple client secret、尝试交换并撤销 Apple Token，然后删除 Supabase Auth 用户并依靠外键级联清理账户数据。Apple 撤销失败不能阻止 Toss/Supabase 数据删除；只有数据删除失败才视为删除未完成。

Apple 身份一致性比较使用经过验证的 Apple `id_token.sub` 与 Supabase Apple identity 的 provider subject（`identity_data.sub`）。不得将 Supabase 内部 `identity_id` 当作 Apple provider subject，也不得记录或持久化 subject、token 或 authorization code。

## 工具链兼容决定

当前开发工具链为 Xcode 15.4 / Swift 5.10。Supabase Swift 固定为 2.49.0，传递依赖 `xctest-dynamic-overlay` 固定为 1.9.0；1.10.x 使用当前 Xcode 无法编译。升级 Xcode 或更新 Package Versions 前必须重新验证并审查该锁定。

## 验收边界

阶段 1 已部署到 Supabase 开发项目并完成 Apple 登录、Session 恢复、偏好、登出和账户删除真机验收。最终删除请求进入 `completed`，Apple 撤销结果为 `revoked`，Auth 用户及关联资料、偏好和 bootstrap 数据均清除；冷启动保持 Guest，Guest Toss 正常。

UI Tests 未作为本轮最终门禁重复执行，因为 Xcode 15.4 存在 runner teardown/materialization 卡住问题。账户关键路径已由单元测试与真机验收覆盖；跨两台真机的偏好同步仍需在后续发布验收中补充确认。

阶段 1 不包含生产项目、App 发布、手机号登录、动态硬币、StoreKit、Storage 正式资源系统、Vue 管理后台或 Cover to Reveal。

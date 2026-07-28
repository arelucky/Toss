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

🚧 开发中

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

### Task 2-5（待开始）

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

⬜ 未开始

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

# Sprint 3

## 状态

⏳ 未开始

规划内容：

* 无限旋转
* 等待揭晓

---

# Sprint 4

## 状态

⏳ 未开始

规划内容：

* Cover to Reveal
* 遮挡检测
* Reveal 动画
* 随机结果
* Haptic Feedback

---

# Sprint 5

## 状态

⏳ 未开始

规划内容：

* 金属材质优化
* 光影动画
* 音效
* 细节打磨

---

# Sprint 6

## 状态

⏳ 未开始

规划内容：

* 完整 UI
* 设置页面
* App Icon
* 发布准备

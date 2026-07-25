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

### Task 2-3（待开始）

**上滑交互**

目标：

* DragGesture
* 判断向上滑
* Toss 手势触发

状态：

⬜ 未开始

---

### Task 2-4（待开始）

**飞行动画**

目标：

* 硬币向上飞起
* 弹性动画
* 动画结束进入旋转状态

状态：

⬜ 未开始

---

### Task 2-5（待开始）

**旋转动画**

目标：

* 开始旋转
* 为 Sprint 3 无限旋转预留接口

状态：

⬜ 未开始

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

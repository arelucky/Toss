# Toss Coin Design Specification

## 1. Brand Direction

Toss Coin 是 App 核心视觉资产。

设计关键词：

- Apple inspired
- Minimal luxury
- Precision engineering
- Premium metal object

避免：

- 游戏金币感
- 夸张黄金效果
- 复杂装饰

## 2. Coin Structure

硬币：

- 圆形厚币
- 真实金属厚度
- 香槟金材质
- 精密倒角
- 边缘细密锯齿纹

## 3. Front Face

正面：

- 中心为几何直立 T Monogram
- T 为浮雕结构
- 保持克制
- 无额外文字

视觉：

- T 高于币面
- 有轻微阴影
- 有金属高光

## 4. Back Face

背面：

- 极简同心圆浮雕
- 中心圆形结构
- 无文字
- 无数字

## 5. Material

Metal:

Base Color:
Champagne Gold

视觉方向：

- 高级香槟金
- 柔和反射
- 非亮黄色黄金

参数参考：

Metallic:
1.0

Roughness:
0.2 - 0.35

## 6. Edge

侧边：

- Fine Reeded Edge
- 细密锯齿纹
- 旋转时产生光影变化

## 7. Runtime 3D Resource

当前硬币运行时资源：

- USDZ 3D model
- RealityKit rendering

RealityKit 是当前正式 3D 渲染路径。首页通过 `Coin3DView` 和当前 3D 展示层加载并显示真实 3D 硬币。

Blender 导出的 PNG 序列帧属于旧方案或视觉参考，不是当前 App 的运行依赖。

## 8. RealityKit and SwiftUI Implementation

Homepage Coin:

RealityKit + USDZ

负责：

- 首页正式硬币展示
- 真实厚度、材质与灯光表现
- 等待状态与结果状态的 3D 呈现

Toss Animation:

RealityKit 实体旋转、位移、缩放与现有状态机

负责：

- Toss
- Flip
- Reveal

SwiftUI 继续负责手势、状态和展示层协调。`CoinView` 作为旧实现、开发回退或兼容展示层保留，但不是当前首页正式渲染方案。

所有渲染路径必须保持同一视觉语言。

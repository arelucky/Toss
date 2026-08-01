# Toss 项目开发规范（AGENTS）

## 一、项目介绍

项目名称：Toss

这是一个使用 SwiftUI 开发的 iOS 应用。

它不是普通的掷硬币工具，而是一款具有仪式感的决策应用。

用户应当感受到：

"不是点击按钮得到答案，而是在完成一次小小的仪式。"

---

## 二、开发目标

所有开发工作都应优先提升：

- 用户体验
- 动画流畅度
- 交互沉浸感
- 代码可维护性

不要为了增加功能而增加复杂度。

体验始终高于功能数量。

---

## 三、技术规范

开发语言：

- Swift

UI：

- SwiftUI

架构：

- MVVM

最低支持：

- iOS 17

优先使用：

- SwiftUI 原生能力

避免：

- UIKit
- 不必要的第三方库
- 复杂抽象

---

## 四、代码规范

代码应满足：

- 简洁
- 易读
- 易维护
- 单一职责

优先拆分组件。

View 不宜过长。

命名应清晰表达含义。

仅在必要时添加注释。

---

## 五、UI 设计原则

遵循 Apple Human Interface Guidelines。

整体风格：

- 极简
- 克制
- 沉浸
- 有质感

避免：

- 花哨动画
- 多余按钮
- 冗余文字

---

## 六、产品理念

Toss 不是随机数工具。

而是一种决策体验。

用户应该是在：

"等待命运揭晓。"

而不是：

"点击按钮。"

所有交互都应围绕这种体验设计。

---

## 七、交互原则

用户应尽可能直接与硬币互动。

减少按钮。

减少菜单。

减少学习成本。

整个应用应该做到：

打开即可使用。

---

## 八、当前产品设计

当前交互流程：

1.

用户打开 App

↓

屏幕中央出现一枚硬币

↓

用户向上滑动

↓

硬币飞起并高速旋转

↓

等待玩家揭晓结果

↓

玩家使用手掌覆盖手机

↓

检测到遮挡

↓

硬币停止旋转

↓

随机生成：

Heads

或

Tails

↓

轻微震动反馈

↓

玩家拿开手掌

↓

看到最终结果

---

## 九、Git 提交规范

完成一个独立功能后：

必须：

- 能正常编译
- 能正常运行
- 提交 Git
- Git Hash 不写入同一个 Commit 内的文件。
- Sprint 记录功能状态即可。
- Git Log 负责保存版本关系。
Commit Message 使用英文。


例如：

feat: add coin view

fix: improve animation

refactor: split coin component

---

## 十、Codex 工作规范

在修改代码前：

必须先阅读整个项目。

优先理解已有架构。

不要随意修改已有设计。

不要删除已有功能。

保持项目始终可以运行。

如果存在更好的实现方案，可以提出建议，但不要直接推翻已有架构。

---

## 十一、 开发完成 Checklist

☐ Build Success

☐ Tests Pass

☐ Git Commit

☐ Update SPRINTS.md

☐ Update README.md（如需要）

☐ Update DECISIONS.md（如需要）

## 十二、AI 开发协作流程

ChatGPT 负责：

- 产品设计
- 架构设计
- Sprint 规划
- Code Review
- 技术决策


Codex 负责：

- 代码实现
- Build
- Test
- Git Commit


开发原则：

- 每次只完成一个独立 Task。
- 避免重复描述已有文档内容。
- 优先引用 README、DECISIONS、SPRINTS。
- 保持修改范围最小。

## Context Loading Rule

同一开发会话：
无需重复读取项目文档。

新会话：
优先读取：
1. AGENTS.md
2. SPRINTS.md

涉及设计修改时读取：
3. DECISIONS.md

README.md 仅在需要了解项目介绍时读取。

## Git Commit Strategy

普通功能开发：
- 完成一个独立功能后提交。

视觉与动画开发：
- 允许多轮修改。
- 未通过视觉验证前不要提交。
- 确认效果后再创建最终 Commit。

避免：
- 为实验性调整创建大量 Commit。
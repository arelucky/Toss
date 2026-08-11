# Toss 🪙

## 项目简介

Toss 是一款面向 iOS 17.5 及以上版本、使用 SwiftUI 与 RealityKit 开发的极简掷硬币应用。

它不是一个普通的随机工具，而是一个具有仪式感的决策 App。

用户可以直接拖动 3D 硬币预览，并通过向上滑动完成一次包含飞行、旋转、落地、声音和触觉反馈的 Toss。默认硬币内置于 App，离线且未登录时仍可使用。

---

## 产品理念

不是点击按钮得到答案。

而是完成一次属于自己的小仪式。

我们希望用户记住的是体验，而不是功能。

---

## 技术栈

- SwiftUI
- Swift
- MVVM
- RealityKit + USDZ
- Supabase Auth、PostgreSQL 与 Edge Functions
- Supabase Swift 2.49.0
- Xcode
- Git
- GitHub
- Codex

最低部署版本：iOS 17.5。

## 当前已验证能力

- RealityKit + USDZ 首页硬币展示
- 拖动、惯性旋转和上滑 Toss 手势
- 飞行、旋转、位移、缩放、随机结果与再次 Toss
- Haptic、抛出音效和空中旋转音效
- Guest-first 启动；账户或网络不可用不会阻塞 Toss
- 原生 Sign in with Apple、Session 恢复与安全登出
- 用户资料及声音、触觉偏好同步
- App 内账户删除，服务端尝试撤销 Apple Token 并删除 Supabase Auth 用户

Cover to Reveal、动态硬币、StoreKit 商业化、Storage 资源发布和管理后台尚未实现。

## Supabase 开发环境

公开的 hosted URL 与 publishable key 通过本机 `Configurations/LocalSecrets.xcconfig` 注入。该文件被 Git 忽略；仓库只保留示例配置。service-role、数据库密码、Apple `.p8` 和其他服务端 Secret 不得进入 iOS App 或 Git。

本地数据库验证使用 Supabase CLI 与 Docker：

```bash
supabase start --network-id toss-supabase-local
supabase db reset --local
supabase test db --network-id toss-supabase-local
supabase db lint --local --level warning
supabase stop
```

Stage 1 已部署到 Toss 的 Supabase 开发项目；尚未创建生产项目。

---

## 开发路线（Roadmap）

### Toss 核心体验

- [x] RealityKit 3D 硬币与 USDZ 资源
- [x] 拖动、惯性旋转和上滑 Toss
- [x] 飞行、落地、随机结果与再次 Toss
- [x] 金属材质、背景、Haptic 与音效
- [ ] Cover to Reveal、遮挡检测与 Reveal 动画

### Supabase Foundation

- [x] 本地环境、迁移和 RLS
- [x] Supabase Swift 依赖注入
- [x] Apple 登录、Session 恢复与登出
- [x] 用户资料与偏好同步
- [x] 账户设置与安全删除

### 后续阶段

- [ ] Cover to Reveal
- [ ] 动态硬币目录与资源下载
- [ ] StoreKit 非消耗型购买
- [ ] Vue 管理后台
- [ ] App Icon 与发布准备

---

## 当前版本

v0.1.0（开发中，Supabase Foundation 已完成）

验证基线：154 项 iOS 单元测试、174 项数据库 pgTAP 和 15 项 Edge Function 测试通过；Debug 模拟器与无签名 Release 编译成功。UI Tests 本轮未重复运行，因为 Xcode 15.4 存在已知 runner teardown/materialization 卡住问题，关键账户流程已完成真机验收。

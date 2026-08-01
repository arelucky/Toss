# Toss 后台系统与 App 整合架构设计

- 状态：已确认
- 日期：2026-08-01
- 范围：架构设计，不包含实现代码

## 1. 背景

Toss 是一款 iOS 17+ 的 SwiftUI 决策仪式 App。当前客户端已经完成 RealityKit 3D 硬币、USDZ 加载、上滑抛掷、正反面结果、Cover to Reveal、触觉、音效和通用展示背景。

默认硬币保持品牌 T 正面与图案背面的设计。产品需要通过后台增加更多硬币，并支持模型版本管理、动态目录、单枚购买和跨设备恢复。

## 2. 已确认的产品边界

- 默认硬币免费并随 App 内置，离线始终可用。
- 核心抛掷体验不要求登录。
- 第一版正式账户方式为 Sign in with Apple。
- 用户登录后可以跨设备同步设置和已购硬币权益。
- 数据模型预留多身份绑定；手机号 OTP 登录放在第二阶段。
- 商业模式为“免费默认硬币 + 单枚永久购买”。
- 每枚付费硬币使用 App Store 非消耗型内购。
- 第一版不实现订阅、代币、礼包、租用、赠送或兑换码。
- 优先降低部署与维护成本，接受托管云服务费用。

## 3. 技术选型

### 3.1 推荐方案

| 层级 | 技术 |
| --- | --- |
| iOS | SwiftUI、RealityKit、StoreKit 2、Supabase Swift |
| 用户认证 | Supabase Auth + Sign in with Apple |
| 数据库 | Supabase PostgreSQL |
| 文件 | Supabase Storage/CDN |
| 服务端业务 | Supabase Edge Functions |
| 管理后台 | Vue 3、TypeScript、Vite、Element Plus |
| 后台托管 | Vercel 或 Cloudflare Pages，实施时择一 |

不增加 Django。Supabase 已覆盖认证、数据库、对象存储和服务端函数，增加 Django 会形成第二套 API、权限、部署和监控体系。

### 3.2 费用策略

- 开发、内部测试和 TestFlight 阶段使用 Supabase Free。
- 启用正式付费硬币并准备上架时升级 Supabase Pro。
- 第一阶段使用 Supabase Storage，不额外引入 Cloudflare R2。
- 当 USDZ 下载流量成为明确成本瓶颈时，再评估独立对象存储迁移。

## 4. 总体架构

1. iOS App 通过 Supabase Auth 完成 Apple 登录。
2. App 从目录 API 获取兼容的硬币清单和用户权益。
3. PostgreSQL 保存硬币、资源版本、商品映射、交易镜像和用户权益。
4. Storage 保存 USDZ、缩略图和可选的硬币专属音效。
5. StoreKit 2 负责客户端商品展示、购买和本地交易验证。
6. Edge Functions 验证 Apple 交易、处理服务端通知并写入权益。
7. Vue 管理后台通过受保护的 Edge Functions 管理资源和发布。

权威来源划分：

| 数据 | 权威来源 |
| --- | --- |
| 商品价格和币种 | StoreKit |
| 交易真实性与退款状态 | Apple 签名交易和服务端 API |
| Toss 用户权益镜像 | PostgreSQL |
| 当前资源版本 | PostgreSQL |
| USDZ 文件 | Supabase Storage |
| 离线可用状态 | App 本地缓存 |

## 5. 用户与登录

### 5.1 第一版体验

- 用户无需登录即可使用内置默认硬币。
- 需要同步设置、管理权益或恢复购买时引导 Apple 登录。
- App 内提供退出登录和删除账户入口。
- 账户删除不能删除 Apple 的购买事实，但应删除或匿名化 Toss 业务数据，并保留法律或财务要求的最小交易记录。

### 5.2 多身份预留

Supabase Auth identities 管理 Apple、phone 等登录身份。业务表只依赖统一的 `auth.users.id`，不在 `user_profiles` 中重复保存 `apple_subject`。

第二阶段增加手机号时，同一业务用户可以绑定 Apple 与 phone 两种身份。两个已经独立存在且都持有数据的账户不得静默自动合并，必须再次验证双方身份，并使用明确的权益合并规则。

## 6. 数据模型

### 6.1 `user_profiles`

- `id`：对应 `auth.users.id`。
- `display_name`：可选昵称。
- `status`：`active`、`disabled`、`deleted`。
- `created_at`、`updated_at`。

### 6.2 `user_preferences`

- `user_id`。
- `selected_coin_id`。
- `haptic_enabled`。
- `sound_enabled`。
- `updated_at`。

仅同步长期设置，不同步动画过程、缓存文件或临时抛掷状态。

### 6.3 `coins`

- `id`：稳定逻辑身份。
- `slug`：稳定路径标识。
- `name`、`description`、`category`。
- `access_type`：`free`、`paid`、`promotional`。
- `active_version_id`。
- `sort_order`、`is_featured`。
- `status`：`draft`、`published`、`hidden`、`retired`。
- `published_at`、`created_at`、`updated_at`。

更新 USDZ 不改变 `coin_id`。默认品牌硬币同样存在一条 `free` 记录。

### 6.4 `coin_versions`

- `id`、`coin_id`。
- `version`：语义化资源版本，例如 `1.0.1`。
- `usdz_path`、`preview_image_path`、`sound_path`。
- `file_size`、`sha256`。
- `min_app_version`、`asset_schema_version`。
- `release_channel`：`internal`、`beta`、`production`。
- `status`：`draft`、`testing`、`published`、`deprecated`。
- `created_at`、`published_at`。

同一硬币的版本号唯一。已发布版本不可覆盖。

### 6.5 `products`

- `id`、`coin_id`。
- `app_store_product_id`：唯一且不可复用。
- `product_type`：首版为 `non_consumable`。
- `status`：`draft`、`active`、`unavailable`。
- `created_at`、`updated_at`。

数据库不保存用于展示的固定价格。App 使用 StoreKit 返回的本地化价格。

### 6.6 `store_transactions`

- `id`、`user_id`、`product_id`。
- `transaction_id`：唯一幂等键。
- `original_transaction_id`。
- `app_account_token`。
- `environment`：`sandbox`、`production`。
- `purchased_at`、`revoked_at`、`revocation_reason`。
- `verification_status`。
- `signed_data_digest` 或受控保存的原始签名数据。
- `created_at`、`updated_at`。

### 6.7 `user_entitlements`

- `id`、`user_id`、`coin_id`。
- `source`：`purchase`、`free`、`promotion`、`admin`。
- `transaction_id`：购买权益关联已验证交易。
- `status`：`active`、`revoked`。
- `granted_at`、`revoked_at`。

App 对此表只读。只有受信服务端流程可以授予或撤销权益。

### 6.8 `audit_logs`

- 管理员身份、操作时间、动作类型、对象类型和对象 ID。
- 修改前后摘要。
- 操作原因与请求追踪 ID。

审计记录不允许普通管理员修改或删除。

## 7. USDZ 生命周期

### 7.1 文件路径

资源路径包含稳定硬币 slug 和不可变版本：

```text
coins/{coin-slug}/{version}/coin.usdz
coins/{coin-slug}/{version}/preview.webp
coins/{coin-slug}/{version}/toss.m4a
```

已发布文件不得原地覆盖。修复资源必须创建新版本。

### 7.2 发布流程

1. 创建硬币草稿。
2. 填写展示资料和 Product ID。
3. 上传 USDZ、缩略图和可选音效到 staging。
4. 检查类型、大小、路径、重复版本、SHA-256、最低 App 版本和必需文件。
5. 将版本切换为 `testing`，仅内部测试账号可见。
6. 在真机验证 RealityKit 加载、材质、缩放、正反方向、动画和音效。
7. 通过后发布，并将 `coins.active_version_id` 指向该版本。
8. 发布失败或发现回归时，把指针切回已验证的旧版本。

回滚不删除问题版本，以保留审计和问题复现能力。

### 7.3 兼容策略

目录 API 根据 App 版本和资源协议版本返回最新兼容资源。若最新版不兼容，则返回最后一个兼容版本；若不存在兼容版本，则隐藏该远程硬币并提示更新 App。内置默认硬币不受此限制。

## 8. App 动态目录与缓存

### 8.1 启动顺序

1. 立即读取本地目录和资源缓存。
2. 展示默认硬币或上次使用的可用硬币。
3. 后台请求远程目录，不阻塞主界面。
4. 成功时合并新增、更新、下架和权益状态。
5. 失败时继续使用本地内容。

### 8.2 刷新时机

- App 启动后。
- 从后台回到前台且超过刷新间隔时。
- 进入硬币选择页时。
- 购买或恢复购买完成后。

不实时监听数据库，不在每次抛掷时请求服务器。

### 8.3 下载规则

1. 确认用户拥有权益或硬币免费。
2. 获取短时签名下载 URL。
3. 下载至临时文件。
4. 校验文件大小与 SHA-256。
5. 校验通过后原子移动至正式缓存目录。
6. RealityKit 加载新版本。
7. 更新失败时继续保留并使用旧版本。

大型 USDZ 按需下载。目录刷新只获取元数据和轻量预览图。

### 8.4 新硬币展示

- 新硬币在下一次目录刷新后进入选择列表。
- 入口使用低调圆点，卡片可显示 `NEW`。
- 浏览后清除本地新内容标记。
- 不在核心抛掷界面展示强弹窗或广告横幅。

### 8.5 下架

- 普通下架：停止新购买，已购用户继续下载和使用。
- 紧急禁用：仅用于版权、安全或严重技术问题，App 切回默认硬币。
- 永久购买不因普通下架被剥夺。

## 9. StoreKit 购买与恢复

### 9.1 购买

1. App 通过 StoreKit 获取商品和本地价格。
2. 发起购买时传入不可反推个人信息的 `appAccountToken`。
3. StoreKit 返回签名交易，App 本地验证。
4. App 将签名交易提交至 Edge Function。
5. 服务端验证 Apple 签名或服务端交易状态。
6. 使用唯一 `transaction_id` 幂等写入交易。
7. 创建或恢复对应用户权益。
8. App 获取签名 URL 并下载硬币。

### 9.2 后台故障

如果 Apple 已完成购买而 Supabase 暂时不可用，App 保留经过本地验证的交易，允许本机临时使用，并加入待同步队列。重试不得再次发起收费。

### 9.3 跨设备恢复

- Apple 登录后先读取 Supabase 权益镜像。
- StoreKit 同时刷新当前 App Store 账户的当前权益。
- 尚未同步的合法交易提交服务端验证。
- 设置中提供明确的“恢复购买”入口。
- 资源在新设备上按需重新下载。

Sign in with Apple 身份与 App Store 购买身份可能不同，因此不能仅凭 Apple 登录判断购买状态。

### 9.4 账户冲突

同一 `transaction_id` 同一时间只能归属一个 Toss 用户。当前设备的 StoreKit 能证明拥有时可以本机使用；若交易已经绑定另一个 Toss 用户，不自动永久迁移到新用户，提示登录原账户。少数迁移由受审计的客服流程处理。

### 9.5 退款与撤销

Apple 服务端通知或可信查询确认退款后：

- 交易记录保留并写入撤销时间与原因。
- 对应权益变为 `revoked`。
- App 下次同步后锁定硬币并切回默认硬币。
- 短暂网络失败不能作为撤销依据。

## 10. 管理后台

### 10.1 模块

- 仪表盘：硬币、版本、交易、下载流量和异常摘要。
- 硬币：资料、分类、排序、推荐、免费/付费和状态。
- 版本：上传、校验、测试、发布、下架和回滚。
- 商品：Product ID 映射和可售状态。
- 用户：身份摘要、交易、权益和删除请求。
- 系统：最低 App 版本、资源协议、紧急禁用和审计日志。

### 10.2 管理员角色

| 角色 | 权限 |
| --- | --- |
| `viewer` | 只读 |
| `editor` | 编辑草稿和上传测试资源 |
| `publisher` | 发布、下架和回滚 |
| `admin` | 管理角色、用户权益和系统配置 |

管理员使用邮箱 OTP、TOTP 和白名单。正式发布、回滚、权益修改及紧急禁用必须由服务端再次验证角色，并记录审计日志。

## 11. 安全设计

### 11.1 RLS

- 公开目录只能读取已发布且允许公开的字段。
- 用户只能读写自己的 profile 和 preferences。
- 用户只能读取自己的权益和必要交易摘要。
- App 无权直接写 `store_transactions` 或 `user_entitlements`。
- 管理操作通过受保护的 Edge Functions 执行。

### 11.2 Storage

| Bucket | 权限 | 内容 |
| --- | --- | --- |
| `coin-previews` | 公开读 | 缩略图 |
| `coin-assets` | 私有 | 正式 USDZ 和音效 |
| `coin-staging` | 管理员 | 草稿和测试资源 |

付费资源由服务端确认权益后签发短时 URL。该措施降低盗链风险，但不承诺无法从客户端提取资源。

### 11.3 密钥

`service_role` 只能存在于 Edge Functions 的服务端环境中，禁止放入 iOS、Vue 前端或 Git。客户端仅使用公开客户端密钥并依赖 RLS。

## 12. 故障处理

- 后台不可用：内置默认硬币和已下载硬币继续工作。
- 目录失败：使用最后一次成功目录。
- 下载中断：删除临时文件，旧版本保持可用。
- 校验失败：不替换旧版本并记录错误。
- 重复交易：通过唯一 `transaction_id` 幂等处理。
- 通知失败：依靠重试、StoreKit 当前权益和周期性补偿查询收敛。
- 错误版本：通过 `active_version_id` 回滚。

## 13. 实施阶段

### 阶段 1：Supabase 基础

建立项目、环境配置、表、约束、RLS、Storage、Apple 登录、用户设置同步和账户删除。

### 阶段 2：硬币目录与管理后台

实现硬币草稿、资源上传、版本状态、内部测试、发布、回滚和审计。

### 阶段 3：App 动态资源

实现目录获取、本地缓存、签名下载、SHA-256、RealityKit 动态加载、离线回退和新硬币提示。

### 阶段 4：商业化

配置 App Store 商品，实现 StoreKit 2、服务端验证、权益、恢复购买、退款撤销和付费资源授权。

### 阶段 5：上线强化

升级 Supabase Pro，验证备份恢复，增加监控，完善隐私政策、账户删除、TestFlight 灰度、故障演练和发布回滚演练。

## 14. 验收标准

- 无网络时默认硬币可正常完成完整 Toss 流程。
- 后台发布兼容的新免费硬币后，App 无需更新即可发现并按需下载。
- 已发布 USDZ 无法被后台直接覆盖。
- 新版本加载失败不会破坏本地旧版本。
- 付费硬币只能由免费规则或可信权益解锁。
- 同一交易重复提交不会重复创建权益。
- 新设备能通过 StoreKit 与 Toss 账户同步恢复合法购买。
- 普通下架不剥夺已购用户的永久权益。
- 退款经可信通知确认后能够撤销权益。
- 普通用户无法读写他人数据，也无法直接授予自己权益。
- 管理员发布、回滚和人工权益修改均可追溯。

## 15. 明确不在本设计中的内容

- 后台与 App 的具体代码实现。
- UI 视觉稿和后台页面布局。
- 订阅、礼包、虚拟货币、赠送和兑换码。
- 手机号短信供应商选择与接入。
- Cloudflare R2 迁移。
- 复杂 DRM。

这些能力只有在实际产品需求出现后才单独设计。

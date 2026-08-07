# Admin 治理面板 + 合约地址管理 · 分批执行提示词

> **执行规则**：每批独立 Commit。每批完成后强制停止，提交外部审核。审核 APPROVED 后才进入下一批。禁止在同一轮自动执行多批。
>
> **全量审核**：4 批次全部完成后，提交整个项目的全量审核（不仅是 4 批次修改，而是全部代码）。

---

## 批次总览

| 批次 | 内容 | 阻断 | 需私钥 |
|------|------|:--:|:--:|
| GE-A01 | 合约地址 CRUD + DB 化管理 | P1 | 否 |
| GE-A02 | 治理只读监控（eth_call） | P1 | 否 |
| GE-A03 | 修复已有路由 auth 中间件缺陷 | P0 | 否 |
| GE-A04 | 治理写操作（eth_sendRawTransaction） | P1 | **是**（可跳过） |

```
执行顺序：
GE-A01 → 审核 → GE-A02 → 审核 → GE-A03 → 审核 → GE-A04 → 审核 → 全量审核
```

---

## 执行总控规则

```
GE-A01 (合约 CRUD)    ──→ 外部审核 ──→ APPROVED
GE-A02 (治理只读)     ──→ 外部审核 ──→ APPROVED
GE-A03 (修复中间件)   ──→ 外部审核 ──→ APPROVED
GE-A04 (治理写,可选)  ──→ 外部审核 ──→ APPROVED
                                         ↓
                                   全量审核 ──→ PASS
```

**规则**：
1. 串行执行，不可跳步
2. 每批次一个独立 Commit
3. 每批次完成后强制停止，提交外部审核
4. 外部审核 APPROVED 是进入下一批次的前置条件
5. GE-A04 可跳过（私钥不进后端时）
6. 全量审核不是仅审核 4 批次修改，而是审核整个项目的全部代码
7. 全量审核 PASS 后所有工作完成

---

# GE-A01：合约地址 CRUD + DB 化管理

> 复制的提示词开始

```
你是 PANGU2 后端开发 Agent，在 E:\github\bnb\bnb-presale-minimal 下工作。

## 执行规则

⚠️ **只执行本批次**。完成本批次后必须停止，不得自动进入 GE-A02。
本批次结束后，提交外部审核。审核 APPROVED 后才允许执行下一批次。

## 任务

合约地址从 .env 硬编码改为 Admin 可通过 API 管理的 DB 记录。

## 约束

- 不修改 Solidity 代码
- 不破坏 AdminDashboardController.contracts() 返回格式（只改数据源）
- 不引入私钥，不写链
- 不修改 Admin 前端
- 不修改已有的路由、控制器、中间件（只新增，不改旧）

## 执行步骤

### 1. 新建 ContractRegistryController

路径：`backend/app/Modules/Core/ContractRegistry/Controllers/ContractRegistryController.php`

4 个方法：

| 方法 | 路由 | 功能 |
|------|------|------|
| `index()` | `GET /admin-api/v1/projects/pangu2/contract-registry` | 从 DB 读全部合约（调用 `ContractRegistryService::getAll()`） |
| `store(Request)` | `POST /admin-api/v1/projects/pangu2/contract-registry` | 新增/更新合约。Body: `{ name, address, abi_version, deployment_block }`。校验 address 为 0x+40hex、name 在白名单内。使用 `updateOrCreate` |
| `destroy(id)` | `DELETE /admin-api/v1/projects/pangu2/contract-registry/{id}` | 软删除：`status → 'UNAVAILABLE'` |
| `resync()` | `POST /admin-api/v1/projects/pangu2/contract-registry/resync` | 从 `config/pangu2.php` 读取当前全部 8 个地址，逐条 upsert 到 DB。幂等 |

合约名白名单：
```
Pangu2Token, Pangu2TradeRouter, DividendDistributor, SupportPool,
BuybackLocker, FeeVault, CostBasisManager, Pangu2Staking,
PancakeV2Adapter, PancakeV2TwapOracle, V2Pair
```

### 2. 修改 AdminDashboardController.contracts()

当前实现：硬编码合约名数组，从 `config('pangu2.xxx_address')` 读地址。

修改后：调用 `app(ContractRegistryService::class)->getAll()` 从 DB 读取。返回格式保持不变。

### 3. 注册路由

在 `backend/routes/web.php` 的 `admin-api/v1/projects/pangu2` 前缀组内新增：

```php
Route::middleware(['auth:web', 'rbac:contracts.manage'])->group(function () {
    Route::get('/contract-registry', [ContractRegistryController::class, 'index']);
    Route::post('/contract-registry', [ContractRegistryController::class, 'store']);
    Route::delete('/contract-registry/{id}', [ContractRegistryController::class, 'destroy'])->whereNumber('id');
    Route::post('/contract-registry/resync', [ContractRegistryController::class, 'resync']);
});
```

### 4. 新增 RBAC 权限

在 `backend/app/Modules/Core/RBAC/RbacMatrix.php` 的 `PERMISSIONS` 数组中新增：

```php
'contracts.manage' => [self::ROLE_SUPER_ADMIN],
```

### 5. 验证

- `php artisan route:list | findstr contract-registry` 返回 4 条路由
- `GET /admin-api/.../contract-registry` 返回 DB 中列表（首次运行前为空）
- `POST /admin-api/.../contract-registry/resync` 从 config 同步地址到 DB 后列表非空
- 旧端点 `GET /admin-api/.../contracts` 仍正常返回（数据源已切换为 DB）
- 新路由已登录 ADMIN 可访问，未登录返回 401

### 6. 提交

```bash
git add backend/app/Modules/Core/ContractRegistry/Controllers/ContractRegistryController.php
git add backend/app/Modules/Core/RBAC/RbacMatrix.php
git add backend/app/Modules/Pangu2/Admin/Controllers/AdminDashboardController.php
git add backend/routes/web.php
git commit -m "feat(admin): GE-A01 — contract registry CRUD + DB-backed contract management"
```

输出本次 Commit 的完整 40 位 SHA。
```

> 复制的提示词结束

---

## GE-A01 → 外部审核闸门

**⛔ 本批次完成，强制停止。不得继续执行 GE-A02。**

提交以下材料给外部审核 Agent：

```
=== GE-A01 外部审核提交 ===

项目：PANGU2
批次：GE-A01 — 合约地址 CRUD + DB 化管理
Commit SHA：<本次 commit 的完整 40 位 SHA>

修改文件：
  - app/Modules/Core/ContractRegistry/Controllers/ContractRegistryController.php (新建)
  - app/Modules/Core/RBAC/RbacMatrix.php (+contracts.manage)
  - app/Modules/Pangu2/Admin/Controllers/AdminDashboardController.php (contracts() 改为 Service)
  - routes/web.php (+4 条路由)

审核重点：
  1. 合约名白名单是否完整（11 项全部覆盖）
  2. address 格式校验是否严格（0x + 40 位 hex）
  3. 所有新增路由是否有 ['auth:web', 'rbac:contracts.manage'] 双重中间件
  4. contracts.manage 权限是否仅限 ROLE_SUPER_ADMIN
  5. 旧 contracts 端点的返回格式是否保持兼容
  6. resync 是否幂等（重复调用不产生重复记录）
  7. store 是否阻止不在白名单内的合约名

要求输出：APPROVED / CHANGES_REQUIRED / NO-GO
CHANGES_REQUIRED → 本批次修复后重新提交审核
APPROVED → 进入 GE-A02
NO-GO → 停止全部工作
```

审核 APPROVED 后，复制 GE-A02 提示词开始下一批次。

---

# GE-A02：治理只读监控 API

> 复制的提示词开始

```
你是 PANGU2 后端开发 Agent，在 E:\github\bnb\bnb-presale-minimal 下工作。

## 执行规则

⚠️ **只执行本批次**。完成本批次后必须停止，不得自动进入 GE-A03。
本批次结束后，提交外部审核。审核 APPROVED 后才允许执行下一批次。

## 前置条件

GE-A01 已获外部审核 APPROVED。确认 GE-A01 的 Commit SHA 后开始本批次。

## 任务

Admin 可通过 API 查看链上实时治理状态：交易开关、Oracle 状态、暂停状态、回购条件、Gas 余额。全部通过 `eth_call` JSON-RPC 只读查询，不写链，不需要私钥。

## 约束

- 不修改 Solidity 代码
- RPC 超时/失败必须返回清晰错误
- 所有新增路由必须带 `['auth:web', 'rbac:governance.read']` 双重中间件
- 不修改已有路由、控制器、中间件

## 执行步骤

### 1. 新建 GovernanceController

路径：`backend/app/Modules/Pangu2/Admin/Controllers/GovernanceController.php`

RPC 调用辅助方法（所有 6 个方法共用）：

```php
private function ethCall(string $to, string $data): string
{
    $payload = [
        'jsonrpc' => '2.0',
        'method'  => 'eth_call',
        'params'  => [['to' => $to, 'data' => $data], 'latest'],
        'id'      => 1,
    ];
    $resp = Http::timeout(5)->post(config('pangu2.rpc_url'), $payload);

    if (!$resp->ok()) {
        throw new \RuntimeException('RPC call failed: HTTP ' . $resp->status());
    }

    $result = $resp->json('result');
    if ($result === null || $result === '0x') {
        throw new \RuntimeException('RPC returned empty result');
    }

    return $result;
}
```

**6 个查询方法**：

| # | 端点 | 合约调用 | Selector | 返回字段 |
|---|------|----------|----------|----------|
| 1 | `GET /governance/trading-status` | `isPair(pairAddr)` | `0xe5e31b13` | `tradingEnabled` |
| 2 | `GET /governance/buyback-check` | `canExecuteBuyback()` | `0x7dc15e0d` | `canBuyback, reason, reasonLabel, poolBalance, nextAllowedAt` |
| 3 | `GET /governance/oracle-status` | `status()` | `0x200d2ed2` | `status (0-3), statusLabel` |
| 4 | `GET /governance/pause-status` | `paused()` | `0x5c975abb` | `paused` |
| 5 | `GET /governance/system-addresses` | `isSystemAddress()` × N | `0x6ba5228f` / `0x4fe67b1a` | `[{ name, address, isSystemAddress, isLiquidityManager }]` |
| 6 | `GET /governance/deployer-balance` | `eth_getBalance` | — | `address, balanceWei, balanceBnb` |

### 2. 注册路由

在 `web.php` 新增：

```php
Route::middleware(['auth:web', 'rbac:governance.read'])->group(function () {
    Route::get('/governance/trading-status', [GovernanceController::class, 'tradingStatus']);
    Route::get('/governance/buyback-check', [GovernanceController::class, 'buybackCheck']);
    Route::get('/governance/oracle-status', [GovernanceController::class, 'oracleStatus']);
    Route::get('/governance/pause-status', [GovernanceController::class, 'pauseStatus']);
    Route::get('/governance/system-addresses', [GovernanceController::class, 'systemAddresses']);
    Route::get('/governance/deployer-balance', [GovernanceController::class, 'deployerBalance']);
});
```

### 3. RBAC

```php
'governance.read' => [self::ROLE_SUPER_ADMIN, self::ROLE_OPERATOR],
```

### 4. 验证

- 已登录 OPERATOR 访问全部 6 条路由返回数据
- RPC 不可用时返回清晰错误（status 502, 含错误原因）
- VIEWER 角色访问返回 403
- 未登录返回 401

### 5. 提交

```bash
git add backend/app/Modules/Pangu2/Admin/Controllers/GovernanceController.php
git add backend/app/Modules/Core/RBAC/RbacMatrix.php
git add backend/routes/web.php
git commit -m "feat(admin): GE-A02 — governance read-only monitoring via eth_call"
```

输出本次 Commit 的完整 40 位 SHA。
```

> 复制的提示词结束

---

## GE-A02 → 外部审核闸门

**⛔ 本批次完成，强制停止。不得继续执行 GE-A03。**

提交以下材料给外部审核 Agent：

```
=== GE-A02 外部审核提交 ===

项目：PANGU2
批次：GE-A02 — 治理只读监控 API
Commit SHA：<本次 commit 的完整 40 位 SHA>

修改文件：
  - app/Modules/Pangu2/Admin/Controllers/GovernanceController.php (新建)
  - app/Modules/Core/RBAC/RbacMatrix.php (+governance.read)
  - routes/web.php (+6 条 GET 路由)

审核重点：
  1. 6 个 ABI selector（0xe5e31b13/0x7dc15e0d/0x200d2ed2/0x5c975abb/0x6ba5228f/0x4fe67b1a）是否正确
  2. RPC 调用失败是否正确处理
  3. 所有 6 条路由是否有 ['auth:web', 'rbac:governance.read'] 双重中间件
  4. governance.read 是否分配给 SUPER_ADMIN + OPERATOR
  5. buyback-check 返回的 reasonLabel 是否为可读文本
  6. oracle-status 返回的 statusLabel 是否包含四种状态映射
  7. system-addresses 是否覆盖全部 7 个系统地址

要求输出：APPROVED / CHANGES_REQUIRED / NO-GO
APPROVED → 进入 GE-A03
```

审核 APPROVED 后，复制 GE-A03 提示词开始下一批次。

# TASK-20260807-002 — Go Backend V2 Migration

## Source
`docs/current/go-backend-v2/`

## Summary
将 Laravel 后端 + TypeScript Chain Worker 旁路替换为 Go 模块化单体。新代码目录 `backend-go/`，独立数据库 `binggoplus_go`，API v2。从部署区块（提交 `3ef50b6`）重建全部链上历史。

## Pre-Development Gates (F00-F08)

| 任务 | 内容 | 状态 |
|------|------|:--:|
| F00 | 原系统证据盘点 | ⏳ |
| F01 | 测试网合约基线固化（runtime bytecode + 角色参数 readback） | ⏳ |
| F02 | 合约修复与审核继承（S0-S9 Finding 绑定） | ⏳ |
| F03 | 业务逻辑冻结 | ⏳ |
| F04 | 数据库冻结（Schema, cursor, raw event unique key） | ⏳ |
| F05 | API 冻结（V2 OpenAPI, 删除 Mock, 补齐字段） | ⏳ |
| F06 | 事件与状态机冻结 | ⏳ |
| F07 | 框架与工具链冻结 | ⏳ |
| F08 | 部署与安全边界冻结 | ⏳ |

## Development Phases (G0-G9)

| 阶段 | 内容 |
|------|------|
| G0 | 签署冻结包 |
| G1 | Go 基础骨架（config/log/DB/Migration/generate/health） |
| G2 | 部署基线导入 + Indexer 旁路重扫 |
| G3 | Projector 与读模型 |
| G4 | Public API 影子运行 |
| G5 | DApp 分域切换 |
| G6 | Admin Auth 与只读切换 |
| G7 | Governance 写路径切换 |
| G8 | Dividend Builder 与业务 Job |
| G9 | 停用旧后端 |

## Status: RESPONSIBLE_OWNER_FREEZE_COMPLETE_RUNTIME_GATE_BLOCKED

Responsible Owner Freeze（pd123, 2026-08-08）已完成 GATE-01~05 签署。
但 `FROZEN_FOR_DEVELOPMENT = NO`：RT-GATE-01/02 因环境缺失仍 BLOCKED。
G1 Entry 尚未授权。

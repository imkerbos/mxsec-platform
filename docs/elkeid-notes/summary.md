# Elkeid 研究总结

> 本文档总结 Elkeid 代码研究的关键发现，以及对我们项目的启示。

---

## 1. 核心发现

### 1.1 Agent 架构

**Elkeid Agent 的核心设计**：
- Agent 作为**插件基座**，不提供具体安全能力
- 通过**父子进程 + Pipe** 的方式管理插件
- 使用 **gRPC 双向流** 与 Server 通信
- 支持**插件热更新**和**版本管理**

**对我们的启示**：
- 我们不需要插件机制，基线检查直接集成到 Agent
- 可以简化通信协议（HTTP 或简化 gRPC）
- 保留心跳、任务机制等核心能力

### 1.2 Baseline 插件

**Elkeid Baseline 的核心设计**：
- 策略以 **YAML 文件**形式存储（按 OS 分类）
- 使用**规则引擎**解析和执行检查
- 支持多种检查类型（文件、命令、权限等）
- 结果通过 **Protobuf** 上报

**对我们的启示**：
- 策略模型可以参考，但需要优化（更清晰的 OS 匹配）
- 检查器设计可以复用（文件检查、命令执行等）
- 结果格式可以简化（JSON 即可）

### 1.3 通信协议

**Elkeid 的通信特点**：
- 双向流式通信（适合实时数据上报）
- 使用 Protobuf（高效、兼容）
- mTLS 双向认证（安全）
- 数据不二次解析（性能优化）

**对我们的启示**：
- v1 可以使用 HTTP（简单、易调试）
- v2 可以考虑 gRPC（性能更好）
- mTLS 可选（根据安全要求）

---

## 2. 关键代码位置

### Agent 核心
- `agent/main.go`：主入口，启动三个核心模块
- `agent/plugin/plugin.go`：插件管理核心逻辑
- `agent/plugin/plugin_linux.go`：Linux 插件加载实现
- `agent/transport/transfer.go`：数据传输实现
- `agent/heartbeat/heartbeat.go`：心跳上报

### Baseline 插件
- `plugins/baseline/main.go`：插件入口，任务接收与定时扫描
- `plugins/baseline/src/check/analysis.go`：分析入口，策略解析
- `plugins/baseline/src/check/rule_engine.go`：规则引擎，结果匹配
- `plugins/baseline/src/check/rules.go`：检查器实现（文件、命令等）
- `plugins/baseline/config/linux/1200.yaml`：策略配置示例

### 通信协议
- `agent/proto/grpc.proto`：gRPC 协议定义
- `plugins/lib/`：插件 SDK（Go/Rust）

---

## 3. 设计决策对比

| 设计点 | Elkeid | 我们的设计 | 原因 |
|--------|--------|-----------|------|
| 插件机制 | ✅ 支持 | ✅ 支持 | 完全参考 Elkeid，保持架构一致性 |
| 通信协议 | gRPC 双向流 | gRPC 双向流 | 完全参考 Elkeid，性能更好 |
| mTLS | ✅ 必须 | ✅ 必须 | 完全参考 Elkeid，保证安全 |
| 资产采集 | ✅ Collector Plugin | ✅ Collector Plugin | 完全参考 Elkeid，功能完整 |
| 策略存储 | YAML 文件 | 数据库 + YAML | 便于动态管理，但保留 YAML 导入 |
| OS 匹配 | baseline_id 硬编码 | os_family + os_version | 更灵活，支持新系统版本 |
| 检查类型 | file_line_check | file_kv + file_line_match | 更直观，但保留兼容性 |
| 结果格式 | Protobuf | Protobuf | 完全参考 Elkeid，保持一致性 |

---

## 4. 可复用的设计

### 4.1 检查器设计

Elkeid 的检查器设计很好，我们可以复用：
- `file_line_check`：文件行匹配（可优化为 `file_line_match`）
- `file_permission`：文件权限检查
- `command_check`：命令执行（可优化为 `command_exec`）
- `file_user_group`：文件属主检查

### 4.2 规则引擎

Elkeid 的规则引擎设计：
- 支持条件组合（all/any/none）
- 支持特殊语法（`$(<=)90`、`$(not)error` 等）
- 支持前置条件（require）

我们可以复用这个设计，但需要：
- 简化特殊语法（更易读）
- 优化错误提示

### 4.3 策略模型

Elkeid 的策略模型：
- baseline_id + check_id（数字 ID）
- YAML 配置
- 按 OS 分类

我们可以优化为：
- policy_id + rule_id（字符串 ID，更易读）
- 数据库存储 + YAML 导入
- os_family + os_version 灵活匹配

---

## 5. 下一步工作

### 5.1 设计文档

- [x] Elkeid 架构分析文档
- [x] 策略模型设计
- [x] Agent 架构设计
- [ ] Server API 设计
- [ ] 数据库模型设计

### 5.2 开发任务

详见 [TODO.md](../TODO.md)

---

## 6. 参考资源

- [Elkeid 官方文档](https://elkeid.bytedance.com/)
- [Elkeid GitHub](https://github.com/bytedance/Elkeid)
- [Elkeid 架构分析文档](./elkeid-architecture-analysis.md)


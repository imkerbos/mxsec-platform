# Changelog

## [Unreleased]

### Phase 1: MVP 基础设施开发

#### 已完成 (2025-01-XX)

**Protobuf 定义**
- ✅ 创建 `api/proto/bridge.proto` - 插件与 Agent 通信协议
- ✅ 创建 `api/proto/grpc.proto` - Agent 与 Server 通信协议
- ✅ 定义 `Record`、`Task`、`PackagedData`、`Command` 等消息类型
- ✅ 定义 `Transfer` gRPC 服务（双向流）

**插件 SDK**
- ✅ 实现 `plugins/lib/go/client.go` - 插件客户端 SDK
- ✅ 实现 `NewClient()` - 创建客户端（从文件描述符 3/4 读取 Pipe）
- ✅ 实现 `SendRecord()` - 发送数据记录到 Agent
- ✅ 实现 `ReceiveTask()` - 从 Agent 接收任务
- ✅ 实现 `SendRecordWithRetry()` - 带重试机制的发送
- ✅ 实现 `ReceiveTaskWithTimeout()` - 带超时机制的接收
- ✅ 实现线程安全的 Pipe 通信（使用互斥锁）
- ✅ 实现消息大小限制（10MB）防止恶意数据

**开发工具**
- ✅ 创建 `scripts/generate-proto.sh` - Protobuf 代码生成脚本
- ✅ 创建 `Makefile` - 构建和开发工具
- ✅ 创建 `DEVELOPMENT.md` - 开发指南
- ✅ 创建 `.gitignore` - Git 忽略规则

**文档**
- ✅ 创建 `api/proto/README.md` - Protobuf 使用说明
- ✅ 创建 `plugins/lib/go/README.md` - 插件 SDK 使用说明

#### 待完成

- [ ] 安装 protoc 并生成 Protobuf Go 代码
- [ ] Agent 基础框架开发
- [ ] Baseline Plugin 开发
- [ ] Server 开发

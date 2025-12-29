# CLAUDE.md - 矩阵云安全平台开发指南

本文档为 Claude Code 在本项目中的工作指南，包含核心项目信息和开发规范。

**最后更新**: 2025-12-29
**当前版本**: v1.0.0 (开发中)

---

## 项目概述

**项目名称**: Matrix Cloud Security Platform (矩阵云安全平台)

**项目目标**:
- **v1**: Linux 操作系统基线合规性检查平台
- **v2**: 扩展到中间件基线（Nginx、Redis、MySQL 等）
- **v3**: K8s 容器安全基线

**核心功能**: 主机基线检查与评分、策略管理、多 OS 版本适配、资产采集、实时监控与告警

**设计理念**: 仿 ByteDance Elkeid 的 Agent + Plugin + Server 架构，轻量化、易维护

---

## 技术栈

### 后端
- **语言**: Golang >= 1.21
- **框架**: Gin (HTTP API), gRPC (Agent 通信)
- **数据库**: MySQL 8.0+, Gorm (ORM)
- **日志**: Zap (结构化 JSON)
- **配置**: Viper (YAML)
- **认证**: JWT

### 前端
- **框架**: Vue 3.x + TypeScript 4.x+
- **状态**: Pinia
- **UI**: Ant Design Vue 4.x
- **构建**: Vite

### 部署
- **容器**: Docker + Docker Compose
- **打包**: nFPM (RPM/DEB)
- **协议**: Protobuf

---

## 项目结构

```
mxsec-platform/
├── cmd/                    # 主程序入口 (agent, server)
├── internal/               # 内部包
│   ├── agent/             # Agent 核心模块
│   └── server/            # Server 核心模块
│       ├── manager/       # HTTP API
│       └── agentcenter/   # gRPC Server
├── plugins/                # 插件 (baseline, collector)
├── api/proto/              # Protobuf 定义
├── ui/                     # 前端代码
├── deploy/                 # 部署配置
├── configs/                # 配置文件
├── docs/                   # 文档
└── scripts/                # 脚本工具
```

详细结构参考: [项目结构文档](docs/PROJECT_STRUCTURE.md)

---

## 快速开始

### Docker 开发环境 (推荐)

```bash
# 启动开发环境 (带热更新)
make dev-docker-up

# 查看日志
make dev-docker-logs

# 停止服务
make dev-docker-down
```

**访问地址**:
- Manager API: http://localhost:8080
- UI: http://localhost:3000
- MySQL: localhost:3306

### 常用命令

```bash
make proto         # 生成 Protobuf 代码
make build-agent   # 构建 Agent
make build-server  # 构建 Server
make test          # 运行测试
make fmt           # 格式化代码
make lint          # 代码检查
```

---

## 核心开发规范

### Go 代码规范

**必须遵循**:
1. **日志**: 使用 Zap 结构化日志，禁止 `fmt.Println`/`log.Println`
2. **响应**: 使用统一响应工具函数 (`internal/server/manager/api/response.go`)
3. **错误**: 返回错误而非 panic，使用 `fmt.Errorf` 包装错误
4. **配置**: 从配置文件读取，禁止硬编码
5. **数据库**: 使用预加载避免 N+1 问题，使用事务保证一致性

**详细规范**: [Go 代码规范](docs/development/GO_STYLE_GUIDE.md)

### TypeScript/Vue 规范

**必须遵循**:
1. **API 调用**: 统一封装在 `ui/src/api/` 目录，禁止直接调用 axios
2. **类型安全**: 定义接口类型，使用 TypeScript
3. **错误处理**: 所有 API 调用必须有 try-catch
4. **组件命名**: PascalCase (组件), camelCase (函数), UPPER_CASE (常量)

**详细规范**: [前端代码规范](docs/development/FRONTEND_STYLE_GUIDE.md)

---

## API 文档

### Manager HTTP API

核心 API 端点:
- `POST /api/v1/auth/login` - 用户登录
- `GET /api/v1/hosts` - 主机列表
- `GET /api/v1/policies` - 策略列表
- `POST /api/v1/tasks` - 创建任务
- `GET /api/v1/results` - 查询结果

**详细 API 文档**: [API 参考](docs/API_REFERENCE.md)

---

## 测试

```bash
# 单元测试
go test ./... -v

# 集成测试
go test ./tests/integration -v

# 覆盖率
go test ./... -cover
```

**测试覆盖率目标**: >= 70% (核心路径: >= 85%)

**详细测试指南**: [测试文档](docs/testing/TESTING_GUIDE.md)

---

## 工作流程

### 任务追踪

- **任务列表**: [docs/TODO.md](docs/TODO.md)
- **状态**: ✅ 已完成 | 🔄 进行中 | ⏳ 待做 | ❌ 阻塞
- **优先级**: P0 (必须) | P1 (重要) | P2 (可选)

### 开发流程

1. 选择任务，标记为 `🔄 进行中`
2. 遵循代码规范开发
3. 编写单元测试
4. 运行 `make fmt lint test`
5. 标记为 `✅ 已完成`

### Git 提交规范

```
<type>: <简短描述>

- 详细改动点1
- 详细改动点2
```

**Type**: `feat` (新功能) | `fix` (修复) | `refactor` (重构) | `docs` (文档) | `test` (测试) | `chore` (构建)

**注意**: Claude Code 提供 commit 命令和消息，用户自行执行提交

---

## 快速参考

### 工具函数

**后端响应** (`internal/server/manager/api/response.go`):
- `Success(c, data)` - 成功响应
- `BadRequest(c, msg)` - 参数错误 (400)
- `NotFound(c, msg)` - 资源不存在 (404)
- `InternalError(c, msg)` - 服务器错误 (500)

**前端 API** (`ui/src/api/client.ts`):
```typescript
apiClient.get<T>('/path', { params })
apiClient.post<T>('/path', data)
apiClient.put<T>('/path', data)
apiClient.delete('/path')
```

### 日志记录

```go
logger.Info("操作成功", zap.String("id", id))
logger.Error("操作失败", zap.Error(err))
logger.Warn("使用默认值", zap.Any("default", val))
```

---

## 参考文档

- **开发指南**: [DEVELOPMENT.md](DEVELOPMENT.md)
- **代码规范**: [docs/development/](docs/development/)
- **API 参考**: [docs/API_REFERENCE.md](docs/API_REFERENCE.md)
- **测试文档**: [docs/testing/](docs/testing/)
- **任务列表**: [docs/TODO.md](docs/TODO.md)
- **设计文档**: [docs/design/](docs/design/)

---

**文档维护者**: Claude Code
**最后更新**: 2025-12-29
**更新内容**: 精简为核心信息，详细内容移至独立文档

# CLAUDE.md - 矩阵云安全平台开发指南

本文档为 Claude Code 在本项目中的工作指南，包含完整的技术栈、开发规范、测试流程和任务追踪。

**最后更新**: 2025-12-11
**当前版本**: v1.0.0 (开发中)

---

## 目录
1. [项目概述](#项目概述)
2. [技术栈](#技术栈)
3. [项目结构](#项目结构)
4. [开发环境](#开发环境)
5. [代码格式与规范](#代码格式与规范)
6. [测试流程](#测试流程)
7. [API 文档](#api-文档)
8. [任务追踪](#任务追踪)
9. [常见问题](#常见问题)
10. [工作流程](#工作流程)

---

## 项目概述

**项目名称**: Matrix Cloud Security Platform (矩阵云安全平台)

**项目目标**:
- **v1**: 实现 Linux 操作系统基线合规性检查平台
- **v2**: 扩展到中间件基线（Nginx、Redis、MySQL 等）
- **v3**: K8s 容器安全基线

**核心功能**:
- 主机基线检查与评分
- 策略灵活管理
- 多 OS 版本适配（Rocky 9、CentOS 7/8、Debian 10/11/12 等）
- 资产采集与展示
- 实时监控与告警

**设计理念**: 仿 ByteDance Elkeid 的 Agent + Plugin + Server 架构，但更轻量化、更易维护。

---

## 技术栈

### 后端 (Backend)

| 组件 | 技术 | 版本 | 用途 |
|------|------|------|------|
| **语言** | Golang | >= 1.21 | 服务端开发 |
| **Web 框架** | Gin | Latest | HTTP API Server (Manager) |
| **gRPC** | Go gRPC | Latest | Agent ↔ Server 通信 (AgentCenter) |
| **ORM** | Gorm | Latest | 数据库 ORM |
| **日志** | Zap | Latest | 结构化日志（JSON 格式） |
| **配置** | Viper | Latest | YAML 配置管理 |
| **验证** | Validator | Latest | 数据验证 |
| **认证** | JWT | golang-jwt | Token 认证 |
| **数据库** | MySQL | 8.0+ | 关系型数据存储 |
| **消息队列** | - | - | 可选，暂不使用 |
| **缓存** | Redis | Optional | 可选，用于得分缓存 |

### 前端 (Frontend)

| 组件 | 技术 | 版本 | 用途 |
|------|------|------|------|
| **框架** | Vue | 3.x | UI 框架 |
| **语言** | TypeScript | 4.x+ | 类型安全 |
| **状态管理** | Pinia | Latest | 状态管理 |
| **路由** | Vue Router | 4.x | 页面路由 |
| **UI 组件库** | Ant Design Vue | 4.x | 组件库 |
| **构建工具** | Vite | Latest | 前端构建 |
| **HTTP 客户端** | Axios | Latest | API 请求 |
| **图表** | ECharts | Latest | 数据可视化 |

### 部署 (Deployment)

| 组件 | 技术 | 用途 |
|------|------|------|
| **容器化** | Docker | 容器部署 |
| **编排** | Docker Compose | 本地/开发环境 |
| **包管理** | nFPM | RPM/DEB 打包 |
| **证书** | OpenSSL | mTLS 证书生成 |

### 其他工具

- **构建**: Make, Shell scripts
- **版本控制**: Git (分支模型：main + feature/fix)
- **协议**: Protobuf (Agent ↔ Server 通信)
- **压缩**: Snappy (可选，大数据压缩)

---

## 项目结构

```
mxsec-platform/
├── cmd/                           # 主程序入口
│   ├── agent/
│   │   └── main.go               # Agent 主程序（单二进制部署）
│   └── server/
│       ├── agentcenter/
│       │   └── main.go           # AgentCenter gRPC Server
│       └── manager/
│           └── main.go           # Manager HTTP API Server
│
├── internal/                       # 内部包（不对外暴露）
│   ├── agent/                     # Agent 核心模块
│   │   ├── config/               # 配置管理（构建时嵌入）
│   │   ├── plugin/               # 插件管理（生命周期）
│   │   ├── transport/            # gRPC 传输层
│   │   ├── heartbeat/            # 心跳上报
│   │   ├── connection/           # 连接管理
│   │   └── resource/             # 资源监控
│   │
│   └── server/                    # Server 核心模块
│       ├── manager/              # Manager HTTP API
│       │   ├── api/              # HTTP 路由处理器
│       │   ├── router/           # 路由定义
│       │   ├── middleware/       # HTTP 中间件
│       │   ├── biz/              # 业务逻辑层
│       │   └── setup/            # 初始化逻辑
│       │
│       ├── agentcenter/          # AgentCenter gRPC
│       │   ├── transfer/         # Transfer 服务实现
│       │   ├── service/          # 业务逻辑（策略、任务）
│       │   ├── scheduler/        # 任务调度器
│       │   ├── server/           # gRPC Server 配置
│       │   └── setup/            # 初始化逻辑
│       │
│       ├── model/                # 数据模型（Gorm）
│       ├── migration/            # 数据库迁移脚本
│       ├── config/               # 配置管理
│       ├── database/             # 数据库连接
│       ├── logger/               # 日志初始化
│       ├── metrics/              # 监控指标
│       └── prometheus/           # Prometheus 客户端
│
├── plugins/                        # 插件
│   ├── baseline/                 # 基线检查插件
│   │   ├── main.go              # 插件入口
│   │   ├── src/                 # 检查器实现（file_kv、command 等）
│   │   └── config/              # 策略配置文件
│   │
│   ├── collector/                # 资产采集插件
│   │   ├── main.go              # 插件入口
│   │   └── engine/              # 采集器实现
│   │
│   └── lib/                      # 插件 SDK
│       └── go/                  # Go 版本 SDK
│           └── client.go        # Plugin Client（Pipe 通信）
│
├── api/                           # API 定义
│   └── proto/                    # Protobuf 定义
│       ├── grpc.proto           # Agent ↔ Server 协议
│       └── bridge.proto         # Agent ↔ Plugin 协议
│
├── ui/                            # 前端代码
│   ├── src/
│   │   ├── api/                # API 客户端
│   │   ├── views/              # 页面组件
│   │   ├── components/         # UI 组件
│   │   ├── stores/             # Pinia 状态管理
│   │   ├── router/             # 路由配置
│   │   ├── utils/              # 工具函数
│   │   ├── App.vue             # 主应用
│   │   └── main.ts             # 入口
│   ├── vite.config.ts          # Vite 配置
│   ├── tsconfig.json           # TypeScript 配置
│   └── package.json            # 依赖管理
│
├── deploy/                        # 部署配置
│   ├── docker-compose/         # Docker Compose 配置
│   │   ├── docker-compose.yml  # 生产环境
│   │   ├── docker-compose.dev.yml # 开发环境
│   │   └── certs/              # mTLS 证书目录
│   ├── systemd/                # Systemd Service 文件
│   └── k8s/                    # K8s 配置（后期）
│
├── configs/                       # 配置文件
│   └── server.yaml.example     # Server 配置示例
│
├── docs/                          # 文档
│   ├── design/                 # 设计文档
│   ├── deployment/             # 部署文档
│   ├── development/            # 开发文档
│   ├── testing/                # 测试文档
│   ├── TODO.md                 # 任务列表
│   ├── NEXT_STEPS.md           # 下一步计划
│   └── README.md               # 项目说明
│
├── tests/                         # 测试代码
│   ├── e2e/                    # 端到端测试
│   └── integration/            # 集成测试
│
├── scripts/                       # 脚本工具
│   ├── build-agent.sh          # Agent 构建脚本
│   ├── package-agent.sh        # Agent 打包脚本
│   ├── generate-certs.sh       # 证书生成脚本
│   ├── generate-proto.sh       # Protobuf 生成脚本
│   └── dev-start.sh            # 本地开发启动脚本
│
├── .cursor/                       # Cursor AI 配置
│   └── rules/
│       └── common.mdc          # Cursor 规则文件
│
├── Makefile                       # 构建脚本
├── go.mod / go.sum              # Go 依赖
├── CLAUDE.md                      # 本文件
├── README.md                      # 项目说明
└── DEVELOPMENT.md                 # 开发指南
```

---

## 开发环境

### 前置要求

**必需**:
- Go >= 1.21
- Node.js >= 16, npm
- MySQL >= 8.0
- Docker & Docker Compose (推荐用于开发)
- Protoc (用于生成 Protobuf 代码)

**可选**:
- Redis (用于得分缓存)
- Prometheus (用于监控)

### 快速启动

#### 方式一: Docker 开发环境 (推荐) ⭐

**使用 make 命令启动** (采用 Docker Compose + Air 热更新):

```bash
# 一键启动开发环境
make dev-docker-up

# 查看所有服务日志（跟踪模式）
make dev-docker-logs

# 停止服务
make dev-docker-down
```

**访问地址**:
- Manager API: http://localhost:8080
- UI (前端): http://localhost:3000
- MySQL: localhost:3306 (用户: mxsec_user, 密码: mxsec_password)
- AgentCenter gRPC: localhost:6751

**热更新说明**:
- 后端使用 **Air** 工具进行代码热重载（修改代码会自动重启服务）
- 前端使用 **Vite HMR** 进行热模块替换
- 无需手动重启服务，保存代码即可看到效果

**查看日志说明** ⚠️:
- **所有日志都在 Docker 容器内部**，不在宿主机文件系统中
- 不要在 `./logs/` 或 `/var/log/` 等宿主机目录中查找日志
- 使用下列命令查看容器日志：

```bash
# 查看所有服务日志
make dev-docker-logs

# 或直接使用 docker-compose
cd deploy/docker-compose
docker-compose -f docker-compose.dev.yml logs -f

# 查看特定服务的日志
docker-compose -f docker-compose.dev.yml logs -f manager
docker-compose -f docker-compose.dev.yml logs -f agentcenter
docker-compose -f docker-compose.dev.yml logs -f ui
docker-compose -f docker-compose.dev.yml logs -f mysql

# 进入容器内部查看日志文件
docker exec -it mxsec-manager-dev sh
# 在容器内查看日志
ls -la /var/log/mxcsec-platform/
tail -f /var/log/mxcsec-platform/manager.log
```

**容器名称对照**:

| 服务 | 开发环境容器名 | 备注 |
|------|---------------|------|
| Manager (HTTP API) | `mxsec-manager-dev` | 使用 Air 热更新 |
| AgentCenter (gRPC) | `mxsec-agentcenter-dev` | 使用 Air 热更新 |
| UI (前端) | `mxsec-ui-dev` | 使用 Vite HMR |
| MySQL | `mxsec-mysql` | 数据库服务 |

#### 方式二: 本地开发环境

```bash
# 1. 初始化数据库
make init-db

# 2. 生成证书
make certs

# 3. 启动后端 (Manager HTTP Server)
make dev-server

# 4. 启动前端 (新终端)
make dev-ui
```

#### 方式三: 分步启动

```bash
# 构建服务
make build-server

# 启动 Manager
./dist/server/manager -config configs/server.yaml

# 启动前端
cd ui && npm install && npm run dev
```

### 常用命令

```bash
# 代码生成
make proto                    # 生成 Protobuf 代码
make generate                 # 同 proto

# 构建
make build-agent             # 构建 Agent
make build-server            # 构建 Server (Manager + AgentCenter)

# 测试
make test                     # 运行所有测试
make fmt                      # 格式化代码
make lint                     # 代码检查

# 开发
make dev-docker-up           # Docker 开发环境
make dev-docker-logs         # 查看日志
make dev-docker-down         # 停止服务

# 清理
make clean                   # 清理生成的文件
make docker-clean            # 清理 Docker 资源
```

---

## 代码格式与规范

### Go 代码规范

#### 1. 项目结构规范

- **遵循 Go 标准项目布局**: `cmd/`, `internal/`, `pkg/` 等目录
- **main.go 保持简洁**: 仅负责启动流程，初始化逻辑提取到 `setup` 包
- **模块隔离**: Agent、AgentCenter、Manager 独立编译，不相互包含

**示例** (`cmd/server/manager/main.go`):
```go
func main() {
    // 初始化所有资源
    app, err := setup.Initialize()
    if err != nil {
        log.Fatal(err)
    }
    defer app.Cleanup()

    // 启动服务
    if err := app.Run(); err != nil {
        log.Fatal(err)
    }
}
```

#### 2. 命名规范

```
包名:          小写，无下划线，简短有意义
函数名:        首字母大写（导出），驼峰命名
变量名:        驼峰命名，避免缩写
常量名:        PascalCase 或 UPPER_CASE
接口名:        以 `er` 结尾（如 Reader, Writer）
```

#### 3. 注释规范

```go
// Package model 提供数据模型定义
package model

// Host 代表一台受管理的主机
type Host struct {
    ID       string    // 主机唯一标识
    Hostname string    // 主机名
    OSFamily string    // 操作系统族（rocky, centos, debian 等）
}

// GetHost 从数据库查询主机信息
func (h *Host) GetHost(id string) (*Host, error) {
    // 实现
}
```

**注释要求**:
- 每个导出的函数、类型、常量都必须有注释
- 注释以被描述对象的名字开头
- 使用完整的句子，以句号结尾

#### 4. 错误处理

```go
// ✅ 正确
if err != nil {
    logger.Error("数据库查询失败",
        zap.String("host_id", hostID),
        zap.Error(err),
    )
    return err
}

// ❌ 错误 - 使用 panic 在业务逻辑中
if err != nil {
    panic(err)  // 不允许！
}
```

**错误链式处理**:
```go
// 返回错误并添加上下文
return fmt.Errorf("查询主机 %s 失败: %w", hostID, err)
```

#### 5. 日志规范

```go
// 使用 Zap 结构化日志
logger.Info("任务开始执行",
    zap.String("task_id", taskID),
    zap.String("policy_id", policyID),
    zap.Int("host_count", len(hostIDs)),
)

logger.Error("任务执行失败",
    zap.String("task_id", taskID),
    zap.Error(err),
)

logger.Debug("详细日志",
    zap.Any("data", complexObject),
)
```

**日志级别**:
- `Debug`: 开发调试
- `Info`: 关键流程（任务开始/结束、连接建立）
- `Warn`: 警告（超时、重试等）
- `Error`: 错误（操作失败）

#### 6. 单元测试规范

```go
package api

import (
    "testing"
    "github.com/stretchr/testify/assert"
)

// 测试函数命名: Test{FunctionName}_{Scenario}_{Expected}
func TestCreatePolicy_ValidRequest_Success(t *testing.T) {
    // Arrange: 准备测试数据
    req := &CreatePolicyRequest{
        ID:   "test-policy",
        Name: "Test Policy",
    }

    // Act: 执行被测试的代码
    policy, err := handler.CreatePolicy(req)

    // Assert: 验证结果
    assert.NoError(t, err)
    assert.NotNil(t, policy)
    assert.Equal(t, "test-policy", policy.ID)
}

func TestCreatePolicy_DuplicateID_Conflict(t *testing.T) {
    // 测试重复 ID 情况
}

func TestCreatePolicy_InvalidRequest_BadRequest(t *testing.T) {
    // 测试无效请求
}
```

**测试覆盖率目标**: >= 70% (critical path: >= 85%)

#### 7. API 请求/响应规范

**请求体验证**:
```go
type CreatePolicyRequest struct {
    ID          string    `json:"id" binding:"required"`
    Name        string    `json:"name" binding:"required,min=3,max=100"`
    OSFamily    []string  `json:"os_family"`
    Enabled     bool      `json:"enabled"`
}

// 在处理器中
if err := c.ShouldBindJSON(&req); err != nil {
    c.JSON(http.StatusBadRequest, gin.H{
        "code":    400,
        "message": "请求参数错误: " + err.Error(),
    })
    return
}
```

**响应格式** (统一 JSON):
```json
// 成功
{
  "code": 0,
  "data": { /* 返回数据 */ }
}

// 错误
{
  "code": 400,
  "message": "详细错误说明"
}
```

**HTTP 状态码规范**:
| 状态码 | 说明 | 使用场景 |
|--------|------|---------|
| 200 | OK | 成功 |
| 400 | Bad Request | 请求参数错误 |
| 401 | Unauthorized | 未认证 |
| 403 | Forbidden | 无权限 |
| 404 | Not Found | 资源不存在 |
| 409 | Conflict | 资源冲突（如 ID 重复） |
| 500 | Internal Error | 服务器错误 |

### TypeScript / Vue 代码规范

#### 1. 文件结构

```
src/
├── api/                    # API 客户端模块
│   ├── index.ts           # 导出所有 API
│   ├── hosts.ts           # 主机相关 API
│   ├── policies.ts        # 策略相关 API
│   └── ...
├── stores/                 # Pinia 状态管理
│   ├── index.ts
│   ├── auth.ts            # 认证状态
│   └── ui.ts              # UI 状态
├── views/                  # 页面组件
│   ├── Home.vue
│   ├── Hosts.vue
│   └── ...
├── components/             # 可重用组件
│   ├── HostTable.vue
│   ├── PolicyForm.vue
│   └── ...
└── utils/                  # 工具函数
    ├── request.ts         # HTTP 请求
    └── format.ts          # 数据格式化
```

#### 2. 命名规范

```typescript
// 组件: PascalCase
export const HostList = defineComponent({})

// 函数: camelCase
const fetchHosts = async () => {}

// 常量: UPPER_CASE
const API_BASE_URL = 'http://localhost:8080'

// 接口: 以 I 开头 (可选)
interface IHost {
  id: string
  hostname: string
}
```

#### 3. API 调用规范

```typescript
// ✅ 正确 - 封装在 api 模块中
// src/api/hosts.ts
import axios from 'axios'

export const getHosts = async (page: number, limit: number) => {
  try {
    const { data } = await axios.get('/api/v1/hosts', {
      params: { page, limit },
    })
    return data
  } catch (error) {
    throw new Error(`获取主机列表失败: ${error.message}`)
  }
}

// 在组件中使用
import { getHosts } from '@/api/hosts'

const hosts = await getHosts(1, 10)

// ❌ 错误 - 直接在组件中调用
const hosts = await axios.get('/api/v1/hosts')
```

#### 4. 类型定义

```typescript
// 定义响应类型
interface ApiResponse<T> {
  code: number
  data?: T
  message?: string
}

interface Host {
  id: string
  hostname: string
  os_family: string
  os_version: string
  baseline_score: number
}

// 使用类型
const response: ApiResponse<Host[]> = await getHosts()
```

#### 5. 组件规范

```vue
<template>
  <div class="host-list">
    <a-table :columns="columns" :data-source="hosts" />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { getHosts } from '@/api/hosts'

interface Host {
  id: string
  hostname: string
}

// 响应式数据
const hosts = ref<Host[]>([])
const loading = ref(false)

// 列表列定义
const columns = [
  { title: '主机名', dataIndex: 'hostname' },
  { title: '主机ID', dataIndex: 'id' },
]

// 加载数据
const loadHosts = async () => {
  loading.value = true
  try {
    const res = await getHosts(1, 10)
    hosts.value = res.data
  } catch (error) {
    console.error('加载失败:', error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadHosts()
})
</script>

<style scoped>
.host-list {
  padding: 20px;
}
</style>
```

---

## 测试流程

### 测试分类

#### 1. 单元测试 (Unit Tests)

**位置**: `*_test.go` (Backend) / `*.spec.ts` (Frontend)

**命令**:
```bash
# 运行所有测试
make test

# 运行特定包的测试
go test ./internal/server/manager/api -v

# 运行特定测试函数
go test -run TestCreatePolicy ./internal/server/manager/api -v

# 查看覆盖率
go test ./... -cover
go test ./... -coverprofile=coverage.out && go tool cover -html=coverage.out
```

**示例**:
```go
func TestCreatePolicy_ValidRequest(t *testing.T) {
    // 准备
    mockDB := setupMockDB(t)
    handler := NewPoliciesHandler(mockDB, logger)

    req := &CreatePolicyRequest{
        ID:       "policy-1",
        Name:     "SSH Security",
        Enabled:  true,
    }

    // 执行
    policy, err := handler.CreatePolicy(req)

    // 断言
    assert.NoError(t, err)
    assert.NotNil(t, policy)
    assert.Equal(t, "policy-1", policy.ID)
}
```

**覆盖场景**:
- ✅ 正常请求
- ✅ 边界值（最小值、最大值）
- ✅ 无效输入（空值、错误类型）
- ✅ 异常情况（DB 错误、超时）

#### 2. 集成测试 (Integration Tests)

**位置**: `tests/integration/`

**命令**:
```bash
# 运行集成测试
go test ./tests/integration -v

# 可选：连接真实 MySQL（需要 MYSQL_URL 环境变量）
MYSQL_URL="root:password@tcp(localhost:3306)/mxsec" go test ./tests/integration -v
```

**覆盖内容**:
- API 路由整合
- 数据库持久化
- 中间件链
- 认证流程

#### 3. 端到端测试 (E2E Tests)

**位置**: `tests/e2e/`

**测试流程**:
```
1. 启动 Manager 和 AgentCenter
2. 创建策略和规则
3. 创建扫描任务
4. 验证任务下发和执行
5. 检查结果存储
```

**命令**:
```bash
# 运行 E2E 测试（需要 Docker 环境）
make test

# 或手动
cd tests/e2e
go test -v -timeout 5m
```

#### 4. API 测试

**工具**: Postman / Insomnia / curl

**测试清单** (`docs/testing/api-tests.md`):
- [ ] 认证 API (POST /auth/login)
- [ ] 主机管理 (GET/POST /hosts)
- [ ] 策略管理 (CRUD /policies)
- [ ] 任务管理 (POST /tasks, POST /tasks/:id/run)
- [ ] 结果查询 (GET /results)

### 测试流程 (CI/CD)

```bash
# 完整测试流程
make fmt          # 格式化
make lint         # 代码检查
make test         # 单元测试
make build-agent  # 构建 Agent
make build-server # 构建 Server
```

---

## API 文档

### Manager HTTP API (`/api/v1`)

#### 认证 API

```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin"
}

Response:
{
  "code": 0,
  "data": {
    "token": "eyJhbGc...",
    "expires_at": "2025-12-12T10:00:00Z"
  }
}
```

#### 主机管理

```http
# 获取主机列表
GET /api/v1/hosts?page=1&limit=10

# 获取主机详情
GET /api/v1/hosts/:host_id

# 获取主机基线得分
GET /api/v1/hosts/:host_id/score

# 获取主机监控数据
GET /api/v1/hosts/:host_id/metrics?range=7d
```

#### 策略管理

```http
# 获取策略列表
GET /api/v1/policies

# 创建策略
POST /api/v1/policies
Content-Type: application/json

{
  "id": "linux-baseline-001",
  "name": "Linux 系统基线",
  "os_family": ["rocky", "centos"],
  "enabled": true,
  "rules": [
    {
      "rule_id": "SSH_001",
      "title": "SSH 禁止 root 登录",
      "check_config": {
        "type": "file_kv",
        "path": "/etc/ssh/sshd_config",
        "key": "PermitRootLogin"
      }
    }
  ]
}

# 更新策略
PUT /api/v1/policies/:policy_id

# 删除策略
DELETE /api/v1/policies/:policy_id

# 获取策略统计信息
GET /api/v1/policies/:policy_id/statistics
```

#### 任务管理

```http
# 创建扫描任务
POST /api/v1/tasks
{
  "name": "全量基线扫描",
  "type": "baseline",
  "policy_id": "linux-baseline-001",
  "targets": {
    "type": "all"  # 或 "host_ids": ["host-1", "host-2"]
  }
}

# 获取任务列表
GET /api/v1/tasks

# 执行任务
POST /api/v1/tasks/:task_id/run
```

#### 结果查询

```http
# 获取检测结果
GET /api/v1/results?host_id=host-1&policy_id=policy-1&status=fail

# 获取主机基线摘要
GET /api/v1/results/host/:host_id/summary
```

#### 资产数据

```http
# 获取进程列表
GET /api/v1/assets/processes?host_id=host-1

# 获取端口列表
GET /api/v1/assets/ports?host_id=host-1

# 获取用户列表
GET /api/v1/assets/users?host_id=host-1
```

#### Dashboard

```http
# 获取统计数据
GET /api/v1/dashboard/stats
```

---

## 任务追踪

### 任务状态

我们使用 `docs/TODO.md` 统一记录所有任务。每个任务都有以下属性：

- **✅ 已完成** (Completed)
- **🔄 进行中** (In Progress)
- **⏳ 待做** (Pending)
- **❌ 阻塞** (Blocked)

### 任务分级

| 级别 | 说明 | 处理时间 |
|------|------|---------|
| **P0** | 必须完成，阻塞上线 | 今天 |
| **P1** | 重要，本周完成 | 本周 |
| **P2** | 可选优化 | 本月 |

### 每日工作流程

1. **早晨**: 检查 `docs/TODO.md`，找出 P0 和 P1 任务
2. **工作中**: 标记任务为 `🔄 进行中`
3. **完成时**: 标记为 `✅ 已完成`，记录完成方式（代码链接或文档）
4. **结束**: 更新 CLAUDE.md 中的"当前工作"部分

### 当前工作

**日期**: 2025-12-11

**已完成任务**:
1. ✅ [P0] 修复 API 问题
   - POST /api/v1/policies: 移除 CheckConfig 的 required 标记，添加手动验证
   - POST /api/v1/tasks/:task_id/run: 改为返回 HTTP 409 Conflict（而非 400）
   - 添加了 4 个新的集成测试用例来验证修复

2. ✅ [P0] 创建中文版 CLAUDE.md
   - 包含完整的技术栈说明
   - 项目结构和代码组织规范
   - 开发、测试、部署流程
   - 任务追踪和工作流程

**当前任务**:
1. ⏳ [P1] 完善基线规则库（扩展 SSH、密码策略、文件权限等规则）
2. ⏳ [P2] 资产采集完整性验证
3. ⏳ [P2] 告警系统集成

**最后更新时间**: 2025-12-11 18:50

---

## 常见问题

### Q1: 如何运行单个测试？
```bash
go test -run TestCreatePolicy_DuplicateID ./internal/server/manager/api -v
```

### Q2: 如何查看特定模块的测试覆盖率？
```bash
go test ./internal/server/manager/api -cover
```

### Q3: Docker 容器连接 MySQL 失败？
- 检查 MySQL 是否运行: `docker ps | grep mysql`
- 检查配置文件: `configs/server.yaml`
- 默认连接: `127.0.0.1:3306`

### Q4: 如何清除并重新初始化数据库？
```bash
mysql -h 127.0.0.1 -u root -p123456 -e "DROP DATABASE IF EXISTS mxsec; CREATE DATABASE mxsec CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
make init-db
```

### Q5: 前端编译失败？
```bash
cd ui
rm -rf node_modules package-lock.json
npm install
npm run dev
```

### Q6: 如何生成 API 文档？
现在使用 Postman / Insomnia，后期可使用 SwaggerUI。

---

## 工作流程

### 新功能开发

1. **创建分支**
   ```bash
   git checkout -b feat/新功能名
   ```

2. **更新 TODO.md**
   - 添加任务条目，标记为 `⏳ 待做`
   - 设置优先级（P0/P1/P2）

3. **在 CLAUDE.md 中记录**
   ```markdown
   **当前工作**:
   - 🔄 [P1] 新功能名 - 实现 XXX
   ```

4. **开发实现**
   - 遵循本文档的代码规范
   - 编写单元测试
   - 保持代码覆盖率 >= 70%

5. **测试验证**
   ```bash
   make fmt
   make lint
   make test
   ```

6. **提交代码**
   ```bash
   git add .
   git commit -m "feat: 新功能名 - 实现 XXX 功能"
   ```

7. **更新文档**
   - 更新 `docs/NEXT_STEPS.md`
   - 更新 TODO.md，标记为 `✅ 已完成`
   - 更新 CLAUDE.md 的"当前工作"部分

8. **Push & PR**
   ```bash
   git push origin feat/新功能名
   ```

### Bug 修复

1. **从 TODO.md 中选择**
   - 找到 "已知问题" 部分的 bug
   - 标记为 `🔄 进行中`

2. **创建分支**
   ```bash
   git checkout -b fix/bug描述
   ```

3. **修复 + 测试**
   - 编写复现测试用例
   - 修复代码
   - 验证测试通过

4. **提交**
   ```bash
   git commit -m "fix: bug描述 - 修复 XXX 问题"
   ```

5. **更新 TODO.md**
   - 标记为 `✅ 已完成`
   - 添加完成说明

---

## 参考资源

- **项目 README**: [README.md](README.md)
- **开发指南**: [DEVELOPMENT.md](DEVELOPMENT.md)
- **任务列表**: [docs/TODO.md](docs/TODO.md)
- **下一步计划**: [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md)
- **Cursor 规则**: [.cursor/rules/common.mdc](.cursor/rules/common.mdc)
- **设计文档**: [docs/design/](docs/design/)
- **测试文档**: [docs/testing/](docs/testing/)

---

**文档维护者**: Claude Code

**最后更新**: 2025-12-11 18:30
**下次更新计划**: 2025-12-12 (API 修复完成后)

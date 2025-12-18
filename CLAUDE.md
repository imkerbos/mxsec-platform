# CLAUDE.md - 矩阵云安全平台开发指南

本文档为 Claude Code 在本项目中的工作指南，包含完整的技术栈、开发规范、测试流程和任务追踪。

**最后更新**: 2025-12-18
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

#### 5. 日志规范（必须遵循）

**使用 Zap 结构化日志**，禁止使用 `fmt.Println`、`log.Println` 等。

```go
// ✅ 正确用法 - 结构化日志，带上下文字段
logger.Info("任务开始执行",
    zap.String("task_id", taskID),
    zap.String("policy_id", policyID),
    zap.Int("host_count", len(hostIDs)),
)

logger.Error("查询主机失败",
    zap.String("host_id", hostID),
    zap.Error(err),
)

logger.Warn("配置不存在，使用默认值",
    zap.String("config_key", key),
    zap.Any("default_value", defaultValue),
)

logger.Debug("详细日志",
    zap.Any("request", req),
    zap.Any("response", resp),
)

// ❌ 错误用法
fmt.Printf("Task %s started\n", taskID)
log.Println("Error:", err)
```

**日志级别使用规范**:
| 级别 | 使用场景 | 示例 |
|------|---------|------|
| `Debug` | 开发调试、详细信息 | 函数参数、中间结果、请求/响应内容 |
| `Info` | 关键业务流程 | 任务开始/完成、连接建立、配置加载、重要操作 |
| `Warn` | 潜在问题、降级处理 | 配置缺失使用默认值、重试、性能警告 |
| `Error` | 操作失败、需要关注 | 数据库错误、外部服务失败、业务逻辑错误 |

**必须包含的上下文字段**:
- 主机相关：`host_id`、`hostname`、`ip`
- 任务相关：`task_id`、`policy_id`
- 告警相关：`alert_id`、`rule_id`、`severity`
- 通知相关：`notification_id`
- 用户相关：`user_id`、`username`

**日志记录时机**:
- ✅ 操作开始时（Info）
- ✅ 操作成功完成时（Info/Debug）
- ✅ 操作失败时（Error）
- ✅ 使用降级/默认值时（Warn）
- ✅ 关键业务数据变更时（Info）

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

#### 8. 统一响应工具函数（必须使用）

**文件位置**: `internal/server/manager/api/response.go`

所有 HTTP API 返回**必须使用统一的响应工具函数**，禁止直接使用 `c.JSON()`。

```go
// ✅ 正确用法 - 使用工具函数
func (h *Handler) GetResource(c *gin.Context) {
    resource, err := h.service.GetResource(id)
    if err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            NotFound(c, "资源不存在")
            return
        }
        h.logger.Error("查询资源失败", zap.String("id", id), zap.Error(err))
        InternalError(c, "查询资源失败")
        return
    }
    Success(c, resource)
}

// 分页数据
func (h *Handler) ListResources(c *gin.Context) {
    total, items, err := h.service.ListResources(page, pageSize)
    if err != nil {
        h.logger.Error("查询列表失败", zap.Error(err))
        InternalError(c, "查询失败")
        return
    }
    SuccessPaginated(c, total, items)
}

// 创建资源
func (h *Handler) CreateResource(c *gin.Context) {
    var req CreateRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        BadRequest(c, "请求参数错误: " + err.Error())
        return
    }
    resource, err := h.service.Create(&req)
    if err != nil {
        h.logger.Error("创建失败", zap.Error(err))
        InternalError(c, "创建失败")
        return
    }
    Created(c, resource)
}

// ❌ 错误用法 - 直接使用 c.JSON
func (h *Handler) GetResource(c *gin.Context) {
    c.JSON(http.StatusOK, gin.H{
        "code": 0,
        "data": resource,
    })
}
```

**可用的响应函数列表**:

| 函数 | HTTP 状态码 | 用途 |
|------|------------|------|
| `Success(c, data)` | 200 | 成功响应，返回数据 |
| `SuccessWithMessage(c, msg, data)` | 200 | 成功响应，带消息和数据 |
| `SuccessMessage(c, msg)` | 200 | 成功响应，仅返回消息 |
| `SuccessPaginated(c, total, items)` | 200 | 成功响应，分页数据 |
| `Created(c, data)` | 201 | 创建成功 |
| `BadRequest(c, msg)` | 400 | 请求参数错误 |
| `Unauthorized(c, msg)` | 401 | 未认证 |
| `Forbidden(c, msg)` | 403 | 无权限 |
| `NotFound(c, msg)` | 404 | 资源不存在 |
| `Conflict(c, msg)` | 409 | 资源冲突（如 ID 重复） |
| `InternalError(c, msg)` | 500 | 服务器内部错误 |

#### 9. 数据库查询规范

```go
// ✅ 正确用法 - 使用预加载避免 N+1 问题
var alerts []model.Alert
db.Preload("Host").Preload("Rule").Find(&alerts)

// ✅ 正确用法 - 使用事务保证数据一致性
err := db.Transaction(func(tx *gorm.DB) error {
    if err := tx.Create(&policy).Error; err != nil {
        return err
    }
    for _, rule := range rules {
        rule.PolicyID = policy.ID
        if err := tx.Create(&rule).Error; err != nil {
            return err
        }
    }
    return nil
})

// ✅ 正确用法 - 分页查询
var total int64
var items []model.Host
db.Model(&model.Host{}).Count(&total)
db.Offset((page - 1) * pageSize).Limit(pageSize).Find(&items)

// ❌ 错误用法 - 循环中查询（N+1 问题）
for _, alert := range alerts {
    var host model.Host
    db.First(&host, "host_id = ?", alert.HostID)  // 每次循环都查询！
}
```

#### 10. 配置管理规范

```go
// ✅ 正确用法 - 从配置文件读取
dbHost := viper.GetString("database.host")
dbPort := viper.GetInt("database.port")
timeout := viper.GetDuration("server.timeout")

// ✅ 正确用法 - 使用常量定义默认值
const (
    DefaultPageSize    = 20
    DefaultTimeout     = 30 * time.Second
    DefaultMaxRetries  = 3
)

// ✅ 正确用法 - 配置结构体
type ServerConfig struct {
    Host    string        `mapstructure:"host"`
    Port    int           `mapstructure:"port"`
    Timeout time.Duration `mapstructure:"timeout"`
}

// ❌ 错误用法 - 硬编码配置
db, _ := gorm.Open(mysql.Open("root:password@tcp(localhost:3306)/mxsec"))
http.ListenAndServe(":8080", router)  // 端口不应硬编码
```

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

#### 3. API 调用规范（必须遵循）

**文件位置**: `ui/src/api/*.ts`

所有 API 调用必须封装在 `src/api` 目录中，禁止在组件中直接调用 axios。

```typescript
// ✅ 正确用法 - 统一封装在 api 目录
// ui/src/api/hosts.ts
import { apiClient } from './client'

// 定义类型
export interface Host {
  id: string
  hostname: string
  ip: string
  os_family: string
  baseline_score: number
}

export interface ListHostsParams {
  page: number
  pageSize: number
  keyword?: string
  status?: string
}

// API 方法封装
export const hostsApi = {
  // 获取列表
  getList: (params: ListHostsParams) => {
    return apiClient.get<{ total: number; items: Host[] }>('/hosts', { params })
  },
  
  // 获取详情
  getById: (id: string) => {
    return apiClient.get<Host>(`/hosts/${id}`)
  },
  
  // 创建
  create: (data: Partial<Host>) => {
    return apiClient.post<Host>('/hosts', data)
  },
  
  // 更新
  update: (id: string, data: Partial<Host>) => {
    return apiClient.put<Host>(`/hosts/${id}`, data)
  },
  
  // 删除
  delete: (id: string) => {
    return apiClient.delete(`/hosts/${id}`)
  },
}

// 在组件中使用
import { hostsApi } from '@/api/hosts'
import { message } from 'ant-design-vue'

const hosts = ref<Host[]>([])
const loading = ref(false)

const loadHosts = async () => {
  loading.value = true
  try {
    const { data } = await hostsApi.getList({ page: 1, pageSize: 10 })
    hosts.value = data.items
  } catch (error) {
    console.error('加载主机列表失败:', error)
    message.error('加载失败')
  } finally {
    loading.value = false
  }
}

// ❌ 错误用法 - 直接在组件中调用 axios
const hosts = await axios.get('/api/v1/hosts')
```

#### 3.1 前端错误处理规范

```typescript
// ✅ 正确用法 - 统一错误处理
const handleSubmit = async () => {
  try {
    await hostsApi.create(formData)
    message.success('创建成功')
    router.push('/hosts')
  } catch (error: any) {
    console.error('创建失败:', error)
    // 根据错误类型显示不同消息
    if (error.response?.status === 409) {
      message.error('资源已存在')
    } else if (error.response?.status === 400) {
      message.error(error.response?.data?.message || '参数错误')
    } else {
      message.error('操作失败，请重试')
    }
  }
}

// ❌ 错误用法 - 忽略错误
const loadData = async () => {
  const data = await hostsApi.getList({ page: 1, pageSize: 10 })  // 没有 try-catch
  hosts.value = data.items
}
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

**日期**: 2025-12-13

**已完成任务**:

1. ✅ [P0] 完善 Baseline 任务执行流程
   - Baseline Plugin 添加 task_id 到检测结果 (`plugins/baseline/main.go`)
   - Baseline Plugin 发送任务完成信号 (DataType=8001)
   - Server 端处理任务完成信号并更新任务状态 (`internal/server/agentcenter/transfer/service.go`)
   - Server 端检测结果去重（UPSERT 机制）
   - 完整的任务状态流转：pending → running → completed/failed

2. ✅ [P1] 创建 CMDB 对接文档
   - 完整对接指南：`docs/CMDB_INTEGRATION.md` (36KB, 1400+ 行)
   - 快速开始指南：`docs/CMDB_INTEGRATION_QUICKSTART.md` (12KB)
   - 包含 Python/Java 示例代码、API 文档、数据模型、故障排查

3. ✅ [P1] 完善基线规则库 (2025-12-13)
   - 从 24 条规则扩展到 **125 条规则**（增加 101 条）
   - 扩展密码策略规则：2 → 15 条（PAM 复杂度、账户锁定、加密算法等）
   - 扩展文件权限规则：3 → 20 条（/etc/sudoers、SSH 密钥、日志文件等）
   - 扩展内核安全参数规则：2 → 25 条（ASLR、网络安全、ptrace 限制等）
   - 扩展服务状态规则：2 → 20 条（禁用不安全服务、防火墙、SELinux 等）
   - 新增账户安全规则：15 条（UID 检查、umask、用户目录权限等）
   - 新增审计日志规则：15 条（auditd 配置、日志保留、审计规则等）
   - 规则文件位置：`plugins/baseline/config/examples/`

**当前任务**:
1. ⏳ [P2] 资产采集完整性验证
2. ⏳ [P2] 告警系统集成

**最后更新时间**: 2025-12-13 14:00

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

### Git 提交规则

**重要**: Claude Code 不直接执行 git commit，而是提供命令和 commit 信息供用户自行提交。

**工作流程**:
1. 用户请求提交代码时，Claude 分析改动内容
2. Claude 提供完整的 git 命令和 commit message
3. 用户自行复制执行命令

**Commit Message 格式**:
```
<type>: <简短描述>

- 详细改动点1
- 详细改动点2
- ...
```

**Type 类型**:
- `feat`: 新功能
- `fix`: Bug 修复
- `refactor`: 重构（不改变功能）
- `docs`: 文档更新
- `style`: 代码格式调整
- `test`: 测试相关
- `chore`: 构建/工具相关

**示例输出**:
```bash
# Claude 提供的命令
git add -A
git commit -m "feat: 实现组件管理系统

- 新增 Component/Version/Package 数据模型
- 实现组件 CRUD API
- 添加版本发布和包上传功能
- 前端组件管理页面"

git push origin main
```

---

## 工具函数速查表

> 开发时快速查阅，避免重复造轮子。

### 后端工具函数

#### API 响应 (`internal/server/manager/api/response.go`)

| 函数 | 用途 | 示例 |
|------|------|------|
| `Success(c, data)` | 返回成功数据 | `Success(c, host)` |
| `SuccessWithMessage(c, msg, data)` | 返回成功+消息+数据 | `SuccessWithMessage(c, "更新成功", host)` |
| `SuccessMessage(c, msg)` | 仅返回成功消息 | `SuccessMessage(c, "删除成功")` |
| `SuccessPaginated(c, total, items)` | 返回分页数据 | `SuccessPaginated(c, 100, hosts)` |
| `Created(c, data)` | 创建成功 (201) | `Created(c, newPolicy)` |
| `BadRequest(c, msg)` | 参数错误 (400) | `BadRequest(c, "ID 不能为空")` |
| `NotFound(c, msg)` | 资源不存在 (404) | `NotFound(c, "主机不存在")` |
| `Conflict(c, msg)` | 资源冲突 (409) | `Conflict(c, "ID 已存在")` |
| `InternalError(c, msg)` | 服务器错误 (500) | `InternalError(c, "数据库错误")` |

#### 日志 (Zap)

```go
// 常用日志模式
logger.Info("操作成功", zap.String("id", id))
logger.Error("操作失败", zap.String("id", id), zap.Error(err))
logger.Warn("使用默认值", zap.String("key", key), zap.Any("default", val))
logger.Debug("调试信息", zap.Any("data", obj))
```

### 前端工具函数

#### API 客户端 (`ui/src/api/client.ts`)

```typescript
import { apiClient } from '@/api/client'

// GET 请求
apiClient.get<ResponseType>('/path', { params })

// POST 请求
apiClient.post<ResponseType>('/path', data)

// PUT 请求
apiClient.put<ResponseType>('/path', data)

// DELETE 请求
apiClient.delete('/path')
```

#### 消息提示 (Ant Design Vue)

```typescript
import { message } from 'ant-design-vue'

message.success('操作成功')
message.error('操作失败')
message.warning('警告信息')
message.info('提示信息')
message.loading('加载中...')
```

### 常用代码模板

#### 后端 API Handler 模板

```go
// GetXxx 获取资源详情
func (h *XxxHandler) GetXxx(c *gin.Context) {
    id := c.Param("id")
    
    var item model.Xxx
    if err := h.db.First(&item, "id = ?", id).Error; err != nil {
        if err == gorm.ErrRecordNotFound {
            NotFound(c, "资源不存在")
            return
        }
        h.logger.Error("查询失败", zap.String("id", id), zap.Error(err))
        InternalError(c, "查询失败")
        return
    }
    
    Success(c, item)
}

// ListXxx 获取资源列表
func (h *XxxHandler) ListXxx(c *gin.Context) {
    page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
    pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
    
    var total int64
    var items []model.Xxx
    
    query := h.db.Model(&model.Xxx{})
    
    if err := query.Count(&total).Error; err != nil {
        h.logger.Error("查询总数失败", zap.Error(err))
        InternalError(c, "查询失败")
        return
    }
    
    offset := (page - 1) * pageSize
    if err := query.Offset(offset).Limit(pageSize).Find(&items).Error; err != nil {
        h.logger.Error("查询列表失败", zap.Error(err))
        InternalError(c, "查询失败")
        return
    }
    
    SuccessPaginated(c, total, items)
}

// CreateXxx 创建资源
func (h *XxxHandler) CreateXxx(c *gin.Context) {
    var req CreateXxxRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        BadRequest(c, "请求参数错误: " + err.Error())
        return
    }
    
    item := model.Xxx{
        // 字段映射
    }
    
    if err := h.db.Create(&item).Error; err != nil {
        h.logger.Error("创建失败", zap.Error(err))
        InternalError(c, "创建失败")
        return
    }
    
    h.logger.Info("资源创建成功", zap.Uint("id", item.ID))
    Created(c, item)
}
```

#### 前端页面模板

```vue
<template>
  <div class="page-container">
    <a-table
      :columns="columns"
      :data-source="items"
      :loading="loading"
      :pagination="pagination"
      @change="handleTableChange"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue'
import { xxxApi, type Xxx } from '@/api/xxx'
import { message } from 'ant-design-vue'

const items = ref<Xxx[]>([])
const loading = ref(false)
const pagination = reactive({
  current: 1,
  pageSize: 20,
  total: 0,
})

const columns = [
  { title: 'ID', dataIndex: 'id' },
  { title: '名称', dataIndex: 'name' },
]

const loadData = async () => {
  loading.value = true
  try {
    const { data } = await xxxApi.getList({
      page: pagination.current,
      pageSize: pagination.pageSize,
    })
    items.value = data.items
    pagination.total = data.total
  } catch (error) {
    console.error('加载数据失败:', error)
    message.error('加载失败')
  } finally {
    loading.value = false
  }
}

const handleTableChange = (pag: any) => {
  pagination.current = pag.current
  pagination.pageSize = pag.pageSize
  loadData()
}

onMounted(() => {
  loadData()
})
</script>
```

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

**最后更新**: 2025-12-18
**更新内容**: 添加统一工具函数规范、API 响应规范、日志规范、代码模板

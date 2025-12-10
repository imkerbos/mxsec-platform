# 项目架构概览

> 本文档说明 Matrix Cloud Security Platform 的整体架构、模块划分和各组件之间的关系。

---

## 1. 整体架构

### 1.1 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      Server 端                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ AgentCenter  │  │   Manager    │  │ServiceDiscov │   │
│  │  (gRPC)      │  │  (HTTP API)  │  │  (可选)      │   │
│  │              │  │              │  │              │   │
│  │ - 与 Agent   │  │ - 策略管理   │  │ - 服务注册   │   │
│  │   通信       │  │ - 任务管理   │  │ - 服务发现   │   │
│  │ - 接收数据   │  │ - 结果查询   │  │              │   │
│  │ - 下发任务   │  │ - Dashboard  │  │              │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│         │                  │                             │
│         └──────────┬───────┘                             │
│                    │                                     │
│              ┌─────▼─────┐                              │
│              │  Database │                              │
│              │ (MySQL/   │                              │
│              │ PostgreSQL)│                              │
│              └───────────┘                              │
└─────────────────────────────────────────────────────────────┘
                    ↕ (gRPC + mTLS)
┌─────────────────────────────────────────────────────────────┐
│                      Agent 端                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            mxsec-agent (主进程)                      │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │  │
│  │  │ Heartbeat│  │ Plugin   │  │ Transport│          │  │
│  │  │ (心跳)   │  │ Manager  │  │ (gRPC)   │          │  │
│  │  └──────────┘  └──────────┘  └──────────┘          │  │
│  └──────────────────────────────────────────────────────┘  │
│                    ↕ (Pipe + Protobuf)                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │               Plugin Processes                         │  │
│  │  ┌──────────┐  ┌──────────┐                          │  │
│  │  │Baseline  │  │Collector │                          │  │
│  │  │ Plugin   │  │ Plugin   │                          │  │
│  │  └──────────┘  └──────────┘                          │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                    ↕ (HTTP API)
┌─────────────────────────────────────────────────────────────┐
│                      UI 端                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            mxsec-console (Vue3 + TS)                  │  │
│  │  - 主机列表与详情                                      │  │
│  │  - 策略管理                                            │  │
│  │  - 任务管理                                            │  │
│  │  - Dashboard                                          │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 模块划分

### 2.1 Server 端模块

#### 2.1.1 AgentCenter（Agent 中心）

**职责**：
- 与 Agent 建立 gRPC 双向流连接（`Transfer` 服务）
- 接收 Agent 上报的数据：
  - 心跳数据（主机信息、Agent 状态）
  - 基线检查结果
  - 资产数据（进程、端口、账户等）
- 下发任务和配置到 Agent：
  - 扫描任务（基线检查任务）
  - 插件配置更新
- 管理 Agent 连接状态（在线/离线）

**技术栈**：
- Golang + gRPC Server
- mTLS 双向认证
- 数据库：MySQL/PostgreSQL（存储检测结果、资产数据）

**入口**：`cmd/server/agentcenter/main.go`

**核心代码**：
- `internal/server/agentcenter/transfer/`：Transfer 服务实现
- `internal/server/agentcenter/service/`：业务逻辑（任务调度、策略匹配等）

---

#### 2.1.2 Manager（管理 API）

**职责**：
- 提供 HTTP REST API 供前端调用
- 策略管理（CRUD 操作）
- 任务管理（创建、执行、查询扫描任务）
- 结果查询（检测结果、基线得分、统计信息）
- Dashboard 数据（主机统计、基线得分趋势等）
- 用户认证与授权（JWT Token）

**技术栈**：
- Golang + Gin（HTTP Server）
- 数据库：MySQL/PostgreSQL（与 AgentCenter 共享）
- JWT 认证

**入口**：`cmd/server/manager/main.go`

**核心代码**：
- `internal/server/manager/api/`：HTTP API 处理器
- `internal/server/manager/biz/`：业务逻辑（基线得分计算、任务管理等）

---

#### 2.1.3 ServiceDiscovery（服务发现，可选）

**职责**：
- 服务注册与发现
- Agent 通过 ServiceDiscovery 获取 AgentCenter 地址（支持多实例负载均衡）
- 服务健康检查

**状态**：
- Phase 1 可简化实现，Agent 直接使用配置的 Server 地址
- Phase 2+ 可扩展为完整的服务发现机制

---

### 2.2 Agent 端模块

#### 2.2.1 mxsec-agent（Agent 主进程）

**职责**：
- 作为插件基座，管理插件生命周期
- 与 Server 的 gRPC 双向流通信
- 心跳上报（主机信息、Agent 状态）
- 插件管理（启动、停止、升级）
- 连接管理（服务发现、mTLS、重连）

**技术栈**：
- Golang（单二进制）
- gRPC Client
- mTLS 双向认证
- systemd service

**入口**：`cmd/agent/main.go`

**核心模块**：
- `internal/agent/core/`：Agent 核心逻辑
- `internal/agent/plugin/`：插件管理
- `internal/agent/transport/`：gRPC 传输
- `internal/agent/heartbeat/`：心跳上报
- `internal/agent/connection/`：连接管理

---

#### 2.2.2 Baseline Plugin（基线检查插件）

**职责**：
- 加载基线策略（从 Server 下发或本地文件）
- 执行基线检查（文件、命令、权限、sysctl 等）
- 上报检测结果

**技术栈**：
- Golang（独立二进制）
- 通过 Pipe + Protobuf 与 Agent 通信

**入口**：`plugins/baseline/main.go`

---

#### 2.2.3 Collector Plugin（资产采集插件）

**职责**：
- 周期性采集主机资产信息：
  - 进程信息（PID、命令行、MD5、容器关联）
  - 端口信息（TCP/UDP 监听端口、进程关联）
  - 账户信息（用户列表、弱密码检测、sudoers 配置）
  - 软件包信息（系统包、Python 包、JAR 包等）
  - 容器信息（Docker、containerd 等运行时）
  - 应用信息（数据库、消息队列、Web 服务等）
  - 硬件信息（网卡、磁盘等）
  - 内核模块信息
  - 系统服务与定时任务
- 上报资产数据

**技术栈**：
- Golang（独立二进制）
- 通过 Pipe + Protobuf 与 Agent 通信

**入口**：`plugins/collector/main.go`

**状态**：Phase 2 实现

---

### 2.3 UI 端模块

#### 2.3.1 mxsec-console（前端界面）

**职责**：
- 主机视图：主机列表、基线得分、详情
- 策略视图：策略列表、规则编辑、策略详情
- 任务视图：扫描任务、任务历史
- Dashboard：统计概览、主机状态、基线得分趋势
- 报表 / 导出

**技术栈**：
- Vue3 + TypeScript
- Pinia（状态管理）
- Ant Design Vue（组件库）
- Axios（HTTP 客户端）

**入口**：`ui/src/main.ts`

---

## 3. 组件关系

### 3.1 Agent ↔ AgentCenter

**通信方式**：gRPC 双向流（`Transfer` 服务）+ mTLS 双向认证

**数据流**：
- **Agent → AgentCenter**：
  - 心跳数据（DataType=1000）：主机信息、Agent 状态
  - 插件状态（DataType=1001）：插件运行状态
  - 基线检查结果（DataType=8000）：检测结果
  - 资产数据（DataType=5050-5064）：各类资产信息

- **AgentCenter → Agent**：
  - 任务下发（Task）：扫描任务
  - 插件配置更新（Config）：插件版本、下载地址等

**协议定义**：`api/proto/grpc.proto`

---

### 3.2 UI ↔ Manager

**通信方式**：HTTP REST API

**主要接口**：
- 认证：`POST /api/v1/auth/login`
- 主机：`GET /api/v1/hosts`
- 策略：`GET /api/v1/policies`
- 任务：`GET /api/v1/tasks`、`POST /api/v1/tasks`
- 结果：`GET /api/v1/results`
- Dashboard：`GET /api/v1/dashboard/stats`

**认证方式**：JWT Token（Bearer Token）

---

### 3.3 Manager ↔ AgentCenter

**通信方式**：共享数据库（MySQL/PostgreSQL）

**数据共享**：
- `hosts` 表：主机信息（AgentCenter 写入，Manager 读取）
- `policies` 表：策略配置（Manager 写入，AgentCenter 读取）
- `rules` 表：规则配置（Manager 写入，AgentCenter 读取）
- `scan_tasks` 表：扫描任务（Manager 写入，AgentCenter 读取并下发）
- `scan_results` 表：检测结果（AgentCenter 写入，Manager 读取）

**注意**：Manager 和 AgentCenter 可以部署在同一进程或不同进程，通过共享数据库协调。

---

### 3.4 Agent ↔ Plugins

**通信方式**：Pipe（管道）+ Protobuf

**通信流程**：
1. Agent 创建 Pipe（`rx` 和 `tx`）
2. Agent 启动插件进程（子进程），传递 Pipe 文件描述符
3. 插件通过 `plugins.Client` SDK 与 Agent 通信：
   - `SendRecord()`：发送数据到 Agent（写入 `rx`）
   - `ReceiveTask()`：接收 Agent 下发的任务（从 `tx` 读取）
4. Agent 将插件数据透传到 Server（不二次解析，性能优化）

**插件 SDK**：`plugins/lib/go/client.go`

---

## 4. 数据流示例

### 4.1 基线扫描流程

```
1. 用户在 UI 创建扫描任务
   UI → Manager: POST /api/v1/tasks
   Manager → Database: INSERT INTO scan_tasks

2. AgentCenter 任务调度器检测到待执行任务
   AgentCenter → Database: SELECT * FROM scan_tasks WHERE status='pending'
   AgentCenter → Agent: 通过 gRPC 下发 Task

3. Agent 接收任务并转发到 Baseline Plugin
   Agent → Baseline Plugin: 通过 Pipe 发送 Task

4. Baseline Plugin 执行基线检查
   Baseline Plugin → 本地系统: 执行检查（读取文件、执行命令等）

5. Baseline Plugin 上报检测结果
   Baseline Plugin → Agent: 通过 Pipe 发送 Record
   Agent → AgentCenter: 通过 gRPC 发送 PackagedData
   AgentCenter → Database: INSERT INTO scan_results

6. UI 查询检测结果
   UI → Manager: GET /api/v1/results?host_id=xxx
   Manager → Database: SELECT * FROM scan_results
   Manager → UI: 返回 JSON 数据
```

---

### 4.2 心跳上报流程

```
1. Agent 心跳模块定期上报
   Agent → AgentCenter: 通过 gRPC 发送心跳（DataType=1000）

2. AgentCenter 更新主机状态
   AgentCenter → Database: UPDATE hosts SET last_heartbeat=now(), status='online'

3. UI 查询主机列表
   UI → Manager: GET /api/v1/hosts
   Manager → Database: SELECT * FROM hosts
   Manager → UI: 返回主机列表（包含在线状态）
```

---

## 5. 部署架构

### 5.1 单机部署（开发环境）

```
┌─────────────────────────────────────┐
│         Docker Compose              │
│  ┌──────────┐  ┌──────────┐        │
│  │AgentCenter│  │ Manager │        │
│  │  :6751   │  │  :8080   │        │
│  └──────────┘  └──────────┘        │
│         │            │              │
│         └─────┬──────┘              │
│               │                     │
│         ┌─────▼─────┐              │
│         │  MySQL    │              │
│         │  :3306    │              │
│         └───────────┘              │
└─────────────────────────────────────┘
```

---

### 5.2 分布式部署（生产环境）

```
┌─────────────────────────────────────────┐
│         Load Balancer                    │
│         (Nginx / HAProxy)                │
└─────────────────────────────────────────┘
         │                    │
    ┌────▼────┐          ┌────▼────┐
    │Manager 1│          │Manager 2│
    │  :8080  │          │  :8080  │
    └─────────┘          └─────────┘
         │                    │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │   AgentCenter        │
         │   (多实例)            │
         │   :6751              │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │   MySQL Cluster     │
         │   (主从复制)         │
         └─────────────────────┘
```

---

## 6. 总结

### 6.1 核心模块

1. **AgentCenter**：与 Agent 通信的核心服务（gRPC）
2. **Manager**：提供管理 API 的服务（HTTP）
3. **Agent**：部署在主机上的客户端
4. **Plugins**：插件（Baseline、Collector）

### 6.2 关键关系

- **Agent ↔ AgentCenter**：gRPC 双向流 + mTLS
- **UI ↔ Manager**：HTTP REST API + JWT
- **Manager ↔ AgentCenter**：共享数据库
- **Agent ↔ Plugins**：Pipe + Protobuf

### 6.3 设计特点

- **轻量**：只做基线检查，不做全家桶 HIDS
- **可扩展**：插件机制，易于扩展新功能
- **可维护**：模块化设计，职责清晰
- **参考 Elkeid**：借鉴其架构设计，但不直接复制代码

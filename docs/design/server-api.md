# Server API 设计

> 本文档定义 Matrix Cloud Security Platform 的 Server API，**参考 Elkeid 的设计**，使用 gRPC + mTLS。

---

## 1. 架构概览

### 1.1 组件划分

- **AgentCenter**：
  - 与 Agent 的 gRPC 双向流通信
  - 接收 Agent 数据（心跳、检测结果、资产数据）
  - 下发任务和配置到 Agent
  - 管理 Agent 连接状态

- **ServiceDiscovery**：
  - 服务注册与发现
  - Agent 通过 ServiceDiscovery 获取 AgentCenter 地址

- **Manager**：
  - 管理 API（策略管理、任务管理、结果查询等）
  - 提供 HTTP/gRPC API 供前端调用

- **数据库**：
  - MySQL/PostgreSQL 存储配置和结果

---

## 2. gRPC API

### 2.1 Transfer 服务（Agent ↔ Server）

**定义**：

```protobuf
service Transfer {
  rpc Transfer(stream PackagedData) returns (stream Command) {}
}

message PackagedData {
  repeated EncodedRecord records = 1;
  string agent_id = 2;
  repeated string intranet_ipv4 = 3;
  repeated string extranet_ipv4 = 4;
  repeated string intranet_ipv6 = 5;
  repeated string extranet_ipv6 = 6;
  string hostname = 7;
  string version = 8;
  string product = 9;
}

message EncodedRecord {
  int32 data_type = 1;
  int64 timestamp = 2;
  bytes data = 3;
}

message Command {
  repeated Task tasks = 2;
  repeated Config configs = 3;
}

message Task {
  int32 data_type = 1;
  string object_name = 2;  // 插件名称
  string data = 3;         // JSON 字符串
  string token = 4;
}

message Config {
  string name = 1;
  string type = 2;
  string version = 3;
  string sha256 = 4;
  string signature = 5;
  repeated string download_urls = 6;
  string detail = 7;
}
```

**数据流**：

1. **Agent → Server**：
   - 心跳数据（DataType=1000）
   - 插件状态（DataType=1001）
   - 基线检查结果（DataType=8000）
   - 资产数据（DataType=5050-5064）

2. **Server → Agent**：
   - 任务下发（Task）
   - 插件配置更新（Config）

### 2.2 数据处理

**AgentCenter 接收数据后**：

1. **解析 EncodedRecord**：
   - 根据 `data_type` 路由到不同的处理器
   - 解析 `data` 字段（Protobuf/JSON）

2. **存储数据**：
   - 心跳数据：更新 `hosts` 表
   - 检测结果：插入 `scan_results` 表
   - 资产数据：插入对应的资产表（`processes`、`ports`、`users` 等）

3. **下发任务**：
   - 查询 `scan_tasks` 表，获取待执行任务
   - 封装为 `Task` 并发送到 Agent

---

## 3. HTTP API（Manager）

### 3.1 主机管理

#### 获取主机列表

```http
GET /api/v1/hosts
```

**查询参数**：
- `page`：页码（默认 1）
- `page_size`：每页数量（默认 20）
- `os_family`：OS 系列过滤
- `status`：状态过滤（online/offline）

**响应**：

```json
{
  "code": 0,
  "data": {
    "total": 100,
    "items": [
      {
        "host_id": "host-uuid",
        "hostname": "hostname",
        "os_family": "rocky",
        "os_version": "9.3",
        "kernel_version": "5.14.0",
        "arch": "x86_64",
        "ipv4": ["192.168.1.100"],
        "status": "online",
        "last_heartbeat": "2025-12-09T12:00:00+08:00",
        "baseline_score": 85,
        "baseline_pass_rate": 0.85
      }
    ]
  }
}
```

#### 获取主机详情

```http
GET /api/v1/hosts/{host_id}
```

**响应**：

```json
{
  "code": 0,
  "data": {
    "host_id": "host-uuid",
    "hostname": "hostname",
    "os_family": "rocky",
    "os_version": "9.3",
    "kernel_version": "5.14.0",
    "arch": "x86_64",
    "ipv4": ["192.168.1.100"],
    "status": "online",
    "last_heartbeat": "2025-12-09T12:00:00+08:00",
    "baseline_score": 85,
    "baseline_pass_rate": 0.85,
    "baseline_results": [
      {
        "rule_id": "LINUX_SSH_001",
        "status": "fail",
        "severity": "high",
        "title": "禁止 root 远程登录",
        "checked_at": "2025-12-09T12:00:00+08:00"
      }
    ]
  }
}
```

### 3.2 策略管理

#### 获取策略列表

```http
GET /api/v1/policies
```

**查询参数**：
- `os_family`：OS 系列过滤
- `enabled`：是否启用

**响应**：

```json
{
  "code": 0,
  "data": {
    "items": [
      {
        "id": "LINUX_ROCKY9_BASELINE",
        "name": "Rocky Linux 9 基线策略",
        "version": "1.0.0",
        "os_family": ["rocky", "centos"],
        "os_version": ">=9",
        "enabled": true,
        "rule_count": 50,
        "created_at": "2025-12-09T10:00:00+08:00",
        "updated_at": "2025-12-09T10:00:00+08:00"
      }
    ]
  }
}
```

#### 创建策略

```http
POST /api/v1/policies
```

**请求体**：

```json
{
  "id": "LINUX_ROCKY9_BASELINE",
  "name": "Rocky Linux 9 基线策略",
  "version": "1.0.0",
  "os_family": ["rocky", "centos"],
  "os_version": ">=9",
  "enabled": true,
  "rules": [
    {
      "rule_id": "LINUX_SSH_001",
      "category": "ssh",
      "title": "禁止 root 远程登录",
      "description": "sshd_config 中应设置 PermitRootLogin no",
      "severity": "high",
      "check": {
        "condition": "all",
        "rules": [
          {
            "type": "file_kv",
            "param": ["/etc/ssh/sshd_config", "PermitRootLogin", "no"]
          }
        ]
      },
      "fix": {
        "suggestion": "修改 /etc/ssh/sshd_config 中的 PermitRootLogin 并重启 sshd"
      }
    }
  ]
}
```

#### 更新策略

```http
PUT /api/v1/policies/{policy_id}
```

#### 删除策略

```http
DELETE /api/v1/policies/{policy_id}
```

#### 获取策略统计信息

```http
GET /api/v1/policies/{policy_id}/statistics
```

**响应**：

```json
{
  "code": 0,
  "data": {
    "policy_id": "LINUX_ROCKY9_BASELINE",
    "pass_rate": 37.5,
    "host_count": 10,
    "host_pass_count": 0,
    "rule_count": 16,
    "risk_rule_count": 10,
    "last_check_time": "2025-12-09T15:11:20+08:00",
    "rule_pass_rates": {
      "LINUX_SSH_001": 0.0,
      "LINUX_SSH_002": 50.0
    }
  }
}
```

### 3.3 认证管理

#### 用户登录

```http
POST /api/v1/auth/login
```

**请求体**：

```json
{
  "username": "admin",
  "password": "admin123"
}
```

**响应**：

```json
{
  "code": 0,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "username": "admin",
      "role": "admin"
    }
  }
}
```

#### 用户登出

```http
POST /api/v1/auth/logout
```

#### 获取当前用户信息

```http
GET /api/v1/auth/me
```

**请求头**：

```
Authorization: Bearer <token>
```

**响应**：

```json
{
  "code": 0,
  "data": {
    "username": "admin",
    "role": "admin"
  }
}
```

### 3.4 Dashboard 统计

#### 获取 Dashboard 统计数据

```http
GET /api/v1/dashboard/stats
```

**请求头**：

```
Authorization: Bearer <token>
```

**响应**：

```json
{
  "code": 0,
  "data": {
    "hosts": 2,
    "clusters": 0,
    "containers": 0,
    "onlineAgents": 2,
    "offlineAgents": 0,
    "pendingAlerts": 0,
    "pendingVulnerabilities": 0,
    "vulnDbUpdateTime": "",
    "baselineFailCount": 5,
    "baselineHardeningPercent": 50.0
  }
}
```

### 3.5 扫描任务管理

#### 创建扫描任务

```http
POST /api/v1/tasks
```

**请求体**：

```json
{
  "name": "全量扫描任务",
  "type": "baseline_scan",
  "targets": {
    "type": "all",  // all / host_ids / os_family
    "host_ids": [],
    "os_family": []
  },
  "policy_id": "LINUX_ROCKY9_BASELINE",
  "rule_ids": [],  // 空表示扫描所有规则
  "schedule": {
    "type": "once",  // once / cron
    "cron": ""
  }
}
```

#### 获取任务列表

```http
GET /api/v1/tasks
```

#### 执行任务

```http
POST /api/v1/tasks/{task_id}/run
```

### 3.4 检测结果查询

#### 获取检测结果

```http
GET /api/v1/results
```

**查询参数**：
- `host_id`：主机 ID
- `policy_id`：策略 ID
- `rule_id`：规则 ID
- `status`：状态（pass/fail/error）
- `severity`：严重级别
- `start_time`：开始时间
- `end_time`：结束时间

**响应**：

```json
{
  "code": 0,
  "data": {
    "total": 1000,
    "items": [
      {
        "result_id": "result-uuid",
        "host_id": "host-uuid",
        "hostname": "hostname",
        "policy_id": "LINUX_ROCKY9_BASELINE",
        "rule_id": "LINUX_SSH_001",
        "status": "fail",
        "severity": "high",
        "category": "ssh",
        "title": "禁止 root 远程登录",
        "actual": "PermitRootLogin yes",
        "expected": "PermitRootLogin no",
        "fix_suggestion": "修改 /etc/ssh/sshd_config 中的 PermitRootLogin 并重启 sshd",
        "checked_at": "2025-12-09T12:00:00+08:00"
      }
    ]
  }
}
```

### 3.5 资产查询

#### 获取进程列表

```http
GET /api/v1/assets/processes?host_id={host_id}
```

#### 获取端口列表

```http
GET /api/v1/assets/ports?host_id={host_id}
```

#### 获取账户列表

```http
GET /api/v1/assets/users?host_id={host_id}
```

#### 获取软件包列表

```http
GET /api/v1/assets/software?host_id={host_id}
```

---

## 4. 数据库模型

### 4.1 hosts 表

```sql
CREATE TABLE hosts (
  host_id VARCHAR(64) PRIMARY KEY,
  hostname VARCHAR(255),
  os_family VARCHAR(50),
  os_version VARCHAR(50),
  kernel_version VARCHAR(100),
  arch VARCHAR(20),
  ipv4 JSON,
  ipv6 JSON,
  status VARCHAR(20),  -- online/offline
  last_heartbeat TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 4.2 policies 表

```sql
CREATE TABLE policies (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(255),
  version VARCHAR(50),
  os_family JSON,
  os_version VARCHAR(50),
  enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 4.3 rules 表

```sql
CREATE TABLE rules (
  rule_id VARCHAR(64) PRIMARY KEY,
  policy_id VARCHAR(64),
  category VARCHAR(50),
  title VARCHAR(255),
  description TEXT,
  severity VARCHAR(20),
  check_config JSON,
  fix_config JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (policy_id) REFERENCES policies(id)
);
```

### 4.4 scan_results 表

```sql
CREATE TABLE scan_results (
  result_id VARCHAR(64) PRIMARY KEY,
  host_id VARCHAR(64),
  policy_id VARCHAR(64),
  rule_id VARCHAR(64),
  status VARCHAR(20),  -- pass/fail/error/na
  severity VARCHAR(20),
  category VARCHAR(50),
  title VARCHAR(255),
  actual TEXT,
  expected TEXT,
  fix_suggestion TEXT,
  checked_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (host_id) REFERENCES hosts(host_id),
  FOREIGN KEY (rule_id) REFERENCES rules(rule_id)
);
```

### 4.5 scan_tasks 表

```sql
CREATE TABLE scan_tasks (
  task_id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(255),
  type VARCHAR(50),  -- baseline_scan
  target_type VARCHAR(20),  -- all/host_ids/os_family
  target_config JSON,
  policy_id VARCHAR(64),
  rule_ids JSON,
  status VARCHAR(20),  -- pending/running/completed/failed
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 4.6 资产表

```sql
-- 进程表
CREATE TABLE processes (
  id VARCHAR(64) PRIMARY KEY,
  host_id VARCHAR(64),
  pid VARCHAR(20),
  cmdline TEXT,
  exe VARCHAR(512),
  exe_hash VARCHAR(64),
  container_id VARCHAR(64),
  collected_at TIMESTAMP,
  FOREIGN KEY (host_id) REFERENCES hosts(host_id)
);

-- 端口表
CREATE TABLE ports (
  id VARCHAR(64) PRIMARY KEY,
  host_id VARCHAR(64),
  protocol VARCHAR(10),
  port INT,
  pid VARCHAR(20),
  process_name VARCHAR(255),
  container_id VARCHAR(64),
  collected_at TIMESTAMP,
  FOREIGN KEY (host_id) REFERENCES hosts(host_id)
);

-- 账户表
CREATE TABLE users (
  id VARCHAR(64) PRIMARY KEY,
  host_id VARCHAR(64),
  username VARCHAR(100),
  uid VARCHAR(20),
  gid VARCHAR(20),
  home VARCHAR(255),
  shell VARCHAR(255),
  weak_password BOOLEAN,
  collected_at TIMESTAMP,
  FOREIGN KEY (host_id) REFERENCES hosts(host_id)
);

-- 软件包表
CREATE TABLE software (
  id VARCHAR(64) PRIMARY KEY,
  host_id VARCHAR(64),
  name VARCHAR(255),
  version VARCHAR(100),
  type VARCHAR(50),  -- rpm/deb/pip/jar
  collected_at TIMESTAMP,
  FOREIGN KEY (host_id) REFERENCES hosts(host_id)
);
```

---

## 5. 实现建议

### 5.1 AgentCenter

- 使用 gRPC Server 实现 `Transfer` 服务
- 使用 mTLS 双向认证
- 维护 Agent 连接状态（Map[agent_id]*Connection）
- 异步处理数据（使用 channel 或消息队列）

### 5.2 Manager

- 使用 Gin/Fiber 实现 HTTP API
- 使用 Gorm 操作数据库
- 实现分页、过滤、排序等功能
- 实现权限控制（可选）

### 5.3 数据存储

- 使用 MySQL/PostgreSQL 存储配置和结果
- 考虑使用 Redis 缓存热点数据
- 考虑使用消息队列（Kafka/RabbitMQ）处理大量数据（可选）

---

## 6. 参考实现

- Elkeid AgentCenter：`Elkeid/server/agent_center/`
- Elkeid Manager：`Elkeid/server/manager/`
- Elkeid ServiceDiscovery：`Elkeid/server/service_discovery/`


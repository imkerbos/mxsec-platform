# Elkeid 架构分析文档

> 本文档基于 Elkeid 开源代码分析，旨在理解其架构设计，为 Matrix Cloud Security Platform 项目提供参考。  
> **注意**：本文档仅借鉴设计思想，不直接复制代码实现。

---

## 1. 整体架构概览

### 1.1 组件关系

Elkeid 采用 **Agent + 插件 + Server** 的架构模式：

```
┌─────────────────────────────────────────────────────────┐
│                    Elkeid Server                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ AgentCenter  │  │ServiceDiscov│  │   Manager    │ │
│  │  (gRPC)      │  │  (注册发现)   │  │  (管理API)   │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
                        ↕ (双向 gRPC + mTLS)
┌─────────────────────────────────────────────────────────┐
│              Elkeid Agent (主进程)                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ Heartbeat│  │ Plugin   │  │ Transport│             │
│  │ (心跳)   │  │ Manager  │  │ (通信)   │             │
│  └──────────┘  └──────────┘  └──────────┘             │
└─────────────────────────────────────────────────────────┘
                        ↕ (Pipe + Protobuf)
┌─────────────────────────────────────────────────────────┐
│              插件进程 (子进程)                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │Baseline  │  │Collector │  │  Driver  │             │
│  │(基线检查) │  │(资产采集) │  │(内核数据)│             │
│  └──────────┘  └──────────┘  └──────────┘             │
└─────────────────────────────────────────────────────────┘
```

### 1.2 核心设计理念

1. **Agent 作为插件基座**：Agent 本身不提供安全能力，只负责：
   - 插件生命周期管理（启动、停止、升级）
   - 与 Server 的双向通信
   - 资源监控与健康检查

2. **插件化架构**：各安全能力以独立插件形式存在：
   - Baseline Plugin：基线检查
   - Collector Plugin：资产采集
   - Driver Plugin：内核数据采集
   - Scanner Plugin：恶意文件扫描
   - RASP Plugin：运行时应用安全

3. **双向流式通信**：Agent 与 Server 通过 gRPC 双向流通信：
   - Agent → Server：数据流（心跳、检测结果等）
   - Server → Agent：控制流（任务下发、配置更新、插件升级）

---

## 2. Agent 核心机制

### 2.1 Agent 主流程

**入口**：`agent/main.go`

```go
// 核心启动流程
func main() {
    // 1. 初始化日志（Zap，结构化日志）
    // 2. 启动三个核心 goroutine：
    wg.Add(3)
    go heartbeat.Startup(ctx, wg)  // 心跳上报
    go plugin.Startup(ctx, wg)      // 插件管理
    go transport.Startup(ctx, wg)   // 数据传输
    wg.Wait()
}
```

**关键模块**：

1. **Heartbeat（心跳）**：
   - 每分钟上报 Agent 状态（CPU、内存、网络、插件状态）
   - 上报主机信息（OS、内核、IP、主机名等）
   - DataType: 1000 (Agent 状态), 1001 (插件状态)

2. **Plugin Manager（插件管理）**：
   - 监听 Server 下发的插件配置（`proto.Config`）
   - 动态加载/卸载/升级插件
   - 管理插件进程生命周期

3. **Transport（传输层）**：
   - 建立与 AgentCenter 的 gRPC 双向流连接
   - 使用 mTLS 双向认证
   - 支持压缩（snappy）
   - 数据打包与发送、任务接收与分发

### 2.2 插件机制详解

#### 2.2.1 插件加载流程

**位置**：`agent/plugin/plugin_linux.go::Load()`

```go
func Load(ctx context.Context, config proto.Config) (*Plugin, error) {
    // 1. 验证插件名称和签名
    // 2. 下载插件（如果本地不存在或签名不匹配）
    // 3. 创建 Pipe（rx_r, rx_w, tx_r, tx_w）
    // 4. 启动插件进程（exec.Command）
    // 5. 启动三个 goroutine：
    //    - 等待进程退出
    //    - 接收插件数据（从 rx_r 读取）
    //    - 发送任务到插件（写入 tx_w）
}
```

**关键点**：

- **父子进程通信**：使用 `os.Pipe()` 创建两个管道
  - `rx`：Agent 从插件接收数据（Agent 读，插件写）
  - `tx`：Agent 向插件发送任务（Agent 写，插件读）
- **进程组管理**：使用 `Setpgid: true`，便于统一管理插件进程
- **工作目录隔离**：每个插件有独立的工作目录（`/var/lib/elkeid-agent/plugin/{name}/`）

#### 2.2.2 插件数据格式

**位置**：`agent/plugin/plugin.go::ReceiveData()`

插件发送的数据格式（二进制）：
```
[4字节长度][1字节分隔符][DataType(varint)][1字节分隔符][Timestamp(varint)][1字节分隔符][Data(bytes)]
```

**特点**：
- Agent 接收后**不解析**插件数据内容
- 只添加外层 Header（Agent ID、IP、主机名等）
- 直接透传到 Server，减少编解码开销

#### 2.2.3 插件任务下发

**位置**：`agent/plugin/plugin.go::SendTask()`

任务格式（protobuf）：
```protobuf
message Task {
  int32 data_type = 1;
  string object_name = 2;
  string data = 3;      // JSON 字符串
  string token = 4;
}
```

**流程**：
1. Server 通过 gRPC 下发 `Command`（包含 `Task` 和 `Config`）
2. Agent 的 `transport` 模块接收并解析
3. 根据 `Task.object_name` 路由到对应插件
4. 插件通过 `pluginClient.ReceiveTask()` 接收任务

---

## 3. Baseline 插件实现

### 3.1 插件入口

**位置**：`plugins/baseline/main.go`

```go
func main() {
    // 1. 初始化插件客户端（plugins.Client）
    // 2. 启动任务接收 goroutine（从 Agent 接收任务）
    // 3. 启动定时任务 goroutine（每日自动扫描）
}
```

**插件库**：`plugins/lib` 提供了 Go/Rust 的插件 SDK，封装了：
- 与 Agent 的 Pipe 通信
- Protobuf 编解码
- 任务接收与数据发送

### 3.2 策略模型

**配置文件格式**：YAML（如 `config/linux/1200.yaml`）

```yaml
baseline_id: 1200
baseline_version: "1.0"
baseline_name: "字节跳动最佳实践-centos基线检查"
system: ["centos"]
check_list:
  - check_id: 1
    type: "Identification"
    title: "Ensure password expiration is 180 days or less"
    security: "high"
    check:
      condition: "all"  # all/any/none
      rules:
        - type: "file_line_check"
          param: ["/etc/login.defs"]
          filter: '\s*\t*PASS_MAX_DAYS\s*\t*(\d+)'
          result: '$(<=)90'
```

**关键字段**：

- `baseline_id`：策略集 ID（按 OS 分类，如 1200=CentOS, 1300=Debian）
- `check_id`：规则 ID（唯一标识）
- `check.condition`：规则组合逻辑（all/any/none）
- `check.rules[].type`：检查类型（见下文）
- `check.rules[].result`：期望结果（支持特殊语法）

### 3.3 检查类型（Rule Types）

**位置**：`plugins/baseline/src/check/rules.go`

| 类型 | 说明 | 参数 | 返回值 |
|------|------|------|--------|
| `command_check` | 执行命令 | `[命令, 特殊参数]` | 命令输出（string） |
| `file_line_check` | 逐行匹配文件 | `[文件路径, flag, 注释符]` | true/false |
| `file_permission` | 检查文件权限 | `[文件路径, 最小权限(8进制)]` | true/false |
| `file_user_group` | 检查文件属主 | `[文件路径, uid:gid]` | true/false |
| `file_md5_check` | 检查文件 MD5 | `[文件路径, MD5值]` | true/false |
| `if_file_exist` | 检查文件是否存在 | `[文件路径]` | true/false |
| `func_check` | 特殊规则函数 | `[函数名]` | true/false |

**示例**：`file_line_check` 实现

```go
func FileLineCheck(ruleStruct RuleStruct, resultMatch ResultMatchFunc) (bool, error) {
    // 1. 检查前置条件（require）
    // 2. 打开文件，逐行扫描
    // 3. 跳过注释行
    // 4. 如果指定 flag，只匹配包含 flag 的行
    // 5. 使用正则匹配（filter）提取值
    // 6. 调用 resultMatch 判断是否符合期望（result）
}
```

### 3.4 结果匹配引擎

**位置**：`plugins/baseline/src/check/rule_engine.go`

**特殊语法**（`result` 字段）：

- `$(<=)90`：数值比较（<= 90）
- `$(>=)2`：数值比较（>= 2）
- `$(<)8$(&&)$(not)2`：组合条件（< 8 且 != 2）
- `$(not)error`：字符串取反
- `ok$(&&)success`：字符串 OR（包含 "ok" 或 "success"）

**匹配流程**：

```go
func AnalysisRule(check BaselineCheck) (bool, error) {
    condition := check.Condition  // all/any/none
    for _, rule := range check.Rules {
        ifPass, err := CheckRule(rule)
        // 根据 condition 判断：
        // - all: 所有规则都通过才返回 true
        // - any: 任一规则通过即返回 true
        // - none: 所有规则都不通过才返回 true
    }
}
```

### 3.5 结果上报

**位置**：`plugins/baseline/main.go::SendServer()`

**数据结构**：

```go
type RetBaselineInfo struct {
    BaselineId      int
    BaselineVersion string
    Status          string  // "success" / "error"
    Msg             string
    CheckList       []RetCheckInfo
}

type RetCheckInfo struct {
    CheckId       int
    Security      string  // "high" / "medium" / "low"
    Type          string
    Title         string
    Result        int     // 1=通过, 2=失败, -1=错误
    Msg           string
    // ... 其他字段（描述、解决方案等）
}
```

**上报流程**：

1. 插件将结果序列化为 JSON
2. 封装为 `plugins.Record`（DataType=8000）
3. 通过 `pluginClient.SendRecord()` 发送到 Agent
4. Agent 透传到 Server

---

## 4. Agent-Server 通信协议

### 4.1 gRPC 服务定义

**位置**：`agent/proto/grpc.proto`

```protobuf
service Transfer {
  rpc Transfer(stream PackagedData) returns (stream Command) {}
}

message PackagedData {
  repeated EncodedRecord records = 1;
  string agent_id = 2;
  repeated string intranet_ipv4 = 3;
  // ... 主机信息
}

message Command {
  Task task = 2;
  repeated Config configs = 3;  // 插件配置
}
```

### 4.2 数据传输流程

**位置**：`agent/transport/transfer.go`

**发送端**（Agent → Server）：
1. 从 `buffer` 读取 `EncodedRecord`
2. 打包为 `PackagedData`（包含 Agent ID、IP、主机名等）
3. 通过 gRPC stream 发送
4. 使用 snappy 压缩

**接收端**（Server → Agent）：
1. 接收 `Command` 流
2. 解析 `Task` 并路由到对应插件
3. 解析 `Config` 并触发插件同步

### 4.3 连接管理

**位置**：`agent/transport/connection/`

**特性**：
- **服务发现**：通过 ServiceDiscovery 获取 AgentCenter 地址
- **mTLS**：双向 TLS 认证（使用自签名证书）
- **重连机制**：连接断开后自动重连（最多重试 5 次）
- **多 Region 支持**：支持跨 Region 通信配置

---

## 5. 关键设计点总结

### 5.1 优点

1. **插件化架构**：
   - 各安全能力解耦，独立开发与升级
   - 插件崩溃不影响 Agent 主进程
   - 支持插件热更新

2. **高效数据传输**：
   - 插件数据不二次解析，直接透传
   - 使用压缩减少网络开销
   - 批量打包发送

3. **灵活的规则引擎**：
   - YAML 配置，易于扩展
   - 支持复杂条件组合
   - 规则与检查逻辑分离

### 5.2 可借鉴的设计

1. **策略模型**：
   - 按 OS 分类的策略集（baseline_id）
   - 规则 ID + 检查类型 + 期望值的模型
   - 支持前置条件（require）

2. **检查器抽象**：
   - 统一的检查接口（`CheckRule`）
   - 多种检查类型（文件、命令、权限等）
   - 结果匹配引擎（支持特殊语法）

3. **通信协议**：
   - 双向流式通信（适合实时数据上报）
   - 使用 Protobuf 保证兼容性
   - 任务与配置统一管理

### 5.3 我们的简化方向

1. **不采用插件机制**：
   - 基线检查直接集成到 Agent
   - 减少进程间通信开销
   - 简化部署与维护

2. **简化通信协议**：
   - 使用 HTTP/gRPC（单向或简化双向）
   - 减少 mTLS 复杂度（可选）
   - 简化服务发现（直接配置）

3. **策略模型优化**：
   - 更清晰的 OS 版本匹配规则
   - 支持策略版本管理
   - 更友好的错误提示

---

## 6. 参考代码位置

### Agent 核心
- `agent/main.go`：Agent 主入口
- `agent/plugin/plugin.go`：插件管理核心
- `agent/plugin/plugin_linux.go`：Linux 插件加载实现
- `agent/transport/transfer.go`：数据传输实现
- `agent/heartbeat/heartbeat.go`：心跳上报

### Baseline 插件
- `plugins/baseline/main.go`：插件入口
- `plugins/baseline/src/check/analysis.go`：分析入口
- `plugins/baseline/src/check/rule_engine.go`：规则引擎
- `plugins/baseline/src/check/rules.go`：检查器实现
- `plugins/baseline/config/linux/1200.yaml`：策略配置示例

### 通信协议
- `agent/proto/grpc.proto`：gRPC 协议定义
- `plugins/lib/`：插件 SDK（Go/Rust）

---

## 7. 下一步工作

基于以上分析，我们需要：

1. **设计我们的策略模型**（参考 Elkeid，但更简洁）
2. **设计 Agent 架构**（简化版，不采用插件机制）
3. **设计 Server API**（HTTP/gRPC，简化通信）
4. **实现基线检查引擎**（参考 Elkeid 的检查器设计）

详见 `docs/design/` 目录下的设计文档。


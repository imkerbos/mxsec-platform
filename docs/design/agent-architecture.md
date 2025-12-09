# Agent 架构设计

> 本文档定义 Matrix Cloud Security Platform 的 Agent 架构，**完全参考 Elkeid 的设计**，采用插件机制、gRPC + mTLS 通信。

---

## 1. 设计原则

### 1.1 完全参考 Elkeid

我们的 Agent 设计**完全参考 Elkeid**，采用相同的架构模式：

1. **插件化架构**：
   - Agent 作为插件基座，不提供具体安全能力
   - 所有能力通过插件实现（Baseline Plugin、Collector Plugin）
   - 插件以子进程形式运行，通过 Pipe 通信

2. **gRPC + mTLS**：
   - 使用 gRPC 双向流与 Server 通信
   - 使用 mTLS 双向认证（自签名证书）
   - 支持服务发现机制

3. **资产采集**：
   - 实现 Collector Plugin，采集各类主机资产
   - 支持进程、端口、账户、软件包、容器、应用等信息采集

### 1.2 与 Elkeid 的差异

1. **策略模型优化**：
   - 使用字符串 ID（policy_id + rule_id）而非数字 ID
   - 支持 `os_family + os_version` 灵活匹配
   - 策略存储在数据库，便于动态管理

2. **新系统版本支持**：
   - 优先支持 Rocky Linux 9、Debian 12 等新版本
   - 优化 OS 检测逻辑

---

## 2. Agent 架构

### 2.1 模块划分

```
┌─────────────────────────────────────────┐
│         Agent Main Process              │
│  ┌──────────┐  ┌──────────┐            │
│  │ Config  │  │  Logger  │            │
│  └──────────┘  └──────────┘            │
│  ┌──────────┐  ┌──────────┐            │
│  │Heartbeat │  │ Transport│            │
│  │(心跳)    │  │ (gRPC)   │            │
│  └──────────┘  └──────────┘            │
│  ┌──────────┐  ┌──────────┐            │
│  │ Plugin   │  │Connection│            │
│  │ Manager  │  │ (mTLS)   │            │
│  └──────────┘  └──────────┘            │
└─────────────────────────────────────────┘
        ↕ (Pipe + Protobuf)
┌─────────────────────────────────────────┐
│         Plugin Processes                 │
│  ┌──────────┐  ┌──────────┐            │
│  │Baseline  │  │Collector │            │
│  │ Plugin   │  │ Plugin   │            │
│  └──────────┘  └──────────┘            │
└─────────────────────────────────────────┘
```

### 2.2 核心模块

1. **Config（配置）**：
   - 加载配置文件（YAML）
   - 管理 Agent 配置（Server 地址、心跳间隔等）

2. **Logger（日志）**：
   - 结构化日志（Zap，JSON 输出）
   - 日志轮转（lumberjack）

3. **Heartbeat（心跳）**：
   - 定期上报 Agent 状态
   - 上报主机基本信息（OS、内核、IP、主机名等）
   - 上报 Agent 资源使用（CPU、内存、网络等）
   - 上报插件状态

4. **Transport（传输）**：
   - 与 Server 的 gRPC 双向流通信
   - 发送心跳、上报检测结果和资产数据
   - 接收任务、接收策略更新、接收插件配置

5. **Plugin Manager（插件管理）**：
   - 插件生命周期管理（启动、停止、重启、升级）
   - 插件配置同步（从 Server 接收配置）
   - Pipe 通信管理（接收插件数据、发送任务到插件）
   - 插件签名验证与下载

6. **Connection（连接管理）**：
   - 服务发现（通过 ServiceDiscovery 获取 Server 地址）
   - mTLS 连接建立与管理
   - 连接重试与故障转移

---

## 3. Agent 主流程

### 3.1 启动流程

```go
func main() {
    // 1. 初始化配置
    cfg := config.Load("agent.yaml")
    
    // 2. 初始化日志
    logger := log.Init(cfg.Log)
    defer logger.Sync()
    
    // 3. 初始化 Agent ID（从文件读取或生成）
    agentID := agent.InitID()
    
    // 4. 启动核心模块
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    wg := &sync.WaitGroup{}
    wg.Add(4)
    
    // 心跳模块
    go heartbeat.Startup(ctx, wg, cfg, agentID)
    
    // 传输模块
    go transport.Startup(ctx, wg, cfg, agentID)
    
    // 插件管理模块
    go plugin.Startup(ctx, wg, cfg)
    
    // 连接管理模块
    go connection.Startup(ctx, wg, cfg)
    
    // 5. 信号处理
    signalCh := make(chan os.Signal, 1)
    signal.Notify(signalCh, syscall.SIGTERM, syscall.SIGINT)
    <-signalCh
    
    // 6. 优雅退出
    cancel()
    wg.Wait()
}
```

### 3.2 心跳模块

**职责**：
- 定期（默认 1 分钟）上报 Agent 状态
- 上报主机信息（OS、内核、IP、主机名等）
- 上报 Agent 资源使用（CPU、内存、网络等）
- 上报插件状态

**实现**：

```go
func Startup(ctx context.Context, wg *sync.WaitGroup, cfg *config.Config, agentID string) {
    defer wg.Done()
    
    ticker := time.NewTicker(cfg.HeartbeatInterval)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            // 采集 Agent 状态
            stat := collectAgentStat()
            
            // 采集插件状态
            pluginStats := plugin.GetAllPluginStats()
            
            // 上报心跳
            transport.SendHeartbeat(agentID, stat, pluginStats)
        }
    }
}
```

### 3.3 传输模块

**职责**：
- 与 Server 建立 gRPC 双向流连接
- 发送心跳、上报检测结果和资产数据
- 接收任务、接收策略更新、接收插件配置

**实现**：

```go
func Startup(ctx context.Context, wg *sync.WaitGroup, cfg *config.Config, agentID string) {
    defer wg.Done()
    
    for {
        // 获取连接
        conn, err := connection.GetConnection(ctx)
        if err != nil {
            log.Error("get connection failed", zap.Error(err))
            time.Sleep(5 * time.Second)
            continue
        }
        
        // 创建 gRPC 客户端
        client := proto.NewTransferClient(conn)
        stream, err := client.Transfer(ctx, grpc.UseCompressor("snappy"))
        if err != nil {
            log.Error("create stream failed", zap.Error(err))
            continue
        }
        
        // 启动发送和接收 goroutine
        subWg := &sync.WaitGroup{}
        subWg.Add(2)
        
        go sendData(ctx, subWg, stream, agentID)
        go receiveCommands(ctx, subWg, stream)
        
        subWg.Wait()
    }
}

func sendData(ctx context.Context, wg *sync.WaitGroup, stream proto.Transfer_TransferClient, agentID string) {
    defer wg.Done()
    
    ticker := time.NewTicker(100 * time.Millisecond)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            // 从 buffer 读取数据
            records := buffer.ReadRecords()
            if len(records) == 0 {
                continue
            }
            
            // 打包数据
            data := &proto.PackagedData{
                Records: records,
                AgentId: agentID,
                // ... 主机信息
            }
            
            // 发送
            if err := stream.Send(data); err != nil {
                log.Error("send data failed", zap.Error(err))
                return
            }
        }
    }
}

func receiveCommands(ctx context.Context, wg *sync.WaitGroup, stream proto.Transfer_TransferClient) {
    defer wg.Done()
    
    for {
        cmd, err := stream.Recv()
        if err != nil {
            log.Error("receive command failed", zap.Error(err))
            return
        }
        
        // 处理任务
        for _, task := range cmd.Tasks {
            plugin.SendTask(task.ObjectName, task)
        }
        
        // 处理插件配置
        if len(cmd.Configs) > 0 {
            plugin.Sync(cmd.Configs)
        }
    }
}
```

### 3.4 插件管理模块

**职责**：
- 监听 Server 下发的插件配置
- 动态加载/卸载/升级插件
- 管理插件进程生命周期
- 通过 Pipe 与插件通信

**实现**：

```go
func Startup(ctx context.Context, wg *sync.WaitGroup, cfg *config.Config) {
    defer wg.Done()
    
    ticker := time.NewTicker(time.Minute)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            // 关闭所有插件
            plugin.ShutdownAll()
            return
        case configs := <-syncCh:
            // 同步插件配置
            syncPlugins(ctx, configs)
        }
    }
}

func Load(ctx context.Context, config proto.Config) (*Plugin, error) {
    // 1. 验证插件名称和签名
    // 2. 下载插件（如果本地不存在或签名不匹配）
    // 3. 创建 Pipe（rx_r, rx_w, tx_r, tx_w）
    // 4. 启动插件进程（exec.Command）
    // 5. 启动三个 goroutine：
    //    - 等待进程退出
    //    - 接收插件数据（从 rx_r 读取）
    //    - 发送任务到插件（写入 tx_w）
    
    cmd := exec.Command(execPath)
    rx_r, rx_w, _ := os.Pipe()
    tx_r, tx_w, _ := os.Pipe()
    
    cmd.ExtraFiles = []*os.File{tx_r, rx_w}
    cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
    
    err := cmd.Start()
    tx_r.Close()
    rx_w.Close()
    
    plg := &Plugin{
        Config: config,
        cmd:    cmd,
        rx:     rx_r,
        tx:     tx_w,
        // ...
    }
    
    // 启动 goroutine
    go waitProcess(plg)
    go receiveData(plg)
    go sendTask(plg)
    
    return plg, nil
}
```

---

## 4. 插件架构

### 4.1 Baseline Plugin

**职责**：
- 加载基线策略（从 Server 下发或本地文件）
- 执行基线检查
- 上报检测结果

**实现**：

```go
func main() {
    // 初始化插件客户端
    client := plugins.New()
    
    // 启动任务接收 goroutine
    go func() {
        for {
            task, err := client.ReceiveTask()
            if err != nil {
                break
            }
            
            // 执行基线检查
            results := executeBaselineCheck(task)
            
            // 上报结果
            for _, result := range results {
                record := &plugins.Record{
                    DataType:  BaselineDataType,
                    Timestamp: time.Now().Unix(),
                    Data: &plugins.Payload{
                        Fields: map[string]string{
                            "data": result.ToJSON(),
                        },
                    },
                }
                client.SendRecord(record)
            }
        }
    }()
    
    // 启动定时扫描
    // ...
}
```

### 4.2 Collector Plugin

**职责**：
- 周期性采集主机资产信息
- 上报资产数据

**实现**：

```go
func main() {
    client := plugins.New()
    engine := collector.NewEngine(client)
    
    // 注册各类采集器
    engine.AddHandler(time.Hour, &ProcessHandler{})
    engine.AddHandler(time.Hour, &PortHandler{})
    engine.AddHandler(time.Hour*6, &UserHandler{})
    engine.AddHandler(time.Hour*6, &SoftwareHandler{})
    engine.AddHandler(time.Hour*6, &ContainerHandler{})
    // ...
    
    engine.Run()
}
```

---

## 5. 通信协议

### 5.1 gRPC 协议定义

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

### 5.2 数据类型（DataType）

- `1000`：Agent 心跳
- `1001`：插件状态
- `8000`：基线检查结果
- `5050`：进程信息
- `5051`：端口信息
- `5052`：账户信息
- `5053`：软件包信息
- `5056`：容器信息
- `5060`：应用信息
- `5061`：硬件信息
- `5062`：内核模块信息
- `5063`：系统服务信息
- `5064`：定时任务信息

### 5.3 mTLS 配置

**Agent 端**：
- CA 证书：验证 Server 证书
- 客户端证书：Server 验证 Agent
- 客户端密钥：客户端私钥

**Server 端**：
- CA 证书：验证 Agent 证书
- 服务端证书：Agent 验证 Server
- 服务端密钥：服务端私钥

---

## 6. 配置文件

### 6.1 agent.yaml

```yaml
# Agent 配置
agent:
  id_file: "/var/lib/mxsec-agent/agent_id"
  work_dir: "/var/lib/mxsec-agent"
  product: "mxsec-agent"
  version: "1.0.0"

# Server 配置
server:
  service_discovery:
    url: "http://service-discovery:8088"
  agent_center:
    private_host: "agent-center:6751"
    public_host: "agent-center:6751"  # 可选

# TLS 配置
tls:
  ca_file: "/etc/mxsec-agent/ca.crt"
  cert_file: "/etc/mxsec-agent/client.crt"
  key_file: "/etc/mxsec-agent/client.key"

# 心跳配置
heartbeat:
  interval: 60s

# 日志配置
log:
  level: "info"
  format: "json"
  file: "/var/log/mxsec-agent/agent.log"
  max_size: 100
  max_backups: 10
  max_age: 7
```

---

## 7. 部署方式

### 7.1 systemd Service

**文件**：`/etc/systemd/system/mxsec-agent.service`

```ini
[Unit]
Description=Matrix Cloud Security Platform Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/mxsec-agent -config /etc/mxsec-agent/agent.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 7.2 打包格式

- **RPM**：用于 RHEL/CentOS/Rocky Linux
- **DEB**：用于 Debian/Ubuntu

---

## 8. 实现优先级

### Phase 1（MVP）
1. ✅ Agent 主流程（配置、日志、信号处理）
2. ✅ 连接管理（服务发现、mTLS）
3. ✅ gRPC 传输（双向流）
4. ✅ 心跳上报
5. ✅ 插件管理（加载、Pipe 通信）
6. ✅ Baseline Plugin（简单检查）

### Phase 2
1. ✅ Collector Plugin（基础资产采集）
2. ✅ 插件升级机制
3. ✅ 任务机制
4. ✅ 策略下发

### Phase 3
1. ⚠️ 完整资产采集（所有类型）
2. ⚠️ 插件热更新
3. ⚠️ 资源监控与上报

---

## 9. 参考实现

- Elkeid Agent：`Elkeid/agent/`
- Elkeid Baseline Plugin：`Elkeid/plugins/baseline/`
- Elkeid Collector Plugin：`Elkeid/plugins/collector/`
- Elkeid Plugin SDK：`Elkeid/plugins/lib/`

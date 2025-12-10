# 基线检查（Baseline Check）工作流程

> 本文档详细说明从创建扫描任务到获取检测结果的完整工作流程。

---

## 1. 流程概览

基线检查的完整流程涉及以下组件：
- **UI（前端）**：用户创建任务
- **Manager（HTTP API）**：接收任务创建请求，写入数据库
- **AgentCenter（gRPC Server）**：任务调度、任务下发
- **Agent（客户端）**：接收任务、转发到插件
- **Baseline Plugin（插件）**：执行基线检查、上报结果
- **数据库**：存储任务和结果

```
┌─────┐      ┌────────┐      ┌──────────┐      ┌──────┐      ┌─────────────┐      ┌──────┐
│ UI  │─────▶│Manager │─────▶│Database │◀─────│Agent │◀────│Baseline     │─────▶│Agent │
│     │      │(HTTP)  │      │         │      │Center│      │Plugin       │      │      │
└─────┘      └────────┘      └──────────┘      └──────┘      └─────────────┘      └──────┘
                                                                                          │
                                                                                          ▼
                                                                                    ┌──────────┐
                                                                                    │Database  │
                                                                                    └──────────┘
```

---

## 2. 详细流程步骤

### 步骤 1：用户在 UI 创建扫描任务

**位置**：`ui/src/views/Tasks/index.vue`

**操作**：
1. 用户在 UI 界面填写任务信息：
   - 任务名称
   - 策略 ID（选择要执行的基线策略）
   - 目标主机（全部主机 / 指定主机 ID 列表 / 按 OS 类型）
   - 规则列表（可选，空表示执行策略中的所有规则）

2. 点击"创建任务"按钮

**API 调用**：
```http
POST /api/v1/tasks
Content-Type: application/json
Authorization: Bearer <token>

{
  "name": "全量基线扫描",
  "type": "baseline_scan",
  "target_type": "all",  // all / host_ids / os_family
  "target_config": {
    "host_ids": ["host-uuid-1", "host-uuid-2"]
  },
  "policy_id": "LINUX_ROCKY9_BASELINE",
  "rule_ids": []  // 空数组表示执行所有规则
}
```

---

### 步骤 2：Manager 接收请求并写入数据库

**位置**：`internal/server/manager/api/tasks.go`

**处理流程**：
1. **验证请求**：
   - 验证 JWT Token
   - 验证请求参数（策略 ID 是否存在、目标配置是否有效）

2. **创建任务记录**：
   ```go
   task := &model.ScanTask{
       TaskID:       uuid.New().String(),
       Name:         req.Name,
       Type:         model.TaskTypeBaselineScan,
       TargetType:   req.TargetType,
       TargetConfig: req.TargetConfig,
       PolicyID:     req.PolicyID,
       RuleIDs:      req.RuleIDs,
       Status:       model.TaskStatusPending,  // 初始状态：pending
   }
   ```

3. **写入数据库**：
   ```sql
   INSERT INTO scan_tasks (
       task_id, name, type, target_type, target_config,
       policy_id, rule_ids, status, created_at
   ) VALUES (...)
   ```

4. **返回响应**：
   ```json
   {
     "code": 0,
     "data": {
       "task_id": "task-uuid",
       "status": "pending"
     }
   }
   ```

---

### 步骤 3：AgentCenter 任务调度器检测待执行任务

**位置**：`internal/server/agentcenter/service/task.go`

**调度机制**：
- AgentCenter 启动一个后台 goroutine（任务调度器）
- **每 30 秒**执行一次任务检查
- 查询数据库中状态为 `pending` 的任务

**查询逻辑**：
```go
// 查询待执行任务
tasks := []model.ScanTask{}
db.Where("status = ?", "pending").
   Where("type = ?", "baseline_scan").
   Find(&tasks)

// 遍历任务，为每个目标主机创建执行任务
for _, task := range tasks {
    // 根据 target_type 确定目标主机列表
    hosts := getTargetHosts(task)
    
    for _, host := range hosts {
        // 检查主机是否在线（通过连接状态管理）
        if isHostOnline(host.HostID) {
            // 创建任务并下发
            dispatchTask(task, host)
        }
    }
}
```

**目标主机确定逻辑**：
- `target_type = "all"`：查询所有在线主机
- `target_type = "host_ids"`：查询指定的主机 ID 列表
- `target_type = "os_family"`：查询匹配 OS 类型的主机

---

### 步骤 4：AgentCenter 封装任务并下发到 Agent

**位置**：`internal/server/agentcenter/transfer/service.go`

**任务封装**：
1. **查询策略和规则**：
   ```go
   // 查询策略
   policy := getPolicy(task.PolicyID)
   
   // 查询规则（如果 rule_ids 为空，查询策略下的所有规则）
   rules := getRules(task.PolicyID, task.RuleIDs)
   
   // 查询主机信息（用于 OS 匹配）
   host := getHost(hostID)
   ```

2. **构建任务数据（JSON）**：
   ```json
   {
     "task_id": "task-uuid",
     "policy_id": "LINUX_ROCKY9_BASELINE",
     "policies": "[{\"id\":\"...\",\"rules\":[...]}]",  // 策略 JSON 字符串
     "os_family": "rocky",
     "os_version": "9.3"
   }
   ```

3. **封装为 Command**：
   ```go
   command := &grpc.Command{
       Tasks: []*grpc.Task{
           {
               DataType:   8000,  // 基线检查任务
               ObjectName: "baseline",  // 插件名称
               Data:       taskDataJSON,
               Token:      task.TaskID,
           },
       },
   }
   ```

4. **通过 gRPC 双向流发送**：
   ```go
   // 获取 Agent 连接
   conn := getConnection(hostID)
   
   // 发送 Command
   conn.stream.Send(command)
   ```

5. **更新任务状态**：
   ```sql
   UPDATE scan_tasks 
   SET status = 'running', executed_at = NOW() 
   WHERE task_id = ?
   ```

---

### 步骤 5：Agent 接收任务并转发到 Baseline Plugin

**位置**：`internal/agent/transport/transport.go`

**接收流程**：
1. **Agent 的 transport 模块**持续监听 gRPC 双向流
2. **接收 Command**：
   ```go
   cmd, err := stream.Recv()
   ```

3. **解析 Command**：
   - 提取 `Tasks` 列表
   - 根据 `Task.ObjectName` 路由到对应插件

4. **转发到 Baseline Plugin**：
   ```go
   // 获取 Baseline Plugin 实例
   plugin := getPlugin("baseline")
   
   // 序列化 Task 为 Protobuf
   taskBytes := serializeTask(task)
   
   // 写入 Pipe（tx 管道）
   plugin.txPipe.Write(taskBytes)
   ```

**Pipe 通信**：
- Agent 创建两个 Pipe：`rx`（接收数据）和 `tx`（发送任务）
- Baseline Plugin 通过文件描述符 3/4 访问 Pipe
- Agent 不解析插件数据，直接透传（性能优化）

---

### 步骤 6：Baseline Plugin 接收任务并执行检查

**位置**：`plugins/baseline/main.go`

**接收任务**：
1. **插件启动任务接收循环**：
   ```go
   go receiveTasks(ctx, client, taskCh, logger)
   ```

2. **从 Pipe 读取任务**：
   ```go
   task, err := client.ReceiveTask()  // 从 tx Pipe 读取
   ```

3. **解析任务数据**：
   ```go
   var taskData map[string]interface{}
   json.Unmarshal([]byte(task.Data), &taskData)
   
   // 提取策略配置
   policiesJSON := taskData["policies"].(string)
   osFamily := taskData["os_family"].(string)
   osVersion := taskData["os_version"].(string)
   ```

**执行检查**：
1. **加载策略**：
   ```go
   var policies []*engine.Policy
   json.Unmarshal([]byte(policiesJSON), &policies)
   ```

2. **OS 匹配**：
   ```go
   // 过滤适用的策略和规则
   applicablePolicies := filterByOS(policies, osFamily, osVersion)
   ```

3. **执行检查引擎**：
   ```go
   results := checkEngine.Execute(ctx, applicablePolicies, osFamily, osVersion)
   ```

**检查执行细节**：
- 遍历策略中的每条规则
- 根据 `check_type` 调用对应的检查器：
  - `file_kv`：读取配置文件，检查键值
  - `file_permission`：检查文件权限
  - `command_exec`：执行命令，检查输出
  - `sysctl`：读取内核参数
  - `service_status`：检查服务状态
  - 等等...
- 生成检查结果（pass/fail/warn/na）

---

### 步骤 7：Baseline Plugin 上报检测结果

**位置**：`plugins/baseline/main.go` - `handleBaselineTask()`

**结果上报**：
1. **遍历检查结果**：
   ```go
   for _, result := range results {
       record := &bridge.Record{
           DataType:  8000,  // 基线检查结果
           Timestamp: time.Now().UnixNano(),
           Data: &bridge.Payload{
               Fields: map[string]string{
                   "rule_id":        result.RuleID,
                   "policy_id":      result.PolicyID,
                   "status":         string(result.Status),  // pass/fail/warn/na
                   "severity":       result.Severity,        // low/medium/high/critical
                   "category":       result.Category,
                   "title":          result.Title,
                   "actual":         result.Actual,         // 实际值
                   "expected":       result.Expected,       // 期望值
                   "fix_suggestion": result.FixSuggestion,
                   "checked_at":     result.CheckedAt.Format(time.RFC3339),
               },
           },
       }
       
       // 发送到 Agent（通过 rx Pipe）
       client.SendRecord(record)
   }
   ```

2. **Agent 接收并透传**：
   - Agent 从 `rx` Pipe 读取数据
   - 不解析内容，直接封装为 `EncodedRecord`
   - 添加到 `PackagedData` 中

3. **Agent 发送到 AgentCenter**：
   ```go
   packagedData := &grpc.PackagedData{
       AgentId:  agentID,
       Records: []*grpc.EncodedRecord{
           {
               DataType:  8000,
               Timestamp: record.Timestamp,
               Data:      serializeRecord(record),  // Protobuf bytes
           },
       },
   }
   
   stream.Send(packagedData)
   ```

---

### 步骤 8：AgentCenter 接收结果并存储到数据库

**位置**：`internal/server/agentcenter/transfer/service.go`

**结果处理**：
1. **接收 PackagedData**：
   ```go
   data, err := stream.Recv()
   ```

2. **解析 EncodedRecord**：
   ```go
   for _, record := range data.Records {
       if record.DataType == 8000 {  // 基线检查结果
           // 解析 Protobuf bytes
           bridgeRecord := parseRecord(record.Data)
           
           // 提取字段
           fields := bridgeRecord.Data.Fields
           ruleID := fields["rule_id"]
           status := fields["status"]
           // ...
       }
   }
   ```

3. **存储到数据库**：
   ```sql
   INSERT INTO scan_results (
       host_id, rule_id, task_id, status, severity,
       actual, expected, fix_suggestion, checked_at
   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
   ```

4. **更新任务状态**（可选）：
   - 如果所有目标主机都已完成检查，更新任务状态为 `completed`

---

### 步骤 9：UI 查询检测结果

**位置**：`ui/src/views/Hosts/Detail.vue` 或 `ui/src/views/Results/index.vue`

**查询方式**：
1. **查询主机基线得分**：
   ```http
   GET /api/v1/results/host/{host_id}/score
   ```

2. **查询检测结果列表**：
   ```http
   GET /api/v1/results?host_id={host_id}&policy_id={policy_id}&status=fail
   ```

3. **查询主机详情**：
   ```http
   GET /api/v1/hosts/{host_id}
   ```

**Manager 处理**：
- 从数据库查询 `scan_results` 表
- 聚合统计（基线得分、通过率等）
- 返回 JSON 数据

**UI 展示**：
- 主机列表页面：显示基线得分
- 主机详情页面：显示检查结果列表
- 策略详情页面：显示影响的主机列表

---

## 3. 数据流图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          基线检查完整流程                                  │
└─────────────────────────────────────────────────────────────────────────┘

1. UI 创建任务
   POST /api/v1/tasks
   └─▶ Manager API
       └─▶ INSERT INTO scan_tasks (status='pending')

2. AgentCenter 任务调度器（每 30 秒）
   SELECT * FROM scan_tasks WHERE status='pending'
   └─▶ 确定目标主机列表
       └─▶ 为每个在线主机创建任务

3. AgentCenter 下发任务
   gRPC Command (DataType=8000, ObjectName="baseline")
   └─▶ Agent transport 模块
       └─▶ 路由到 Baseline Plugin
           └─▶ Pipe (tx) 发送任务

4. Baseline Plugin 执行检查
   接收任务 → 加载策略 → OS 匹配 → 执行检查器 → 生成结果
   └─▶ 遍历规则，调用检查器（file_kv、command_exec 等）

5. Baseline Plugin 上报结果
   Pipe (rx) 发送 Record (DataType=8000)
   └─▶ Agent 透传
       └─▶ gRPC PackagedData
           └─▶ AgentCenter

6. AgentCenter 存储结果
   解析 EncodedRecord → 提取字段
   └─▶ INSERT INTO scan_results

7. UI 查询结果
   GET /api/v1/results?host_id=xxx
   └─▶ Manager API
       └─▶ SELECT * FROM scan_results
           └─▶ 返回 JSON 数据
```

---

## 4. 关键数据结构

### 4.1 任务数据结构

**数据库表（scan_tasks）**：
```go
type ScanTask struct {
    TaskID       string       // 任务 ID
    Name         string       // 任务名称
    Type         TaskType     // "baseline_scan"
    TargetType   TargetType   // "all" / "host_ids" / "os_family"
    TargetConfig TargetConfig // 目标配置（JSON）
    PolicyID     string       // 策略 ID
    RuleIDs      []string     // 规则 ID 列表（空表示所有规则）
    Status       TaskStatus   // "pending" / "running" / "completed" / "failed"
    CreatedAt    time.Time
    ExecutedAt   *time.Time
}
```

**gRPC Task**：
```protobuf
message Task {
  int32 data_type = 1;      // 8000 = 基线检查任务
  string object_name = 2;   // "baseline" = 插件名称
  string data = 3;          // JSON 字符串（任务数据）
  string token = 4;         // 任务 ID
}
```

**任务数据（JSON）**：
```json
{
  "task_id": "task-uuid",
  "policy_id": "LINUX_ROCKY9_BASELINE",
  "policies": "[{\"id\":\"...\",\"rules\":[...]}]",
  "os_family": "rocky",
  "os_version": "9.3"
}
```

### 4.2 结果数据结构

**数据库表（scan_results）**：
```go
type ScanResult struct {
    ID            uint
    HostID       string    // 主机 ID
    RuleID       string    // 规则 ID
    TaskID       string    // 任务 ID
    Status       string    // "pass" / "fail" / "warn" / "na"
    Severity     string    // "low" / "medium" / "high" / "critical"
    Actual       string    // 实际值
    Expected     string    // 期望值
    FixSuggestion string   // 修复建议
    CheckedAt    time.Time // 检查时间
}
```

**bridge.Record**：
```protobuf
message Record {
  int32 data_type = 1;      // 8000 = 基线检查结果
  int64 timestamp = 2;      // Unix 纳秒时间戳
  Payload data = 3;         // 数据负载
}

message Payload {
  map<string, string> fields = 1;  // 键值对
}
```

---

## 5. 时序图

```
用户          UI          Manager       Database      AgentCenter      Agent        Baseline Plugin
 │            │            │              │              │              │                │
 │──创建任务──▶│            │              │              │              │                │
 │            │──POST /api/v1/tasks──▶│              │              │              │                │
 │            │            │──INSERT scan_tasks──▶│              │              │                │
 │            │            │              │              │              │                │
 │            │◀──返回task_id──│              │              │              │                │
 │            │            │              │              │              │                │
 │            │            │              │              │              │                │
 │            │            │              │──任务调度器（30秒）──│              │                │
 │            │            │              │──SELECT pending tasks──│              │                │
 │            │            │              │              │              │                │
 │            │            │              │              │──gRPC Command──▶│                │
 │            │            │              │              │              │──Pipe(tx)──▶│
 │            │            │              │              │              │                │
 │            │            │              │              │              │                │──接收任务
 │            │            │              │              │              │                │──加载策略
 │            │            │              │              │              │                │──执行检查
 │            │            │              │              │              │                │
 │            │            │              │              │              │◀──Pipe(rx)──│──上报结果
 │            │            │              │              │◀──gRPC PackagedData──│                │
 │            │            │              │──INSERT scan_results──│              │                │
 │            │            │              │              │              │                │
 │──查询结果──▶│            │              │              │              │                │
 │            │──GET /api/v1/results──▶│              │              │              │                │
 │            │            │──SELECT scan_results──▶│              │              │                │
 │            │            │              │              │              │                │
 │            │◀──返回结果──│              │              │              │                │
 │            │            │              │              │              │                │
```

---

## 6. 关键配置和参数

### 6.1 任务调度间隔
- **AgentCenter 任务调度器**：每 30 秒检查一次待执行任务
- 配置位置：`internal/server/agentcenter/service/task.go`

### 6.2 任务状态流转
```
pending → running → completed/failed
```

### 6.3 数据类型（data_type）
- `8000`：基线检查任务 / 基线检查结果
- `1000`：心跳数据
- `5050-5064`：资产数据

### 6.4 插件名称（object_name）
- `"baseline"`：Baseline Plugin
- `"collector"`：Collector Plugin

---

## 7. 错误处理

### 7.1 任务创建失败
- Manager API 返回错误响应
- 任务不会写入数据库

### 7.2 Agent 离线
- AgentCenter 任务调度器跳过离线主机
- 任务保持 `pending` 状态，等待主机上线

### 7.3 插件执行失败
- Baseline Plugin 记录错误日志
- 单个规则检查失败不影响其他规则
- 部分结果仍会上报

### 7.4 结果上报失败
- Agent 重试机制
- 如果持续失败，结果可能丢失（后续可增加本地缓存）

---

## 8. 性能优化

### 8.1 Agent 数据透传
- Agent 不解析插件数据内容
- 直接透传到 Server，减少编解码开销

### 8.2 批量结果上报
- Baseline Plugin 可以批量上报多条结果
- Agent 打包多条记录到单个 PackagedData

### 8.3 任务调度优化
- 任务调度器使用 goroutine 并发处理
- 避免阻塞主流程

---

## 9. 总结

基线检查的完整流程包括：

1. **任务创建**：UI → Manager → Database
2. **任务调度**：AgentCenter 定时查询待执行任务
3. **任务下发**：AgentCenter → Agent → Baseline Plugin
4. **执行检查**：Baseline Plugin 加载策略、执行检查器
5. **结果上报**：Baseline Plugin → Agent → AgentCenter → Database
6. **结果查询**：UI → Manager → Database

整个流程采用**异步、事件驱动**的设计：
- 任务创建和执行是异步的
- 通过数据库状态协调各组件
- 支持多主机并发执行
- 支持任务重试和错误恢复

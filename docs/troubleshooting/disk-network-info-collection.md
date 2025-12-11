# 磁盘和网卡信息采集排查指南

## 问题现象

前端页面显示"磁盘信息功能待实现"或"网卡信息未采集"。

## 排查步骤

### 1. 检查数据库字段是否存在

手动检查数据库字段：

```sql
-- 检查字段是否存在
SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'mxsec'
  AND TABLE_NAME = 'hosts'
  AND COLUMN_NAME IN ('disk_info', 'network_interfaces');
```

**如果字段不存在**：
- 重启 AgentCenter 服务，GORM 会自动执行迁移
- 或手动添加字段：
  ```sql
  ALTER TABLE hosts ADD COLUMN disk_info TEXT NULL COMMENT '磁盘信息（JSON格式）';
  ALTER TABLE hosts ADD COLUMN network_interfaces TEXT NULL COMMENT '网卡信息（JSON格式）';
  ```

### 2. 检查 Agent 是否已部署最新版本

**检查 Agent 代码**：
- 确认 Agent 代码中包含 `internal/agent/heartbeat/hostinfo.go`
- 确认心跳采集函数中调用了 `CollectDiskInfo` 和 `CollectNetworkInterfaces`

**检查 Agent 版本**：
```bash
# 查看 Agent 日志，确认版本信息
tail -f /var/log/mxsec-agent/agent.log | grep -E "(version|Version|buildVersion)"
```

### 3. 检查 Agent 心跳是否包含磁盘和网卡信息

**查看 Agent 日志**：
```bash
# 查看 Agent 心跳发送日志
tail -f /var/log/mxsec-agent/agent.log | grep -E "(heartbeat|disk_info|network_interfaces)"
```

**检查心跳数据**：
- 在 Agent 代码中添加日志，确认 `fields` map 中是否包含 `disk_info` 和 `network_interfaces`
- 参考 `internal/agent/heartbeat/heartbeat_example.go` 的实现

### 4. 检查 AgentCenter 是否收到数据

**查看 AgentCenter 日志**：
```bash
# 查看心跳处理日志
docker logs mxsec-agentcenter-dev --tail 100 | grep -E "(收到磁盘信息|收到网卡信息|disk_info|network_interfaces|心跳处理完成)"
```

**日志示例**：
```
收到磁盘信息 agent_id=xxx disk_info_length=xxx
收到网卡信息 agent_id=xxx network_interfaces_length=xxx
心跳处理完成 agent_id=xxx hostname=xxx has_disk_info=true has_network_interfaces=true
```

**如果没有看到相关日志**：
- Agent 可能还没有实现采集功能
- Agent 采集失败但没有上报（函数返回空字符串）

### 5. 检查数据库中的数据

**查询主机数据**：
```sql
SELECT 
    host_id,
    hostname,
    CASE 
        WHEN disk_info IS NULL OR disk_info = '' THEN '未采集'
        ELSE CONCAT('已采集 (', LENGTH(disk_info), ' 字符)')
    END AS disk_info_status,
    CASE 
        WHEN network_interfaces IS NULL OR network_interfaces = '' THEN '未采集'
        ELSE CONCAT('已采集 (', LENGTH(network_interfaces), ' 字符)')
    END AS network_interfaces_status,
    LEFT(disk_info, 200) AS disk_info_preview,
    LEFT(network_interfaces, 200) AS network_interfaces_preview
FROM hosts
WHERE host_id = 'your_host_id';
```

**如果数据为空**：
- 检查 Agent 是否已连接（`last_heartbeat` 是否在5分钟内）
- 检查 Agent 代码是否正确实现了采集逻辑

### 6. 检查 API 是否正确返回数据

**测试 API**：
```bash
curl -X GET "http://localhost:8080/api/v1/hosts/your_host_id" \
  -H "Authorization: Bearer your_token"
```

**检查响应**：
- 确认响应中包含 `disk_info` 和 `network_interfaces` 字段
- 如果字段存在但为空字符串，说明 Agent 没有上报数据

### 7. 检查前端解析逻辑

**浏览器控制台**：
```javascript
// 检查解析后的数据
console.log('parsedDiskInfo:', parsedDiskInfo.value)
console.log('parsedNetworkInterfaces:', parsedNetworkInterfaces.value)
```

**如果解析失败**：
- 检查 JSON 格式是否正确
- 检查控制台是否有错误信息

## 常见问题

### Q1: 数据库字段不存在

**原因**：数据库迁移未执行

**解决方案**：
1. 重启 AgentCenter 服务
2. 或手动执行 SQL 添加字段

### Q2: Agent 未上报数据

**原因**：
- Agent 代码未实现采集功能
- 采集函数返回空字符串（采集失败）

**解决方案**：
1. 确认 Agent 代码中调用了 `CollectDiskInfo` 和 `CollectNetworkInterfaces`
2. 检查 Agent 日志，查看采集失败的原因
3. 参考 `internal/agent/heartbeat/hostinfo.go` 的实现

### Q3: AgentCenter 收到数据但未存储

**原因**：
- 更新逻辑中字段被过滤（空字符串被跳过）

**检查代码**：
- `internal/server/agentcenter/transfer/service.go` 的 `handleHeartbeat` 方法
- 确认 `cleanUpdates` 逻辑正确处理了空字符串

### Q4: 数据存储但前端不显示

**原因**：
- API 未返回字段
- 前端解析失败

**解决方案**：
1. 检查 API 响应是否包含字段
2. 检查前端控制台是否有错误
3. 检查 JSON 格式是否正确

## 调试技巧

### 1. 添加详细日志

**Agent 端**：
```go
logger.Info("采集磁盘信息",
    zap.String("disk_info", diskInfoJSON),
    zap.Int("length", len(diskInfoJSON)))
```

**Server 端**：
```go
s.logger.Info("处理心跳",
    zap.String("agent_id", conn.AgentID),
    zap.String("disk_info", networkInfo["disk_info"]),
    zap.String("network_interfaces", networkInfo["network_interfaces"]))
```

### 2. 使用检查脚本

```bash
# 检查所有主机
# 使用 SQL 查询检查字段（见下方 SQL 示例）

# 检查特定主机
# 使用 SQL 查询检查字段（见下方 SQL 示例） your_host_id
```

### 3. 直接查询数据库

```sql
-- 查看最近心跳的主机
SELECT host_id, hostname, last_heartbeat, 
       LENGTH(disk_info) AS disk_info_len,
       LENGTH(network_interfaces) AS network_interfaces_len
FROM hosts
ORDER BY last_heartbeat DESC
LIMIT 10;

-- 查看具体数据
SELECT disk_info, network_interfaces
FROM hosts
WHERE host_id = 'your_host_id';
```

## 验证清单

- [ ] 数据库字段 `disk_info` 和 `network_interfaces` 存在
- [ ] Agent 代码包含采集函数实现
- [ ] Agent 心跳中调用了采集函数
- [ ] AgentCenter 日志显示收到数据
- [ ] 数据库中有数据（字段不为空）
- [ ] API 返回了 `disk_info` 和 `network_interfaces` 字段
- [ ] 前端能正确解析 JSON 数据
- [ ] 前端表格正常显示数据

## 相关文件

- Agent 采集函数：`internal/agent/heartbeat/hostinfo.go`
- Agent 使用示例：`internal/agent/heartbeat/heartbeat_example.go`
- Server 心跳处理：`internal/server/agentcenter/transfer/service.go`
- 前端展示组件：`ui/src/views/Hosts/components/HostOverview.vue`
- 使用 SQL 查询检查数据库字段（见本文档第1节）

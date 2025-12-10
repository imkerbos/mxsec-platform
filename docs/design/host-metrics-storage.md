# 主机监控数据存储设计

> 针对 300+ 主机端点的监控数据存储最佳实践

---

# 主机监控数据存储设计

> **针对 300+ 主机端点的监控数据存储最佳实践**  
> **设计理念**：通过配置灵活选择存储方式，MySQL（短期）+ Prometheus（长期）双写策略

---

## 1. 数据量估算

### 1.1 数据量计算

**假设条件**：
- 主机数量：300 台
- 心跳间隔：60 秒（默认）
- 每条记录大小：约 200 字节（包含 CPU、内存、磁盘、网络指标）

**数据量**：
- 每分钟：300 条记录
- 每小时：18,000 条记录
- 每天：432,000 条记录（约 86 MB）
- 每月：约 1,300 万条记录（约 2.6 GB）
- 每年：约 1.58 亿条记录（约 31 GB）

### 1.2 查询需求分析

**常见查询场景**：
1. **实时监控**：查看当前资源使用情况（最新数据）
2. **历史趋势**：查看过去 7 天/30 天的资源使用趋势
3. **告警分析**：查询特定时间段内的异常数据
4. **报表统计**：按主机、时间范围聚合统计

---

## 2. 存储方案设计

### 2.1 方案对比

| 方案 | 优点 | 缺点 | 适用场景 |
|------|------|------|---------|
| **MySQL 时间序列表** | 简单、无需额外组件、支持复杂查询 | 数据量大时性能下降、需要定期清理 | 中小规模（< 500 主机） |
| **MySQL + 数据归档** | 平衡性能和功能 | 需要实现归档逻辑 | 中等规模（500-2000 主机） |
| **Prometheus + MySQL** | 专业时间序列、性能好、长期存储 | 需要额外组件 | 大规模（> 2000 主机）或已有 Prometheus |

### 2.2 推荐方案：二选一策略（MySQL 或 Prometheus）

**设计理念**：
- **MySQL（默认）**：默认启用，保留 30 天，用于实时查询和复杂关联查询
- **Prometheus（可选）**：启用后自动禁用 MySQL，用于长期趋势分析和监控告警

**配置方式**：
```yaml
# 默认配置：使用 MySQL
metrics:
  mysql:
    enabled: true          # 默认启用
    retention_days: 30     # 保留 30 天
  prometheus:
    enabled: false         # 禁用 Prometheus

# 启用 Prometheus：自动禁用 MySQL
metrics:
  mysql:
    enabled: false         # 自动禁用（当 Prometheus 启用时）
  prometheus:
    enabled: true          # 启用 Prometheus
    remote_write_url: "http://prometheus:9090/api/v1/write"
```

**优势**：
1. ✅ **简单**：二选一，避免双写复杂度
2. ✅ **轻量**：默认使用 MySQL，无需额外组件
3. ✅ **灵活**：根据基础设施选择存储方式
4. ✅ **符合项目规则**：对接现有 Prometheus 系统（"不作为本项目核心范畴"）

---

## 3. 数据库设计

### 3.1 表结构

```sql
CREATE TABLE host_metrics (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  host_id VARCHAR(64) NOT NULL,
  cpu_usage DECIMAL(5,2) COMMENT 'CPU 使用率（%）',
  mem_usage DECIMAL(5,2) COMMENT '内存使用率（%）',
  disk_usage DECIMAL(5,2) COMMENT '磁盘使用率（%）',
  net_bytes_sent BIGINT COMMENT '网络发送字节数（累计）',
  net_bytes_recv BIGINT COMMENT '网络接收字节数（累计）',
  collected_at TIMESTAMP NOT NULL COMMENT '采集时间',
  
  INDEX idx_host_collected (host_id, collected_at DESC),
  INDEX idx_collected_at (collected_at DESC),
  
  FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='主机监控指标表';

-- 按月分区（可选，MySQL 5.7+）
-- ALTER TABLE host_metrics PARTITION BY RANGE (UNIX_TIMESTAMP(collected_at)) (
--   PARTITION p202501 VALUES LESS THAN (UNIX_TIMESTAMP('2025-02-01')),
--   PARTITION p202502 VALUES LESS THAN (UNIX_TIMESTAMP('2025-03-01')),
--   ...
-- );
```

### 3.2 数据保留策略

**策略**：
- **详细数据**：保留 30 天（用于实时查询和短期趋势）
- **聚合数据**：保留 90 天（按小时聚合，用于长期趋势）
- **归档数据**：超过 90 天的数据可以归档或删除

**实现**：
- 定期任务（每天凌晨执行）：
  1. 清理 30 天前的详细数据
  2. 将 30-90 天的数据按小时聚合
  3. 删除 90 天前的聚合数据

### 3.3 聚合表设计（可选）

```sql
CREATE TABLE host_metrics_hourly (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  host_id VARCHAR(64) NOT NULL,
  cpu_usage_avg DECIMAL(5,2) COMMENT '平均 CPU 使用率',
  cpu_usage_max DECIMAL(5,2) COMMENT '最大 CPU 使用率',
  mem_usage_avg DECIMAL(5,2) COMMENT '平均内存使用率',
  mem_usage_max DECIMAL(5,2) COMMENT '最大内存使用率',
  disk_usage_avg DECIMAL(5,2) COMMENT '平均磁盘使用率',
  net_bytes_sent_total BIGINT COMMENT '总发送字节数',
  net_bytes_recv_total BIGINT COMMENT '总接收字节数',
  hour_start TIMESTAMP NOT NULL COMMENT '小时开始时间',
  
  INDEX idx_host_hour (host_id, hour_start DESC),
  
  FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='主机监控指标聚合表（按小时）';
```

---

## 4. 实现方案

### 4.1 数据写入

**位置**：`internal/server/agentcenter/transfer/service.go`

```go
// handleHeartbeat 处理心跳数据
func (s *Service) handleHeartbeat(ctx context.Context, data *grpcProto.PackagedData, conn *Connection) error {
    // ... 更新 hosts 表的基本信息 ...
    
    // 解析资源监控数据
    if len(data.Records) > 0 {
        for _, record := range data.Records {
            if record.DataType == 1000 { // 心跳数据
                var bridgeRecord bridge.Record
                if err := proto.Unmarshal(record.Data, &bridgeRecord); err == nil {
                    // 提取资源指标
                    if cpuUsage := bridgeRecord.Data.Fields["cpu_usage_detailed"]; cpuUsage != "" {
                        // 存储到 host_metrics 表
                        s.storeHostMetrics(ctx, conn.AgentID, &bridgeRecord)
                    }
                }
            }
        }
    }
    
    return nil
}

// storeHostMetrics 存储主机监控指标
func (s *Service) storeHostMetrics(ctx context.Context, hostID string, record *bridge.Record) error {
    metrics := &model.HostMetric{
        HostID:        hostID,
        CPUUsage:      parseFloat(record.Data.Fields["cpu_usage_detailed"]),
        MemUsage:      parseFloat(record.Data.Fields["mem_usage_detailed"]),
        DiskUsage:     parseFloat(record.Data.Fields["disk_usage"]),
        NetBytesSent:  parseInt(record.Data.Fields["net_bytes_sent"]),
        NetBytesRecv:  parseInt(record.Data.Fields["net_bytes_recv"]),
        CollectedAt:   time.Unix(0, record.Timestamp),
    }
    
    // 批量插入（每 10 条或每 5 秒批量插入一次）
    return s.metricsBuffer.Add(metrics)
}
```

### 4.2 批量插入优化

**实现批量插入缓冲区**：

```go
type MetricsBuffer struct {
    buffer    []*model.HostMetric
    mu        sync.Mutex
    maxSize   int
    flushInterval time.Duration
    db        *gorm.DB
    logger    *zap.Logger
}

func (b *MetricsBuffer) Add(metric *model.HostMetric) error {
    b.mu.Lock()
    defer b.mu.Unlock()
    
    b.buffer = append(b.buffer, metric)
    
    if len(b.buffer) >= b.maxSize {
        return b.flush()
    }
    
    return nil
}

func (b *MetricsBuffer) flush() error {
    if len(b.buffer) == 0 {
        return nil
    }
    
    // 批量插入
    if err := b.db.CreateInBatches(b.buffer, 100).Error; err != nil {
        return err
    }
    
    b.buffer = b.buffer[:0]
    return nil
}
```

### 4.3 数据清理任务

**位置**：`internal/server/agentcenter/service/cleanup.go`

```go
// StartCleanupTask 启动数据清理任务
func StartCleanupTask(ctx context.Context, db *gorm.DB, logger *zap.Logger) {
    ticker := time.NewTicker(24 * time.Hour) // 每天执行一次
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            // 清理 30 天前的详细数据
            if err := cleanupOldMetrics(db, logger, 30*24*time.Hour); err != nil {
                logger.Error("failed to cleanup old metrics", zap.Error(err))
            }
            
            // 聚合 30-90 天的数据
            if err := aggregateMetrics(db, logger); err != nil {
                logger.Error("failed to aggregate metrics", zap.Error(err))
            }
            
            // 清理 90 天前的聚合数据
            if err := cleanupOldAggregatedMetrics(db, logger, 90*24*time.Hour); err != nil {
                logger.Error("failed to cleanup old aggregated metrics", zap.Error(err))
            }
        }
    }
}
```

---

## 5. 查询 API 设计

### 5.1 获取主机最新指标

```http
GET /api/v1/hosts/{host_id}/metrics/latest
```

**响应**：
```json
{
  "code": 0,
  "data": {
    "host_id": "host-uuid",
    "cpu_usage": 45.2,
    "mem_usage": 62.8,
    "disk_usage": 78.5,
    "net_bytes_sent": 1024000000,
    "net_bytes_recv": 2048000000,
    "collected_at": "2025-01-15T10:30:00Z"
  }
}
```

### 5.2 获取主机历史趋势

```http
GET /api/v1/hosts/{host_id}/metrics/trend?start_time=2025-01-01T00:00:00Z&end_time=2025-01-15T23:59:59Z&interval=1h
```

**参数**：
- `start_time`：开始时间
- `end_time`：结束时间
- `interval`：聚合间隔（1h, 1d）

**响应**：
```json
{
  "code": 0,
  "data": {
    "host_id": "host-uuid",
    "interval": "1h",
    "points": [
      {
        "time": "2025-01-15T10:00:00Z",
        "cpu_usage_avg": 45.2,
        "mem_usage_avg": 62.8,
        "disk_usage_avg": 78.5
      },
      ...
    ]
  }
}
```

### 5.3 查询逻辑

```go
func GetHostMetricsTrend(ctx context.Context, db *gorm.DB, hostID string, startTime, endTime time.Time, interval string) ([]*MetricPoint, error) {
    duration := endTime.Sub(startTime)
    
    // 如果查询范围 > 30 天，使用聚合表
    if duration > 30*24*time.Hour {
        return queryFromAggregatedTable(db, hostID, startTime, endTime, interval)
    }
    
    // 否则使用详细表
    return queryFromDetailTable(db, hostID, startTime, endTime, interval)
}
```

---

## 6. 性能优化建议

### 6.1 索引优化

```sql
-- 主查询索引
CREATE INDEX idx_host_collected ON host_metrics(host_id, collected_at DESC);

-- 时间范围查询索引
CREATE INDEX idx_collected_at ON host_metrics(collected_at DESC);

-- 聚合表索引
CREATE INDEX idx_host_hour ON host_metrics_hourly(host_id, hour_start DESC);
```

### 6.2 分区表（可选）

对于 MySQL 5.7+，可以使用分区表按时间分区：

```sql
ALTER TABLE host_metrics PARTITION BY RANGE (UNIX_TIMESTAMP(collected_at)) (
  PARTITION p202501 VALUES LESS THAN (UNIX_TIMESTAMP('2025-02-01')),
  PARTITION p202502 VALUES LESS THAN (UNIX_TIMESTAMP('2025-03-01')),
  PARTITION p202503 VALUES LESS THAN (UNIX_TIMESTAMP('2025-04-01')),
  PARTITION pmax VALUES LESS THAN MAXVALUE
);
```

### 6.3 读写分离（可选）

如果数据量很大，可以考虑：
- 主库：写入监控数据
- 从库：查询历史数据

---

## 7. 监控和告警

### 7.1 Prometheus 指标导出

将监控数据同时导出到 Prometheus（符合项目规则）：

```go
// 在存储监控数据时，同时更新 Prometheus 指标
metrics.RecordHostCPUUsage(hostID, cpuUsage)
metrics.RecordHostMemUsage(hostID, memUsage)
metrics.RecordHostDiskUsage(hostID, diskUsage)
```

### 7.2 告警规则

可以基于 Prometheus 指标设置告警：
- CPU 使用率 > 90% 持续 5 分钟
- 内存使用率 > 90% 持续 5 分钟
- 磁盘使用率 > 90%

---

## 8. 实施建议

### 8.1 分阶段实施

**Phase 1：基础存储**
1. 创建 `host_metrics` 表
2. 实现数据写入逻辑
3. 实现基础查询 API

**Phase 2：数据保留策略**
1. 实现数据清理任务
2. 实现聚合表（可选）
3. 优化查询性能

**Phase 3：高级功能**
1. 对接 Prometheus（可选）
2. 实现告警规则
3. 实现数据可视化

### 8.2 配置项

```yaml
# configs/server.yaml
metrics:
  # MySQL 存储配置（默认启用）
  mysql:
    enabled: true          # 是否启用 MySQL 存储
    retention_days: 30     # 数据保留天数（默认 30 天）
    batch_size: 100        # 批量插入大小（默认 100）
    flush_interval: 5s    # 刷新间隔（默认 5 秒）
  
  # Prometheus 配置（可选启用）
  prometheus:
    enabled: false         # 是否启用 Prometheus 远程写入
    remote_write_url: "http://prometheus:9090/api/v1/write"  # Remote Write API URL
    pushgateway_url: ""    # Pushgateway URL（可选，与 remote_write_url 二选一）
    job_name: "mxsec-platform"  # Job 名称
    timeout: 10s          # 请求超时
  
  # 清理任务配置（MySQL 存储启用时）
  cleanup:
    enabled: true
    schedule: "0 2 * * *"  # 每天凌晨 2 点执行（cron 格式）
```

### 8.3 使用场景

**场景 1：使用 MySQL（默认）**
```yaml
metrics:
  mysql:
    enabled: true
    retention_days: 30
  prometheus:
    enabled: false
```
- ✅ 适合：中小规模部署（< 500 主机）
- ✅ 优势：简单、无需额外组件、支持复杂查询
- ✅ 用途：短期查询、复杂关联查询
- ✅ 数据保留：30 天（可配置）

**场景 2：使用 Prometheus（可选）**
```yaml
metrics:
  mysql:
    enabled: false  # 自动禁用（当 Prometheus 启用时）
  prometheus:
    enabled: true
    remote_write_url: "http://prometheus:9090/api/v1/write"  # 必须配置外部 Prometheus
```
- ✅ 适合：已有 Prometheus 基础设施、大规模部署（> 1000 主机）
- ✅ 优势：专业时间序列数据库、性能好、长期存储
- ✅ 用途：长期趋势分析、监控告警
- ⚠️ **重要**：必须配置外部 Prometheus 服务，本项目不自动拉起 Prometheus
- ⚠️ **注意**：失去复杂关联查询能力
  - Prometheus 只能查询时间序列指标（CPU、内存、磁盘、网络）
  - 无法关联查询业务数据（基线结果、规则、策略）
  - 需要配合 MySQL 查询业务数据，然后在应用层组装
  - 详见：[MySQL vs Prometheus 查询能力对比](./mysql-vs-prometheus-query.md)

---

## 9. 总结

### 9.1 方案优势

1. ✅ **灵活性**：通过配置选择存储方式，适应不同基础设施
2. ✅ **渐进式**：可以先使用 MySQL，后续需要时再启用 Prometheus
3. ✅ **最佳实践**：MySQL 用于短期查询，Prometheus 用于长期监控
4. ✅ **性能**：批量插入、索引优化、数据保留策略
5. ✅ **符合项目规则**：对接现有 Prometheus 系统（"不作为本项目核心范畴"）

### 9.2 适用场景

**MySQL 存储（默认）**：
- ✅ 中小规模部署（< 500 主机）
- ✅ 需要复杂查询和关联查询
- ✅ 希望保持架构简单
- ✅ **300 个主机端点推荐使用此方案**

**Prometheus 存储（可选）**：
- ✅ 已有 Prometheus 基础设施
- ✅ 大规模部署（> 1000 主机）
- ✅ 需要长期趋势分析和监控告警
- ✅ 需要与现有监控系统集成

### 9.3 最佳实践建议

**对于 300 个主机端点**：
1. **默认配置**：使用 MySQL 存储（30 天保留）
   ```yaml
   metrics:
     mysql:
       enabled: true
       retention_days: 30
     prometheus:
       enabled: false
   ```
2. **可选配置**：如果已有 Prometheus，可以切换到 Prometheus
   ```yaml
   metrics:
     mysql:
       enabled: false  # 自动禁用
     prometheus:
       enabled: true
       remote_write_url: "http://prometheus:9090/api/v1/write"
   ```
3. **数据保留**：
   - MySQL：保留 30 天详细数据
   - Prometheus：由 Prometheus 配置控制（通常 30-90 天）
4. **查询方式**：
   - MySQL：使用 SQL 查询（支持复杂关联查询）
   - Prometheus：使用 PromQL 查询（适合时间序列分析）

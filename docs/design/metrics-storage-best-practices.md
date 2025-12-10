# 监控数据存储最佳实践

> 针对 300+ 主机端点的监控数据存储方案说明

---

## 1. 方案概述

### 1.1 设计理念

**二选一策略**：MySQL（默认）或 Prometheus（可选）

- **MySQL（默认）**：默认启用，保留 30 天，用于实时查询和复杂关联查询
- **Prometheus（可选）**：启用后自动禁用 MySQL，用于长期趋势分析和监控告警
- **重要**：Prometheus 需要**外部配置**，本项目不自动拉起 Prometheus 服务

### 1.2 数据存储范围

**重要说明**：只有**监控数据**（CPU、内存、磁盘、网络）可以存储到 Prometheus 或 MySQL（二选一）。

**业务数据**（基线结果、规则、策略、主机信息、扫描任务）**必须**存储在 MySQL，不能存储到 Prometheus。

详见：[数据存储说明](./data-storage-clarification.md)

### 1.2 配置方式

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

---

## 2. 为什么这是最佳实践？

### 2.1 符合项目设计原则

1. ✅ **轻量**：默认使用 MySQL，无需额外组件
2. ✅ **可扩展**：支持对接现有 Prometheus 系统
3. ✅ **符合项目规则**：对接现有系统（"不作为本项目核心范畴"）

### 2.2 适应不同基础设施

**场景 A：没有 Prometheus（默认）**
- 使用 MySQL 存储
- 简单、易维护
- 适合中小规模部署（< 500 主机）
- **300 个主机端点推荐使用此方案**

**场景 B：已有 Prometheus**
- 配置外部 Prometheus 服务（必须）
- 启用 Prometheus，自动禁用 MySQL
- 专业时间序列数据库，性能好
- 适合大规模部署（> 1000 主机）
- 需要配合 Grafana 等工具
- ⚠️ **注意**：必须配置 `remote_write_url` 或 `pushgateway_url`
- ⚠️ **限制**：不能在一次 SQL JOIN 中完成复杂关联查询
  - ✅ 仍然可以实现复杂查询（多次查询 + 应用层组装）
  - ⚠️ 需要配合 MySQL 查询业务数据，然后在应用层组装
  - ⚠️ 代码复杂度增加，性能可能略差
  - 详见：[MySQL vs Prometheus 查询能力对比](./mysql-vs-prometheus-query.md)

### 2.3 数据保留策略

| 存储方式 | 保留时间 | 用途 |
|---------|---------|------|
| **MySQL** | 30 天 | 实时查询、复杂关联查询、短期趋势 |
| **Prometheus** | 长期（可配置） | 长期趋势分析、监控告警、历史数据 |

---

## 3. 实现细节

### 3.1 存储逻辑（二选一）

```go
// 存储监控数据（二选一：MySQL 或 Prometheus）
if hasMetrics {
    // 优先使用 Prometheus（如果启用），否则使用 MySQL
    if s.prometheusClient != nil {
        // 写入 Prometheus
        s.prometheusClient.WriteMetrics(ctx, hostID, metricsMap, timestamp)
    } else if s.metricsBuffer != nil {
        // 写入 MySQL（默认）
        s.metricsBuffer.Add(metric)
    }
}
```
```

### 3.2 错误处理

- MySQL 写入失败：记录日志，不影响心跳处理
- Prometheus 写入失败：记录日志，不影响心跳处理
- 两者都失败：记录警告日志，但不影响心跳处理

### 3.3 性能优化

**MySQL**：
- 批量插入（每批 100 条）
- 定期刷新（每 5 秒）
- 索引优化（host_id + collected_at）

**Prometheus**：
- 异步写入（不阻塞主流程）
- 批量写入（可选）
- 超时控制（默认 10 秒）

---

## 4. 配置示例

### 4.1 仅 MySQL（默认）

```yaml
metrics:
  mysql:
    enabled: true
    retention_days: 30
  prometheus:
    enabled: false
```

**适用场景**：
- 中小规模部署（< 500 主机）
- 不需要长期历史数据
- 希望保持架构简单

### 4.2 Prometheus（可选）

```yaml
metrics:
  mysql:
    enabled: false  # 自动禁用（当 Prometheus 启用时）
  prometheus:
    enabled: true
    remote_write_url: "http://prometheus:9090/api/v1/write"
    job_name: "mxsec-platform"
```

**适用场景**：
- 已有 Prometheus 基础设施
- 大规模部署（> 1000 主机）
- 需要长期趋势分析和监控告警

### 4.3 仅 Prometheus

```yaml
metrics:
  mysql:
    enabled: false
  prometheus:
    enabled: true
    remote_write_url: "http://prometheus:9090/api/v1/write"
```

**适用场景**：
- 大规模部署（> 1000 主机）
- 已有完整 Prometheus 生态
- 不需要复杂关联查询

---

## 5. 查询策略

### 5.1 MySQL 查询（30 天内）

```sql
-- 查询主机最新指标
SELECT * FROM host_metrics 
WHERE host_id = ? 
ORDER BY collected_at DESC 
LIMIT 1;

-- 查询主机历史趋势（30 天内）
SELECT 
    DATE_FORMAT(collected_at, '%Y-%m-%d %H:00:00') as hour,
    AVG(cpu_usage) as cpu_avg,
    AVG(mem_usage) as mem_avg
FROM host_metrics
WHERE host_id = ? AND collected_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY hour
ORDER BY hour;
```

### 5.2 Prometheus 查询（长期）

```promql
# 查询主机 CPU 使用率（最近 7 天）
mxsec_host_cpu_usage{host_id="host-uuid"}[7d]

# 查询所有主机平均 CPU 使用率
avg(mxsec_host_cpu_usage)

# 查询 CPU 使用率超过 90% 的主机
mxsec_host_cpu_usage > 90
```

---

## 6. 数据清理策略

### 6.1 MySQL 数据清理

**自动清理任务**（每天凌晨 2 点执行）：
1. 清理 30 天前的详细数据
2. 可选：将 30-90 天的数据按小时聚合
3. 清理 90 天前的聚合数据

### 6.2 Prometheus 数据保留

Prometheus 的数据保留由 Prometheus 配置控制：
```yaml
# prometheus.yml
global:
  retention: 30d  # 保留 30 天（可配置）
```

---

## 7. 监控和告警

### 7.1 Prometheus 告警规则示例

```yaml
groups:
  - name: mxsec_host_alerts
    rules:
      - alert: HighCPUUsage
        expr: mxsec_host_cpu_usage > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "主机 CPU 使用率过高"
          description: "主机 {{ $labels.host_id }} CPU 使用率为 {{ $value }}%"
      
      - alert: HighMemoryUsage
        expr: mxsec_host_mem_usage > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "主机内存使用率过高"
          description: "主机 {{ $labels.host_id }} 内存使用率为 {{ $value }}%"
```

### 7.2 Grafana 仪表板

可以创建 Grafana 仪表板展示：
- 主机资源使用趋势
- 资源使用分布
- 告警统计

---

## 8. 总结

### 8.1 方案优势

1. ✅ **灵活性**：通过配置选择存储方式
2. ✅ **渐进式**：可以先使用 MySQL，后续启用 Prometheus
3. ✅ **最佳实践**：MySQL 用于短期查询，Prometheus 用于长期监控
4. ✅ **符合项目规则**：对接现有 Prometheus 系统
5. ✅ **性能优化**：批量插入、索引优化、数据保留策略

### 8.2 对于 300 个主机端点的建议

**推荐配置（默认）**：
```yaml
metrics:
  mysql:
    enabled: true
    retention_days: 30
  prometheus:
    enabled: false
```

**理由**：
1. ✅ MySQL 保留 30 天详细数据，满足日常查询需求
2. ✅ 简单、无需额外组件，符合"轻量"设计理念
3. ✅ 支持复杂查询和关联查询
4. ✅ 性能足够（300 主机规模）

**可选配置（如果已有 Prometheus）**：
```yaml
metrics:
  mysql:
    enabled: false  # 自动禁用
  prometheus:
    enabled: true
    remote_write_url: "http://prometheus:9090/api/v1/write"
```

**理由**：
1. ✅ 利用现有 Prometheus 基础设施
2. ✅ 专业时间序列数据库，性能更好
3. ✅ 支持长期存储和监控告警
4. ⚠️ 需要配合 Grafana 等工具进行查询

---

## 9. 参考

- [Prometheus Remote Write API](https://prometheus.io/docs/prometheus/latest/storage/#remote-storage-integrations)
- [Prometheus Pushgateway](https://github.com/prometheus/pushgateway)
- [Grafana 仪表板示例](https://grafana.com/docs/grafana/latest/dashboards/)

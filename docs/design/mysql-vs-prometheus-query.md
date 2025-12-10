# MySQL vs Prometheus 查询能力对比

> 说明"失去复杂关联查询能力"的具体含义

---

## 重要说明

**数据存储范围**：
- ✅ **监控数据**（CPU、内存、磁盘、网络）：可以存储到 Prometheus 或 MySQL（二选一）
- ✅ **业务数据**（基线结果、规则、策略、主机信息）：必须存储在 MySQL，不能存储到 Prometheus

因此，即使使用 Prometheus 存储监控数据，业务数据仍然存储在 MySQL 中。

详见：[数据存储说明](./data-storage-clarification.md)

---

## 1. 什么是"复杂关联查询"？

**关联查询**是指通过 JOIN 操作将多个表的数据关联起来，形成更丰富的查询结果。

在我们的项目中，常见的关联查询场景包括：

**重要澄清**：
- ✅ **使用 Prometheus 存储监控数据时，仍然可以实现复杂查询**
- ⚠️ **只是不能在一次 SQL JOIN 中完成**
- ✅ **可以通过多次查询 + 应用层组装来实现**
- ⚠️ **代码复杂度会增加，性能可能略差**

---

## 2. 实际查询场景对比

### 场景 1：查询主机详情（包含基线结果和规则信息）

#### MySQL 实现（支持关联查询）

```sql
-- 查询主机详情，同时关联基线结果和规则信息
SELECT 
    h.host_id,
    h.hostname,
    h.os_family,
    h.os_version,
    sr.result_id,
    sr.status,
    sr.severity,
    sr.title,
    r.category,
    r.description,
    p.name as policy_name
FROM hosts h
LEFT JOIN scan_results sr ON h.host_id = sr.host_id
LEFT JOIN rules r ON sr.rule_id = r.rule_id
LEFT JOIN policies p ON r.policy_id = p.id
WHERE h.host_id = 'host-uuid'
ORDER BY sr.checked_at DESC
LIMIT 100;
```

**GORM 实现**：
```go
var host model.Host
db.Where("host_id = ?", hostID).
    Preload("ScanResults").      // 关联查询基线结果
    Preload("ScanResults.Rule"). // 关联查询规则信息
    Preload("ScanResults.Rule.Policy"). // 关联查询策略信息
    First(&host)
```

**结果**：一次查询就能获取主机信息、基线结果、规则详情、策略名称等所有相关信息。

---

#### Prometheus + MySQL 实现（多次查询 + 应用层组装）

**Prometheus 只能查询时间序列数据**：

```promql
# 查询主机 CPU 使用率
mxsec_host_cpu_usage{host_id="host-uuid"}

# 查询主机内存使用率
mxsec_host_mem_usage{host_id="host-uuid"}
```

**实现方式**：
- ✅ 仍然可以实现复杂查询（多次查询 + 应用层组装）
- ⚠️ 不能在一次 SQL JOIN 中完成
- ⚠️ 需要编写更多代码

**解决方案**：
- 需要多次查询：
  1. 查询 Prometheus 获取监控数据
  2. 查询 MySQL 获取基线结果
  3. 查询 MySQL 获取规则信息
  4. 在应用层组装数据

**代码示例**：
```go
// 1. 查询 Prometheus 获取监控数据
cpuResult, _ := prometheusClient.Query("mxsec_host_cpu_usage{host_id=\"host-uuid\"}")
memResult, _ := prometheusClient.Query("mxsec_host_mem_usage{host_id=\"host-uuid\"}")

// 2. 查询 MySQL 获取业务数据
var host model.Host
db.Where("host_id = ?", hostID).
    Preload("ScanResults").
    Preload("ScanResults.Rule").
    Preload("ScanResults.Rule.Policy").
    First(&host)

// 3. 组装数据
hostDetail := HostDetail{
    Host: host,
    CPUUsage: cpuResult.Value,
    MemUsage: memResult.Value,
}
```

**对比**：
- **MySQL**：一次 SQL JOIN 查询获取完整数据（简单、高效）
- **Prometheus + MySQL**：多次查询 + 应用层组装（仍然可以实现，只是方式不同）

---

### 场景 2：查询"高风险主机列表"（CPU 使用率高 + 基线检查失败）

#### MySQL 实现（支持复杂关联查询）

```sql
-- 查询 CPU 使用率 > 90% 且存在高危基线失败的主机
SELECT DISTINCT
    h.host_id,
    h.hostname,
    h.os_family,
    hm.cpu_usage,
    COUNT(sr.result_id) as fail_count
FROM hosts h
INNER JOIN host_metrics hm ON h.host_id = hm.host_id
INNER JOIN scan_results sr ON h.host_id = sr.host_id
WHERE hm.cpu_usage > 90
  AND sr.status = 'fail'
  AND sr.severity IN ('high', 'critical')
  AND hm.collected_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
GROUP BY h.host_id, h.hostname, h.os_family, hm.cpu_usage
HAVING fail_count > 0
ORDER BY fail_count DESC;
```

**优势**：
- ✅ 一次查询就能获取完整结果
- ✅ 可以关联多个表（hosts、host_metrics、scan_results）
- ✅ 支持复杂的 WHERE 条件和 GROUP BY

---

#### Prometheus + MySQL 实现（多次查询 + 应用层处理）

**Prometheus 无法直接关联查询**：

```promql
# 只能查询 CPU 使用率 > 90% 的主机
mxsec_host_cpu_usage > 90

# 无法同时查询基线检查结果（基线结果存储在 MySQL）
```

**解决方案**：
- ✅ 仍然可以实现复杂查询（多次查询 + 应用层处理）
- ⚠️ 不能在一次 SQL JOIN 中完成
- ⚠️ 需要编写更多代码

**实现步骤**：
1. 查询 Prometheus：`mxsec_host_cpu_usage > 90` → 获取主机列表 A
2. 查询 MySQL：`SELECT DISTINCT host_id FROM scan_results WHERE status='fail' AND severity IN ('high','critical')` → 获取主机列表 B
3. 在应用层取交集：`A ∩ B`

**代码示例**：
```go
// 1. 查询 Prometheus：获取 CPU > 90% 的主机
cpuHosts, _ := prometheusClient.Query("mxsec_host_cpu_usage > 90")

// 2. 查询 MySQL：获取存在高危基线失败的主机
var baselineHosts []string
db.Model(&model.ScanResult{}).
    Select("DISTINCT host_id").
    Where("status = ?", "fail").
    Where("severity IN (?)", []string{"high", "critical"}).
    Pluck("host_id", &baselineHosts)

// 3. 取交集
cpuHostSet := make(map[string]bool)
for _, host := range cpuHosts {
    cpuHostSet[host.HostID] = true
}

var highRiskHosts []string
for _, hostID := range baselineHosts {
    if cpuHostSet[hostID] {
        highRiskHosts = append(highRiskHosts, hostID)
    }
}
```

**对比**：
- **MySQL**：一次 SQL JOIN 查询获取结果（简单、高效）
- **Prometheus + MySQL**：多次查询 + 应用层处理（仍然可以实现，只是方式不同）
  - ✅ 可以实现相同的查询结果
  - ⚠️ 需要编写更多代码（取交集逻辑）
  - ⚠️ 性能可能略差（多次查询）

---

### 场景 3：查询"策略执行情况统计"（按策略、按主机聚合）

#### MySQL 实现（支持复杂关联查询）

```sql
-- 查询每个策略的执行情况，包含主机信息
SELECT 
    p.name as policy_name,
    p.description,
    COUNT(DISTINCT sr.host_id) as host_count,
    COUNT(CASE WHEN sr.status = 'pass' THEN 1 END) as pass_count,
    COUNT(CASE WHEN sr.status = 'fail' THEN 1 END) as fail_count,
    AVG(CASE WHEN sr.status = 'pass' THEN 1 ELSE 0 END) * 100 as pass_rate
FROM policies p
LEFT JOIN rules r ON p.id = r.policy_id
LEFT JOIN scan_results sr ON r.rule_id = sr.rule_id
LEFT JOIN hosts h ON sr.host_id = h.host_id
WHERE p.enabled = true
  AND h.status = 'online'
GROUP BY p.id, p.name, p.description
ORDER BY fail_count DESC;
```

**优势**：
- ✅ 一次查询就能获取完整的统计信息
- ✅ 可以关联多个表（policies、rules、scan_results、hosts）
- ✅ 支持复杂的聚合和条件过滤

---

#### Prometheus 实现（不支持关联查询）

**Prometheus 无法查询策略和规则信息**（这些数据存储在 MySQL）：

```promql
# 只能查询监控指标
mxsec_host_cpu_usage

# 无法查询策略信息（policies 表）
# 无法查询规则信息（rules 表）
# 无法查询基线检查结果（scan_results 表）
```

**解决方案**：
- 需要分别查询：
  1. 查询 MySQL 获取策略和规则信息
  2. 查询 MySQL 获取基线检查结果
  3. 查询 Prometheus 获取监控数据（如果需要）
  4. 在应用层组装和聚合数据

---

### 场景 4：查询"主机资源使用趋势 + 基线得分趋势"

#### MySQL 实现（支持关联查询）

```sql
-- 查询主机资源使用和基线得分趋势（关联查询）
SELECT 
    DATE_FORMAT(hm.collected_at, '%Y-%m-%d %H:00:00') as hour,
    AVG(hm.cpu_usage) as avg_cpu,
    AVG(hm.mem_usage) as avg_mem,
    -- 关联查询基线得分（假设有基线得分表）
    AVG(bs.score) as avg_baseline_score
FROM host_metrics hm
LEFT JOIN baseline_scores bs ON hm.host_id = bs.host_id 
    AND DATE_FORMAT(hm.collected_at, '%Y-%m-%d %H:00:00') = DATE_FORMAT(bs.calculated_at, '%Y-%m-%d %H:00:00')
WHERE hm.host_id = 'host-uuid'
  AND hm.collected_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY hour
ORDER BY hour;
```

**优势**：
- ✅ 一次查询就能获取资源使用和基线得分的关联数据
- ✅ 可以关联多个表
- ✅ 支持时间聚合

---

#### Prometheus + MySQL 实现（多次查询 + 应用层合并）

**Prometheus 只能查询时间序列数据**：

```promql
# 查询 CPU 使用率趋势
mxsec_host_cpu_usage{host_id="host-uuid"}[7d]

# 查询内存使用率趋势
mxsec_host_mem_usage{host_id="host-uuid"}[7d]

# 无法查询基线得分（基线得分存储在 MySQL）
```

**解决方案**：
- ✅ 仍然可以实现复杂查询（多次查询 + 应用层合并）
- ⚠️ 不能在一次 SQL JOIN 中完成
- ⚠️ 需要编写更多代码

**实现步骤**：
1. 查询 Prometheus 获取资源使用趋势
2. 查询 MySQL 获取基线得分趋势
3. 在应用层合并数据

**对比**：
- **MySQL**：一次 SQL JOIN 查询获取关联数据（简单、高效）
- **Prometheus + MySQL**：多次查询 + 应用层合并（仍然可以实现，只是方式不同）

---

## 3. 核心区别总结

### MySQL（关系型数据库）

**支持**：
- ✅ JOIN 多个表（hosts、host_metrics、scan_results、rules、policies）
- ✅ 复杂 WHERE 条件
- ✅ 子查询
- ✅ 关联查询（Preload）
- ✅ 事务支持
- ✅ 外键约束

**示例**：
```sql
SELECT h.*, hm.*, sr.*, r.*, p.*
FROM hosts h
JOIN host_metrics hm ON h.host_id = hm.host_id
JOIN scan_results sr ON h.host_id = sr.host_id
JOIN rules r ON sr.rule_id = r.rule_id
JOIN policies p ON r.policy_id = p.id
WHERE h.host_id = 'xxx' AND hm.cpu_usage > 90 AND sr.status = 'fail'
```

---

### Prometheus（时间序列数据库）

**支持**：
- ✅ 时间序列数据查询
- ✅ 指标聚合（sum、avg、max、min）
- ✅ 时间范围查询（[1h]、[7d]）
- ✅ 标签过滤（{host_id="xxx"}）
- ✅ PromQL 查询语言

**不支持**：
- ❌ JOIN 多个表
- ❌ 关联查询
- ❌ 复杂的关系查询
- ❌ 只能查询时间序列指标，无法查询业务数据（策略、规则、基线结果）

**示例**：
```promql
# 只能查询单个指标
mxsec_host_cpu_usage{host_id="host-uuid"}

# 无法关联查询其他表的数据
# 无法查询 scan_results、rules、policies 等业务数据
```

---

## 4. 实际影响

### 4.1 查询性能

**MySQL**：
- 一次查询获取所有数据
- 数据库层面优化（索引、JOIN 优化）
- 适合复杂查询

**Prometheus**：
- 需要多次查询
- 需要在应用层组装数据
- 适合简单的时间序列查询

### 4.2 开发复杂度

**MySQL**：
- 简单的 SQL 查询
- 一次查询获取完整结果
- 代码简洁

**Prometheus**：
- 需要多次查询
- 需要在应用层处理数据
- 代码复杂度增加

### 4.3 数据一致性

**MySQL**：
- 事务支持，保证数据一致性
- 外键约束，保证数据完整性

**Prometheus**：
- 无事务支持
- 无外键约束
- 需要应用层保证数据一致性

---

## 5. 解决方案

### 5.1 混合方案（推荐）

**监控数据**：
- 存储到 Prometheus（时间序列数据）
- 用于长期趋势分析和监控告警

**业务数据**：
- 存储到 MySQL（策略、规则、基线结果）
- 用于复杂查询和关联查询

**查询策略**：
- 监控数据：查询 Prometheus
- 业务数据：查询 MySQL
- 在应用层组装数据

### 5.2 仅 MySQL 方案（当前默认）

**所有数据**：
- 存储到 MySQL
- 支持复杂查询和关联查询

**优势**：
- ✅ 简单、无需额外组件
- ✅ 支持复杂查询
- ✅ 适合中小规模部署（< 500 主机）

---

## 6. 总结

### "失去复杂关联查询能力"的真正含义

**MySQL 存储监控数据**：
- ✅ 可以一次 SQL JOIN 查询关联多个表（hosts、host_metrics、scan_results、rules、policies）
- ✅ 可以获取完整的主机详情（包含监控数据、基线结果、规则信息、策略信息）
- ✅ 可以执行复杂的业务查询（如"高风险主机列表"）
- ✅ 代码简洁，开发效率高

**Prometheus 存储监控数据**：
- ✅ **仍然可以实现复杂查询**（多次查询 + 应用层组装）
- ✅ 可以查询监控数据（Prometheus）
- ✅ 可以查询业务数据（MySQL）
- ⚠️ **不能在一次 SQL JOIN 中完成**
- ⚠️ 需要编写更多代码（组装逻辑）
- ⚠️ 性能可能略差（多次查询，网络开销）

**关键区别**：
- **MySQL**：一次 SQL JOIN 查询，数据库层面完成关联
- **Prometheus + MySQL**：多次查询，应用层完成关联
- **结果相同**：两种方式都能实现相同的查询结果
- **复杂度不同**：Prometheus 方式需要更多代码和逻辑

### 对于 300 个主机端点的建议

**推荐使用 MySQL（默认）**：
- ✅ 支持复杂关联查询
- ✅ 一次查询获取完整数据
- ✅ 代码简洁，开发效率高
- ✅ 无需额外组件

**如果使用 Prometheus**：
- ⚠️ 需要配合 MySQL 查询业务数据
- ⚠️ 需要在应用层组装数据
- ⚠️ 代码复杂度增加
- ✅ 但可以利用 Prometheus 的专业时间序列能力

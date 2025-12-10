# 数据存储说明：哪些数据存储在哪里？

> 明确说明哪些数据可以存储到 Prometheus，哪些数据必须存储在 MySQL

---

## 1. 数据分类

### 1.1 监控数据（可存储到 Prometheus 或 MySQL）

**数据类型**：主机资源监控指标

**包含字段**：
- CPU 使用率（`cpu_usage`）
- 内存使用率（`mem_usage`）
- 磁盘使用率（`disk_usage`）
- 网络发送字节数（`net_bytes_sent`）
- 网络接收字节数（`net_bytes_recv`）
- 采集时间（`collected_at`）

**存储位置**：
- ✅ **MySQL**（默认）：`host_metrics` 表
- ✅ **Prometheus**（可选）：通过 Remote Write API 或 Pushgateway 写入

**存储逻辑**：
- 二选一：如果启用 Prometheus，则只存储到 Prometheus；否则存储到 MySQL
- 配置方式：通过 `configs/server.yaml` 中的 `metrics.mysql.enabled` 和 `metrics.prometheus.enabled` 控制

**代码位置**：
- `internal/server/agentcenter/transfer/service.go` → `storeHostMetrics()`

---

### 1.2 业务数据（必须存储在 MySQL）

以下数据**只能**存储在 MySQL，**不能**存储到 Prometheus：

#### 1.2.1 基线检查结果（ScanResult）

**数据类型**：基线检查执行结果

**包含字段**：
- 结果 ID（`result_id`）
- 主机 ID（`host_id`）
- 策略 ID（`policy_id`）
- 规则 ID（`rule_id`）
- 任务 ID（`task_id`）
- 状态（`status`：pass/fail/error/na）
- 严重级别（`severity`：low/medium/high/critical）
- 类别（`category`：ssh/password/file_permission 等）
- 标题（`title`）
- 实际值（`actual`）
- 期望值（`expected`）
- 修复建议（`fix_suggestion`）
- 检查时间（`checked_at`）

**存储位置**：
- ✅ **MySQL**：`scan_results` 表
- ❌ **Prometheus**：不支持（业务数据，不是时间序列指标）

**代码位置**：
- `internal/server/agentcenter/transfer/service.go` → `handleBaselineResult()`

---

#### 1.2.2 规则信息（Rule）

**数据类型**：基线检查规则定义

**包含字段**：
- 规则 ID（`rule_id`）
- 策略 ID（`policy_id`）
- 类别（`category`）
- 标题（`title`）
- 描述（`description`）
- 严重级别（`severity`）
- 检查配置（`check_config`：JSON）
- 修复配置（`fix_config`：JSON）

**存储位置**：
- ✅ **MySQL**：`rules` 表
- ❌ **Prometheus**：不支持（配置数据，不是时间序列指标）

---

#### 1.2.3 策略信息（Policy）

**数据类型**：基线检查策略集定义

**包含字段**：
- 策略 ID（`id`）
- 名称（`name`）
- 版本（`version`）
- 描述（`description`）
- 适用的操作系统系列（`os_family`：JSON 数组）
- 适用的操作系统版本（`os_version`）
- 是否启用（`enabled`）

**存储位置**：
- ✅ **MySQL**：`policies` 表
- ❌ **Prometheus**：不支持（配置数据，不是时间序列指标）

---

#### 1.2.4 主机信息（Host）

**数据类型**：主机基本信息

**包含字段**：
- 主机 ID（`host_id`）
- 主机名（`hostname`）
- 操作系统系列（`os_family`）
- 操作系统版本（`os_version`）
- 内核版本（`kernel_version`）
- 架构（`arch`）
- IPv4 地址列表（`ipv4`：JSON 数组）
- IPv6 地址列表（`ipv6`：JSON 数组）
- 状态（`status`：online/offline）
- 最后心跳时间（`last_heartbeat`）

**存储位置**：
- ✅ **MySQL**：`hosts` 表
- ❌ **Prometheus**：不支持（业务数据，不是时间序列指标）

---

#### 1.2.5 扫描任务（ScanTask）

**数据类型**：基线扫描任务

**包含字段**：
- 任务 ID（`task_id`）
- 策略 ID（`policy_id`）
- 目标类型（`target_type`）
- 目标值（`target_value`：JSON）
- 状态（`status`：pending/running/completed/failed）
- 创建时间（`created_at`）
- 开始时间（`started_at`）
- 完成时间（`completed_at`）

**存储位置**：
- ✅ **MySQL**：`scan_tasks` 表
- ❌ **Prometheus**：不支持（业务数据，不是时间序列指标）

---

## 2. 数据存储总结

| 数据类型 | MySQL | Prometheus | 说明 |
|---------|-------|-----------|------|
| **监控数据**（CPU、内存、磁盘、网络） | ✅ 默认 | ✅ 可选 | 二选一存储 |
| **基线检查结果**（ScanResult） | ✅ 必须 | ❌ 不支持 | 业务数据 |
| **规则信息**（Rule） | ✅ 必须 | ❌ 不支持 | 配置数据 |
| **策略信息**（Policy） | ✅ 必须 | ❌ 不支持 | 配置数据 |
| **主机信息**（Host） | ✅ 必须 | ❌ 不支持 | 业务数据 |
| **扫描任务**（ScanTask） | ✅ 必须 | ❌ 不支持 | 业务数据 |

---

## 3. 为什么这样设计？

### 3.1 Prometheus 的定位

**Prometheus 是时间序列数据库**，专门用于存储和查询时间序列指标数据：
- ✅ 适合：CPU 使用率、内存使用率、网络流量等**数值型时间序列数据**
- ❌ 不适合：业务数据（基线结果、规则、策略、主机信息）

### 3.2 MySQL 的定位

**MySQL 是关系型数据库**，适合存储结构化业务数据：
- ✅ 适合：业务数据（基线结果、规则、策略、主机信息）
- ✅ 适合：支持复杂关联查询（JOIN 多个表）
- ✅ 适合：支持事务和外键约束

### 3.3 混合存储的优势

**监控数据**（时间序列）：
- 存储到 Prometheus：专业时间序列数据库，性能好，适合长期存储
- 存储到 MySQL：简单、无需额外组件，适合短期查询

**业务数据**（结构化）：
- 存储到 MySQL：支持复杂关联查询，保证数据一致性

---

## 4. 查询场景示例

### 4.1 查询主机详情（包含监控数据和基线结果）

**如果使用 MySQL 存储监控数据**：
```sql
-- 一次查询获取完整数据
SELECT 
    h.*,
    hm.cpu_usage,
    hm.mem_usage,
    sr.status,
    sr.severity,
    r.title,
    p.name as policy_name
FROM hosts h
LEFT JOIN host_metrics hm ON h.host_id = hm.host_id
LEFT JOIN scan_results sr ON h.host_id = sr.host_id
LEFT JOIN rules r ON sr.rule_id = r.rule_id
LEFT JOIN policies p ON r.policy_id = p.id
WHERE h.host_id = 'host-uuid'
ORDER BY hm.collected_at DESC, sr.checked_at DESC
LIMIT 100;
```

**如果使用 Prometheus 存储监控数据**：
1. 查询 Prometheus：`mxsec_host_cpu_usage{host_id="host-uuid"}` → 获取监控数据
2. 查询 MySQL：`SELECT * FROM scan_results WHERE host_id = 'host-uuid'` → 获取基线结果
3. 查询 MySQL：`SELECT * FROM rules WHERE rule_id IN (...)` → 获取规则信息
4. 查询 MySQL：`SELECT * FROM policies WHERE id IN (...)` → 获取策略信息
5. 在应用层组装数据

**对比**：
- **MySQL**：一次 SQL JOIN 查询获取完整数据（简单、高效）
- **Prometheus + MySQL**：多次查询 + 应用层组装（仍然可以实现，只是方式不同）
  - ✅ 可以实现相同的查询结果
  - ⚠️ 需要编写更多代码
  - ⚠️ 性能可能略差（多次查询）

---

### 4.2 查询"高风险主机"（CPU > 90% + 基线检查失败）

**如果使用 MySQL 存储监控数据**：
```sql
-- 一次查询获取结果
SELECT DISTINCT
    h.host_id,
    h.hostname,
    hm.cpu_usage,
    COUNT(sr.result_id) as fail_count
FROM hosts h
INNER JOIN host_metrics hm ON h.host_id = hm.host_id
INNER JOIN scan_results sr ON h.host_id = sr.host_id
WHERE hm.cpu_usage > 90
  AND sr.status = 'fail'
  AND sr.severity IN ('high', 'critical')
  AND hm.collected_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
GROUP BY h.host_id, h.hostname, hm.cpu_usage
HAVING fail_count > 0
ORDER BY fail_count DESC;
```

**如果使用 Prometheus 存储监控数据**：
1. 查询 Prometheus：`mxsec_host_cpu_usage > 90` → 获取主机列表 A
2. 查询 MySQL：`SELECT DISTINCT host_id FROM scan_results WHERE status='fail' AND severity IN ('high','critical')` → 获取主机列表 B
3. 在应用层取交集：`A ∩ B`

**对比**：
- **MySQL**：一次 SQL JOIN 查询获取结果（简单、高效）
- **Prometheus + MySQL**：多次查询 + 应用层处理（仍然可以实现，只是方式不同）
  - ✅ 可以实现相同的查询结果
  - ⚠️ 需要编写更多代码（取交集逻辑）
  - ⚠️ 性能可能略差（多次查询）

---

## 5. 总结

### 5.1 数据存储规则

1. **监控数据**（CPU、内存、磁盘、网络）：
   - ✅ 可以存储到 Prometheus 或 MySQL（二选一）
   - 通过配置控制存储位置

2. **业务数据**（基线结果、规则、策略、主机信息、扫描任务）：
   - ✅ 必须存储在 MySQL
   - ❌ 不能存储到 Prometheus

### 5.2 查询能力

**如果使用 MySQL 存储监控数据**：
- ✅ 支持复杂关联查询（一次 SQL JOIN 查询获取完整数据）
- ✅ 可以关联监控数据、基线结果、规则、策略等多个表
- ✅ 代码简洁，开发效率高
- ✅ 数据库层面优化（索引、JOIN 优化）

**如果使用 Prometheus 存储监控数据**：
- ✅ 可以查询监控数据（Prometheus）
- ✅ 可以查询业务数据（MySQL）
- ✅ **仍然可以实现复杂查询**（多次查询 + 应用层组装）
- ⚠️ 不能在一次 SQL JOIN 中完成
- ⚠️ 需要编写更多代码（组装逻辑）
- ⚠️ 性能可能略差（多次查询，网络开销）

### 5.3 推荐方案

**对于 300 个主机端点**：
- ✅ **推荐使用 MySQL 存储监控数据**（默认）
- ✅ 支持复杂关联查询
- ✅ 一次查询获取完整数据
- ✅ 代码简洁，开发效率高

**如果已有 Prometheus 基础设施**：
- ✅ 可以使用 Prometheus 存储监控数据
- ⚠️ 但需要配合 MySQL 查询业务数据
- ⚠️ 需要在应用层组装数据

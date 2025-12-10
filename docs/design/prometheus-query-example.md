# Prometheus + MySQL 混合查询示例

> 展示如何使用 Prometheus 存储监控数据，同时从 MySQL 查询业务数据，实现复杂查询

---

## 1. 场景说明

**数据存储**：
- 监控数据（CPU、内存、磁盘、网络）→ Prometheus
- 业务数据（基线结果、规则、策略、主机信息）→ MySQL

**查询需求**：查询主机详情（包含监控数据和基线结果）

---

## 2. 实现方式对比

### 2.1 MySQL 方式（一次 SQL JOIN）

```go
// 一次 SQL JOIN 查询获取完整数据
type HostDetail struct {
    HostID       string
    Hostname     string
    CPUUsage     float64
    MemUsage     float64
    BaselineResults []BaselineResult
}

var hostDetail HostDetail
db.Table("hosts h").
    Select("h.host_id, h.hostname, hm.cpu_usage, hm.mem_usage").
    Joins("LEFT JOIN host_metrics hm ON h.host_id = hm.host_id").
    Joins("LEFT JOIN scan_results sr ON h.host_id = sr.host_id").
    Joins("LEFT JOIN rules r ON sr.rule_id = r.rule_id").
    Where("h.host_id = ?", hostID).
    Preload("BaselineResults").
    First(&hostDetail)
```

**优点**：
- ✅ 一次查询获取完整数据
- ✅ 代码简洁
- ✅ 数据库层面优化

---

### 2.2 Prometheus + MySQL 方式（多次查询 + 应用层组装）

```go
// 1. 查询 Prometheus 获取监控数据
func getHostMetricsFromPrometheus(hostID string) (*HostMetrics, error) {
    // 查询 Prometheus API
    cpuQuery := fmt.Sprintf("mxsec_host_cpu_usage{host_id=\"%s\"}", hostID)
    memQuery := fmt.Sprintf("mxsec_host_mem_usage{host_id=\"%s\"}", hostID)
    
    cpuResult, err := prometheusClient.Query(cpuQuery)
    if err != nil {
        return nil, err
    }
    
    memResult, err := prometheusClient.Query(memQuery)
    if err != nil {
        return nil, err
    }
    
    return &HostMetrics{
        CPUUsage: cpuResult.Value,
        MemUsage: memResult.Value,
    }, nil
}

// 2. 查询 MySQL 获取业务数据
func getHostBaselineResultsFromMySQL(hostID string) ([]BaselineResult, error) {
    var results []BaselineResult
    db.Where("host_id = ?", hostID).
        Preload("Rule").
        Preload("Rule.Policy").
        Find(&results)
    return results, nil
}

// 3. 组装数据
func getHostDetail(hostID string) (*HostDetail, error) {
    // 并行查询
    var metrics *HostMetrics
    var baselineResults []BaselineResult
    var err1, err2 error
    
    var wg sync.WaitGroup
    wg.Add(2)
    
    go func() {
        defer wg.Done()
        metrics, err1 = getHostMetricsFromPrometheus(hostID)
    }()
    
    go func() {
        defer wg.Done()
        baselineResults, err2 = getHostBaselineResultsFromMySQL(hostID)
    }()
    
    wg.Wait()
    
    if err1 != nil {
        return nil, err1
    }
    if err2 != nil {
        return nil, err2
    }
    
    // 组装结果
    return &HostDetail{
        HostID:          hostID,
        CPUUsage:        metrics.CPUUsage,
        MemUsage:        metrics.MemUsage,
        BaselineResults: baselineResults,
    }, nil
}
```

**优点**：
- ✅ 仍然可以实现复杂查询
- ✅ 可以利用 Prometheus 的专业时间序列能力
- ⚠️ 需要编写更多代码
- ⚠️ 性能可能略差（多次查询）

---

## 3. 复杂查询示例：高风险主机列表

### 3.1 需求

查询满足以下条件的主机：
- CPU 使用率 > 90%
- 存在高危基线检查失败（severity = 'high' 或 'critical'）

### 3.2 MySQL 方式（一次 SQL JOIN）

```go
type HighRiskHost struct {
    HostID    string
    Hostname  string
    CPUUsage  float64
    FailCount int
}

var hosts []HighRiskHost
db.Table("hosts h").
    Select("h.host_id, h.hostname, hm.cpu_usage, COUNT(sr.result_id) as fail_count").
    Joins("INNER JOIN host_metrics hm ON h.host_id = hm.host_id").
    Joins("INNER JOIN scan_results sr ON h.host_id = sr.host_id").
    Where("hm.cpu_usage > ?", 90).
    Where("sr.status = ?", "fail").
    Where("sr.severity IN (?)", []string{"high", "critical"}).
    Where("hm.collected_at >= ?", time.Now().Add(-1*time.Hour)).
    Group("h.host_id, h.hostname, hm.cpu_usage").
    Having("fail_count > 0").
    Order("fail_count DESC").
    Find(&hosts)
```

---

### 3.3 Prometheus + MySQL 方式（多次查询 + 应用层处理）

```go
// 1. 查询 Prometheus：获取 CPU > 90% 的主机列表
func getHighCPUHostsFromPrometheus() ([]string, error) {
    query := "mxsec_host_cpu_usage > 90"
    result, err := prometheusClient.Query(query)
    if err != nil {
        return nil, err
    }
    
    var hostIDs []string
    for _, sample := range result.Data.Result {
        hostID := sample.Metric["host_id"]
        if hostID != "" {
            hostIDs = append(hostIDs, hostID)
        }
    }
    return hostIDs, nil
}

// 2. 查询 MySQL：获取存在高危基线失败的主机列表
func getHighRiskBaselineHostsFromMySQL() ([]string, error) {
    var hostIDs []string
    db.Model(&model.ScanResult{}).
        Select("DISTINCT host_id").
        Where("status = ?", "fail").
        Where("severity IN (?)", []string{"high", "critical"}).
        Pluck("host_id", &hostIDs)
    return hostIDs, nil
}

// 3. 取交集
func getHighRiskHosts() ([]HighRiskHost, error) {
    // 并行查询
    var cpuHosts, baselineHosts []string
    var err1, err2 error
    
    var wg sync.WaitGroup
    wg.Add(2)
    
    go func() {
        defer wg.Done()
        cpuHosts, err1 = getHighCPUHostsFromPrometheus()
    }()
    
    go func() {
        defer wg.Done()
        baselineHosts, err2 = getHighRiskBaselineHostsFromMySQL()
    }()
    
    wg.Wait()
    
    if err1 != nil {
        return nil, err1
    }
    if err2 != nil {
        return nil, err2
    }
    
    // 取交集
    cpuHostSet := make(map[string]bool)
    for _, hostID := range cpuHosts {
        cpuHostSet[hostID] = true
    }
    
    var highRiskHosts []HighRiskHost
    for _, hostID := range baselineHosts {
        if cpuHostSet[hostID] {
            // 查询主机详情
            var host model.Host
            db.Where("host_id = ?", hostID).First(&host)
            
            // 查询 CPU 使用率（从 Prometheus）
            cpuResult, _ := prometheusClient.Query(fmt.Sprintf("mxsec_host_cpu_usage{host_id=\"%s\"}", hostID))
            
            // 查询失败数量（从 MySQL）
            var failCount int64
            db.Model(&model.ScanResult{}).
                Where("host_id = ?", hostID).
                Where("status = ?", "fail").
                Where("severity IN (?)", []string{"high", "critical"}).
                Count(&failCount)
            
            highRiskHosts = append(highRiskHosts, HighRiskHost{
                HostID:    hostID,
                Hostname:  host.Hostname,
                CPUUsage:  cpuResult.Value,
                FailCount: int(failCount),
            })
        }
    }
    
    // 排序
    sort.Slice(highRiskHosts, func(i, j int) bool {
        return highRiskHosts[i].FailCount > highRiskHosts[j].FailCount
    })
    
    return highRiskHosts, nil
}
```

---

## 4. 性能对比

| 方式 | 查询次数 | 网络开销 | 代码复杂度 | 性能 |
|------|---------|---------|-----------|------|
| **MySQL（一次 JOIN）** | 1 次 | 低 | 低 | 高 |
| **Prometheus + MySQL** | 2-3 次 | 中 | 中 | 中 |

---

## 5. 最佳实践建议

### 5.1 使用 MySQL 存储监控数据（推荐）

**适用场景**：
- 中小规模部署（< 500 主机）
- 需要复杂关联查询
- 希望保持代码简洁

**优点**：
- ✅ 一次 SQL JOIN 查询获取完整数据
- ✅ 代码简洁，开发效率高
- ✅ 数据库层面优化

---

### 5.2 使用 Prometheus 存储监控数据

**适用场景**：
- 已有 Prometheus 基础设施
- 大规模部署（> 1000 主机）
- 需要长期趋势分析和监控告警

**优点**：
- ✅ 专业时间序列数据库，性能好
- ✅ 长期存储，适合历史数据分析
- ✅ 可以配合 Grafana 等工具

**注意事项**：
- ⚠️ 需要编写更多代码（组装逻辑）
- ⚠️ 性能可能略差（多次查询）
- ⚠️ 建议使用并行查询优化性能

---

## 6. 总结

**关键点**：
1. ✅ **Prometheus + MySQL 仍然可以实现复杂查询**
2. ⚠️ **只是不能在一次 SQL JOIN 中完成**
3. ✅ **可以通过多次查询 + 应用层组装来实现**
4. ⚠️ **代码复杂度会增加，性能可能略差**

**选择建议**：
- 对于 300 个主机端点，推荐使用 MySQL 存储监控数据（默认）
- 如果已有 Prometheus 基础设施，可以使用 Prometheus 存储监控数据
- 两种方式都能实现相同的查询结果，只是实现方式不同

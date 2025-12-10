# Prometheus 集成指南

> 说明如何配置 Prometheus 存储监控数据

---

## 1. 概述

本项目支持将监控数据写入 Prometheus，但**需要配置外部 Prometheus 服务**。本项目只提供客户端，不自动拉起 Prometheus 服务。

**设计理念**：
- 对接现有 Prometheus 系统（符合项目规则："不作为本项目核心范畴"）
- 不自动拉起 Prometheus，避免增加系统复杂度
- 支持两种方式：Remote Write API 或 Pushgateway

---

## 2. 配置方式

### 2.1 方式 1：Prometheus Remote Write API（推荐）

**前提条件**：
- 已部署 Prometheus 服务
- Prometheus 支持 Remote Write API（Prometheus 2.0+）

**配置步骤**：

1. **配置 Server**：
```yaml
metrics:
  mysql:
    enabled: false  # 禁用 MySQL 存储
  prometheus:
    enabled: true
    remote_write_url: "http://prometheus:9090/api/v1/write"
    job_name: "mxsec-platform"
```

2. **配置 Prometheus**（如果需要认证）：
```yaml
# prometheus.yml
remote_write:
  - url: "http://localhost:9090/api/v1/write"
    # 如果需要认证
    basic_auth:
      username: "prometheus"
      password: "password"
```

**注意**：
- Prometheus Remote Write API 通常用于 Prometheus 之间的数据同步
- 本项目直接写入到 Prometheus 的 `/api/v1/write` 端点
- 需要确保 Prometheus 配置允许接收远程写入

### 2.2 方式 2：Pushgateway（推荐用于短期任务）

**前提条件**：
- 已部署 Pushgateway 服务

**配置步骤**：

1. **部署 Pushgateway**：
```bash
docker run -d -p 9091:9091 prom/pushgateway
```

2. **配置 Server**：
```yaml
metrics:
  mysql:
    enabled: false  # 禁用 MySQL 存储
  prometheus:
    enabled: true
    pushgateway_url: "http://pushgateway:9091"
    job_name: "mxsec-platform"
```

3. **配置 Prometheus 抓取 Pushgateway**：
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'pushgateway'
    static_configs:
      - targets: ['pushgateway:9091']
```

**适用场景**：
- 短期任务或批处理作业
- 需要临时存储指标的场景
- 不适合长期运行的监控数据（Pushgateway 会一直保留数据）

---

## 3. 数据格式

### 3.1 指标命名

所有指标以 `mxsec_host_` 为前缀：

- `mxsec_host_cpu_usage{host_id="host-uuid"}`：CPU 使用率（%）
- `mxsec_host_mem_usage{host_id="host-uuid"}`：内存使用率（%）
- `mxsec_host_disk_usage{host_id="host-uuid"}`：磁盘使用率（%）
- `mxsec_host_net_bytes_sent{host_id="host-uuid"}`：网络发送字节数
- `mxsec_host_net_bytes_recv{host_id="host-uuid"}`：网络接收字节数

### 3.2 标签

- `host_id`：主机唯一标识

---

## 4. 验证配置

### 4.1 检查 Prometheus 是否接收数据

```bash
# 查询指标
curl 'http://prometheus:9090/api/v1/query?query=mxsec_host_cpu_usage'

# 查看所有 mxsec 相关指标
curl 'http://prometheus:9090/api/v1/label/__name__/values' | grep mxsec
```

### 4.2 检查 Pushgateway 是否接收数据

```bash
# 查看 Pushgateway 指标
curl http://pushgateway:9091/metrics | grep mxsec
```

---

## 5. Grafana 仪表板示例

### 5.1 CPU 使用率趋势图

```promql
# 查询单个主机 CPU 使用率（最近 1 小时）
mxsec_host_cpu_usage{host_id="host-uuid"}[1h]

# 查询所有主机平均 CPU 使用率
avg(mxsec_host_cpu_usage)
```

### 5.2 内存使用率趋势图

```promql
# 查询单个主机内存使用率
mxsec_host_mem_usage{host_id="host-uuid"}

# 查询内存使用率超过 90% 的主机
mxsec_host_mem_usage > 90
```

### 5.3 告警规则示例

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

---

## 6. 常见问题

### 6.1 为什么需要外部 Prometheus？

**原因**：
1. 符合项目设计理念："对接现有 ELK / Loki / Prometheus，不作为本项目核心范畴"
2. 避免增加系统复杂度（不自动拉起 Prometheus）
3. 利用现有监控基础设施

### 6.2 如果没有 Prometheus 怎么办？

**方案**：
- 使用默认配置（MySQL 存储）
- MySQL 存储足够满足 300 个主机端点的需求
- 后续需要时可以部署 Prometheus 并切换配置

### 6.3 Remote Write API 和 Pushgateway 的区别？

| 特性 | Remote Write API | Pushgateway |
|------|-----------------|-------------|
| **用途** | Prometheus 之间的数据同步 | 短期任务指标推送 |
| **数据保留** | 由 Prometheus 配置控制 | Pushgateway 会一直保留 |
| **适用场景** | 长期监控数据 | 批处理作业、短期任务 |
| **推荐** | ✅ 推荐用于监控数据 | ⚠️ 不推荐用于长期监控 |

### 6.4 如何切换存储方式？

**从 MySQL 切换到 Prometheus**：
1. 配置外部 Prometheus 服务
2. 修改配置文件，启用 Prometheus
3. 重启 Server
4. MySQL 存储自动禁用，数据写入 Prometheus

**从 Prometheus 切换回 MySQL**：
1. 修改配置文件，禁用 Prometheus
2. 重启 Server
3. MySQL 存储自动启用

---

## 7. 部署示例

### 7.1 使用 Docker Compose 部署 Prometheus

```yaml
version: '3'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'

volumes:
  prometheus-data:
```

### 7.2 Prometheus 配置文件

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# 如果使用 Pushgateway，需要配置抓取
scrape_configs:
  - job_name: 'pushgateway'
    static_configs:
      - targets: ['pushgateway:9091']

# Remote Write 配置（如果需要）
remote_write:
  - url: "http://localhost:9090/api/v1/write"
```

---

## 8. 总结

### 8.1 关键点

1. ✅ **必须配置外部 Prometheus**：本项目不自动拉起 Prometheus 服务
2. ✅ **默认使用 MySQL**：无需额外组件，简单易用
3. ✅ **符合项目规则**：对接现有系统，不作为核心范畴
4. ✅ **灵活切换**：可以根据基础设施选择存储方式

### 8.2 推荐方案

**对于 300 个主机端点**：
- **默认**：使用 MySQL 存储（无需额外组件）
- **可选**：如果已有 Prometheus，可以切换到 Prometheus

---

## 9. 参考

- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Prometheus Remote Write](https://prometheus.io/docs/prometheus/latest/storage/#remote-storage-integrations)
- [Pushgateway 文档](https://github.com/prometheus/pushgateway)

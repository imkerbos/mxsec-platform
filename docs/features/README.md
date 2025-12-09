# 功能特性文档

本目录包含 Matrix Cloud Security Platform 的功能特性文档。

## 文档列表

- [性能优化](./performance-optimization.md): SQL 查询优化、缓存优化、性能建议
- [依赖说明](./dependencies.md): 可选依赖安装说明

## 已实现功能

### 1. 端到端测试

- ✅ 完整的 Agent + Server + Plugin 端到端测试框架
- ✅ 测试覆盖：心跳上报、任务下发、结果上报、得分计算
- 位置：`tests/e2e/e2e_test.go`

### 2. SQL 查询优化

- ✅ 添加性能优化索引
- ✅ 优化基线得分计算查询（使用窗口函数）
- ✅ 索引自动创建（迁移时）
- 位置：`internal/server/migration/add_indexes.go`

### 3. 缓存优化

- ✅ 内存缓存实现（默认）
- ✅ Redis 缓存接口设计（可扩展）
- 位置：
  - `internal/server/manager/biz/score.go` (内存缓存)
  - `internal/server/manager/biz/score_redis.go` (Redis 缓存)

### 4. Prometheus 指标导出

- ✅ 完整的 Prometheus 指标导出
- ✅ 指标类型：Agent 连接、心跳、基线结果、得分、任务、HTTP 请求、数据库查询
- ✅ Metrics 端点：`/metrics`
- 位置：`internal/server/metrics/metrics.go`

## 使用说明

### 运行端到端测试

```bash
go test -tags=e2e ./tests/e2e/...
```

### 启用 Prometheus 指标

指标导出默认启用，访问 `http://localhost:8080/metrics` 即可查看。

### 使用 Redis 缓存

参考 [性能优化文档](./performance-optimization.md) 中的 Redis 缓存部分。

## 下一步计划

- [ ] 添加更多性能监控指标
- [ ] 实现缓存预热机制
- [ ] 添加性能基准测试
- [ ] 实现分布式缓存（Redis Cluster）

# 故障排查指南

本文档帮助您解决 Matrix Cloud Security Platform 使用过程中遇到的常见问题。

## 目录

- [后端问题](#后端问题)
- [前端问题](#前端问题)
- [Agent 问题](#agent-问题)
- [数据库问题](#数据库问题)
- [网络问题](#网络问题)

## 后端问题

### AgentCenter 无法启动

**症状：** AgentCenter 启动失败或立即退出

**可能原因：**
1. 端口被占用
2. 证书文件不存在或格式错误
3. 配置文件错误

**解决方法：**

```bash
# 检查端口占用
lsof -i :6751

# 检查证书文件
ls -la deploy/certs/

# 重新生成证书
./scripts/generate-certs.sh

# 检查配置文件
cat configs/server.yaml
```

### Manager API 返回 500 错误

**症状：** API 请求返回 500 内部服务器错误

**可能原因：**
1. 数据库连接失败
2. 数据库表不存在
3. 业务逻辑错误

**解决方法：**

```bash
# 检查数据库连接
mysql -u root -p -e "USE mxsec_platform; SHOW TABLES;"

# 检查日志
tail -f logs/manager.log

# 运行数据库迁移
# （如果使用 Gorm AutoMigrate，重启服务会自动迁移）
```

### 数据库连接失败

**症状：** 日志显示 "数据库连接失败"

**可能原因：**
1. 数据库服务未启动
2. 用户名或密码错误
3. 数据库不存在
4. 网络问题

**解决方法：**

```bash
# 检查数据库服务状态
systemctl status mysql  # 或 postgresql

# 测试数据库连接
mysql -u <username> -p -h <host> <database>

# 检查配置文件
cat configs/server.yaml | grep -A 5 database
```

## 前端问题

### 前端无法连接后端 API

**症状：** 浏览器控制台显示网络错误或 CORS 错误

**可能原因：**
1. 后端服务未启动
2. 代理配置错误
3. CORS 配置问题

**解决方法：**

```bash
# 检查后端服务是否运行
curl http://localhost:8080/api/v1/health

# 检查 Vite 代理配置
cat ui/vite.config.ts

# 检查浏览器控制台错误信息
# 打开浏览器开发者工具 (F12) -> Console
```

### 登录后立即跳转到登录页

**症状：** 登录成功但立即被重定向回登录页

**可能原因：**
1. Token 存储失败
2. 路由守卫检查失败
3. Token 格式错误

**解决方法：**

```bash
# 检查浏览器 localStorage
# 打开浏览器开发者工具 (F12) -> Application -> Local Storage
# 查看是否有 mxcsec_token

# 检查路由守卫逻辑
cat ui/src/router/index.ts

# 检查 API 响应格式
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### 页面显示空白

**症状：** 页面加载后显示空白

**可能原因：**
1. JavaScript 错误
2. 路由配置错误
3. 组件加载失败

**解决方法：**

```bash
# 检查浏览器控制台错误
# 打开浏览器开发者工具 (F12) -> Console

# 检查网络请求
# 打开浏览器开发者工具 (F12) -> Network

# 检查构建是否成功
cd ui
npm run build
```

## Agent 问题

### Agent 无法连接到 Server

**症状：** Agent 日志显示连接失败

**可能原因：**
1. Server 地址配置错误
2. 网络不通
3. 证书问题
4. 防火墙阻止

**解决方法：**

```bash
# 检查 Agent 配置（构建时嵌入的）
strings mxsec-agent | grep -i server

# 测试网络连接
telnet <server-host> 6751

# 检查证书
ls -la /var/lib/mxsec-agent/certs/

# 检查防火墙
sudo iptables -L -n | grep 6751
```

### Agent 插件无法启动

**症状：** Agent 日志显示插件启动失败

**可能原因：**
1. 插件文件不存在
2. 插件权限问题
3. 插件签名验证失败

**解决方法：**

```bash
# 检查插件文件
ls -la /var/lib/mxsec-agent/plugins/

# 检查插件权限
chmod +x /var/lib/mxsec-agent/plugins/*

# 检查 Agent 日志
tail -f /var/log/mxsec-agent/agent.log
```

## 数据库问题

### 表不存在错误

**症状：** 日志显示 "表不存在"

**可能原因：**
1. 数据库迁移未执行
2. 数据库连接错误

**解决方法：**

```bash
# 检查数据库表
mysql -u root -p mxsec_platform -e "SHOW TABLES;"

# 手动运行迁移（如果需要）
# 通常 Gorm AutoMigrate 会在服务启动时自动执行
```

### 数据库性能问题

**症状：** 查询速度慢

**可能原因：**
1. 缺少索引
2. 数据量过大
3. 查询语句未优化

**解决方法：**

```bash
# 检查表索引
mysql -u root -p mxsec_platform -e "SHOW INDEX FROM hosts;"

# 分析慢查询
mysql -u root -p mxsec_platform -e "SHOW PROCESSLIST;"

# 优化查询（添加索引等）
```

## 网络问题

### gRPC 连接失败

**症状：** Agent 无法通过 gRPC 连接到 AgentCenter

**可能原因：**
1. 端口未开放
2. mTLS 证书问题
3. 网络配置问题

**解决方法：**

```bash
# 检查端口监听
netstat -tlnp | grep 6751

# 检查证书
openssl x509 -in deploy/certs/server.crt -text -noout

# 测试连接
openssl s_client -connect localhost:6751 -CAfile deploy/certs/ca.crt
```

### CORS 错误

**症状：** 浏览器控制台显示 CORS 错误

**可能原因：**
1. CORS 中间件未配置
2. 允许的源配置错误

**解决方法：**

```bash
# 检查 CORS 配置
cat internal/server/manager/main.go | grep -i cors

# 检查配置文件
cat configs/server.yaml | grep -i cors
```

## 日志查看

### 后端日志

```bash
# AgentCenter 日志
tail -f logs/agentcenter.log

# Manager 日志
tail -f logs/manager.log

# 查看错误日志
grep -i error logs/*.log
```

### Agent 日志

```bash
# Agent 日志
tail -f /var/log/mxsec-agent/agent.log

# 查看最近的错误
grep -i error /var/log/mxsec-agent/agent.log | tail -20
```

### 前端日志

打开浏览器开发者工具 (F12) -> Console 查看前端日志。

## 性能问题

### 响应时间慢

**可能原因：**
1. 数据库查询慢
2. 缺少缓存
3. 网络延迟

**解决方法：**

```bash
# 检查数据库查询时间
mysql -u root -p mxsec_platform -e "SHOW PROCESSLIST;"

# 添加缓存（Redis）
# 检查网络延迟
ping <server-host>
```

## 获取帮助

如果以上方法无法解决问题：

1. 查看详细日志
2. 检查 GitHub Issues
3. 提交新的 Issue，包含：
   - 错误信息
   - 日志片段
   - 复现步骤
   - 环境信息（OS、版本等）

## 常见错误代码

| 错误代码 | 含义 | 解决方法 |
|---------|------|---------|
| 401 | 未授权 | 检查 Token 是否有效 |
| 403 | 禁止访问 | 检查用户权限 |
| 404 | 资源不存在 | 检查请求路径 |
| 500 | 服务器错误 | 查看服务器日志 |
| 502 | 网关错误 | 检查服务是否运行 |
| 503 | 服务不可用 | 检查服务状态 |

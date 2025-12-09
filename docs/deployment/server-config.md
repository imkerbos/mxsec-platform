# Server 配置文档

> 本文档详细说明 Matrix Cloud Security Platform Server 的配置选项。

---

## 1. 配置文件结构

Server 使用 YAML 格式配置文件，默认路径：`/etc/mxcsec-platform/server.yaml`

配置文件结构：

```yaml
server:
  grpc: ...
  http: ...
database:
  type: ...
  mysql: ...
  postgres: ...
mtls: ...
log: ...
agent: ...
```

---

## 2. Server 配置

### 2.1 gRPC 服务配置（AgentCenter）

```yaml
server:
  grpc:
    host: "0.0.0.0"  # 监听地址，0.0.0.0 表示所有接口
    port: 6751        # gRPC 端口
```

**说明**：
- `host`: 监听地址，`0.0.0.0` 表示监听所有网络接口
- `port`: gRPC 服务端口，默认 6751

### 2.2 HTTP 服务配置（Manager）

```yaml
server:
  http:
    host: "0.0.0.0"  # 监听地址
    port: 8080       # HTTP 端口
```

**说明**：
- `host`: 监听地址，`0.0.0.0` 表示监听所有网络接口
- `port`: HTTP API 端口，默认 8080

---

## 3. 数据库配置

### 3.1 数据库类型

```yaml
database:
  type: "mysql"  # 或 "postgres"
```

### 3.2 MySQL 配置

```yaml
database:
  mysql:
    host: "localhost"           # 数据库主机
    port: 3306                 # 数据库端口
    user: "mxsec_user"           # 数据库用户
    password: "mxsec_password"   # 数据库密码
    database: "mxsec"   # 数据库名称
    charset: "utf8mb4"         # 字符集
    parse_time: true           # 解析时间字段
    loc: "Asia/Shanghai"       # 时区
    max_idle_conns: 10         # 最大空闲连接数
    max_open_conns: 100       # 最大打开连接数
    conn_max_lifetime: "1h"   # 连接最大生存时间
```

**说明**：
- `host`: 数据库主机地址
- `port`: 数据库端口，MySQL 默认 3306
- `user`: 数据库用户名
- `password`: 数据库密码
- `database`: 数据库名称
- `charset`: 字符集，推荐 `utf8mb4`
- `parse_time`: 是否解析时间字段
- `loc`: 时区设置
- `max_idle_conns`: 连接池最大空闲连接数
- `max_open_conns`: 连接池最大打开连接数
- `conn_max_lifetime`: 连接最大生存时间

### 3.3 PostgreSQL 配置

```yaml
database:
  postgres:
    host: "localhost"           # 数据库主机
    port: 5432                 # 数据库端口
    user: "mxsec_user"           # 数据库用户
    password: "mxsec_password"   # 数据库密码
    database: "mxsec"   # 数据库名称
    sslmode: "disable"         # SSL 模式
    timezone: "Asia/Shanghai"  # 时区
    max_idle_conns: 10         # 最大空闲连接数
    max_open_conns: 100       # 最大打开连接数
    conn_max_lifetime: "1h"   # 连接最大生存时间
```

**说明**：
- `host`: 数据库主机地址
- `port`: 数据库端口，PostgreSQL 默认 5432
- `user`: 数据库用户名
- `password`: 数据库密码
- `database`: 数据库名称
- `sslmode`: SSL 模式，可选值：`disable`, `require`, `verify-ca`, `verify-full`
- `timezone`: 时区设置
- 连接池配置同 MySQL

---

## 4. mTLS 配置

```yaml
mtls:
  ca_cert: "certs/ca.crt"           # CA 证书路径
  server_cert: "certs/server.crt"   # Server 证书路径
  server_key: "certs/server.key"    # Server 私钥路径
```

**说明**：
- `ca_cert`: CA 根证书路径，用于验证 Agent 证书
- `server_cert`: Server 证书路径，用于 mTLS 认证
- `server_key`: Server 私钥路径，必须保密

**证书生成**：

```bash
# 使用项目提供的脚本生成证书
./scripts/generate-certs.sh
```

---

## 5. 日志配置

```yaml
log:
  level: "info"   # 日志级别：debug, info, warn, error
  format: "json"  # 日志格式：json 或 console
  file: "/var/log/mxcsec-platform/server.log"  # 日志文件路径
  max_age: 30     # 日志保留天数
```

**说明**：
- `level`: 日志级别
  - `debug`: 调试信息，包含详细的执行流程
  - `info`: 一般信息，包含关键操作记录
  - `warn`: 警告信息
  - `error`: 错误信息
- `format`: 日志格式
  - `json`: JSON 格式，适合日志收集系统（推荐生产环境）
  - `console`: 控制台格式，适合开发调试
- `file`: 日志文件路径
- `max_age`: 日志文件保留天数，超过此天数的日志文件会被自动删除

**日志轮转**：
- 日志按天轮转，每天生成新文件：`server.log.YYYY-MM-DD`
- 自动清理超过 `max_age` 天的日志文件

---

## 6. Agent 配置（下发到 Agent）

```yaml
agent:
  heartbeat_interval: 60  # 心跳间隔（秒）
  work_dir: "/var/lib/mxsec-agent"  # Agent 工作目录
```

**说明**：
- `heartbeat_interval`: Agent 心跳上报间隔（秒），默认 60 秒
- `work_dir`: Agent 工作目录，用于存储 Agent ID、证书等

**注意**：这些配置会通过 gRPC 下发给 Agent，Agent 连接后会自动应用。

---

## 7. 配置示例

### 7.1 开发环境配置

```yaml
server:
  grpc:
    host: "0.0.0.0"
    port: 6751
  http:
    host: "0.0.0.0"
    port: 8080

database:
  type: "mysql"
  mysql:
    host: "localhost"
    port: 3306
    user: "mxsec_user"
    password: "mxsec_password"
    database: "mxsec"
    charset: "utf8mb4"
    parse_time: true
    loc: "Asia/Shanghai"
    max_idle_conns: 5
    max_open_conns: 20
    conn_max_lifetime: "30m"

mtls:
  ca_cert: "certs/ca.crt"
  server_cert: "certs/server.crt"
  server_key: "certs/server.key"

log:
  level: "debug"
  format: "console"
  file: "/var/log/mxcsec-platform/server.log"
  max_age: 7

agent:
  heartbeat_interval: 30
  work_dir: "/var/lib/mxsec-agent"
```

### 7.2 生产环境配置

```yaml
server:
  grpc:
    host: "0.0.0.0"
    port: 6751
  http:
    host: "0.0.0.0"
    port: 8080

database:
  type: "mysql"
  mysql:
    host: "mysql.example.com"
    port: 3306
    user: "mxsec_user"
    password: "strong_password_here"
    database: "mxsec"
    charset: "utf8mb4"
    parse_time: true
    loc: "Asia/Shanghai"
    max_idle_conns: 10
    max_open_conns: 100
    conn_max_lifetime: "1h"

mtls:
  ca_cert: "/etc/mxcsec-platform/certs/ca.crt"
  server_cert: "/etc/mxcsec-platform/certs/server.crt"
  server_key: "/etc/mxcsec-platform/certs/server.key"

log:
  level: "info"
  format: "json"
  file: "/var/log/mxcsec-platform/server.log"
  max_age: 30

agent:
  heartbeat_interval: 60
  work_dir: "/var/lib/mxsec-agent"
```

---

## 8. 配置验证

### 8.1 检查配置文件语法

```bash
# 使用 yamllint（如果已安装）
yamllint configs/server.yaml

# 或使用 Python
python3 -c "import yaml; yaml.safe_load(open('configs/server.yaml'))"
```

### 8.2 测试配置加载

```bash
# 启动 Server 时会自动验证配置
/opt/mxcsec-platform/agentcenter -config /etc/mxcsec-platform/server.yaml

# 如果配置有误，会显示错误信息
```

---

## 9. 环境变量覆盖

部分配置可以通过环境变量覆盖：

```bash
# 数据库配置
export BLS_DB_HOST=mysql.example.com
export BLS_DB_PORT=3306
export BLS_DB_USER=mxsec_user
export BLS_DB_PASSWORD=password

# 日志级别
export BLS_LOG_LEVEL=debug
```

**注意**：环境变量覆盖功能需要在代码中实现，当前版本暂不支持。

---

## 10. 配置最佳实践

### 10.1 路径配置

- **使用绝对路径**：生产环境使用绝对路径，避免相对路径问题
- **配置文件权限**：设置为 `600`，仅 root 可读
  ```bash
  sudo chmod 600 /etc/mxcsec-platform/server.yaml
  sudo chown root:root /etc/mxcsec-platform/server.yaml
  ```

### 10.2 日志配置

- **生产环境**：使用 `info` 级别，`json` 格式
- **开发环境**：使用 `debug` 级别，`console` 格式
- **日志轮转**：确保日志目录有足够空间，定期清理旧日志

### 10.3 数据库连接池

根据实际负载调整连接池大小：

```yaml
database:
  mysql:
    max_idle_conns: 10      # 空闲连接数（建议：CPU 核心数）
    max_open_conns: 100     # 最大连接数（建议：max_idle_conns * 10）
    conn_max_lifetime: "1h" # 连接最大生存时间
```

**建议**：
- 小规模部署（< 100 Agent）：`max_idle_conns: 5, max_open_conns: 50`
- 中等规模（100-1000 Agent）：`max_idle_conns: 10, max_open_conns: 100`
- 大规模（> 1000 Agent）：`max_idle_conns: 20, max_open_conns: 200`

### 10.4 证书管理

- **定期轮换**：建议每 90 天轮换一次证书
- **证书备份**：备份 CA 证书和私钥到安全位置
- **权限控制**：证书文件权限设置为 `600`，仅 root 可读

### 10.5 安全建议

1. **防火墙配置**：限制 gRPC 和 HTTP 端口的访问来源
2. **TLS 配置**：生产环境必须启用 mTLS
3. **数据库安全**：使用强密码，限制数据库访问来源
4. **定期更新**：及时更新 Server 版本，修复安全漏洞

---

## 11. 高级配置选项

### 11.1 环境变量覆盖（计划中）

未来版本将支持通过环境变量覆盖配置：

```bash
# 数据库配置
export BLS_SERVER_DATABASE_TYPE=mysql
export BLS_SERVER_DATABASE_MYSQL_HOST=mysql.example.com
export BLS_SERVER_DATABASE_MYSQL_PORT=3306

# 日志配置
export BLS_SERVER_LOG_LEVEL=debug
export BLS_SERVER_LOG_FORMAT=console
```

### 11.2 多配置文件支持

可以通过命令行参数指定配置文件：

```bash
# 使用自定义配置文件
/opt/mxcsec-platform/agentcenter -config /etc/mxcsec-platform/server-prod.yaml

# 或通过环境变量
export BLS_SERVER_CONFIG=/etc/mxcsec-platform/server-prod.yaml
```

### 11.3 配置验证

Server 启动时会自动验证配置：

```bash
# 检查配置是否正确
/opt/mxcsec-platform/agentcenter -config /etc/mxcsec-platform/server.yaml

# 如果配置有误，会显示错误信息并退出
```

---

## 12. 故障排查

### 12.1 配置加载失败

```bash
# 检查配置文件语法
cat /etc/mxcsec-platform/server.yaml | grep -v "^#" | grep -v "^$"

# 使用 yamllint 验证（如果已安装）
yamllint /etc/mxcsec-platform/server.yaml

# 检查文件权限
ls -la /etc/mxcsec-platform/server.yaml

# 检查路径是否存在
ls -la /etc/mxcsec-platform/certs/
```

### 12.2 数据库连接失败

```bash
# 测试数据库连接
mysql -h localhost -u mxsec_user -p mxsec

# 检查数据库配置
grep -A 10 "database:" /etc/mxcsec-platform/server.yaml

# 检查数据库服务状态
sudo systemctl status mysql

# 检查连接池配置
grep -A 5 "max_" /etc/mxcsec-platform/server.yaml
```

### 12.3 证书问题

```bash
# 检查证书文件
ls -la /etc/mxcsec-platform/certs/

# 验证证书有效期
openssl x509 -in /etc/mxcsec-platform/certs/server.crt -noout -dates

# 验证证书链
openssl verify -CAfile /etc/mxcsec-platform/certs/ca.crt /etc/mxcsec-platform/certs/server.crt

# 检查证书和私钥是否匹配
openssl x509 -noout -modulus -in /etc/mxcsec-platform/certs/server.crt | openssl md5
openssl rsa -noout -modulus -in /etc/mxcsec-platform/certs/server.key | openssl md5
# 两个 MD5 值应该相同
```

### 12.4 端口占用

```bash
# 检查端口占用
sudo netstat -tuln | grep -E '6751|8080'

# 或使用 ss
sudo ss -tuln | grep -E '6751|8080'

# 查看占用端口的进程
sudo lsof -i :6751
sudo lsof -i :8080
```

### 12.5 日志问题

```bash
# 检查日志文件权限
ls -la /var/log/mxcsec-platform/

# 检查日志目录空间
df -h /var/log/mxcsec-platform/

# 查看最近的错误日志
sudo journalctl -u mxsec-agentcenter -p err -n 50
sudo journalctl -u mxsec-manager -p err -n 50
```

---

## 12. 参考文档

- [Server 部署指南](./server-deployment.md)
- [Agent 部署指南](./agent-deployment.md)

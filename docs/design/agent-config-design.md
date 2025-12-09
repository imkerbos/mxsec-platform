# Agent 配置设计

> 本文档描述 Agent 配置的设计原则和实现方式。

---

## 1. 设计原则

### 1.1 配置分类

Agent 配置分为两类：

1. **构建时嵌入配置**（必须）
   - Server 地址（必须）
   - 产品版本信息
   - 构建时间
   - 日志配置（默认：按天轮转，保留30天）

2. **Server 下发配置**（运行时）
   - 心跳间隔
   - 工作目录
   - 证书（首次连接时）
   - 插件配置

### 1.2 配置原则

- **完全依赖构建时嵌入**：所有配置在编译时确定，不需要配置文件
- **简化部署**：安装后即可运行，无需额外配置
- **标准目录**：使用标准 Linux 目录结构（/var/log, /var/lib）

---

## 2. 配置方式

### 2.1 构建时嵌入（唯一方式）

**优点：**
- 部署简单，不需要配置文件
- 配置和二进制绑定，避免配置丢失
- 适合大规模部署，配置统一
- 减少运行时配置错误

**实现方式：**

```bash
# Server 在部署时生成配置并构建 Agent
SERVER_HOST="10.0.0.1:6751"
VERSION="1.0.0"

go build -ldflags "\
    -X main.serverHost=$SERVER_HOST \
    -X main.buildVersion=$VERSION \
    -X main.buildTime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    -o mxsec-agent ./cmd/agent
```

**适用场景：**
- 所有环境（生产、测试、开发）
- RPM/DEB 安装包
- 大规模统一部署

---

## 3. 目录结构

### 3.1 标准 Linux 目录结构

```
/etc/mxsec-agent/          # 配置文件目录（可选）
  └── agent.yaml         # 配置文件（可选）

/var/lib/mxsec-agent/      # 数据目录
  ├── agent_id           # Agent ID
  └── certs/             # 证书目录（Server 下发）
      ├── ca.crt
      ├── client.crt
      └── client.key

/var/log/mxsec-agent/      # 日志目录（标准 Linux 日志目录）
  └── agent.log          # 主日志文件
```

### 3.2 目录权限

- `/etc/mxsec-agent/`: `0755` (root:root)
- `/var/lib/mxsec-agent/`: `0755` (root:root)
- `/var/lib/mxsec-agent/certs/`: `0755` (root:root)
- `/var/lib/mxsec-agent/certs/*.key`: `0600` (root:root)
- `/var/log/mxsec-agent/`: `0755` (root:root)

---

## 4. 配置项说明

### 4.1 构建时嵌入配置（必须）

| 配置项 | 变量名 | 说明 | 示例 |
|--------|--------|------|------|
| Server 地址 | `serverHost` | AgentCenter 地址 | `10.0.0.1:6751` |
| 构建版本 | `buildVersion` | Agent 版本 | `1.0.0` |
| 构建时间 | `buildTime` | 构建时间戳 | `2025-01-15T10:30:00Z` |

### 4.2 默认配置（构建时嵌入）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| Agent ID 文件 | `/var/lib/mxsec-agent/agent_id` | Agent ID 存储路径 |
| CA 证书 | `/var/lib/mxsec-agent/certs/ca.crt` | CA 证书路径（Server 下发） |
| 客户端证书 | `/var/lib/mxsec-agent/certs/client.crt` | 客户端证书路径（Server 下发） |
| 客户端密钥 | `/var/lib/mxsec-agent/certs/client.key` | 客户端密钥路径（Server 下发） |
| 日志级别 | `info` | 日志级别 |
| 日志格式 | `json` | 日志格式（JSON） |
| 日志文件 | `/var/log/mxsec-agent/agent.log` | 日志文件路径 |
| 日志轮转 | 每天 | 每天生成一个新日志文件 |
| 日志保留 | `30` 天 | 日志文件保留天数 |

### 4.3 Server 下发配置（运行时）

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| 心跳间隔 | 心跳上报间隔（秒） | `60` |
| 工作目录 | Agent 工作目录 | `/var/lib/mxsec-agent` |
| 产品名称 | 产品名称 | `mxsec-agent` |
| 版本 | Agent 版本 | Server 管理 |

---

## 5. 最佳实践

### 5.1 生产环境部署流程

**推荐方式：**
1. Server 在部署时生成配置和证书
2. 构建 Agent 时嵌入 Server 地址
3. 打包为 RPM/DEB 安装包
4. 安装后 Agent 自动连接 Server 下载证书和配置

**示例：**

```bash
# Server 端生成配置
SERVER_HOST="10.0.0.1:6751"
VERSION="1.0.0"

# 构建 Agent（嵌入 Server 地址）
go build -ldflags "\
    -X main.serverHost=$SERVER_HOST \
    -X main.buildVersion=$VERSION \
    -X main.buildTime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    -o mxsec-agent ./cmd/agent

# 打包为 RPM/DEB
# 安装包中包含预编译的 Server 地址
```

### 5.2 日志管理

**默认配置：**
- 日志路径：`/var/log/mxsec-agent/agent.log`
- 轮转方式：按天轮转（每天生成新文件）
- 文件格式：`agent.log.YYYY-MM-DD`
- 保留时间：30天
- 自动清理：超过30天的日志文件自动删除

**日志文件示例：**
```
/var/log/mxsec-agent/
├── agent.log              # 当前日志（符号链接）
├── agent.log.2025-01-15  # 2025-01-15 的日志
├── agent.log.2025-01-14  # 2025-01-14 的日志
└── ...
```

---

## 6. 配置验证

### 6.1 启动时验证

Agent 启动时会验证：
1. Server 地址是否已设置（构建时嵌入或配置文件）
2. 证书文件是否存在（如果存在，验证有效性）
3. 日志目录是否可写

### 6.2 运行时验证

- Server 下发的配置会验证格式和有效性
- 证书更新时会验证证书有效性

---

## 7. 配置更新

### 7.1 本地配置更新

- 修改 `/etc/mxsec-agent/agent.yaml`
- 重启 Agent：`systemctl restart mxsec-agent`

### 7.2 Server 配置更新

- Server 通过 gRPC 下发配置
- Agent 自动更新，无需重启（部分配置可能需要重启）

---

## 8. 故障排查

### 8.1 检查配置

```bash
# 查看构建时嵌入的配置
mxsec-agent -version

# 查看配置文件（如果存在）
cat /etc/mxsec-agent/agent.yaml

# 查看实际使用的配置（日志中）
journalctl -u mxsec-agent | grep "config"
```

### 8.2 常见问题

**问题1：Server 地址未设置**

```
panic: serverHost must be embedded at build time
```

**解决：** 构建时使用 `-ldflags` 嵌入 Server 地址

**问题2：配置文件格式错误**

```
failed to load config file: yaml: ...
```

**解决：** 检查 YAML 格式，或删除配置文件使用默认值

**问题3：日志目录不可写**

```
failed to create log file: permission denied
```

**解决：** 检查 `/var/log/mxsec-agent/` 目录权限

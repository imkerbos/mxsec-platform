# Agent 部署指南

> 本文档描述 Matrix Cloud Security Platform Agent 的部署方式。

---

## 1. 部署方式概述

Agent 支持三种部署方式：

1. **一键安装脚本**（推荐）：通过 Server 提供的安装脚本自动安装
2. **手动安装**：下载安装包手动安装
3. **源码编译**：从源码编译并部署

---

## 2. 一键安装脚本部署（推荐）

### 2.1 安装流程

```bash
# 方式1：直接执行（Server 地址通过脚本自动检测）
curl -sS http://SERVER_IP:8080/agent/install.sh | bash

# 方式2：指定 Server 地址
curl -sS http://SERVER_IP:8080/agent/install.sh | BLS_SERVER_HOST=10.0.0.1:6751 bash
```

### 2.2 安装脚本功能

安装脚本会自动：
1. 检测操作系统类型和架构
2. 从 Server 下载对应架构的安装包（RPM/DEB）
3. 安装 Agent
4. 启动 Agent 服务
5. Agent 自动连接 Server 并下载配置和证书

### 2.3 安装后验证

```bash
# 检查服务状态
systemctl status mxsec-agent

# 查看日志
journalctl -u mxsec-agent -f

# 检查 Agent ID
cat /var/lib/mxsec-agent/agent_id
```

---

## 3. 手动安装部署

### 3.1 下载安装包

从 Server 下载对应架构的安装包：

```bash
# RPM (RHEL/CentOS/Rocky Linux)
wget http://SERVER_IP:8080/api/v1/agent/download/rpm/amd64 -O mxsec-agent.rpm

# DEB (Debian/Ubuntu)
wget http://SERVER_IP:8080/api/v1/agent/download/deb/amd64 -O mxsec-agent.deb
```

### 3.2 安装

```bash
# RPM
sudo yum install -y mxsec-agent.rpm
# 或
sudo dnf install -y mxsec-agent.rpm

# DEB
sudo apt-get install -y mxsec-agent.deb
```

### 3.3 配置（可选）

如果安装包中未预编译 Server 地址，可以通过以下方式配置：

**方式1：环境变量**
```bash
export BLS_SERVER_HOST=10.0.0.1:6751
systemctl restart mxsec-agent
```

**方式2：配置文件**
```bash
# 编辑配置文件（如果存在）
sudo vi /etc/mxsec-agent/agent.yaml
```

---

## 4. 源码编译部署

### 4.1 编译

```bash
# 设置 Server 地址
export BLS_SERVER_HOST=10.0.0.1:6751
export BLS_VERSION=1.0.0

# 执行构建脚本
bash scripts/build-agent.sh

# 或手动编译
go build -ldflags "\
    -X main.serverHost=10.0.0.1:6751 \
    -X main.buildVersion=1.0.0 \
    -X main.buildTime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    -o mxsec-agent ./cmd/agent
```

### 4.2 部署

```bash
# 复制二进制文件
sudo cp mxsec-agent /usr/local/bin/

# 创建 systemd service
sudo tee /etc/systemd/system/mxsec-agent.service > /dev/null <<EOF
[Unit]
Description=Matrix Cloud Security Platform Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/mxsec-agent
Restart=always
RestartSec=10
Environment="BLS_SERVER_HOST=10.0.0.1:6751"

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
sudo systemctl daemon-reload
sudo systemctl enable mxsec-agent
sudo systemctl start mxsec-agent
```

---

## 5. 配置说明

### 5.1 本地配置（最小配置）

Agent 本地配置只包含必要的连接信息：

- **Server 地址**：通过构建时嵌入、环境变量或配置文件指定
- **Agent ID 文件路径**：默认 `/var/lib/mxsec-agent/agent_id`
- **证书存储目录**：默认 `/var/lib/mxsec-agent/certs`
- **日志配置**：默认 `/var/log/mxsec-agent/agent.log`

### 5.2 远程配置（Server 下发）

以下配置由 Server 自动下发，无需手动配置：

- **心跳间隔**：默认 60 秒
- **工作目录**：默认 `/var/lib/mxsec-agent`
- **产品名称和版本**：由 Server 管理
- **证书**：首次连接时自动下载

### 5.3 配置优先级

1. **构建时嵌入**（最高优先级）
2. **环境变量** (`BLS_SERVER_HOST`)
3. **配置文件** (`/etc/mxsec-agent/agent.yaml`)
4. **默认值**（最低优先级）

---

## 6. 证书管理

### 6.1 首次连接

Agent 首次启动时：
1. 如果没有证书，会尝试从 Server 下载
2. 证书保存到 `/var/lib/mxsec-agent/certs/`
3. 后续连接使用本地证书

### 6.2 证书更新

Server 可以通过 gRPC 命令下发新的证书包，Agent 会自动更新。

---

## 7. 故障排查

### 7.1 检查连接

```bash
# 查看 Agent 日志
journalctl -u mxsec-agent -f

# 检查 Agent ID
cat /var/lib/mxsec-agent/agent_id

# 检查证书
ls -la /var/lib/mxsec-agent/certs/
```

### 7.2 常见问题

**问题1：Agent 无法连接 Server**

- 检查 Server 地址是否正确
- 检查网络连通性：`telnet SERVER_IP 6751`
- 检查防火墙规则

**问题2：证书错误**

- 删除旧证书：`rm -rf /var/lib/mxsec-agent/certs/*`
- 重启 Agent：`systemctl restart mxsec-agent`
- Agent 会重新下载证书

**问题3：配置未更新**

- 检查 Server 是否下发了配置
- 查看日志中的配置更新记录

---

## 8. 卸载

```bash
# 停止服务
sudo systemctl stop mxsec-agent
sudo systemctl disable mxsec-agent

# 卸载包
# RPM
sudo yum remove mxsec-agent

# DEB
sudo apt-get remove mxsec-agent

# 清理数据（可选）
sudo rm -rf /var/lib/mxsec-agent
sudo rm -rf /var/log/mxsec-agent
```

---

## 9. 最佳实践

1. **使用安装脚本**：推荐使用一键安装脚本，自动处理所有配置
2. **构建时嵌入**：生产环境建议在构建时嵌入 Server 地址，避免配置文件管理
3. **监控 Agent 状态**：通过 Server 管理界面监控 Agent 连接状态
4. **定期更新**：通过 Server 统一管理 Agent 版本和配置更新

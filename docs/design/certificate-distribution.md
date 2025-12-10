# 证书下发流程说明

> 本文档说明 AgentCenter 如何将证书下发给 Agent，以及证书在 Agent 和 Server 之间的使用方式。

---

## 1. 证书架构设计

### 1.1 证书角色

- **AgentCenter（Server）**：
  - 使用 Server 证书（`server.crt` + `server.key`）作为服务端证书
  - 使用 CA 证书（`ca.crt`）验证 Agent 的客户端证书
  - **证书申请后一直使用**，不频繁更换

- **Agent（Client）**：
  - 使用客户端证书（`client.crt` + `client.key`）作为客户端证书
  - 使用 CA 证书（`ca.crt`）验证 Server 的服务端证书
  - **证书由 Server 首次连接时自动下发**

### 1.2 证书文件位置

**Server 端（AgentCenter）**：
- CA 证书：`deploy/certs/ca.crt`
- Server 证书：`deploy/certs/server.crt`
- Server 密钥：`deploy/certs/server.key`
- Agent 证书（用于下发）：`deploy/certs/client.crt`
- Agent 密钥（用于下发）：`deploy/certs/client.key`

**Agent 端（首次连接后）**：
- CA 证书：`/var/lib/mxsec-agent/certs/ca.crt`
- 客户端证书：`/var/lib/mxsec-agent/certs/client.crt`
- 客户端密钥：`/var/lib/mxsec-agent/certs/client.key`

---

## 2. 证书下发流程

### 2.1 首次连接流程

```
1. Agent 启动
   └─> 检查本地是否有证书（/var/lib/mxsec-agent/certs/）
       ├─> 如果没有证书：使用临时证书或跳过证书验证（仅用于首次连接）
       └─> 如果有证书：使用本地证书建立 mTLS 连接

2. Agent 连接到 AgentCenter（gRPC Transfer 服务）
   └─> 发送第一个 PackagedData（包含 Agent ID、主机信息等）

3. AgentCenter 接收连接
   └─> 检查是否为首次连接（可选：查询数据库或检查 Agent 是否已有证书记录）
   └─> 调用 sendCertificateBundleIfNeeded()
       ├─> 读取 Server 端的证书文件：
       │   ├─> ca.crt（CA 证书）
       │   ├─> client.crt（客户端证书）
       │   └─> client.key（客户端密钥）
       └─> 构建 CertificateBundle
           └─> 通过 gRPC Command 发送到 Agent

4. Agent 接收证书包
   └─> transport.receiveCommands() 接收到 Command
   └─> 检测到 CertificateBundle 字段
   └─> 调用配置更新回调函数
       └─> config.SyncCertificatesFromServer()
           ├─> 保存证书到 /var/lib/mxsec-agent/certs/
           │   ├─> ca.crt
           │   ├─> client.crt
           │   └─> client.key
           ├─> 更新本地配置中的证书路径
           └─> 验证证书有效性

5. Agent 重新建立连接（使用新证书）
   └─> 后续连接使用本地保存的证书
   └─> 建立完整的 mTLS 双向认证连接
```

### 2.2 证书更新流程

如果 Server 需要更新证书（例如证书即将过期），可以通过以下方式：

1. **Server 端更新证书文件**：
   - 替换 `deploy/certs/` 目录下的证书文件
   - 重启 AgentCenter（或热重载证书配置）

2. **下发新证书包**：
   - Server 检测到证书更新后，向所有已连接的 Agent 下发新的 `CertificateBundle`
   - Agent 接收后自动更新本地证书文件

3. **Agent 重新连接**：
   - Agent 检测到证书更新后，重新建立连接（使用新证书）

---

## 3. 代码实现位置

### 3.1 Server 端（AgentCenter）

**文件**：`internal/server/agentcenter/transfer/service.go`

**关键函数**：
- `sendCertificateBundleIfNeeded()`：检查并下发证书包
- `Transfer()`：处理 Agent 连接，在连接建立后调用证书下发

**实现逻辑**：
```go
// 在 Transfer() 方法中，连接建立后立即下发证书
if err := s.sendCertificateBundleIfNeeded(ctx, conn); err != nil {
    s.logger.Error("下发证书包失败", zap.Error(err))
    // 证书下发失败不影响连接，继续处理
}
```

### 3.2 Agent 端

**文件**：
- `internal/agent/transport/transport.go`：接收证书包
- `internal/agent/config/sync.go`：保存和验证证书

**关键函数**：
- `receiveCommands()`：接收 Server 命令，检测 `CertificateBundle`
- `SyncCertificatesFromServer()`：保存证书到本地文件系统

**实现逻辑**：
```go
// 在 receiveCommands() 中处理证书包
if cmd.CertificateBundle != nil {
    m.logger.Info("received certificate bundle from server")
    if m.onConfigUpdate != nil {
        m.onConfigUpdate(nil, cmd.CertificateBundle)
    }
}
```

---

## 4. 证书验证

### 4.1 Server 端验证 Agent

Server 使用 CA 证书验证 Agent 的客户端证书：

```go
// Server 端 mTLS 配置
tlsConfig := &tls.Config{
    ClientCAs:  caCertPool,  // CA 证书池（用于验证客户端证书）
    ClientAuth: tls.RequireAndVerifyClientCert,  // 要求并验证客户端证书
}
```

### 4.2 Agent 端验证 Server

Agent 使用 CA 证书验证 Server 的服务端证书：

```go
// Agent 端 mTLS 配置
tlsConfig := &tls.Config{
    RootCAs:            caCertPool,  // CA 证书池（用于验证服务端证书）
    Certificates:       []tls.Certificate{cert},  // 客户端证书
    InsecureSkipVerify: false,  // 不跳过验证
}
```

---

## 5. 安全考虑

### 5.1 首次连接安全

- **问题**：Agent 首次连接时可能没有证书，如何建立安全连接？
- **解决方案**：
  1. Agent 首次启动时，可以跳过证书验证（仅用于首次连接）
  2. 或者使用预置的临时证书（在 Agent 安装包中）
  3. 连接建立后，Server 立即下发正式证书
  4. Agent 保存证书后，后续连接使用正式证书

### 5.2 证书存储安全

- Agent 端证书文件权限：
  - CA 证书：`644`（可读）
  - 客户端证书：`644`（可读）
  - 客户端密钥：`600`（仅所有者可读写）

### 5.3 证书轮换

- Server 端证书可以定期轮换（例如每年一次）
- 轮换时，Server 向所有 Agent 下发新证书
- Agent 自动更新本地证书，无需手动操作

---

## 6. 故障排查

### 6.1 Agent 无法连接 Server

**可能原因**：
1. Agent 没有证书（首次连接）
2. 证书文件不存在或路径错误
3. 证书已过期
4. 证书验证失败（证书不是由 CA 签发）

**排查步骤**：
```bash
# 检查 Agent 证书文件
ls -la /var/lib/mxsec-agent/certs/

# 检查证书有效期
openssl x509 -in /var/lib/mxsec-agent/certs/client.crt -noout -dates

# 检查证书是否由 CA 签发
openssl verify -CAfile /var/lib/mxsec-agent/certs/ca.crt \
    /var/lib/mxsec-agent/certs/client.crt
```

### 6.2 Server 无法验证 Agent

**可能原因**：
1. Server 的 CA 证书与 Agent 的客户端证书不匹配
2. Agent 证书不是由 Server 的 CA 签发

**排查步骤**：
```bash
# 检查 Server CA 证书
openssl x509 -in deploy/certs/ca.crt -noout -subject

# 检查 Agent 客户端证书的签发者
openssl x509 -in /var/lib/mxsec-agent/certs/client.crt -noout -issuer

# 验证 Agent 证书是否由 Server CA 签发
openssl verify -CAfile deploy/certs/ca.crt \
    /var/lib/mxsec-agent/certs/client.crt
```

---

## 7. 总结

1. **证书申请**：AgentCenter 的证书申请后一直使用，不频繁更换
2. **证书分发**：Server 在 Agent 首次连接时自动下发证书包（`CertificateBundle`）
3. **证书存储**：Agent 将证书保存到 `/var/lib/mxsec-agent/certs/` 目录
4. **证书使用**：后续连接使用本地保存的证书建立 mTLS 双向认证
5. **证书更新**：Server 可以通过 gRPC 命令下发新证书，Agent 自动更新

这种设计实现了：
- **零配置部署**：Agent 安装后无需手动配置证书
- **自动化管理**：证书由 Server 统一管理和分发
- **安全通信**：使用 mTLS 双向认证保证通信安全

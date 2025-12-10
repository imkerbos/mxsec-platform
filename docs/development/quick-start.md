# 快速开始指南

本文档帮助您快速搭建和运行 Matrix Cloud Security Platform 开发环境。

## 前置要求

- **Go** >= 1.21
- **Node.js** >= 18.x
- **MySQL** >= 8.0 或 **PostgreSQL** >= 13
- **Git**

## 1. 克隆项目

```bash
git clone <repository-url>
cd mxsec-platform
```

## 2. 后端服务启动

### 2.1 配置数据库

创建 MySQL 数据库：

```bash
mysql -u root -p
CREATE DATABASE mxsec_platform CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 2.2 配置服务

复制配置文件：

```bash
cp configs/server.yaml.example configs/server.yaml
```

编辑 `configs/server.yaml`，配置数据库连接等信息。

### 2.3 生成证书

```bash
./scripts/generate-certs.sh
```

### 2.4 启动 AgentCenter（gRPC Server）

```bash
cd cmd/server/agentcenter
go run main.go
```

默认监听端口：`6751`

### 2.5 启动 Manager（HTTP API Server）

```bash
cd cmd/server/manager
go run main.go
```

默认监听端口：`8080`

## 3. 前端服务启动

### 3.1 安装依赖

```bash
cd ui
npm install
```

### 3.2 启动开发服务器

```bash
npm run dev
```

前端开发服务器将在 `http://localhost:3000` 启动。

## 4. 访问系统

1. 打开浏览器访问：`http://localhost:3000`
2. 使用默认账户登录：
   - 用户名：`admin`
   - 密码：`admin123`

## 5. 验证安装

### 5.1 测试 API

运行自动化测试脚本：

```bash
./scripts/test-frontend-api.sh
```

### 5.2 检查服务状态

- AgentCenter：`http://localhost:6751`（gRPC，无法直接访问）
- Manager API：`http://localhost:8080/api/v1`
- 前端 UI：`http://localhost:3000`

## 6. 下一步

- 查看 [开发指南](./development-guide.md) 了解如何开发新功能
- 查看 [部署文档](../deployment/server-deployment.md) 了解生产环境部署
- 查看 [API 文档](./server-api.md) 了解 API 接口

## 常见问题

### 数据库连接失败

- 检查数据库服务是否运行
- 检查 `configs/server.yaml` 中的数据库配置
- 检查数据库用户权限

### 前端无法连接后端

- 检查后端服务是否运行
- 检查 `ui/vite.config.ts` 中的代理配置
- 检查浏览器控制台的错误信息

### 证书错误

- 确保已运行 `./scripts/generate-certs.sh` 生成证书
- 检查证书文件权限
- 检查配置文件中的证书路径

更多问题请参考 [故障排查指南](./troubleshooting.md)。

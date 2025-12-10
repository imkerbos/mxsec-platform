# Docker 开发环境使用指南

本文档说明如何使用 Docker Compose 在 Linux 环境中运行开发环境，避免 macOS 权限问题。

## 快速开始

### 方式一：一键启动（推荐）

```bash
# 启动 Docker 开发环境（后端和前端都在 Docker 中）
make dev-docker-up
```

这个命令会：
1. 检查宿主机 MySQL 连接（127.0.0.1:3306, root/123456）
2. 启动 Manager 容器（支持代码热重载，使用 host 网络模式访问宿主机 MySQL）
3. 启动 UI 容器（支持代码热重载，使用 Vite 开发服务器）

**注意**：
- 使用宿主机现有的 MySQL，不需要在 Docker 中启动 MySQL 容器
- 后端和前端都在 Docker 中运行，支持代码热重载
- 服务在前台运行，日志会实时显示，按 `Ctrl+C` 停止

### 方式二：分步启动

```bash
# 1. 确保宿主机 MySQL 已启动（127.0.0.1:3306, root/123456）
# 可以使用本地 MySQL 或通过其他方式启动

# 2. 启动 Manager 和 UI（前台运行，可以看到日志）
cd deploy/docker-compose
docker-compose -f docker-compose.dev.yml up --build manager ui

# 或者只启动 Manager
docker-compose -f docker-compose.dev.yml up --build manager

# 或者只启动 UI
docker-compose -f docker-compose.dev.yml up --build ui
```

### 方式三：后台运行

```bash
# 启动所有服务（后台模式）
make dev-docker-up-d

# 查看日志
make dev-docker-logs

# 停止服务
make dev-docker-down
```

## 服务地址

- **后端API**: http://localhost:8080（Docker 容器，端口映射）
- **前端UI**: http://localhost:3000（Docker 容器，端口映射，支持热重载）
- **MySQL**: localhost:3306 (root/123456)（宿主机现有 MySQL）

**注意**：
- 开发环境的后端和前端都在 Docker 容器中运行
- **macOS/Windows**: 使用端口映射（`host.docker.internal` 访问宿主机 MySQL）
- **Linux**: 可以使用 `network_mode: "host"` 或端口映射（`172.17.0.1` 访问宿主机 MySQL）
- 前端使用 Vite 开发服务器，支持代码热重载
- 后端使用 Air（如果可用）或 go run，支持代码热重载

## 代码热重载

开发环境支持代码热重载：

1. **后端（Manager）**：
   - **使用 Air（推荐）**：容器内已安装 Air，修改 Go 代码后会自动重新编译和运行
   - **使用 go run**：如果没有 Air，使用 go run 模式，修改代码后需要手动重启容器

2. **后端（AgentCenter）**：
   - **使用 Air（推荐）**：容器内已安装 Air，修改 Go 代码后会自动重新编译和运行
   - **使用 go run**：如果没有 Air，使用 go run 模式，修改代码后需要手动重启容器
   - **配置文件**：使用 `.air.agentcenter.toml`

3. **后端（Agent）**：
   - **使用 Air（推荐）**：容器内已安装 Air，修改 Go 代码后会自动重新编译和运行
   - **使用 go run**：如果没有 Air，使用 go run 模式，修改代码后需要手动重启容器
   - **配置文件**：使用 `.air.agent.toml`
   - **环境变量**：`SERVER_HOST` 和 `VERSION` 通过环境变量传递给 Air（在 docker-compose.dev.yml 中设置）

4. **前端（UI）**：
   - **Vite 热重载**：修改 Vue/TypeScript 代码后，浏览器会自动刷新
   - **无需重启**：前端代码修改立即生效，支持 HMR（热模块替换）

**提示**：所有服务都在 Docker 容器中运行，代码通过 volume 挂载，修改宿主机代码会立即反映到容器中。

### 重启服务

```bash
# 方式1：使用 Makefile（重启 Manager 和 UI）
make dev-docker-restart

# 方式2：直接使用 docker-compose（重启所有服务）
cd deploy/docker-compose
docker-compose -f docker-compose.dev.yml restart

# 方式3：重启单个服务
docker-compose -f docker-compose.dev.yml restart manager
docker-compose -f docker-compose.dev.yml restart agentcenter
docker-compose -f docker-compose.dev.yml restart agent
docker-compose -f docker-compose.dev.yml restart ui

# 方式4：重新构建并启动（修改 Dockerfile 后需要）
docker-compose -f docker-compose.dev.yml up --build agentcenter manager agent ui
```

## 查看日志

```bash
# 查看所有服务日志
make dev-docker-logs

# 或直接使用 docker-compose
cd deploy/docker-compose
docker-compose -f docker-compose.dev.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.dev.yml logs -f manager
docker-compose -f docker-compose.dev.yml logs -f ui
```

## 进入容器调试

```bash
# 进入 Manager 容器
docker exec -it mxsec-manager-dev sh

# 在容器内可以：
# - 查看文件
ls -la /workspace

# - 手动编译
cd /workspace
go build -o /tmp/manager ./cmd/server/manager

# - 运行测试
go test ./...

# 进入 UI 容器
docker exec -it mxsec-ui-dev sh

# 在容器内可以：
# - 查看文件
ls -la /app

# - 安装依赖（如果需要）
npm install

# - 运行构建
npm run build

# - 查看进程
ps aux | grep vite
```

## 数据库操作

由于使用宿主机 MySQL，可以直接在宿主机操作：

```bash
# 连接 MySQL（宿主机）
mysql -h 127.0.0.1 -P 3306 -u root -p123456

# 或直接执行 SQL
mysql -h 127.0.0.1 -P 3306 -u root -p123456 -e "USE mxsec; SHOW TABLES;"

# 初始化数据库（如果不存在）
mysql -h 127.0.0.1 -P 3306 -u root -p123456 -e "CREATE DATABASE IF NOT EXISTS mxsec CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

## 清理数据

```bash
# 停止并删除容器
make dev-docker-down

# 或直接使用 docker-compose
cd deploy/docker-compose
docker-compose -f docker-compose.dev.yml down

# 注意：MySQL 数据在宿主机，不会被删除
# 如需清理 MySQL 数据，需要手动操作宿主机 MySQL
```

## 配置文件

开发环境使用 `deploy/docker-compose/configs/server.dev.yaml`，主要配置：

- **数据库**: 使用 `host.docker.internal`（macOS/Windows）或 `172.17.0.1`（Linux）访问宿主机 MySQL
- **网络模式**: 端口映射（macOS/Windows 不支持 host 模式，Linux 可以手动改为 host 模式）
- **日志**: 输出到控制台，不写文件
- **证书**: 挂载到容器内的 `/etc/mxcsec-platform/certs/`

## 常见问题

### 1. 端口被占用

```bash
# 检查端口占用
lsof -i :8080
lsof -i :3306

# 停止占用端口的进程，或修改 docker-compose.dev.yml 中的端口映射
```

### 2. 容器启动失败

```bash
# 查看详细日志
docker-compose -f docker-compose.dev.yml logs manager

# 检查镜像是否构建成功
docker images | grep mxsec

# 重新构建
docker-compose -f docker-compose.dev.yml build --no-cache manager
```

### 3. 代码修改不生效

- 确保代码已挂载到容器（`/workspace`）
- 如果使用 Air，检查 `.air.toml` 配置
- 如果没有 Air，需要手动重启容器

### 4. 数据库连接失败

- 确保宿主机 MySQL 已启动：`mysql -h 127.0.0.1 -P 3306 -u root -p123456 -e "SELECT 1;"`
- 检查 MySQL 是否监听在 127.0.0.1:3306：`lsof -i :3306`
- 确认 root 密码是否为 123456
- 如果使用 host 网络模式，容器可以直接访问宿主机 MySQL

## 与生产环境的区别

| 项目 | 开发环境 | 生产环境 |
|------|---------|---------|
| 代码挂载 | 是（支持热重载） | 否（构建到镜像） |
| 日志输出 | 控制台 | 文件 |
| 资源限制 | 无 | 有（CPU/内存限制） |
| 数据库 | 宿主机 MySQL (root/123456) | Docker MySQL (mxsec_user/mxsec_password) |
| 网络模式 | 端口映射（macOS/Windows）或 host（Linux） | bridge（Docker 网络） |
| 后端热重载 | 支持（Air/go run） | 不支持 |
| 前端热重载 | 支持（Vite HMR） | 不支持（静态文件） |
| 前端运行位置 | Docker 容器 | Docker 容器（Nginx） |

## 下一步

- 查看 [开发文档](../../DEVELOPMENT.md)
- 查看 [API文档](../../docs/design/server-api.md)
- 查看 [TODO列表](../../docs/TODO.md)

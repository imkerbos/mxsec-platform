# 开发指南

本文档介绍如何参与 Matrix Cloud Security Platform 的开发工作。

## 目录结构

```
mxsec-platform/
├── cmd/                    # 主程序入口
│   ├── server/             # Server 主程序
│   │   ├── agentcenter/   # AgentCenter (gRPC Server)
│   │   └── manager/        # Manager (HTTP API Server)
│   └── agent/              # Agent 主程序
├── internal/               # 内部包（不对外暴露）
│   ├── server/             # Server 内部实现
│   │   ├── api/           # HTTP API 处理器
│   │   ├── biz/           # 业务逻辑层
│   │   ├── model/         # 数据模型
│   │   └── ...
│   └── agent/              # Agent 内部实现
├── plugins/                # 插件
│   ├── baseline/          # 基线检查插件
│   ├── collector/         # 资产采集插件
│   └── lib/               # 插件 SDK
├── ui/                     # 前端项目
│   └── src/
│       ├── api/           # API 客户端
│       ├── views/         # 页面组件
│       └── ...
├── docs/                   # 文档
└── scripts/                # 脚本工具
```

## 开发环境设置

### 1. 代码规范

#### Go 代码

- 使用 `gofmt` 格式化代码
- 使用 `golint` 检查代码规范
- 遵循 Go 官方代码规范

```bash
# 格式化代码
go fmt ./...

# 检查代码规范
golint ./...
```

#### TypeScript/Vue 代码

- 使用 ESLint 检查代码规范
- 使用 Prettier 格式化代码（如果配置了）

```bash
cd ui
npm run lint
```

### 2. 提交规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

- `feat:` 新功能
- `fix:` 修复 bug
- `docs:` 文档更新
- `refactor:` 重构
- `test:` 测试
- `chore:` 其他（构建、工具等）

示例：

```bash
git commit -m "feat: 添加主机监控数据 API"
git commit -m "fix: 修复策略统计信息计算错误"
git commit -m "docs: 更新 API 文档"
```

## 开发流程

### 1. 创建功能分支

```bash
git checkout -b feat/your-feature-name
```

### 2. 开发功能

- 编写代码
- 添加单元测试
- 更新文档

### 3. 测试

```bash
# 后端测试
go test ./...

# 前端测试
cd ui && npm run test

# API 集成测试
# 使用 curl 或 Postman 手动测试 API 端点
```

### 4. 提交代码

```bash
git add .
git commit -m "feat: 描述你的更改"
git push origin feat/your-feature-name
```

### 5. 创建 Pull Request

在 GitHub/GitLab 上创建 PR，等待代码审查。

## 添加新功能

### 添加新的 API 端点

1. **定义路由**（`internal/server/manager/api/`）
2. **实现处理器**（`internal/server/manager/api/`）
3. **实现业务逻辑**（`internal/server/manager/biz/`）
4. **添加前端 API 调用**（`ui/src/api/`）
5. **更新文档**

### 添加新的检查器

1. **实现检查器接口**（`plugins/baseline/src/checkers/`）
2. **添加单元测试**
3. **更新策略配置示例**
4. **更新文档**

### 添加新的前端页面

1. **创建页面组件**（`ui/src/views/`）
2. **添加路由**（`ui/src/router/index.ts`）
3. **添加 API 调用**（`ui/src/api/`）
4. **更新导航菜单**（如果需要）

## 测试

### 单元测试

```bash
# 运行所有测试
go test ./...

# 运行特定包的测试
go test ./internal/server/manager/api/...

# 运行测试并显示覆盖率
go test -cover ./...
```

### 集成测试

```bash
# 运行 E2E 测试
cd tests/e2e
go test -v

# 运行前端 API 测试
# 使用 curl 或 Postman 手动测试 API 端点
```

## 调试

### 后端调试

使用 `delve` 调试器：

```bash
# 安装 delve
go install github.com/go-delve/delve/cmd/dlv@latest

# 启动调试
dlv debug ./cmd/server/manager/main.go
```

### 前端调试

使用浏览器开发者工具：

1. 打开浏览器开发者工具（F12）
2. 查看 Console 标签页查看日志
3. 查看 Network 标签页查看 API 请求

## 性能优化

### 后端优化

- 使用数据库索引
- 使用连接池
- 添加缓存（Redis）
- 优化 SQL 查询

### 前端优化

- 使用代码分割
- 懒加载路由
- 优化图片资源
- 使用 CDN

## 文档更新

添加新功能时，记得更新：

1. **API 文档**（`docs/design/server-api.md`）
2. **开发文档**（`docs/development/`）
3. **README.md**（如果需要）
4. **代码注释**（重要函数和类型）

## 代码审查清单

提交 PR 前，请检查：

- [ ] 代码通过所有测试
- [ ] 代码符合规范
- [ ] 添加了必要的注释
- [ ] 更新了相关文档
- [ ] 没有引入新的警告或错误
- [ ] 提交信息符合规范

## 获取帮助

- 查看 [文档索引](../README.md)
- 查看 [故障排查指南](./troubleshooting.md)
- 提交 Issue 或联系维护者

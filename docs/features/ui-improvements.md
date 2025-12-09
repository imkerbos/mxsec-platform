# UI 改进需求文档

> 本文档记录基于 Elkeid 参考的 UI 改进需求和实现情况。

## 1. 概述

根据 Elkeid 控制台的 UI 设计，对 Matrix Cloud Security Platform 的前端 UI 进行了全面改进，包括：

1. **登录界面和安全认证**：添加了完整的用户认证系统
2. **Dashboard 页面**：参考 Elkeid console0.png，实现安全概览仪表盘
3. **主机详情页**：参考 Elkeid console3.png，实现多标签页的主机详情展示
4. **基线检查详情页**：参考 Elkeid console7.png，实现检查项视角和主机视角的基线检查详情

## 2. 登录界面和安全认证

### 2.1 需求

- 实现用户登录界面
- 实现 JWT Token 认证机制
- 添加路由守卫，保护需要认证的页面
- 支持用户登出功能

### 2.2 实现

#### 前端实现

- **登录页面** (`ui/src/views/Login.vue`)
  - 用户名/密码登录表单
  - 错误提示显示
  - 登录状态管理

- **认证状态管理** (`ui/src/stores/auth.ts`)
  - 使用 Pinia 管理认证状态
  - Token 存储（localStorage）
  - 用户信息存储
  - 登录/登出方法

- **路由守卫** (`ui/src/router/index.ts`)
  - 路由前置守卫检查认证状态
  - 未认证用户重定向到登录页
  - 已认证用户访问登录页重定向到首页

- **API 客户端** (`ui/src/api/client.ts`)
  - 请求拦截器：自动添加 Authorization header
  - 响应拦截器：处理 401 错误，自动跳转登录

#### 后端实现

- **认证 API** (`internal/server/manager/api/auth.go`)
  - `POST /api/v1/auth/login`：用户登录，返回 JWT Token
  - `POST /api/v1/auth/logout`：用户登出
  - `GET /api/v1/auth/me`：获取当前用户信息
  - JWT 认证中间件：验证 Token，提取用户信息

- **配置** (`internal/server/config/config.go`)
  - 添加 `JWTSecret` 配置项，用于 JWT Token 签名

### 2.3 默认账户

- 用户名：`admin`
- 密码：`admin123`

> 注意：生产环境应实现完整的用户管理系统，包括用户表、密码加密存储等。

## 3. Dashboard 页面

### 3.1 需求（参考 console0.png）

Dashboard 应展示以下内容：

1. **资产概览**
   - 主机数量
   - 集群数量
   - 容器数量
   - 在线 Agent 数量

2. **入侵告警（近7天）**
   - 待处理告警数量
   - 告警趋势图
   - 按类型分类的告警统计

3. **主机风险分布**
   - 待处理告警百分比（圆环图）
   - 高可利用漏洞百分比（圆环图）
   - 待加固基线百分比（圆环图）

4. **漏洞风险（近7天）**
   - 待处理高可利用漏洞数量
   - 已开启漏洞热补丁数量
   - 漏洞库更新时间
   - 漏洞趋势图

5. **Agent 概览**
   - 在线 Agent 数量（较昨日变化）
   - 离线 Agent 数量（较昨日变化）

### 3.2 实现

#### 前端实现

- **Dashboard 页面** (`ui/src/views/Dashboard/index.vue`)
  - 使用 Ant Design Vue 组件
  - 卡片式布局展示各项统计
  - 圆环图展示风险分布（使用 a-progress 组件）

#### 后端实现

- **Dashboard API** (`internal/server/manager/api/dashboard.go`)
  - `GET /api/v1/dashboard/stats`：返回 Dashboard 统计数据
  - 统计主机数量、在线/离线 Agent
  - 计算基线风险统计
  - 计算基线加固百分比

## 4. Layout 布局改进

### 4.1 需求（参考 Elkeid 样式）

- 左侧导航栏（可折叠）
- 顶部栏（用户信息和退出登录）
- 主内容区

### 4.2 实现

- **Layout 组件** (`ui/src/layouts/BasicLayout.vue`)
  - 左侧导航栏：使用 `a-layout-sider`
  - 顶部栏：显示平台名称、版本、用户信息
  - 导航菜单：安全概览、主机和容器防护、基线检查、扫描任务
  - 用户下拉菜单：退出登录

## 5. 主机详情页改进

### 5.1 需求（参考 console3.png）

主机详情页应包含以下标签页：

1. **主机概览**
   - 主机基本信息（网格布局）
   - 安全告警圆环图（按风险级别统计）
   - 漏洞风险圆环图（按严重级别统计）
   - 基线风险圆环图（按严重级别统计）
   - 资产指纹（容器、端口、进程、用户等）

2. **安全告警**
   - 告警列表（待实现）

3. **漏洞风险**
   - 漏洞列表（待实现）

4. **基线风险**
   - 基线检查失败结果列表

5. **运行时安全告警**（待实现）
6. **病毒查杀**（待实现）
7. **性能监控**（待实现）
8. **资产指纹**
   - 资产指纹详情（待实现）

### 5.2 实现

#### 前端实现

- **主机详情页** (`ui/src/views/Hosts/Detail.vue`)
  - 使用 `a-tabs` 实现标签页切换
  - 各标签页使用独立组件

- **主机概览组件** (`ui/src/views/Hosts/components/HostOverview.vue`)
  - 基本信息网格布局（使用 `a-descriptions`）
  - 安全告警/漏洞风险/基线风险圆环图
  - 资产指纹卡片展示

- **基线风险组件** (`ui/src/views/Hosts/components/BaselineRisk.vue`)
  - 显示基线检查失败结果列表
  - 支持按规则、状态、严重级别筛选

#### 后端实现

- **主机 API** (`internal/server/manager/api/hosts.go`)
  - `GET /api/v1/hosts/{host_id}`：返回主机详情和基线结果
  - 支持返回主机扩展信息（设备型号、CPU信息、内存等）

## 6. 基线检查详情页改进

### 6.1 需求（参考 console7.png）

基线检查详情页应包含：

1. **顶部概览**
   - 最近检查通过率
   - 检查主机数（圆环图：通过/未通过）
   - 检查项数（圆环图：风险项/通过项）
   - 最近检查时间
   - 立即检查按钮

2. **检查详情区**
   - **检查项视角**
     - 左侧：检查项列表（可搜索、可批量操作）
       - 检查项名称
       - 级别（严重级别标签）
       - 通过率
       - 操作（重新检查）
     - 右侧：选中检查项详情
       - 描述
       - 加固建议
       - 影响的主机列表（可搜索、可批量加白名单）
   - **主机视角**（待实现）

### 6.2 实现

#### 前端实现

- **基线检查详情页** (`ui/src/views/Policies/Detail.vue`)
  - 顶部概览卡片
  - 检查项视角/主机视角切换
  - 左侧检查项列表（表格）
  - 右侧检查项详情（描述、加固建议、影响主机列表）

#### 后端实现

- **策略统计 API** (`internal/server/manager/api/policies.go`)
  - `GET /api/v1/policies/{policy_id}/statistics`：返回策略统计信息
    - 通过率
    - 检查主机数
    - 检查项数
    - 风险项数量
    - 最近检查时间
    - 各规则通过率

## 7. API 接口总结

### 7.1 认证相关

- `POST /api/v1/auth/login` - 用户登录
- `POST /api/v1/auth/logout` - 用户登出
- `GET /api/v1/auth/me` - 获取当前用户信息

### 7.2 Dashboard

- `GET /api/v1/dashboard/stats` - 获取 Dashboard 统计数据

### 7.3 策略相关

- `GET /api/v1/policies/{policy_id}/statistics` - 获取策略统计信息

### 7.4 其他

- 所有需要认证的 API 都需要在请求头中添加 `Authorization: Bearer <token>`
- 认证中间件会自动验证 Token，未授权请求返回 401

## 8. 待实现功能

1. **用户管理**
   - 用户表设计
   - 用户 CRUD API
   - 角色权限管理

2. **告警系统**
   - 告警数据模型
   - 告警统计 API
   - 告警列表页面

3. **漏洞管理**
   - 漏洞数据模型
   - 漏洞统计 API
   - 漏洞列表页面

4. **资产指纹**
   - 资产数据采集和存储
   - 资产指纹 API
   - 资产指纹详情页面

5. **图表展示**
   - 集成图表库（如 ECharts）
   - 实现趋势图展示

6. **主机视角**
   - 基线检查详情页的主机视角实现

## 9. 配置说明

### 9.1 后端配置

在 `configs/server.yaml` 中添加：

```yaml
server:
  jwt_secret: "your-secret-key-here"  # JWT 密钥，建议使用随机字符串
```

### 9.2 前端配置

前端 API 基础路径在 `ui/src/api/client.ts` 中配置：

```typescript
const apiClient: AxiosInstance = axios.create({
  baseURL: '/api/v1',
  // ...
})
```

## 10. 测试说明

### 10.1 登录测试

1. 访问前端页面，应自动跳转到登录页
2. 使用默认账户登录：`admin` / `admin123`
3. 登录成功后应跳转到 Dashboard

### 10.2 API 测试

使用 curl 测试认证 API：

```bash
# 登录
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# 获取 Dashboard 统计（需要 Token）
curl -X GET http://localhost:8080/api/v1/dashboard/stats \
  -H "Authorization: Bearer <token>"
```

## 11. 参考

- Elkeid Console 截图：`Elkeid/png/console*.png`
- Elkeid 官方文档：https://github.com/bytedance/Elkeid

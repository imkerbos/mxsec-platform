# 项目状态总览

> 本文档说明 Matrix Cloud Security Platform 的模块规划和当前完成进度。

---

## 1. 总体模块规划

### 1.1 核心模块（7 个）

| 模块 | 类型 | 职责 | 状态 |
|------|------|------|------|
| **Agent** | 客户端 | 插件基座，管理插件生命周期，与 Server 通信 | ✅ 已完成 |
| **AgentCenter** | Server 端 | gRPC 服务，与 Agent 双向流通信，接收数据、下发任务 | ✅ 已完成 |
| **Manager** | Server 端 | HTTP API 服务，提供管理接口（策略、任务、结果查询） | ✅ 已完成 |
| **ServiceDiscovery** | Server 端（可选） | 服务注册与发现，Agent 获取 AgentCenter 地址 | ⏸️ 可选（Phase 1 简化） |
| **Baseline Plugin** | 插件 | 基线检查插件，执行基线规则检查 | ✅ 已完成 |
| **Collector Plugin** | 插件 | 资产采集插件，采集主机资产信息 | ⏳ Phase 2 |
| **UI (Console)** | 前端 | Vue3 前端界面，主机管理、策略管理、Dashboard | ✅ 已完成 |

---

## 2. 开发阶段划分

### Phase 0: Elkeid 研究与设计 ✅

**目标**：理解 Elkeid 架构，设计自己的架构

**完成情况**：
- ✅ Elkeid 代码研究（Agent、Baseline Plugin、Collector Plugin、插件 SDK）
- ✅ 架构设计文档（Agent 架构、Server API、策略模型）
- ✅ 数据库模型设计
- ✅ 通信协议设计（gRPC、Protobuf）

---

### Phase 1: MVP（最小可行产品）✅

**目标**：实现最小可用的 Agent + Server + Baseline Plugin

#### 1.0 基础设施 ✅

- ✅ 插件 SDK（Go 语言，Pipe 通信封装）
- ✅ Protobuf 定义（bridge.proto、grpc.proto）
- ✅ 代码生成工具

#### 1.1 Agent 开发 ✅

**基础框架**：
- ✅ Agent 主程序（配置加载、日志、信号处理）
- ✅ Agent ID 管理
- ✅ 优雅退出

**连接管理**：
- ✅ 服务发现（简化实现，直接使用配置地址）
- ✅ mTLS 配置（证书由 Server 下发）
- ✅ gRPC 连接建立与管理
- ✅ 连接重试与故障转移

**传输模块**：
- ✅ gRPC 双向流实现
- ✅ 数据打包与发送
- ✅ 命令接收与处理
- ✅ Agent 配置更新处理
- ✅ 证书包更新处理

**心跳模块**：
- ✅ 定时心跳（默认 60 秒）
- ✅ Agent 状态采集（CPU、内存、启动时间）
- ✅ 主机信息采集（OS、内核、IP、主机名）
- ✅ 插件状态采集
- ✅ gRPC 心跳上报

**插件管理**：
- ✅ 插件配置同步（从 Server 接收）
- ✅ 插件签名验证与下载（SHA256 校验）
- ✅ 插件进程启动（Pipe 创建）
- ✅ 插件数据接收（从 Pipe 读取）
- ✅ 插件任务发送（写入 Pipe）
- ✅ 插件生命周期管理（启动、停止、重启、升级）

**Baseline Plugin**：
- ✅ 插件入口（main.go）
- ✅ 插件 SDK 集成
- ✅ 策略加载与解析（JSON）
- ✅ OS 匹配逻辑
- ✅ 规则执行框架
- ✅ 检查器实现（6 种）：
  - ✅ `file_kv`（配置文件键值检查）
  - ✅ `file_line_match`（文件行匹配）
  - ✅ `file_permission`（文件权限检查）
  - ✅ `command_exec`（命令执行）
  - ✅ `sysctl`（内核参数检查）
  - ✅ `service_status`（服务状态检查）
- ✅ 结果生成与上报
- ✅ 示例规则（SSH、密码策略、文件权限等）

**Collector Plugin**：
- ⏳ Phase 2 实现

#### 1.2 Server 开发 ✅

**数据库模型**：
- ✅ `hosts` 表（主机信息）
- ✅ `policies` 表（策略集）
- ✅ `rules` 表（规则）
- ✅ `scan_results` 表（检测结果）
- ✅ `scan_tasks` 表（扫描任务）
- ⏳ 资产表（Phase 2）

**AgentCenter**：
- ✅ 主程序入口
- ✅ 配置加载（Viper + YAML）
- ✅ 日志初始化（Zap）
- ✅ gRPC Server 启动
- ✅ mTLS 配置
- ✅ 数据库连接
- ✅ `Transfer` 服务实现（双向流）
- ✅ 接收 Agent 数据（心跳、检测结果）
- ✅ 下发任务和配置到 Agent
- ✅ 连接状态管理
- ✅ 任务调度器（每 30 秒检查待执行任务）
- ✅ 任务状态自动更新机制

**Manager**：
- ✅ 主程序入口
- ✅ HTTP Server（Gin）
- ✅ 中间件（CORS、日志、Recovery）
- ✅ 数据库连接
- ✅ API 接口实现：
  - ✅ 主机管理 API（列表、详情）
  - ✅ 策略管理 API（CRUD）
  - ✅ 任务管理 API（创建、执行、查询）
  - ✅ 结果查询 API（列表、得分、摘要）
  - ✅ Dashboard API（统计信息）
  - ✅ 认证 API（登录、登出、用户信息）
- ✅ 基线得分计算和缓存机制
- ✅ 错误处理和重试逻辑

**ServiceDiscovery**：
- ⏸️ Phase 1 简化实现（Agent 直接使用配置地址）

#### 1.3 部署与测试 ✅

**打包与部署**：
- ✅ Agent 构建脚本（支持构建时嵌入 Server 地址）
- ✅ Agent 安装脚本（一键安装）
- ✅ Agent 打包脚本（RPM/DEB）
- ✅ systemd service 文件
- ✅ Server Docker Compose 配置
- ✅ 证书生成脚本（mTLS）

**测试**：
- ✅ Agent 单元测试
- ✅ 插件管理单元测试
- ✅ Baseline Plugin 单元测试（所有检查器测试通过）
- ✅ Manager API 集成测试
- ✅ 端到端测试（Agent + Server + Plugin 完整流程）

**文档**：
- ✅ Agent 部署文档
- ✅ Agent 配置设计文档
- ✅ Server 部署文档
- ✅ Server 配置文档
- ✅ 插件开发文档

#### 1.4 UI 开发 ✅

- ✅ 前端项目基础结构（Vue3 + TypeScript + Pinia + Ant Design Vue）
- ✅ API 客户端封装
- ✅ 登录界面和安全认证（JWT Token）
- ✅ Dashboard 页面（统计概览）
- ✅ 主机列表页面（筛选、基线得分、分页）
- ✅ 主机详情页面（基本信息、基线得分、检查结果列表）
- ✅ 策略管理页面（列表、创建、编辑、删除、启用/禁用）
- ✅ 策略详情页面（检查概览、检查项视角、影响的主机列表）
- ✅ 扫描任务管理页面（列表、创建、执行任务）
- ✅ Layout 布局（左侧导航栏、顶部栏）

---

### Phase 2: 功能完善 🔄

**目标**：扩展功能，完善基线检查能力

#### 2.1 Agent 增强

- ✅ 插件热更新机制 - 已完成：平滑切换、回滚机制
- ✅ 插件版本管理 - 已完成：语义化版本比较、版本解析
- ✅ 更多检查器实现：
  - ✅ `file_owner`（文件属主检查）- 已完成
  - ✅ `package_installed`（软件包检查）- 已完成
- ✅ 检查结果本地缓存（断网时暂存）- 已完成：本地文件缓存、自动重试
- ✅ 资源监控与上报 - 已完成：CPU、内存、磁盘、网络指标

#### 2.2 Server 增强

- ✅ 策略管理 API（CRUD）
- ✅ 主机管理 API（列表、详情）
- ✅ 检测结果查询 API（按主机、按规则、按策略）
- ✅ 扫描任务管理 API（创建、执行、查询）
- ✅ 统计与聚合（基线得分、通过率等）

#### 2.3 Collector Plugin 开发

- ⏳ 插件入口（main.go）
- ⏳ 插件 SDK 集成
- ⏳ 采集引擎（engine）
- ⏳ 基础采集器实现：
  - ⏳ 进程采集（ProcessHandler）
  - ⏳ 端口采集（PortHandler）
  - ⏳ 账户采集（UserHandler）
- ⏳ 完整采集器实现：
  - ⏳ 软件包采集（SoftwareHandler）
  - ⏳ 容器采集（ContainerHandler）
  - ⏳ 应用采集（AppHandler）
  - ⏳ 硬件采集（NetInterfaceHandler、VolumeHandler）
  - ⏳ 内核模块采集（KmodHandler）
  - ⏳ 系统服务采集（ServiceHandler）
  - ⏳ 定时任务采集（CronHandler）
- ⏳ 资产数据上报

#### 2.4 UI 增强

- ⏳ 统计报表页面
- ⏳ 图表展示（趋势图）
- ⏳ 批量操作功能
- ⏳ 导出功能

---

### Phase 3: 扩展功能 ⏳

**目标**：扩展中间件基线、高级特性、集成对接

#### 3.1 中间件基线

- ⏳ Nginx 基线检查
- ⏳ Redis 基线检查
- ⏳ MySQL 基线检查
- ⏳ 其他中间件基线

#### 3.2 高级特性

- ⏳ 策略版本管理
- ⏳ 规则依赖关系
- ⏳ 自定义检查器（脚本/插件）
- ⏳ 插件市场（第三方插件支持）
- ⏳ 插件权限控制

#### 3.3 集成与对接

- ⏳ Prometheus 指标导出
- ⏳ 告警对接（Webhook、Lark、邮件等）
- ⏳ CMDB 集成
- ⏳ 日志系统集成（ELK/Loki）

---

## 3. 当前完成进度

### 3.1 整体进度

| 阶段 | 完成度 | 状态 |
|------|--------|------|
| **Phase 0** | 100% | ✅ 已完成 |
| **Phase 1** | 95% | ✅ 基本完成 |
| **Phase 2** | 30% | 🔄 进行中 |
| **Phase 3** | 0% | ⏳ 未开始 |

### 3.2 模块完成情况

| 模块 | 完成度 | 状态 |
|------|--------|------|
| **Agent** | 100% | ✅ 已完成 |
| **AgentCenter** | 100% | ✅ 已完成 |
| **Manager** | 100% | ✅ 已完成 |
| **ServiceDiscovery** | 0% | ⏸️ 可选（Phase 1 简化） |
| **Baseline Plugin** | 100% | ✅ 已完成 |
| **Collector Plugin** | 0% | ⏳ Phase 2 |
| **UI (Console)** | 90% | ✅ 基本完成 |

### 3.3 功能完成情况

#### ✅ 已完成功能

1. **Agent 核心功能**
   - ✅ 配置管理（构建时嵌入）
   - ✅ 日志系统（Zap，JSON 输出，按天轮转）
   - ✅ 连接管理（mTLS、gRPC、重连）
   - ✅ 心跳上报（主机信息、Agent 状态、插件状态）
   - ✅ 插件管理（生命周期、Pipe 通信、配置同步）
   - ✅ 数据传输（双向流、数据打包、命令接收）

2. **Baseline Plugin**
   - ✅ 策略加载与解析
   - ✅ OS 匹配逻辑
   - ✅ 规则执行框架
   - ✅ 6 种检查器（file_kv、file_permission、file_line_match、command_exec、sysctl、service_status）
   - ✅ 结果生成与上报
   - ✅ 示例规则（SSH、密码策略、文件权限）

3. **Server 核心功能**
   - ✅ AgentCenter（gRPC Server、数据接收、任务下发）
   - ✅ Manager（HTTP API、策略管理、任务管理、结果查询）
   - ✅ 数据库模型（hosts、policies、rules、scan_results、scan_tasks）
   - ✅ 基线得分计算和缓存
   - ✅ 任务状态自动更新

4. **UI 核心功能**
   - ✅ 登录认证（JWT Token）
   - ✅ Dashboard（统计概览）
   - ✅ 主机管理（列表、详情、基线得分）
   - ✅ 策略管理（CRUD、启用/禁用）
   - ✅ 策略详情（检查概览、检查项视角、影响的主机列表）
   - ✅ 任务管理（创建、执行、查询）

#### ⏳ 待完成功能

1. **Phase 2 功能**
   - ⏳ Collector Plugin（资产采集）
   - ⏳ 更多检查器（file_owner、package_installed）
   - ⏳ 插件热更新机制
   - ⏳ 检查结果本地缓存
   - ⏳ 统计报表页面
   - ⏳ 图表展示

2. **Phase 3 功能**
   - ⏳ 中间件基线（Nginx、Redis、MySQL）
   - ⏳ 策略版本管理
   - ⏳ 告警对接
   - ⏳ CMDB 集成
   - ⏳ Prometheus 指标导出

---

## 4. 下一步计划

### 4.1 短期目标（Phase 2）

1. **Collector Plugin 开发**（优先级：P1）
   - 实现基础采集器（进程、端口、账户）
   - 实现资产数据上报
   - 实现资产数据查询 API

2. **更多检查器实现**（优先级：P2）
   - `file_owner` 检查器
   - `package_installed` 检查器

3. **UI 增强**（优先级：P2）
   - 统计报表页面
   - 图表展示（趋势图）
   - 批量操作功能

### 4.2 中期目标（Phase 3）

1. **中间件基线**（优先级：P1）
   - Nginx 基线检查
   - Redis 基线检查
   - MySQL 基线检查

2. **高级特性**（优先级：P2）
   - 策略版本管理
   - 规则依赖关系
   - 自定义检查器

3. **集成对接**（优先级：P2）
   - Prometheus 指标导出
   - 告警对接（Webhook、Lark、邮件）
   - CMDB 集成

---

## 5. 总结

### 5.1 项目状态

- **Phase 1 MVP 基本完成** ✅
  - 核心模块（Agent、AgentCenter、Manager、Baseline Plugin、UI）已实现
  - 端到端流程已打通（Agent → Server → 数据库 → UI）
  - 基础功能可用（基线检查、策略管理、任务管理）

- **Phase 2 功能完善进行中** 🔄
  - Collector Plugin 待开发
  - 更多检查器待实现
  - UI 增强待完成

- **Phase 3 扩展功能未开始** ⏳
  - 中间件基线待开发
  - 高级特性待实现
  - 集成对接待完成

### 5.2 核心成就

1. ✅ **完整的 Agent + Server 架构**：参考 Elkeid，实现了插件化架构
2. ✅ **6 种基线检查器**：覆盖文件、命令、系统配置等检查场景
3. ✅ **完整的 UI 界面**：主机管理、策略管理、任务管理、Dashboard
4. ✅ **端到端测试通过**：验证了完整的数据流

### 5.3 下一步重点

1. **Collector Plugin 开发**：实现资产采集功能
2. **更多检查器**：扩展基线检查能力
3. **中间件基线**：支持 Nginx、Redis、MySQL 等中间件基线检查

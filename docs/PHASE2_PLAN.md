# Phase 2 开发计划

> Phase 2: 功能完善阶段 - 详细任务分解和开发计划

---

## 📋 总体目标

Phase 2 的主要目标是：
1. **实现 Collector Plugin（资产采集插件）** - 优先级 P1
2. **扩展 Baseline Plugin 检查器能力** - 优先级 P2
3. **增强 Agent 功能**（热更新、版本管理、本地缓存等）- 优先级 P2
4. **完善 Server 端资产数据管理** - 优先级 P1
5. **增强 UI 功能**（报表、图表、批量操作、导出）- 优先级 P2

---

## 🎯 开发优先级

### P1（必须完成）
- Collector Plugin 开发（基础采集器：进程、端口、账户）
- Server 端资产数据模型和存储
- Server 端资产数据查询 API

### P2（重要，但可延后）
- Collector Plugin 完整采集器（软件包、容器、应用、硬件等）
- 更多 Baseline 检查器（file_owner、package_installed）
- Agent 增强功能（热更新、版本管理、本地缓存）
- UI 增强功能（报表、图表、批量操作、导出）

---

## 📦 任务 1：Collector Plugin 开发（P1）

### 1.1 项目结构设计

```
plugins/collector/
├── main.go                    # 插件入口
├── engine/                    # 采集引擎
│   ├── engine.go             # 引擎核心（定时采集、任务触发）
│   ├── models.go             # 数据模型（Asset 结构）
│   └── handlers/             # 采集器实现
│       ├── process.go        # 进程采集器
│       ├── port.go           # 端口采集器
│       ├── user.go           # 账户采集器
│       ├── software.go       # 软件包采集器（Phase 2 完整版）
│       ├── container.go      # 容器采集器（Phase 2 完整版）
│       ├── app.go            # 应用采集器（Phase 2 完整版）
│       ├── network.go        # 网卡采集器（Phase 2 完整版）
│       ├── volume.go         # 磁盘采集器（Phase 2 完整版）
│       ├── kmod.go           # 内核模块采集器（Phase 2 完整版）
│       ├── service.go        # 系统服务采集器（Phase 2 完整版）
│       └── cron.go           # 定时任务采集器（Phase 2 完整版）
└── README.md                 # 插件说明文档
```

### 1.2 插件入口（main.go）

**功能**：
- 初始化插件客户端（plugins.Client）
- 启动采集引擎
- 接收 Agent 下发的采集任务
- 上报资产数据

**实现步骤**：
1. 创建 `plugins/collector/main.go`
2. 集成插件 SDK（plugins.Client）
3. 实现任务接收循环（ReceiveTask）
4. 实现数据上报逻辑（SendRecord）
5. 启动采集引擎

**预计时间**：0.5 天

### 1.3 采集引擎（engine.go）

**功能**：
- 管理所有采集器
- 支持定时采集（按配置的间隔）
- 支持任务触发采集（接收 Agent 任务）
- 统一的数据上报接口

**实现步骤**：
1. 定义 `Engine` 结构体
2. 实现采集器注册机制（RegisterHandler）
3. 实现定时采集调度（goroutine + ticker）
4. 实现任务触发采集（根据任务类型调用对应采集器）
5. 实现数据序列化和上报

**预计时间**：1 天

### 1.4 数据模型（models.go）

**功能**：
- 定义统一的资产数据模型（Asset）
- 定义各类型资产的具体结构（Process、Port、User 等）
- 提供序列化方法（JSON/Protobuf）

**实现步骤**：
1. 定义 `Asset` 基础结构（包含通用字段：host_id、collected_at 等）
2. 定义各类型资产结构：
   - `ProcessAsset`（PID、命令行、可执行文件、MD5、容器 ID 等）
   - `PortAsset`（协议、端口、PID、进程名、容器 ID 等）
   - `UserAsset`（用户名、UID、GID、主目录、shell 等）
   - 其他类型（后续扩展）
3. 实现序列化方法

**预计时间**：0.5 天

### 1.5 进程采集器（ProcessHandler）

**功能**：
- 采集所有进程信息
- 读取 `/proc/{pid}/` 目录
- 提取进程基本信息（PID、PPID、命令行、可执行文件路径等）
- 计算可执行文件 MD5（可选）
- 检测容器关联（通过 cgroup、namespace 等）

**实现步骤**：
1. 实现 `ProcessHandler` 结构体
2. 实现 `Collect()` 方法：
   - 遍历 `/proc` 目录
   - 读取 `/proc/{pid}/cmdline`、`/proc/{pid}/exe`、`/proc/{pid}/stat` 等
   - 解析进程信息
   - 检测容器关联（读取 `/proc/{pid}/cgroup`）
   - 计算 MD5（如果可执行文件存在）
3. 返回 `[]*ProcessAsset`

**预计时间**：1.5 天

**参考**：
- Elkeid Collector Plugin 的进程采集实现
- Linux `/proc` 文件系统文档

### 1.6 端口采集器（PortHandler）

**功能**：
- 采集所有监听端口（TCP/UDP）
- 读取 `/proc/net/tcp`、`/proc/net/udp` 等
- 关联进程信息（通过 `/proc/net/tcp` 的 inode 关联到进程）
- 检测容器关联

**实现步骤**：
1. 实现 `PortHandler` 结构体
2. 实现 `Collect()` 方法：
   - 读取 `/proc/net/tcp`、`/proc/net/udp`、`/proc/net/tcp6`、`/proc/net/udp6`
   - 解析端口信息（协议、端口、状态、inode）
   - 通过 inode 关联到进程（遍历 `/proc/{pid}/fd/`）
   - 检测容器关联
3. 返回 `[]*PortAsset`

**预计时间**：1.5 天

**参考**：
- Elkeid Collector Plugin 的端口采集实现
- Linux 网络状态文件格式

### 1.7 账户采集器（UserHandler）

**功能**：
- 采集系统账户信息
- 读取 `/etc/passwd`、`/etc/shadow`（如果可读）
- 提取用户基本信息（用户名、UID、GID、主目录、shell 等）
- 检测 sudoers 配置（可选）

**实现步骤**：
1. 实现 `UserHandler` 结构体
2. 实现 `Collect()` 方法：
   - 读取 `/etc/passwd`（解析用户列表）
   - 读取 `/etc/shadow`（如果可读，提取密码策略信息）
   - 读取 `/etc/group`（解析组信息）
   - 检测 sudoers 配置（`/etc/sudoers`、`/etc/sudoers.d/*`）
3. 返回 `[]*UserAsset`

**预计时间**：1 天

**参考**：
- Linux 用户管理文档
- Elkeid Collector Plugin 的账户采集实现

### 1.8 软件包采集器（SoftwareHandler）- Phase 2 完整版

**功能**：
- 采集系统软件包信息
- 支持 RPM（`rpm -qa`）和 DEB（`dpkg -l`）
- 提取包名、版本、架构等信息

**预计时间**：1 天

### 1.9 容器采集器（ContainerHandler）- Phase 2 完整版

**功能**：
- 采集容器信息（Docker、containerd）
- 读取容器运行时 API 或文件系统
- 提取容器 ID、镜像、状态等信息

**预计时间**：1.5 天

### 1.10 其他采集器（Phase 2 完整版）

- **应用采集器（AppHandler）**：检测数据库、消息队列、Web 服务等（1.5 天）
- **硬件采集器（NetInterfaceHandler、VolumeHandler）**：采集网卡、磁盘信息（1 天）
- **内核模块采集器（KmodHandler）**：采集已加载的内核模块（0.5 天）
- **系统服务采集器（ServiceHandler）**：采集 systemd/SysV 服务信息（1 天）
- **定时任务采集器（CronHandler）**：采集 crontab 定时任务（0.5 天）

---

## 🗄️ 任务 2：Server 端资产数据管理（P1）

### 2.1 数据库模型设计

**需要创建的表**：
- `processes`（进程表）
- `ports`（端口表）
- `users`（账户表）
- `software`（软件包表）
- `containers`（容器表）
- `apps`（应用表）
- `network_interfaces`（网卡表）
- `volumes`（磁盘表）
- `kernel_modules`（内核模块表）
- `services`（系统服务表）
- `cron_jobs`（定时任务表）

**实现步骤**：
1. 在 `internal/server/model/` 目录下创建各资产模型文件
2. 定义 Gorm 模型结构
3. 编写数据库迁移脚本（AutoMigrate）
4. 创建索引（host_id、collected_at 等）

**预计时间**：1 天

### 2.2 AgentCenter 资产数据接收

**功能**：
- 在 AgentCenter 的 Transfer 服务中处理资产数据
- 根据 `data_type` 路由到对应的处理器
- 解析资产数据并存储到数据库

**实现步骤**：
1. 在 `internal/server/agentcenter/transfer/service.go` 中添加资产数据处理逻辑
2. 实现各类型资产数据的解析（反序列化）
3. 实现各类型资产数据的存储（批量插入，支持去重）
4. 处理数据更新策略（全量替换 vs 增量更新）

**预计时间**：1.5 天

### 2.3 Manager 资产数据查询 API

**功能**：
- 提供资产数据查询接口（按主机、按类型）
- 支持分页、筛选、排序

**API 接口**：
- `GET /api/v1/assets/processes` - 获取进程列表
- `GET /api/v1/assets/ports` - 获取端口列表
- `GET /api/v1/assets/users` - 获取账户列表
- `GET /api/v1/assets/software` - 获取软件包列表
- `GET /api/v1/assets/containers` - 获取容器列表
- 其他类型资产接口...

**实现步骤**：
1. 在 `internal/server/manager/api/` 目录下创建 `assets.go`
2. 实现各类型资产的查询接口
3. 实现分页、筛选、排序逻辑
4. 添加 API 文档注释

**预计时间**：1.5 天

---

## 🔍 任务 3：Baseline Plugin 扩展（P2）

### 3.1 file_owner 检查器

**功能**：
- 检查文件属主（uid:gid）
- 支持用户名/组名解析
- 支持期望值匹配（等于、不等于）

**实现步骤**：
1. 在 `plugins/baseline/engine/checkers.go` 中实现 `FileOwnerChecker`
2. 实现 `Check()` 方法：
   - 读取文件 stat 信息
   - 获取 UID、GID
   - 解析用户名/组名（可选）
   - 与期望值比较
3. 编写单元测试
4. 注册到 Engine

**预计时间**：0.5 天

### 3.2 package_installed 检查器

**功能**：
- 检查软件包是否安装
- 支持 RPM（`rpm -q`）和 DEB（`dpkg -l`）
- 支持版本比较（>=、<=、==）

**实现步骤**：
1. 在 `plugins/baseline/engine/checkers.go` 中实现 `PackageInstalledChecker`
2. 实现 `Check()` 方法：
   - 检测系统类型（RPM/DEB）
   - 执行包查询命令
   - 解析版本信息
   - 与期望版本比较
3. 编写单元测试
4. 注册到 Engine

**预计时间**：1 天

---

## 🤖 任务 4：Agent 增强功能（P2）

### 4.1 插件热更新机制

**功能**：
- 支持插件升级时无需重启 Agent
- 平滑切换插件版本

**实现步骤**：
1. 在插件管理模块中实现版本检测
2. 实现插件升级流程（下载新版本 → 停止旧版本 → 启动新版本）
3. 确保升级过程中数据不丢失
4. 添加回滚机制（升级失败时回滚）

**预计时间**：2 天

### 4.2 插件版本管理

**功能**：
- 版本比较逻辑（语义化版本）
- 升级策略配置（自动升级、手动升级）
- 版本历史记录

**预计时间**：1 天

### 4.3 检查结果本地缓存

**功能**：
- 断网时暂存检查结果
- 网络恢复后自动上报
- 缓存大小限制和清理策略

**实现步骤**：
1. 实现本地缓存存储（文件或内存）
2. 实现缓存写入逻辑（发送失败时写入缓存）
3. 实现缓存读取和上报逻辑（网络恢复时）
4. 实现缓存清理策略（大小限制、时间限制）

**预计时间**：1.5 天

### 4.4 资源监控与上报

**功能**：
- 监控 Agent 资源使用情况（CPU、内存、磁盘、网络）
- 定期上报资源指标到 Server

**预计时间**：1 天

---

## 🎨 任务 5：UI 增强功能（P2）

### 5.1 统计报表页面

**功能**：
- 展示整体统计信息（主机数、基线得分分布、风险项统计等）
- 支持时间范围筛选
- 支持导出报表

**预计时间**：2 天

### 5.2 图表展示

**功能**：
- 基线得分趋势图（折线图）
- 风险项分布图（饼图）
- 主机状态分布图（柱状图）

**预计时间**：1.5 天

### 5.3 批量操作功能

**功能**：
- 批量创建扫描任务
- 批量导出结果
- 批量操作主机

**预计时间**：1.5 天

### 5.4 导出功能

**功能**：
- 导出为 Excel
- 导出为 CSV
- 导出为 PDF（可选）

**预计时间**：1.5 天

---

## 📅 开发时间估算

### Phase 2.1：Collector Plugin 基础版（P1）
- 插件入口：0.5 天
- 采集引擎：1 天
- 数据模型：0.5 天
- 进程采集器：1.5 天
- 端口采集器：1.5 天
- 账户采集器：1 天
- **小计**：6 天

### Phase 2.2：Server 端资产数据管理（P1）
- 数据库模型：1 天
- AgentCenter 数据接收：1.5 天
- Manager API：1.5 天
- **小计**：4 天

### Phase 2.3：Collector Plugin 完整版（P2）
- 软件包采集器：1 天
- 容器采集器：1.5 天
- 应用采集器：1.5 天
- 硬件采集器：1 天
- 内核模块采集器：0.5 天
- 系统服务采集器：1 天
- 定时任务采集器：0.5 天
- **小计**：7 天

### Phase 2.4：Baseline Plugin 扩展（P2）
- file_owner 检查器：0.5 天
- package_installed 检查器：1 天
- **小计**：1.5 天

### Phase 2.5：Agent 增强（P2）
- 插件热更新：2 天
- 插件版本管理：1 天
- 本地缓存：1.5 天
- 资源监控：1 天
- **小计**：5.5 天

### Phase 2.6：UI 增强（P2）
- 统计报表：2 天
- 图表展示：1.5 天
- 批量操作：1.5 天
- 导出功能：1.5 天
- **小计**：6.5 天

### 总计
- **P1 任务**：10 天
- **P2 任务**：26.5 天
- **总计**：36.5 天（约 7-8 周）

---

## 🚀 推荐开发顺序

### 第一阶段（Week 1-2）：Collector Plugin 基础版 + Server 端支持
1. ✅ Collector Plugin 入口和引擎
2. ✅ 进程、端口、账户采集器
3. ✅ Server 端资产数据模型和存储
4. ✅ Server 端资产数据查询 API

### 第二阶段（Week 3-4）：Collector Plugin 完整版
1. ✅ 软件包、容器、应用采集器
2. ✅ 硬件、内核模块、系统服务、定时任务采集器

### 第三阶段（Week 5）：Baseline Plugin 扩展
1. ✅ file_owner 检查器
2. ✅ package_installed 检查器

### 第四阶段（Week 6-7）：Agent 增强
1. ✅ 插件热更新机制
2. ✅ 插件版本管理
3. ✅ 检查结果本地缓存
4. ✅ 资源监控与上报

### 第五阶段（Week 8）：UI 增强
1. ✅ 统计报表页面
2. ✅ 图表展示
3. ✅ 批量操作功能
4. ✅ 导出功能

---

## 📝 注意事项

1. **参考 Elkeid 实现**：
   - 参考 Elkeid Collector Plugin 的实现思路
   - 不直接复制代码，而是理解设计思想后自己实现

2. **测试覆盖**：
   - 每个采集器都要有单元测试
   - 端到端测试验证完整流程

3. **性能考虑**：
   - 采集器要考虑性能影响（避免频繁采集）
   - 数据库批量插入优化

4. **错误处理**：
   - 采集失败要有错误处理和日志记录
   - 网络异常要有重试机制

5. **文档更新**：
   - 及时更新 API 文档
   - 更新插件开发文档
   - 更新部署文档

---

## ✅ 验收标准

### Collector Plugin 基础版
- [ ] 插件可以正常启动和运行
- [ ] 进程、端口、账户采集器可以正常采集数据
- [ ] 采集的数据可以正常上报到 Server
- [ ] Server 可以正常存储和查询资产数据

### Collector Plugin 完整版
- [ ] 所有采集器都已实现
- [ ] 所有采集器都有单元测试
- [ ] 端到端测试通过

### Server 端资产数据管理
- [ ] 所有资产表都已创建
- [ ] AgentCenter 可以正常接收和存储资产数据
- [ ] Manager API 可以正常查询资产数据

### Baseline Plugin 扩展
- [ ] file_owner 检查器可以正常工作
- [ ] package_installed 检查器可以正常工作
- [ ] 两个检查器都有单元测试

### Agent 增强
- [ ] 插件热更新机制可以正常工作
- [ ] 插件版本管理可以正常工作
- [ ] 本地缓存可以正常工作
- [ ] 资源监控可以正常上报

### UI 增强
- [ ] 统计报表页面可以正常展示
- [ ] 图表可以正常展示
- [ ] 批量操作功能可以正常使用
- [ ] 导出功能可以正常使用

---

## 📚 参考文档

- [Elkeid Collector Plugin 源码](../Elkeid/plugins/collector/)
- [插件开发指南](./development/plugin-development.md)
- [Server API 设计](./design/server-api.md)
- [Agent 架构设计](./design/agent-architecture.md)

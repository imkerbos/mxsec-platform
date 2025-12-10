# Matrix Cloud Security Platform - 功能清单

> 本文档列出当前项目已实现的功能模块和特性。

---

## 1. mxsec-agent（Agent 主程序）

### 1.1 基础框架 ✅
- ✅ **配置管理**
  - 构建时嵌入配置（Server 地址、版本信息通过 `-ldflags` 嵌入）
  - 无需配置文件，安装后即可运行
  - 证书由 Server 首次连接时自动下发
- ✅ **日志系统**
  - 使用 Zap 结构化日志
  - JSON 格式输出
  - 按天轮转（`agent.log.YYYY-MM-DD`）
  - 保留 30 天日志
  - 默认路径：`/var/log/mxsec-agent/agent.log`
- ✅ **Agent ID 管理**
  - 从文件读取或生成唯一 Agent ID
  - 存储路径：`/var/lib/mxsec-agent/agent_id`
- ✅ **信号处理**
  - 支持 SIGTERM、SIGINT
  - 优雅退出（清理资源、停止插件）

### 1.2 连接管理 ✅
- ✅ **服务发现**
  - 简化实现，直接使用配置的 Server 地址
  - 支持连接重试和故障转移
- ✅ **mTLS 配置**
  - 双向 TLS 认证
  - 证书由 Server 下发到 `/var/lib/mxsec-agent/certs/`
  - 支持证书自动更新
- ✅ **gRPC 连接**
  - 与 AgentCenter 建立双向流连接
  - 连接状态管理
  - 自动重连机制

### 1.3 传输模块 ✅
- ✅ **gRPC 双向流**
  - `Transfer` 服务实现
  - 数据打包与发送（PackagedData）
  - 命令接收与处理（Command）
- ✅ **数据发送**
  - 心跳数据（DataType=1000）
  - 插件状态（DataType=1001）
  - 基线检查结果（DataType=8000）
  - 资产数据（DataType=5050-5064）
- ✅ **配置更新处理**
  - Agent 配置更新（AgentConfig）
  - 证书包更新（CertificateBundle）
  - 插件配置更新（Config）

### 1.4 心跳模块 ✅
- ✅ **定时心跳**
  - 默认间隔 60 秒（可由 Server 配置）
  - 自动上报主机信息
- ✅ **状态采集**
  - Agent 状态（CPU、内存、启动时间）
  - 主机信息（OS、内核版本、IP、主机名）
  - 插件状态（运行状态、版本）
- ✅ **主机信息采集**
  - 读取 `/etc/os-release` 获取 OS 信息
  - 读取 `/proc/version` 获取内核版本
  - 读取网络接口获取 IP 地址
  - 获取主机名

### 1.5 插件管理 ✅
- ✅ **插件配置同步**
  - 从 Server 接收插件配置（名称、版本、SHA256、下载地址）
  - 支持插件配置更新
- ✅ **插件下载与验证**
  - HTTP 下载插件
  - SHA256 校验
  - 自动重试机制
  - 设置可执行权限
- ✅ **插件生命周期管理**
  - 启动插件进程（创建 Pipe 管道）
  - 停止插件
  - 重启插件
  - 升级插件
- ✅ **插件通信**
  - 创建 rx/tx 管道（文件描述符 3/4）
  - 接收插件数据（从 Pipe 读取）
  - 发送任务到插件（写入 Pipe）
  - 使用 Protobuf 序列化
  - Agent 不解析插件数据，直接透传到 Server

### 1.6 任务处理 ✅
- ✅ **任务接收**
  - 从 Server 接收任务（Command）
  - 按插件名称分发任务
- ✅ **任务执行**
  - 将任务序列化并发送到对应插件
  - 支持基线检查任务
  - 支持资产采集任务

---

## 2. AgentCenter（gRPC Server）

### 2.1 基础框架 ✅
- ✅ **主程序入口**
  - `cmd/server/agentcenter/main.go`
  - 配置加载（Viper + YAML）
  - 日志初始化（Zap，JSON 输出）
- ✅ **gRPC Server**
  - 监听端口（默认 6751）
  - mTLS 配置（CA、证书、密钥）
  - 支持证书生成脚本
- ✅ **数据库连接**
  - Gorm + MySQL/PostgreSQL
  - 自动迁移数据库表

### 2.2 Transfer 服务 ✅
- ✅ **双向流通信**
  - 实现 `Transfer` 服务接口
  - 接收 Agent 数据流（`stream PackagedData`）
  - 发送命令流（`stream Command`）
- ✅ **连接状态管理**
  - Map[agent_id]*Connection 管理连接
  - 连接断开处理（清理连接状态）

### 2.3 数据接收与处理 ✅
- ✅ **数据解析**
  - 解析 `PackagedData` 和 `EncodedRecord`
  - 根据 `data_type` 路由到不同处理器
- ✅ **心跳数据处理**
  - DataType=1000：心跳数据
  - 更新 `hosts` 表（主机信息、状态、最后心跳时间）
  - 自动注册新主机
- ✅ **基线检查结果处理**
  - DataType=8000：基线检查结果
  - 插入 `scan_results` 表
  - 更新任务状态
- ✅ **资产数据处理**（待实现）
  - DataType=5050-5064：资产数据
  - 插入对应资产表（processes、ports、users 等）

### 2.4 任务下发 ✅
- ✅ **任务查询**
  - 查询 `scan_tasks` 表，获取待执行任务
  - 任务调度器（每 30 秒检查一次）
- ✅ **任务封装与发送**
  - 封装为 `Command` 并发送到 Agent
  - 按 Agent ID 分发任务
- ✅ **任务状态更新**
  - 自动更新任务状态（pending → running → completed/failed）
  - 记录任务执行时间

### 2.5 业务服务 ✅
- ✅ **策略管理服务**
  - 策略 CRUD 操作
  - 规则 CRUD 操作
  - 根据主机信息查询适用策略
- ✅ **错误处理与重试**
  - 错误处理逻辑
  - 重试机制

---

## 3. Manager（HTTP API Server）

### 3.1 基础框架 ✅
- ✅ **主程序入口**
  - `cmd/server/manager/main.go`
  - 配置加载（Viper + YAML）
  - 日志初始化（Zap，JSON 输出）
- ✅ **HTTP Server**
  - Gin 框架
  - 默认端口 8080
  - 中间件（CORS、日志、Recovery）
- ✅ **数据库连接**
  - Gorm + MySQL/PostgreSQL

### 3.2 主机管理 API ✅
- ✅ **GET /api/v1/hosts**
  - 获取主机列表
  - 支持分页（page、page_size）
  - 支持过滤（os_family、status）
  - 返回基线得分、通过率
- ✅ **GET /api/v1/hosts/{host_id}**
  - 获取主机详情
  - 包含基本信息、基线得分、检查结果列表

### 3.3 策略管理 API ✅
- ✅ **GET /api/v1/policies**
  - 获取策略列表
  - 支持过滤（os_family、enabled）
- ✅ **POST /api/v1/policies**
  - 创建策略
  - 支持策略名称、描述、OS 匹配条件
- ✅ **PUT /api/v1/policies/{policy_id}**
  - 更新策略
  - 支持修改策略信息、规则列表
- ✅ **DELETE /api/v1/policies/{policy_id}**
  - 删除策略
- ✅ **GET /api/v1/policies/{policy_id}/statistics**
  - 获取策略统计信息
  - 返回通过率、主机数、检查项数、风险项数、最近检查时间

### 3.4 扫描任务管理 API ✅
- ✅ **POST /api/v1/tasks**
  - 创建扫描任务
  - 支持任务名称、策略 ID、目标主机、调度配置
- ✅ **GET /api/v1/tasks**
  - 获取任务列表
  - 支持分页、过滤
- ✅ **POST /api/v1/tasks/{task_id}/run**
  - 执行任务
  - 立即触发任务执行

### 3.5 检测结果查询 API ✅
- ✅ **GET /api/v1/results**
  - 获取检测结果列表
  - 支持过滤（host_id、policy_id、rule_id、status、severity、时间范围）
  - 支持分页
- ✅ **GET /api/v1/results/host/{host_id}/score**
  - 获取主机基线得分
  - 返回得分、通过率、风险项数
- ✅ **GET /api/v1/results/host/{host_id}/summary**
  - 获取主机基线摘要
  - 返回按严重级别统计的结果

### 3.6 认证 API ✅
- ✅ **POST /api/v1/auth/login**
  - 用户登录
  - 返回 JWT Token
- ✅ **POST /api/v1/auth/logout**
  - 用户登出
- ✅ **GET /api/v1/auth/me**
  - 获取当前用户信息
  - 需要 Bearer Token 认证

### 3.7 Dashboard API ✅
- ✅ **GET /api/v1/dashboard/stats**
  - 获取 Dashboard 统计数据
  - 返回主机数、在线/离线 Agent 数、基线失败数、加固百分比等

### 3.8 业务逻辑 ✅
- ✅ **基线得分计算**
  - 根据检查结果计算基线得分
  - 支持缓存机制（Redis 或内存缓存）
  - 按严重级别加权计算
- ✅ **任务状态自动更新**
  - 自动更新任务状态
  - 记录任务执行时间
- ✅ **错误处理和重试**
  - 统一的错误处理
  - 重试逻辑

---

## 4. Baseline Plugin（基线检查插件）

### 4.1 基础功能 ✅
- ✅ **插件入口**
  - `plugins/baseline/main.go`
  - 通过 Pipe 与 Agent 通信
- ✅ **插件 SDK 集成**
  - 使用 `plugins.Client` 与 Agent 通信
  - 接收任务、上报结果

### 4.2 策略处理 ✅
- ✅ **策略加载与解析**
  - 支持 JSON 格式的策略配置
  - 从 Server 接收策略或本地文件加载
- ✅ **OS 匹配逻辑**
  - 支持 `os_family` 匹配（rocky、centos、debian 等）
  - 支持 `os_version` 匹配（>=、<=、==、>、<）
  - `MatchOS` 方法实现

### 4.3 规则执行 ✅
- ✅ **规则执行框架**
  - `Engine.Execute` 执行策略
  - `executeRule` 执行单条规则
  - `executeCheck` 执行检查器
- ✅ **结果生成**
  - 生成检查结果（pass/fail/warn/na）
  - 记录实际值、期望值
  - 上报到 Agent

### 4.4 检查器实现 ✅
- ✅ **file_kv**（配置文件键值检查）
  - 支持多种键值格式（key=value、key value 等）
  - 支持正则匹配
- ✅ **file_line_match**（文件行匹配）
  - 支持正则匹配
  - 支持匹配/不匹配检查
- ✅ **file_permission**（文件权限检查）
  - 支持 8 进制权限比较
  - 支持符号权限解析
- ✅ **command_exec**（命令执行）
  - 执行系统命令
  - 支持输出匹配（正则、包含、等于）
- ✅ **sysctl**（内核参数检查）
  - 读取 sysctl 参数值
  - 支持值检查和正则匹配
- ✅ **service_status**（服务状态检查）
  - 支持 systemd 服务状态检查
  - 支持 SysV 服务状态检查
- ✅ **file_owner**（文件属主检查）
  - 支持 uid:gid 格式
  - 支持 username:groupname 格式
  - 支持用户名/组名解析
- ✅ **package_installed**（软件包检查）
  - 支持 RPM 包管理器
  - 支持 DEB 包管理器
  - 支持版本约束（>=、<=、==、>、<）

### 4.5 示例规则 ✅
- ✅ **SSH 配置检查**
  - PermitRootLogin 检查
  - PasswordAuthentication 检查
  - 其他 SSH 安全配置
- ✅ **密码策略检查**
  - PASS_MAX_DAYS 检查
  - 密码复杂度检查
- ✅ **文件权限检查**
  - /etc/passwd 权限检查
  - /etc/shadow 权限检查
  - 其他关键文件权限检查

---

## 5. Collector Plugin（资产采集插件）✅

### 5.1 基础功能 ✅
- ✅ **插件入口**
  - `plugins/collector/main.go`
  - 通过 Pipe 与 Agent 通信
- ✅ **采集引擎**
  - 定时采集机制
  - 任务触发采集
  - 数据上报

### 5.2 采集器实现 ✅
- ✅ **ProcessHandler**（进程采集器）
  - 采集进程信息（PID、PPID、命令行、可执行文件路径）
  - 计算可执行文件 MD5 哈希值
  - 检测容器关联（Docker、containerd）
  - 采集间隔：1 小时
- ✅ **PortHandler**（端口采集器）
  - 采集 TCP/UDP 监听端口
  - 关联进程信息（通过 inode）
  - 检测容器关联
  - 采集间隔：1 小时
- ✅ **UserHandler**（账户采集器）
  - 采集系统账户信息（用户名、UID、GID、主目录、shell）
  - 检测密码策略（基于 /etc/shadow）
  - 采集间隔：6 小时
- ✅ **SoftwareHandler**（软件包采集器）
  - 支持 RPM 包管理器（rpm -qa）
  - 支持 DEB 包管理器（dpkg-query）
  - 采集包名、版本、架构、供应商、安装时间
  - 采集间隔：12 小时
- ✅ **ContainerHandler**（容器采集器）
  - 支持 Docker（docker ps）
  - 支持 containerd（ctr 命令或元数据目录）
  - 采集容器 ID、名称、镜像、状态等
  - 采集间隔：1 小时
- ✅ **AppHandler**（应用采集器）
  - 检测 MySQL、PostgreSQL、Redis、MongoDB
  - 检测 Nginx、Apache
  - 检测 Kafka、Elasticsearch、RabbitMQ
  - 通过进程名和端口识别应用
  - 采集间隔：6 小时
- ✅ **NetInterfaceHandler**（网卡采集器）
  - 使用 `net.Interfaces()` 获取网络接口
  - 采集 MAC 地址、IPv4/IPv6 地址、MTU、状态
  - 采集间隔：6 小时
- ✅ **VolumeHandler**（磁盘采集器）
  - 读取 `/proc/mounts` 获取挂载信息
  - 使用 `df` 命令获取磁盘使用情况
  - 过滤虚拟文件系统
  - 采集间隔：6 小时
- ✅ **KmodHandler**（内核模块采集器）
  - 读取 `/proc/modules` 获取已加载模块
  - 采集模块名、大小、引用计数、状态
  - 采集间隔：12 小时
- ✅ **ServiceHandler**（系统服务采集器）
  - 支持 systemd（systemctl list-units）
  - 支持 SysV（/etc/init.d）
  - 采集服务状态、是否启用、描述
  - 采集间隔：6 小时
- ✅ **CronHandler**（定时任务采集器）
  - 采集用户 crontab（crontab -l）
  - 采集系统 crontab（/etc/crontab、/etc/cron.d）
  - 采集 systemd timers（systemctl list-timers）
  - 采集间隔：12 小时

---

## 6. UI（前端控制台）

### 6.1 基础功能 ✅
- ✅ **项目结构**
  - Vue3 + TypeScript + Pinia + Ant Design Vue
  - API 客户端封装
- ✅ **认证系统**
  - 登录界面
  - JWT Token 认证
  - 路由守卫
  - 用户信息管理

### 6.2 页面功能 ✅
- ✅ **Dashboard 页面**
  - 统计概览（主机数、在线/离线 Agent、基线失败数等）
  - 数据可视化
- ✅ **主机列表页面**
  - 主机列表展示
  - 筛选功能（OS、状态）
  - 基线得分展示
  - 分页功能
- ✅ **主机详情页面**
  - 基本信息展示
  - 基线得分展示
  - 检查结果列表
  - 多标签页实现
- ✅ **策略管理页面**
  - 策略列表
  - 创建策略
  - 编辑策略
  - 删除策略
  - 启用/禁用策略
- ✅ **策略详情页面**
  - 检查概览（通过率、主机数、检查项数）
  - 检查项视角（规则列表和详情）
  - 影响的主机列表（显示受影响的主机及其检查结果）
- ✅ **扫描任务管理页面**
  - 任务列表
  - 创建任务
  - 执行任务
- ✅ **Layout 布局**
  - 左侧导航栏
  - 顶部栏（用户信息和退出登录）

---

## 7. 数据库模型

### 7.1 核心表 ✅
- ✅ **hosts** 表
  - 主机信息（host_id、hostname、os_family、os_version、kernel_version、arch、ipv4、status、last_heartbeat）
- ✅ **policies** 表
  - 策略集（policy_id、name、description、os_family、os_version、enabled、created_at）
- ✅ **rules** 表
  - 规则（rule_id、policy_id、category、title、description、severity、check_type、check_param、fix_suggestion）
- ✅ **scan_results** 表
  - 检测结果（id、host_id、rule_id、task_id、status、actual、expected、checked_at）
- ✅ **scan_tasks** 表
  - 扫描任务（task_id、policy_id、target_hosts、status、created_at、executed_at）

### 7.2 资产表 ✅
- ✅ **processes** 表（进程资产）
- ✅ **ports** 表（端口资产）
- ✅ **asset_users** 表（账户资产）
- ⏳ 其他资产表（Phase 2 待实现）

---

## 8. 部署与工具

### 8.1 打包脚本 ✅
- ✅ **Agent 构建脚本**
  - 支持构建时嵌入 Server 地址
  - 支持版本信息嵌入
- ✅ **Agent 安装脚本**
  - 一键安装
  - 自动下载对应架构的安装包
- ✅ **Agent 打包脚本**
  - RPM/DEB 打包（使用 nFPM）
- ✅ **证书生成脚本**
  - mTLS 证书生成（CA、Server、Agent）

### 8.2 部署配置 ✅
- ✅ **systemd service 文件**
  - Agent、AgentCenter、Manager 的 systemd 配置
- ✅ **Docker Compose 配置**
  - Server 端 Docker Compose 配置
  - 包含 MySQL、AgentCenter、Manager

---

## 9. 测试

### 9.1 单元测试 ✅
- ✅ Agent 单元测试（配置、日志、ID 管理）
- ✅ 插件管理单元测试
- ✅ Baseline Plugin 单元测试（所有检查器测试通过）

### 9.2 集成测试 ✅
- ✅ Manager API 集成测试
- ✅ 端到端测试（Agent + Server + Plugin 完整流程）

---

## 10. 文档

### 10.1 部署文档 ✅
- ✅ Agent 部署文档
- ✅ Agent 配置设计文档
- ✅ Server 部署文档
- ✅ Server 配置文档

### 10.2 开发文档 ✅
- ✅ 插件开发文档
- ✅ Agent 架构设计文档
- ✅ Baseline 策略模型设计文档
- ✅ Server API 设计文档

---

## 总结

### 已完成功能
- ✅ **Agent 核心功能**：配置管理、连接管理、心跳上报、插件管理、数据传输
- ✅ **AgentCenter**：gRPC Server、数据接收、任务下发、连接管理
- ✅ **Manager**：HTTP API、策略管理、任务管理、结果查询、认证
- ✅ **Baseline Plugin**：8 种检查器、策略加载、规则执行
- ✅ **Collector Plugin**：11 种采集器、定时采集、任务触发
- ✅ **UI**：完整的控制台界面、主机管理、策略管理、任务管理
- ✅ **数据库**：完整的数据库模型和迁移脚本
- ✅ **部署工具**：打包脚本、安装脚本、证书生成脚本

### 待实现功能（Phase 2/3）
- ⏳ 资产数据查询 API
- ⏳ 插件热更新机制
- ⏳ 检查结果本地缓存
- ⏳ 中间件基线检查（Nginx、Redis、MySQL）
- ⏳ 统计报表页面
- ⏳ 告警对接
- ⏳ Prometheus 指标导出

# Baseline 策略模型设计

> 本文档定义 Matrix Cloud Security Platform 的策略模型，参考 Elkeid 的设计，但做了简化和优化。

---

## 1. 策略模型层次

```
Policy（策略集）
  └── Rule（规则）
        └── Check（检查项）
```

- **Policy（策略集）**：一组规则的集合，通常按 OS 或合规要求划分
- **Rule（规则）**：一条基线检查规则，包含检查逻辑和元数据
- **Check（检查项）**：具体的检查执行逻辑（可包含多个子检查）

---

## 2. Policy（策略集）模型

### 2.1 字段定义

```yaml
id: "LINUX_ROCKY9_BASELINE"        # 策略集 ID（唯一标识）
name: "Rocky Linux 9 基线策略"      # 策略名称
version: "1.0.0"                    # 策略版本
description: "Rocky Linux 9 操作系统基线检查策略"
os_family: ["rocky", "centos"]      # 适用的 OS 系列
os_version: ">=9"                   # OS 版本要求（语义化版本）
enabled: true                       # 是否启用
rules:                              # 规则列表
  - rule_id: "LINUX_SSH_001"
    # ... 规则定义
```

### 2.2 OS 匹配规则

- `os_family`：OS 系列列表（如 `["rocky", "centos", "oracle"]`）
- `os_version`：版本约束（支持语义化版本，如 `">=9"`, `"7.x"`, `"8.0 - 8.9"`）

**匹配逻辑**：
1. Agent 上报的 `os_family` 必须在策略的 `os_family` 列表中
2. Agent 上报的 `os_version` 必须满足策略的 `os_version` 约束

---

## 3. Rule（规则）模型

### 3.1 字段定义

```yaml
rule_id: "LINUX_SSH_001"                    # 规则 ID（全局唯一）
category: "ssh"                             # 规则分类
title: "禁止 root 远程登录"                  # 规则标题
description: "sshd_config 中应设置 PermitRootLogin no"
severity: "high"                            # 严重级别：low/medium/high/critical
os_family: ["rocky", "centos", "oracle"]    # 可选：覆盖策略集的 OS 限制
os_version: ">=7"                           # 可选：覆盖策略集的版本限制
check:                                      # 检查定义
  condition: "all"                          # all/any/none
  rules:
    - type: "file_kv"                       # 检查类型
      # ... 检查参数
fix:                                        # 修复建议
  suggestion: "修改 /etc/ssh/sshd_config 中的 PermitRootLogin 并重启 sshd"
  command: "sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && systemctl restart sshd"
```

### 3.2 规则分类（category）

建议分类：
- `account`：账号与认证
- `ssh`：SSH 服务安全
- `permission`：权限与 sudo
- `service`：系统服务
- `log`：日志与审计
- `sysctl`：内核参数
- `file`：文件与目录权限
- `network`：网络配置
- `time`：时间同步

### 3.3 严重级别（severity）

- `low`：低风险，建议修复
- `medium`：中风险，应尽快修复
- `high`：高风险，必须修复
- `critical`：严重风险，立即修复

---

## 4. Check（检查项）模型

### 4.1 检查类型（type）

| 类型 | 说明 | 参数 | 返回值 |
|------|------|------|--------|
| `file_kv` | 检查配置文件键值对 | `[文件路径, 键名, 期望值]` | true/false |
| `file_line_match` | 文件行正则匹配 | `[文件路径, 正则表达式, 期望匹配]` | true/false |
| `file_permission` | 检查文件权限 | `[文件路径, 最小权限(8进制)]` | true/false |
| `file_owner` | 检查文件属主 | `[文件路径, uid:gid]` | true/false |
| `file_exists` | 检查文件是否存在 | `[文件路径]` | true/false |
| `command_exec` | 执行命令检查 | `[命令, 期望输出/正则]` | true/false |
| `sysctl` | 检查内核参数 | `[参数名, 期望值]` | true/false |
| `service_status` | 检查服务状态 | `[服务名, 期望状态]` | true/false |
| `package_installed` | 检查软件包安装 | `[包名, 版本约束]` | true/false |

### 4.2 检查参数示例

#### file_kv（配置文件键值检查）

```yaml
type: "file_kv"
param:
  - "/etc/ssh/sshd_config"    # 文件路径
  - "PermitRootLogin"          # 键名
  - "no"                        # 期望值（支持正则）
```

**实现逻辑**：
1. 读取配置文件
2. 解析键值对（支持 `Key Value`、`Key=Value`、`Key: Value` 等格式）
3. 忽略注释行（以 `#` 开头）
4. 匹配键名（不区分大小写）
5. 比较值与期望值（支持正则匹配）

#### file_line_match（文件行匹配）

```yaml
type: "file_line_match"
param:
  - "/etc/login.defs"          # 文件路径
  - '\s*PASS_MAX_DAYS\s+(\d+)' # 正则表达式（支持分组）
result: '$(<=)90'              # 期望结果（支持特殊语法）
```

**特殊语法**（result 字段）：
- `$(<=)90`：数值比较（<= 90）
- `$(>=)2`：数值比较（>= 2）
- `$(<)8$(&&)$(not)2`：组合条件（< 8 且 != 2）
- `$(not)error`：字符串取反
- `ok$(&&)success`：字符串 OR（包含 "ok" 或 "success"）

#### command_exec（命令执行）

```yaml
type: "command_exec"
param:
  - "sysctl net.ipv4.ip_forward"  # 命令
  - "0"                           # 期望输出（支持正则）
ignore_error: false               # 是否忽略命令错误
```

#### sysctl（内核参数）

```yaml
type: "sysctl"
param:
  - "net.ipv4.ip_forward"     # 参数名
  - "0"                        # 期望值
```

### 4.3 条件组合（condition）

- `all`：所有子检查都通过才通过
- `any`：任一子检查通过即通过
- `none`：所有子检查都不通过才通过

**示例**：

```yaml
check:
  condition: "all"
  rules:
    - type: "file_exists"
      param: ["/etc/ssh/sshd_config"]
    - type: "file_kv"
      param: ["/etc/ssh/sshd_config", "PermitRootLogin", "no"]
```

---

## 5. 策略配置示例

### 5.1 完整示例

```yaml
id: "LINUX_ROCKY9_BASELINE"
name: "Rocky Linux 9 基线策略"
version: "1.0.0"
description: "Rocky Linux 9 操作系统基线检查策略"
os_family: ["rocky", "centos"]
os_version: ">=9"
enabled: true
rules:
  - rule_id: "LINUX_SSH_001"
    category: "ssh"
    title: "禁止 root 远程登录"
    description: "sshd_config 中应设置 PermitRootLogin no"
    severity: "high"
    check:
      condition: "all"
      rules:
        - type: "file_exists"
          param: ["/etc/ssh/sshd_config"]
        - type: "file_kv"
          param: ["/etc/ssh/sshd_config", "PermitRootLogin", "no"]
    fix:
      suggestion: "修改 /etc/ssh/sshd_config 中的 PermitRootLogin 并重启 sshd"
      command: "sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && systemctl restart sshd"

  - rule_id: "LINUX_ACCOUNT_001"
    category: "account"
    title: "密码过期时间 <= 90 天"
    description: "/etc/login.defs 中 PASS_MAX_DAYS 应 <= 90"
    severity: "high"
    check:
      condition: "all"
      rules:
        - type: "file_line_match"
          param: ["/etc/login.defs", '\s*PASS_MAX_DAYS\s+(\d+)']
          result: '$(<=)90'
    fix:
      suggestion: "在 /etc/login.defs 中设置 PASS_MAX_DAYS 90"
```

### 5.2 数据库映射

策略模型需要映射到数据库表：

**policies 表**：
- `id` (VARCHAR, PK)
- `name` (VARCHAR)
- `version` (VARCHAR)
- `os_family` (JSON)
- `os_version` (VARCHAR)
- `enabled` (BOOLEAN)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

**rules 表**：
- `rule_id` (VARCHAR, PK)
- `policy_id` (VARCHAR, FK)
- `category` (VARCHAR)
- `title` (VARCHAR)
- `description` (TEXT)
- `severity` (VARCHAR)
- `check_config` (JSON)  # 存储 check 配置
- `fix_config` (JSON)    # 存储 fix 配置
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

---

## 6. 与 Elkeid 的差异

### 6.1 简化点

1. **策略结构**：
   - Elkeid：baseline_id + check_id（数字 ID）
   - 我们：policy_id + rule_id（字符串 ID，更易读）

2. **OS 匹配**：
   - Elkeid：通过 baseline_id 硬编码（1200=CentOS, 1300=Debian）
   - 我们：通过 `os_family` + `os_version` 灵活匹配

3. **检查类型**：
   - Elkeid：`file_line_check`（通用但复杂）
   - 我们：`file_kv`（专门处理配置文件，更直观）

### 6.2 增强点

1. **版本管理**：策略支持版本号，便于升级与回滚
2. **修复建议**：提供 `fix.command`，可直接执行修复
3. **规则分类**：更清晰的分类体系
4. **数据库存储**：策略存储在数据库，便于动态管理

---

## 7. 实现建议

### 7.1 策略加载

1. **初始化**：从数据库加载所有启用的策略
2. **匹配**：根据 Agent 上报的 OS 信息匹配策略
3. **缓存**：策略列表缓存在内存，定期刷新

### 7.2 规则执行

1. **解析**：解析规则的 `check` 配置
2. **执行**：根据 `type` 调用对应的检查器
3. **组合**：根据 `condition` 组合多个子检查的结果
4. **返回**：返回 pass/fail/error/na（不适用）

### 7.3 结果上报

```json
{
  "rule_id": "LINUX_SSH_001",
  "host_id": "host-uuid",
  "policy_id": "LINUX_ROCKY9_BASELINE",
  "policy_version": "1.0.0",
  "status": "fail",
  "severity": "high",
  "category": "ssh",
  "title": "禁止 root 远程登录",
  "actual": "PermitRootLogin yes",
  "expected": "PermitRootLogin no",
  "fix_suggestion": "修改 /etc/ssh/sshd_config 中的 PermitRootLogin 并重启 sshd",
  "checked_at": "2025-12-09T12:00:00+08:00"
}
```

---

## 8. 后续扩展

1. **中间件基线**：扩展 `category` 和检查类型（如 `nginx`、`redis`、`mysql`）
2. **规则依赖**：支持规则之间的依赖关系（如先检查文件是否存在，再检查内容）
3. **自定义检查器**：支持用户自定义检查器（通过脚本或插件）
4. **策略模板**：提供常用策略模板（CIS Benchmark、等保等）


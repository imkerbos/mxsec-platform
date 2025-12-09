# 下一步开发建议

> 基于当前项目状态（Phase 1.1 进行中），给出优先级排序的开发建议。

---

## 📊 当前状态总结

### ✅ 已完成
1. **基础设施**：插件 SDK、Protobuf 定义、代码生成
2. **Agent 核心**：主程序、配置管理、日志系统、连接管理、传输模块、心跳模块、插件管理
3. **Baseline Plugin**：插件入口、策略加载解析、OS 匹配、规则执行框架
4. **检查器实现**：`file_kv`、`file_permission`、`file_line_match`、`command_exec`、`sysctl`、`service_status`

### 🔄 待完成
1. Baseline Plugin 示例规则（SSH、密码策略等）
2. 单元测试和集成测试
3. 更多检查器（`file_owner`、`package_installed` 等）
4. Server 端开发（AgentCenter、Manager、ServiceDiscovery）

---

## 🎯 推荐开发顺序（按优先级）

### Phase 1.1.1：Baseline Plugin 示例规则（**最高优先级** ⭐⭐⭐）

**目标**：创建 3-5 条示例规则，验证整个检查流程是否正常工作。

**理由**：
- 可以立即验证已实现的检查器是否正常工作
- 为后续开发提供参考示例
- 便于集成测试和端到端验证

**任务清单**：
- [ ] 创建示例策略配置文件（JSON 格式）
  - [ ] SSH 配置检查规则（`PermitRootLogin`）
  - [ ] 密码策略检查规则（`PASS_MAX_DAYS`）
  - [ ] 文件权限检查规则（`/etc/passwd`、`/etc/shadow`）
  - [ ] 内核参数检查规则（`net.ipv4.ip_forward`）
  - [ ] 服务状态检查规则（`auditd`、`chronyd`）
- [ ] 在 `plugins/baseline/config/` 目录下创建示例策略文件
- [ ] 编写简单的测试脚本，验证规则执行

**预计时间**：1-2 天

**产出物**：
- `plugins/baseline/config/examples/ssh-baseline.json`
- `plugins/baseline/config/examples/password-policy.json`
- `plugins/baseline/config/examples/file-permissions.json`
- `scripts/test-baseline-rules.sh`（可选）

---

### Phase 1.1.2：编写单元测试（**高优先级** ⭐⭐）

**目标**：为检查器编写单元测试，确保代码质量和稳定性。

**理由**：
- 保证检查器实现的正确性
- 防止后续重构引入 bug
- 符合编码规范要求

**任务清单**：
- [ ] 为每个检查器编写单元测试（`*_test.go`）
  - [ ] `FileKVChecker` 测试（pass、fail、文件不存在、键不存在）
  - [ ] `FilePermissionChecker` 测试（pass、fail、文件不存在）
  - [ ] `FileLineMatchChecker` 测试（match、not_match、文件不存在）
  - [ ] `CommandExecChecker` 测试（pass、fail、命令错误）
  - [ ] `SysctlChecker` 测试（pass、fail、参数不存在）
  - [ ] `ServiceStatusChecker` 测试（systemd、SysV、服务不存在）
- [ ] 为 `Engine` 编写测试（OS 匹配、条件组合、错误处理）
- [ ] 创建测试辅助工具（临时文件、mock 服务等）

**预计时间**：2-3 天

**产出物**：
- `plugins/baseline/engine/checkers_test.go`
- `plugins/baseline/engine/engine_test.go`
- `plugins/baseline/engine/test_helpers.go`（可选）

**测试覆盖率目标**：> 80%

---

### Phase 1.1.3：实现更多检查器（**中优先级** ⭐）

**目标**：扩展检查器能力，支持更多基线检查场景。

**理由**：
- 丰富基线检查能力
- 为更多规则提供支持

**任务清单**：
- [ ] 实现 `file_owner` 检查器
  - [ ] 检查文件属主（uid:gid）
  - [ ] 支持用户名/组名解析
  - [ ] 编写单元测试
- [ ] 实现 `package_installed` 检查器
  - [ ] 支持 RPM（`rpm -q`）和 DEB（`dpkg -l`）
  - [ ] 支持版本比较（>=、<=、==）
  - [ ] 编写单元测试
- [ ] 注册新检查器到 `Engine`

**预计时间**：2-3 天

**产出物**：
- `plugins/baseline/engine/checkers.go`（扩展）
- `plugins/baseline/engine/checkers_test.go`（扩展）

---

### Phase 1.2：Server 端开发（**高优先级** ⭐⭐）

**目标**：实现 Server 端核心功能，支持 Agent 连接和数据接收。

**理由**：
- Agent 需要 Server 才能完整运行
- 是端到端测试的前提

**任务清单**：

#### 1.2.1 数据库模型（**先做**）
- [ ] 定义数据库模型（Gorm）
  - [ ] `hosts` 表（主机信息）
  - [ ] `policies` 表（策略集）
  - [ ] `rules` 表（规则）
  - [ ] `scan_results` 表（检测结果）
  - [ ] `scan_tasks` 表（扫描任务）
- [ ] 编写数据库迁移脚本
- [ ] 创建初始化数据（默认策略）

#### 1.2.2 AgentCenter（gRPC Server）
- [ ] AgentCenter 主程序入口
- [ ] 配置加载（Viper + YAML）
- [ ] 日志初始化（Zap）
- [ ] gRPC Server 启动
- [ ] mTLS 配置（CA、证书、密钥）
- [ ] 数据库连接（Gorm）
- [ ] `Transfer` 服务实现（双向流）
- [ ] 接收 Agent 数据（心跳、检测结果）
- [ ] 下发任务和配置到 Agent
- [ ] 连接状态管理

#### 1.2.3 Manager（HTTP API Server）
- [ ] Manager 主程序入口
- [ ] HTTP Server（Gin/Fiber）
- [ ] 中间件（CORS、认证、限流）
- [ ] API 接口实现：
  - [ ] `GET /api/v1/hosts`：获取主机列表
  - [ ] `GET /api/v1/hosts/{host_id}`：获取主机详情
  - [ ] `GET /api/v1/policies`：获取策略列表
  - [ ] `POST /api/v1/policies`：创建策略
  - [ ] `POST /api/v1/tasks`：创建扫描任务
  - [ ] `GET /api/v1/results`：获取检测结果

**预计时间**：5-7 天

**产出物**：
- `cmd/server/agentcenter/main.go`
- `cmd/server/manager/main.go`
- `internal/server/model/*.go`
- `internal/server/api/*.go`
- `configs/server.yaml.example`

---

## 📋 详细任务分解

### 任务 1：创建示例规则（Phase 1.1.1）

#### 1.1 SSH 配置检查规则

**文件**：`plugins/baseline/config/examples/ssh-baseline.json`

```json
{
  "id": "LINUX_SSH_BASELINE",
  "name": "SSH 安全配置基线",
  "version": "1.0.0",
  "description": "SSH 服务安全配置检查",
  "os_family": ["rocky", "centos", "oracle", "debian", "ubuntu"],
  "os_version": ">=7",
  "enabled": true,
  "rules": [
    {
      "rule_id": "LINUX_SSH_001",
      "category": "ssh",
      "title": "禁止 root 远程登录",
      "description": "sshd_config 中应设置 PermitRootLogin no",
      "severity": "high",
      "check": {
        "condition": "all",
        "rules": [
          {
            "type": "file_exists",
            "param": ["/etc/ssh/sshd_config"]
          },
          {
            "type": "file_kv",
            "param": ["/etc/ssh/sshd_config", "PermitRootLogin", "no"]
          }
        ]
      },
      "fix": {
        "suggestion": "修改 /etc/ssh/sshd_config，设置 PermitRootLogin no，然后重启 sshd 服务"
      }
    },
    {
      "rule_id": "LINUX_SSH_002",
      "category": "ssh",
      "title": "禁止空密码登录",
      "description": "sshd_config 中应设置 PermitEmptyPasswords no",
      "severity": "high",
      "check": {
        "condition": "all",
        "rules": [
          {
            "type": "file_exists",
            "param": ["/etc/ssh/sshd_config"]
          },
          {
            "type": "file_kv",
            "param": ["/etc/ssh/sshd_config", "PermitEmptyPasswords", "no"]
          }
        ]
      },
      "fix": {
        "suggestion": "修改 /etc/ssh/sshd_config，设置 PermitEmptyPasswords no，然后重启 sshd 服务"
      }
    }
  ]
}
```

#### 1.2 密码策略检查规则

**文件**：`plugins/baseline/config/examples/password-policy.json`

```json
{
  "id": "LINUX_PASSWORD_POLICY",
  "name": "密码策略基线",
  "version": "1.0.0",
  "description": "系统密码策略检查",
  "os_family": ["rocky", "centos", "oracle", "debian", "ubuntu"],
  "os_version": ">=7",
  "enabled": true,
  "rules": [
    {
      "rule_id": "LINUX_PASS_001",
      "category": "password",
      "title": "密码最大有效期",
      "description": "密码最大有效期应不超过 90 天",
      "severity": "medium",
      "check": {
        "condition": "all",
        "rules": [
          {
            "type": "file_exists",
            "param": ["/etc/login.defs"]
          },
          {
            "type": "file_line_match",
            "param": ["/etc/login.defs", "\\s*PASS_MAX_DAYS\\s+(\\d+)", "match"]
          }
        ]
      },
      "fix": {
        "suggestion": "修改 /etc/login.defs，设置 PASS_MAX_DAYS 90 或更小"
      }
    }
  ]
}
```

#### 1.3 文件权限检查规则

**文件**：`plugins/baseline/config/examples/file-permissions.json`

```json
{
  "id": "LINUX_FILE_PERMISSIONS",
  "name": "关键文件权限基线",
  "version": "1.0.0",
  "description": "关键系统文件权限检查",
  "os_family": ["rocky", "centos", "oracle", "debian", "ubuntu"],
  "os_version": ">=7",
  "enabled": true,
  "rules": [
    {
      "rule_id": "LINUX_FILE_001",
      "category": "file_permission",
      "title": "/etc/passwd 文件权限",
      "description": "/etc/passwd 文件权限应不超过 644",
      "severity": "high",
      "check": {
        "condition": "all",
        "rules": [
          {
            "type": "file_exists",
            "param": ["/etc/passwd"]
          },
          {
            "type": "file_permission",
            "param": ["/etc/passwd", "644"]
          }
        ]
      },
      "fix": {
        "suggestion": "执行 chmod 644 /etc/passwd"
      }
    },
    {
      "rule_id": "LINUX_FILE_002",
      "category": "file_permission",
      "title": "/etc/shadow 文件权限",
      "description": "/etc/shadow 文件权限应不超过 400",
      "severity": "critical",
      "check": {
        "condition": "all",
        "rules": [
          {
            "type": "file_exists",
            "param": ["/etc/shadow"]
          },
          {
            "type": "file_permission",
            "param": ["/etc/shadow", "400"]
          }
        ]
      },
      "fix": {
        "suggestion": "执行 chmod 400 /etc/shadow"
      }
    }
  ]
}
```

---

### 任务 2：编写单元测试（Phase 1.1.2）

#### 2.1 检查器测试示例

**文件**：`plugins/baseline/engine/checkers_test.go`

```go
package engine

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"go.uber.org/zap"
)

func TestFileKVChecker(t *testing.T) {
	logger, _ := zap.NewDevelopment()
	checker := NewFileKVChecker(logger)

	// 创建临时文件
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "test.conf")
	os.WriteFile(configFile, []byte("PermitRootLogin no\n"), 0644)

	tests := []struct {
		name     string
		rule     *CheckRule
		wantPass bool
		wantErr  bool
	}{
		{
			name: "pass - key value match",
			rule: &CheckRule{
				Type:  "file_kv",
				Param: []string{configFile, "PermitRootLogin", "no"},
			},
			wantPass: true,
			wantErr:  false,
		},
		{
			name: "fail - key value mismatch",
			rule: &CheckRule{
				Type:  "file_kv",
				Param: []string{configFile, "PermitRootLogin", "yes"},
			},
			wantPass: false,
			wantErr:  false,
		},
		{
			name: "fail - file not exists",
			rule: &CheckRule{
				Type:  "file_kv",
				Param: []string{"/nonexistent/file", "Key", "Value"},
			},
			wantPass: false,
			wantErr:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := checker.Check(context.Background(), tt.rule)
			if (err != nil) != tt.wantErr {
				t.Errorf("Check() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if result.Pass != tt.wantPass {
				t.Errorf("Check() Pass = %v, want %v", result.Pass, tt.wantPass)
			}
		})
	}
}
```

---

## 🚀 快速开始建议

### 第一步：创建示例规则（推荐先做）

1. 创建目录结构：
   ```bash
   mkdir -p plugins/baseline/config/examples
   ```

2. 创建示例规则文件（参考上面的 JSON 示例）

3. 编写简单的测试脚本验证规则：
   ```bash
   # scripts/test-baseline-rules.sh
   # 使用 go run 直接运行 baseline plugin，传入策略文件
   ```

### 第二步：编写单元测试

1. 为每个检查器创建测试文件
2. 使用 `testing` 包和 `testify`（可选）编写测试
3. 运行测试：`go test ./plugins/baseline/engine/...`

### 第三步：扩展检查器

1. 实现 `file_owner` 检查器
2. 实现 `package_installed` 检查器
3. 注册到 `Engine`

### 第四步：开始 Server 端开发

1. 先设计数据库模型
2. 实现 AgentCenter（gRPC Server）
3. 实现 Manager（HTTP API Server）

---

## 📝 注意事项

1. **遵循编码规范**：
   - 使用 Zap 进行日志记录
   - 禁止在业务逻辑中使用 `panic`
   - 所有检查器必须有单元测试

2. **保持代码质量**：
   - 每次提交前运行测试
   - 保持测试覆盖率 > 80%
   - 遵循 Go 代码规范（`gofmt`、`golint`）

3. **文档更新**：
   - 新增检查器时更新 `docs/design/baseline-policy-model.md`
   - 更新 `docs/TODO.md` 中的进度

4. **测试环境**：
   - 建议在 Docker 容器中测试（不同 OS 版本）
   - 使用 `testcontainers`（可选）进行集成测试

---

## 🎯 里程碑目标

### 里程碑 1：Baseline Plugin 可用（Phase 1.1 完成）
- ✅ 示例规则创建完成
- ✅ 单元测试覆盖率 > 80%
- ✅ 端到端测试通过（Agent + Plugin + 示例规则）

### 里程碑 2：Server 端可用（Phase 1.2 完成）
- ✅ AgentCenter 可以接收 Agent 连接
- ✅ Manager API 可以查询主机和结果
- ✅ 完整的 Agent → Server → 数据库流程打通

---

## 📚 参考资源

- [Baseline 策略模型设计](./design/baseline-policy-model.md)
- [Agent 架构设计](./design/agent-architecture.md)
- [Server API 设计](./design/server-api.md)
- [TODO 列表](./TODO.md)

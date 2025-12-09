# 发行版支持说明

> 本文档说明 Matrix Cloud Security Platform 对不同 Linux 发行版的支持情况，以及如何为特定发行版打包。

---

## 1. 支持的发行版

### 1.1 RPM 发行版（基于 Red Hat）

| 发行版 | DISTRO 值 | 包名示例 |
|--------|-----------|----------|
| CentOS 7 | `centos7`, `el7` | `mxsec-agent-1.0.0-1.el7.x86_64.rpm` |
| CentOS 8 | `centos8`, `el8` | `mxsec-agent-1.0.0-1.el8.x86_64.rpm` |
| CentOS Stream 9 | `centos9`, `centos-stream9`, `el9` | `mxsec-agent-1.0.0-1.el9.x86_64.rpm` |
| Rocky Linux 8 | `rocky8`, `rhel8` | `mxsec-agent-1.0.0-1.el8.x86_64.rpm` |
| Rocky Linux 9 | `rocky9`, `rhel9`, `el9` | `mxsec-agent-1.0.0-1.el9.x86_64.rpm` |
| RHEL 7 | `rhel7`, `el7` | `mxsec-agent-1.0.0-1.el7.x86_64.rpm` |
| RHEL 8 | `rhel8`, `el8` | `mxsec-agent-1.0.0-1.el8.x86_64.rpm` |
| RHEL 9 | `rhel9`, `el9` | `mxsec-agent-1.0.0-1.el9.x86_64.rpm` |

### 1.2 DEB 发行版（基于 Debian）

| 发行版 | DISTRO 值 | 包名示例 |
|--------|-----------|----------|
| Debian 10 (Buster) | `debian10`, `buster` | `mxsec-agent_1.0.0-1~debian10_amd64.deb` |
| Debian 11 (Bullseye) | `debian11`, `bullseye` | `mxsec-agent_1.0.0-1~debian11_amd64.deb` |
| Debian 12 (Bookworm) | `debian12`, `bookworm` | `mxsec-agent_1.0.0-1~debian12_amd64.deb` |
| Ubuntu 20.04 (Focal) | `ubuntu20`, `focal` | `mxsec-agent_1.0.0-1~ubuntu20_amd64.deb` |
| Ubuntu 22.04 (Jammy) | `ubuntu22`, `jammy` | `mxsec-agent_1.0.0-1~ubuntu22_amd64.deb` |

---

## 2. 打包方式

### 2.1 Agent 打包

#### 为特定发行版打包

```bash
# Rocky Linux 9
make package-agent SERVER_HOST=10.0.0.1:6751 VERSION=1.0.0 DISTRO=rocky9

# CentOS 7
make package-agent SERVER_HOST=10.0.0.1:6751 VERSION=1.0.0 DISTRO=centos7

# Debian 12
make package-agent SERVER_HOST=10.0.0.1:6751 VERSION=1.0.0 DISTRO=debian12

# Ubuntu 22.04
make package-agent SERVER_HOST=10.0.0.1:6751 VERSION=1.0.0 DISTRO=ubuntu22
```

#### 通用包（不指定发行版）

```bash
# 生成通用 RPM 包（适用于所有 RPM 发行版）
make package-agent SERVER_HOST=10.0.0.1:6751 VERSION=1.0.0

# 生成通用 DEB 包（适用于所有 DEB 发行版）
make package-agent SERVER_HOST=10.0.0.1:6751 VERSION=1.0.0
```

### 2.2 Server 打包

#### 为特定发行版打包

```bash
# Rocky Linux 9
make package-server VERSION=1.0.0 DISTRO=rocky9

# CentOS 8
make package-server VERSION=1.0.0 DISTRO=centos8

# Debian 11
make package-server VERSION=1.0.0 DISTRO=debian11
```

#### 通用包（不指定发行版）

```bash
# 生成通用包
make package-server VERSION=1.0.0
```

---

## 3. 包命名规则

### 3.1 RPM 包命名

**指定发行版：**
```
mxsec-agent-{VERSION}-{RELEASE}.{ARCH}.rpm
```

示例：
- `mxsec-agent-1.0.0-1.el7.x86_64.rpm` (CentOS 7)
- `mxsec-agent-1.0.0-1.el9.x86_64.rpm` (Rocky Linux 9)
- `mxsec-agent-1.0.0-1.el9.aarch64.rpm` (Rocky Linux 9, ARM64)

**通用包：**
```
mxsec-agent-{VERSION}-{ARCH}.rpm
```

示例：
- `mxsec-agent-1.0.0-x86_64.rpm`
- `mxsec-agent-1.0.0-aarch64.rpm`

### 3.2 DEB 包命名

**指定发行版：**
```
mxsec-agent_{VERSION}-{RELEASE}_{ARCH}.deb
```

示例：
- `mxsec-agent_1.0.0-1~debian10_amd64.deb` (Debian 10)
- `mxsec-agent_1.0.0-1~debian12_amd64.deb` (Debian 12)
- `mxsec-agent_1.0.0-1~ubuntu22_amd64.deb` (Ubuntu 22.04)

**通用包：**
```
mxsec-agent_{VERSION}_{ARCH}.deb
```

示例：
- `mxsec-agent_1.0.0_amd64.deb`
- `mxsec-agent_1.0.0_arm64.deb`

---

## 4. 安装说明

### 4.1 RPM 发行版安装

```bash
# Rocky Linux 9 / CentOS 8+
sudo dnf install mxsec-agent-1.0.0-1.el9.x86_64.rpm

# CentOS 7
sudo yum install mxsec-agent-1.0.0-1.el7.x86_64.rpm

# 或使用通用包
sudo dnf install mxsec-agent-1.0.0-x86_64.rpm
```

### 4.2 DEB 发行版安装

```bash
# Debian 12
sudo dpkg -i mxsec-agent_1.0.0-1~debian12_amd64.deb

# Ubuntu 22.04
sudo dpkg -i mxsec-agent_1.0.0-1~ubuntu22_amd64.deb

# 或使用通用包
sudo dpkg -i mxsec-agent_1.0.0_amd64.deb
```

---

## 5. 批量打包脚本

### 5.1 为所有支持的发行版打包

创建 `scripts/package-all-distros.sh`：

```bash
#!/bin/bash

VERSION="${1:-1.0.0}"
SERVER_HOST="${2:-localhost:6751}"

# RPM 发行版
for distro in centos7 centos8 rocky8 rocky9; do
    echo "Packaging for $distro..."
    make package-agent SERVER_HOST=$SERVER_HOST VERSION=$VERSION DISTRO=$distro
done

# DEB 发行版
for distro in debian10 debian11 debian12 ubuntu20 ubuntu22; do
    echo "Packaging for $distro..."
    make package-agent SERVER_HOST=$SERVER_HOST VERSION=$VERSION DISTRO=$distro
done

echo "All packages built successfully!"
```

使用方法：
```bash
chmod +x scripts/package-all-distros.sh
./scripts/package-all-distros.sh 1.0.0 10.0.0.1:6751
```

---

## 6. 发行版检测

### 6.1 自动检测发行版

安装脚本（`scripts/install.sh`）会自动检测目标系统的发行版：

```bash
# 自动检测并下载对应发行版的包
curl -sS http://SERVER_IP:8080/agent/install.sh | bash
```

检测逻辑：
1. 读取 `/etc/os-release`
2. 根据 `ID` 和 `VERSION_ID` 确定发行版
3. 下载对应发行版的安装包

### 6.2 手动指定发行版

```bash
# 指定发行版
BLS_DISTRO=rocky9 curl -sS http://SERVER_IP:8080/agent/install.sh | bash
```

---

## 7. 兼容性说明

### 7.1 RPM 发行版兼容性

- **el7 包**：适用于 CentOS 7、RHEL 7
- **el8 包**：适用于 CentOS 8、Rocky Linux 8、RHEL 8
- **el9 包**：适用于 Rocky Linux 9、RHEL 9、CentOS Stream 9
  - **重要**：Rocky Linux 9 和 CentOS Stream 9 可以共用 `el9` 包
  - 因为我们的应用是静态编译的 Go 二进制，不依赖系统库版本
  - 两个发行版都基于 RHEL 9，使用相同的 `el9` release 标识
- **通用包**：理论上适用于所有 RPM 发行版，但建议使用特定发行版包

### 7.1.1 Rocky Linux 9 与 CentOS Stream 9 兼容性

**可以共用 `el9` 包**，原因如下：

1. **相同的 RHEL 9 基础**：两个发行版都基于 Red Hat Enterprise Linux 9
2. **相同的 release 标识**：都使用 `el9` (Enterprise Linux 9) 作为包 release
3. **静态编译**：我们的应用是静态编译的 Go 二进制，不依赖系统库版本
4. **包格式兼容**：RPM 包格式和依赖关系完全兼容

**注意事项**：
- CentOS Stream 9 是滚动发布，可能包含更新的系统包
- 对于依赖系统库的应用，可能需要分别打包
- 我们的应用是静态编译，不受此影响

**推荐做法**：
```bash
# 使用 el9 包，适用于 Rocky Linux 9 和 CentOS Stream 9
make package-server VERSION=1.0.0 DISTRO=el9

# 或使用 rocky9（实际生成的是 el9 包）
make package-server VERSION=1.0.0 DISTRO=rocky9

# CentOS Stream 9 也可以使用
make package-server VERSION=1.0.0 DISTRO=centos9
```

### 7.2 DEB 发行版兼容性

- **debian10/11/12 包**：适用于对应版本的 Debian
- **ubuntu20/22 包**：适用于对应版本的 Ubuntu
- **通用包**：理论上适用于所有 DEB 发行版，但建议使用特定发行版包

### 7.3 架构支持

所有发行版都支持以下架构：
- `amd64` / `x86_64`：64 位 x86
- `arm64` / `aarch64`：64 位 ARM

---

## 8. 最佳实践

1. **生产环境**：使用特定发行版包，确保最佳兼容性
2. **开发环境**：可以使用通用包，简化部署
3. **CI/CD**：为所有支持的发行版构建包，存储在制品仓库
4. **版本管理**：在包名中包含版本和发行版信息，便于管理

---

## 9. 故障排查

### 9.1 包安装失败

```bash
# 检查包依赖
rpm -qpR mxsec-agent-1.0.0-1.el9.x86_64.rpm
dpkg -I mxsec-agent_1.0.0-1~debian12_amd64.deb

# 强制安装（不推荐）
rpm -ivh --nodeps mxsec-agent-1.0.0-1.el9.x86_64.rpm
dpkg -i --force-depends mxsec-agent_1.0.0-1~debian12_amd64.deb
```

### 9.2 发行版不匹配

如果安装时提示发行版不匹配，可以：
1. 使用通用包
2. 使用 `--nodeps` 强制安装（RPM）
3. 使用 `--force-depends` 强制安装（DEB）

---

## 10. 参考文档

- [Agent 部署指南](./agent-deployment.md)
- [Server 部署指南](./server-deployment.md)
- [快速部署指南](./quick-start.md)

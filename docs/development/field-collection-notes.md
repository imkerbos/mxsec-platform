# 字段采集说明

本文档说明为什么某些主机信息字段可能显示为"未采集"。

## 硬件信息字段

### device_model（设备型号）
- **采集方式**：读取 `/sys/class/dmi/id/product_name`
- **未采集原因**：
  - 容器环境中无法访问 DMI（Desktop Management Interface）信息
  - 虚拟机环境中可能没有 DMI 信息
  - 某些物理机可能没有 DMI 支持

### manufacturer（制造商）
- **采集方式**：读取 `/sys/class/dmi/id/sys_vendor`
- **未采集原因**：同 device_model，依赖 DMI 信息

### device_serial（设备序列号）
- **采集方式**：读取 `/sys/class/dmi/id/product_serial`
- **未采集原因**：同 device_model，依赖 DMI 信息

### 解决方案
- **物理机/虚拟机**：确保系统支持 DMI，Agent 需要访问 `/sys/class/dmi/id/` 目录
- **容器环境**：这些字段在容器中无法采集是正常现象，因为容器无法访问宿主机的硬件信息

## 网络信息字段

### IPv6（私网IPv6）
- **采集方式**：通过 `net.Interfaces()` 读取网络接口的 IPv6 地址
- **未采集原因**：
  - 系统未配置 IPv6
  - 网络接口没有 IPv6 地址
  - 容器网络可能只使用 IPv4

### 解决方案
- 确保系统已启用 IPv6
- 检查网络接口配置：`ip -6 addr show`
- 容器环境可能需要特殊网络配置

## 其他字段

### CPU信息、内存大小、系统负载
- **采集方式**：读取 `/proc/cpuinfo`、`/proc/meminfo`、`/proc/loadavg`
- **采集状态**：通常可以正常采集（除非 `/proc` 文件系统不可访问）

### 默认网关、DNS服务器
- **采集方式**：读取路由表和 `/etc/resolv.conf`
- **采集状态**：通常可以正常采集

## 建议

1. **容器环境**：device_model、manufacturer、device_serial 无法采集是正常的，可以考虑：
   - 在容器启动时通过环境变量手动设置
   - 在 Server 端提供手动编辑功能（已实现标签功能，可扩展）

2. **物理机/虚拟机**：如果这些字段未采集，检查：
   - `/sys/class/dmi/id/` 目录是否存在
   - Agent 是否有读取权限
   - 系统是否支持 DMI

3. **IPv6**：如果不需要 IPv6，可以忽略此字段；如果需要，确保系统配置正确。

# 字段状态显示说明

## 概述

前端现在能够区分字段的不同状态，提供更清晰的信息展示。

## 字段状态类型

### 1. 有值（has_value）
- **显示**：显示实际值
- **含义**：字段已成功采集到数据

### 2. 未采集（not_collected）
- **显示**：显示"未采集"
- **含义**：Agent 未连接或代码未更新，字段尚未被采集
- **判断条件**：`last_heartbeat` 不存在或超过 5 分钟

### 3. 无数据（no_data）
- **显示**：
  - 硬件信息字段：显示"无数据（容器环境）"
  - 其他字段：显示"无数据"
- **含义**：Agent 已连接并尝试采集，但未能获取到数据
- **判断条件**：`last_heartbeat` 存在且在 5 分钟内，但字段值为空

## 硬件信息字段特殊处理

以下字段在容器环境中无法采集，会显示特殊提示：

- **设备型号**（device_model）
- **生产商**（manufacturer）
- **设备序列号**（device_serial）

### 显示逻辑

1. **物理机/虚拟机**：通常可以正常采集并显示
2. **容器环境**：
   - 如果 Agent 已连接：显示"无数据（容器环境）"
   - 如果 Agent 未连接：显示"未采集"

### Tooltip 提示

鼠标悬停在"无数据（容器环境）"上时，会显示详细说明：

> 容器环境中无法访问 DMI（Desktop Management Interface）信息，这是正常现象。物理机/虚拟机通常可以正常采集。

## 时间字段

以下时间字段也支持状态区分：

- **系统启动时间**（system_boot_time）
- **客户端启动时间**（agent_start_time）

### 显示逻辑

- **有值**：显示格式化的时间（如：2025-01-15 14:30:25）
- **未采集**：显示"未采集"，提示检查 Agent 状态
- **无数据**：显示"无数据"，说明 Agent 已连接但采集失败

## IP 地址字段

以下 IP 地址字段支持状态区分：

- **公网IPv4**（public_ipv4）
- **公网IPv6**（public_ipv6）
- **私网IPv4**（ipv4）
- **私网IPv6**（ipv6）

### 显示逻辑

- **有值**：显示第一个 IP 地址，如果有多个则显示标签（如：+2）
- **未采集**：显示"未采集"，提示检查 Agent 状态
- **无数据**：显示"无数据"，根据字段类型提供不同的提示

### 特殊提示

#### 公网 IP 字段
- **无数据**：提示"很多服务器没有公网 IP 地址是正常现象（仅配置内网 IP）"
- **原因**：大多数内网服务器只配置私网 IP，没有公网 IP 是正常的

#### IPv6 字段
- **无数据**：提示"可能是系统未启用 IPv6 或网络接口未配置 IPv6 地址"
- **原因**：很多系统默认未启用 IPv6，或者网络接口未配置 IPv6 地址

#### 私网 IPv4
- **无数据**：提示"Agent 已连接并尝试采集，但未能获取到私网IPv4"
- **原因**：正常情况下应该有私网 IPv4，如果没有可能是网络配置问题

## 实现细节

### 状态判断方法

```typescript
const getFieldStatus = (fieldValue: any, fieldType: 'hardware' | 'normal' = 'normal'): 'has_value' | 'not_collected' | 'no_data'
```

### 状态文本获取方法

```typescript
const getFieldStatusText = (fieldValue: any, fieldType: 'hardware' | 'normal' = 'normal'): { text: string, tooltip: string }
```

### 样式类

- `.empty-value`：默认空值样式（灰色）
- `.empty-value.status-no-data`：无数据状态样式（稍深的灰色，斜体）

## 使用示例

### 硬件信息字段

```vue
<template v-if="getFieldStatus(host.device_model, 'hardware') === 'has_value'">
  <a-tooltip :title="host.device_model" placement="topLeft">
    <span class="copyable-text">{{ host.device_model }}</span>
  </a-tooltip>
</template>
<a-tooltip v-else :title="getFieldStatusText(host.device_model, 'hardware').tooltip" placement="topLeft">
  <span class="empty-value" :class="{ 'status-no-data': getFieldStatus(host.device_model, 'hardware') === 'no_data' }">
    {{ getFieldStatusText(host.device_model, 'hardware').text }}
  </span>
</a-tooltip>
```

### 普通字段

```vue
<template v-if="getFieldStatus(host.system_boot_time) === 'has_value'">
  <span>{{ formatDateTime(host.system_boot_time) }}</span>
</template>
<a-tooltip v-else :title="getFieldStatusText(host.system_boot_time).tooltip" placement="topLeft">
  <span class="empty-value" :class="{ 'status-no-data': getFieldStatus(host.system_boot_time) === 'no_data' }">
    {{ getFieldStatusText(host.system_boot_time).text }}
  </span>
</a-tooltip>
```

### IP 地址字段（数组）

```vue
<template v-if="getArrayFieldStatus(host.public_ipv4) === 'has_value'">
  <a-tooltip :title="host.public_ipv4!.join(', ')" placement="topLeft">
    <span class="copyable-text">{{ host.public_ipv4![0] }}</span>
  </a-tooltip>
  <a-tag v-if="host.public_ipv4!.length > 1" color="blue" size="small">+{{ host.public_ipv4!.length - 1 }}</a-tag>
</template>
<a-tooltip v-else :title="getArrayFieldStatusText(host.public_ipv4, '公网IPv4').tooltip" placement="topLeft">
  <span class="empty-value" :class="{ 'status-no-data': getArrayFieldStatus(host.public_ipv4) === 'no_data' }">
    {{ getArrayFieldStatusText(host.public_ipv4, '公网IPv4').text }}
  </span>
</a-tooltip>
```

## 常见问题

### Q: 为什么容器环境显示"无数据（容器环境）"而不是"未采集"？

A: 因为容器环境中无法访问宿主机的 DMI 信息，这是正常现象。如果显示"未采集"，可能会误导用户认为 Agent 有问题。通过区分状态，用户可以清楚地知道：
- Agent 已连接并正常工作
- 只是在这个环境中无法采集到硬件信息

### Q: 如何判断字段是"未采集"还是"无数据"？

A: 系统通过 `last_heartbeat` 字段判断：
- 如果 `last_heartbeat` 存在且在 5 分钟内：Agent 已连接，字段为空则为"无数据"
- 如果 `last_heartbeat` 不存在或超过 5 分钟：Agent 未连接，字段为空则为"未采集"

### Q: 如何解决"未采集"问题？

A: 请检查：
1. Agent 是否正在运行
2. Agent 是否已连接到 Server
3. Agent 代码是否已更新到最新版本
4. 数据库字段是否已创建（需要重启 AgentCenter 触发迁移）

### Q: 如何解决"无数据"问题？

A: 对于硬件信息字段：
- 容器环境：这是正常现象，无需处理
- 物理机/虚拟机：检查 `/sys/class/dmi/id/` 目录是否存在，Agent 是否有读取权限

对于 IP 地址字段：
- **公网 IP**：没有公网 IP 是正常现象（大多数内网服务器只有私网 IP）
- **IPv6**：检查系统是否启用 IPv6：`ip -6 addr show`，或检查网络配置
- **私网 IPv4**：正常情况下应该有，如果没有可能是网络配置问题，检查网络接口配置

对于其他字段：
- 检查 Agent 日志，查看采集失败的原因
- 确认系统环境是否支持该字段的采集

### Q: 为什么公网 IP 显示"无数据"而不是"未采集"？

A: 因为很多服务器（特别是内网服务器）确实没有公网 IP 地址，这是正常现象。如果显示"未采集"，可能会误导用户认为 Agent 有问题。通过区分状态，用户可以清楚地知道：
- Agent 已连接并正常工作
- 只是这台服务器没有配置公网 IP（这是正常的）

### Q: IPv6 字段显示"无数据"是什么意思？

A: 表示 Agent 已连接并尝试采集 IPv6 地址，但系统未配置 IPv6。可能的原因：
- 系统未启用 IPv6
- 网络接口未配置 IPv6 地址
- 网络环境不支持 IPv6

这是正常现象，很多系统默认只使用 IPv4。

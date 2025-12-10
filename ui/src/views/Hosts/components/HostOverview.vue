<template>
  <a-spin :spinning="loading">
    <div v-if="host" class="host-overview">
      <!-- 主机基本信息 -->
      <a-card title="主机基本信息" :bordered="false" class="host-info-card">
        <div class="host-info-container">
          <!-- 左侧列 -->
          <div class="info-column">
            <div class="info-group">
              <div class="info-item">
                <span class="info-label">操作系统</span>
                <span class="info-value">
                  <a-tooltip 
                    v-if="host.os_family || host.os_version"
                    :title="(host.os_family || '未知') + (host.os_family && host.os_version ? ' ' : '') + (host.os_version || '')"
                    placement="topLeft"
                  >
                    <span 
                      class="copyable-text"
                      @click="copyText((host.os_family || '未知') + (host.os_family && host.os_version ? ' ' : '') + (host.os_version || ''), '操作系统')"
                    >
                      {{ host.os_family || '未知' }}{{ host.os_family && host.os_version ? ' ' : '' }}{{ host.os_version || '' }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">主机标签</span>
                <span class="info-value">
                  <a-tag v-if="host.tags && host.tags.length > 0" v-for="tag in host.tags" :key="tag" color="blue" style="margin-right: 4px">
                    {{ tag }}
                  </a-tag>
                  <span v-else class="empty-value">未设置</span>
                  <a-button 
                    type="link" 
                    size="small" 
                    style="padding: 0; margin-left: 8px; height: auto;"
                    @click="showTagModal = true"
                  >
                    {{ host.tags && host.tags.length > 0 ? '编辑' : '设置' }}
                  </a-button>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">设备型号</span>
                <span class="info-value">
                  <a-tooltip v-if="host.device_model" :title="host.device_model" placement="topLeft">
                    <span class="copyable-text" @click="copyText(host.device_model, '设备型号')">
                      {{ host.device_model }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">生产商</span>
                <span class="info-value">
                  <a-tooltip v-if="host.manufacturer" :title="host.manufacturer" placement="topLeft">
                    <span class="copyable-text" @click="copyText(host.manufacturer, '生产商')">
                      {{ host.manufacturer }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">系统负载</span>
                <span class="info-value">
                  <a-tooltip v-if="host.system_load" :title="host.system_load" placement="topLeft">
                    <span class="copyable-text" @click="copyText(host.system_load, '系统负载')">
                      {{ host.system_load }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
            </div>
          </div>

          <!-- 中间列 -->
          <div class="info-column">
            <div class="info-group">
              <div class="info-item">
                <span class="info-label">私网IPv4</span>
                <span class="info-value">
                  <template v-if="host.ipv4 && host.ipv4.length > 0">
                    <a-tooltip :title="host.ipv4.join(', ')" placement="topLeft">
                      <span class="copyable-text" @click="copyText(host.ipv4.join(', '), '私网IPv4')">
                        {{ host.ipv4[0] }}
                      </span>
                    </a-tooltip>
                    <a-tag v-if="host.ipv4.length > 1" color="blue" size="small" style="margin-left: 6px">
                      +{{ host.ipv4.length - 1 }}
                    </a-tag>
                  </template>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">私网IPv6</span>
                <span class="info-value">
                  <template v-if="host.ipv6 && host.ipv6.length > 0">
                    <a-tooltip :title="host.ipv6.join(', ')" placement="topLeft">
                      <span class="copyable-text" @click="copyText(host.ipv6.join(', '), '私网IPv6')">
                        {{ host.ipv6[0] }}
                      </span>
                    </a-tooltip>
                    <a-tag v-if="host.ipv6.length > 1" color="blue" size="small" style="margin-left: 6px">
                      +{{ host.ipv6.length - 1 }}
                    </a-tag>
                  </template>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">CPU信息</span>
                <span class="info-value">
                  <a-tooltip v-if="host.cpu_info" :title="host.cpu_info" placement="topLeft">
                    <span class="copyable-text" @click="copyText(host.cpu_info, 'CPU信息')">
                      {{ host.cpu_info }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">内存大小</span>
                <span class="info-value">
                  <a-tooltip v-if="host.memory_size" :title="host.memory_size" placement="topLeft">
                    <span class="copyable-text" @click="copyText(host.memory_size, '内存大小')">
                      {{ host.memory_size }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">默认网关</span>
                <span class="info-value">
                  <a-tooltip v-if="host.default_gateway" :title="host.default_gateway" placement="topLeft">
                    <span class="copyable-text" @click="copyText(host.default_gateway, '默认网关')">
                      {{ host.default_gateway }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
            </div>
          </div>

          <!-- 右侧列 -->
          <div class="info-column">
            <div class="info-group">
              <div class="info-item">
                <span class="info-label">网络模式</span>
                <span class="info-value">
                  <a-tooltip v-if="host.network_mode" :title="host.network_mode" placement="topLeft">
                    <span class="copyable-text" @click="copyText(host.network_mode, '网络模式')">
                      {{ host.network_mode }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">客户端状态</span>
                <span class="info-value">
                  <a-tag :color="host.status === 'online' ? 'success' : 'error'" class="status-tag">
                    <span class="status-dot" :class="host.status === 'online' ? 'online' : 'offline'"></span>
                    {{ host.status === 'online' ? '运行中' : '离线' }}
                  </a-tag>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">CPU使用率</span>
                <span class="info-value">
                  <a-tooltip v-if="host.cpu_usage" :title="host.cpu_usage" placement="topLeft">
                    <span class="copyable-text" @click="copyText(host.cpu_usage, 'CPU使用率')">
                      {{ host.cpu_usage }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">内存使用率</span>
                <span class="info-value">
                  <a-tooltip v-if="host.memory_usage" :title="host.memory_usage" placement="topLeft">
                    <span class="copyable-text" @click="copyText(host.memory_usage, '内存使用率')">
                      {{ host.memory_usage }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
              <div class="info-item">
                <span class="info-label">DNS服务器</span>
                <span class="info-value">
                  <template v-if="host.dns_servers && host.dns_servers.length > 0">
                    <a-tooltip :title="host.dns_servers.join(', ')" placement="topLeft">
                      <span class="copyable-text" @click="copyText(host.dns_servers.join(', '), 'DNS服务器')">
                        {{ host.dns_servers[0] }}
                      </span>
                    </a-tooltip>
                    <a-tag v-if="host.dns_servers.length > 1" color="blue" size="small" style="margin-left: 6px">
                      +{{ host.dns_servers.length - 1 }}
                    </a-tag>
                  </template>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- 第二行信息：时间相关 -->
        <div class="host-info-container" style="margin-top: 24px; padding-top: 24px; border-top: 1px solid #f0f0f0">
          <div class="info-column">
            <div class="info-group">
              <div class="info-item">
                <span class="info-label">客户端安装时间</span>
                <span class="info-value">
                  <a-tooltip 
                    v-if="host.created_at" 
                    :title="formatDateTime(host.created_at)" 
                    placement="topLeft"
                  >
                    <span 
                      class="copyable-text" 
                      @click="copyText(formatDateTime(host.created_at), '客户端安装时间')"
                    >
                      {{ formatDateTime(host.created_at) }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
            </div>
          </div>
          <div class="info-column">
            <div class="info-group">
              <div class="info-item">
                <span class="info-label">客户端启动时间</span>
                <span class="info-value">
                  <a-tooltip 
                    v-if="host.last_heartbeat" 
                    :title="formatDateTime(host.last_heartbeat)" 
                    placement="topLeft"
                  >
                    <span 
                      class="copyable-text" 
                      @click="copyText(formatDateTime(host.last_heartbeat), '客户端启动时间')"
                    >
                      {{ formatDateTime(host.last_heartbeat) }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
            </div>
          </div>
          <div class="info-column">
            <div class="info-group">
              <div class="info-item">
                <span class="info-label">设备序列号</span>
                <span class="info-value">
                  <a-tooltip v-if="host.device_serial" :title="host.device_serial" placement="topLeft">
                    <span class="copyable-text" @click="copyText(host.device_serial, '设备序列号')">
                      {{ host.device_serial }}
                    </span>
                  </a-tooltip>
                  <span v-else class="empty-value">未采集</span>
                </span>
              </div>
            </div>
          </div>
        </div>

      </a-card>

      <!-- 安全态势概览 -->
      <div class="risk-overview-container">
        <div class="risk-card">
          <div class="risk-card-header">
            <span class="risk-card-title">安全告警</span>
            <a-button type="link" size="small" class="risk-card-link" @click="$emit('view-detail', 'alerts')">详情</a-button>
          </div>
          <div class="risk-card-content">
            <div class="risk-progress-wrapper">
              <a-progress
                type="circle"
                :percent="alertPercent"
                :stroke-color="alertColor"
                :size="100"
                :stroke-width="8"
                :format="() => `${alertCount}个\n未处理告警`"
                class="risk-progress"
              />
            </div>
            <div class="risk-stats">
              <div class="risk-stat-item">
                <span class="risk-stat-label">紧急</span>
                <span class="risk-stat-value">{{ alertStats.critical || 0 }}</span>
              </div>
              <div class="risk-stat-item">
                <span class="risk-stat-label">高风险</span>
                <span class="risk-stat-value">{{ alertStats.high || 0 }}</span>
              </div>
              <div class="risk-stat-item">
                <span class="risk-stat-label">中风险</span>
                <span class="risk-stat-value">{{ alertStats.medium || 0 }}</span>
              </div>
              <div class="risk-stat-item">
                <span class="risk-stat-label">低风险</span>
                <span class="risk-stat-value">{{ alertStats.low || 0 }}</span>
              </div>
            </div>
          </div>
        </div>
        <div class="risk-card">
          <div class="risk-card-header">
            <span class="risk-card-title">漏洞风险</span>
            <a-button type="link" size="small" class="risk-card-link" @click="$emit('view-detail', 'vulnerabilities')">详情</a-button>
          </div>
          <div class="risk-card-content">
            <div class="risk-progress-wrapper">
              <a-progress
                type="circle"
                :percent="vulnPercent"
                :stroke-color="vulnColor"
                :size="100"
                :stroke-width="8"
                :format="() => `${vulnerabilityCount}个\n未处理高可利用漏洞`"
                class="risk-progress"
              />
            </div>
            <div class="risk-stats">
              <div class="risk-stat-item">
                <span class="risk-stat-label">严重</span>
                <span class="risk-stat-value">{{ vulnStats.critical || 0 }}</span>
              </div>
              <div class="risk-stat-item">
                <span class="risk-stat-label">高危</span>
                <span class="risk-stat-value">{{ vulnStats.high || 0 }}</span>
              </div>
              <div class="risk-stat-item">
                <span class="risk-stat-label">中危</span>
                <span class="risk-stat-value">{{ vulnStats.medium || 0 }}</span>
              </div>
              <div class="risk-stat-item">
                <span class="risk-stat-label">低危</span>
                <span class="risk-stat-value">{{ vulnStats.low || 0 }}</span>
              </div>
            </div>
          </div>
        </div>
        <div class="risk-card">
          <div class="risk-card-header">
            <span class="risk-card-title">基线风险</span>
            <a-button type="link" size="small" class="risk-card-link" @click="$emit('view-detail', 'baseline')">详情</a-button>
          </div>
          <div class="risk-card-content">
            <div class="risk-progress-wrapper">
              <a-progress
                type="circle"
                :percent="baselinePercent"
                :stroke-color="baselineColor"
                :size="100"
                :stroke-width="8"
                :format="() => `${baselineCount}个\n待加固基线`"
                class="risk-progress"
              />
            </div>
            <div class="risk-stats">
              <div class="risk-stat-item">
                <span class="risk-stat-label">高危</span>
                <span class="risk-stat-value">{{ baselineStats.high || 0 }}</span>
              </div>
              <div class="risk-stat-item">
                <span class="risk-stat-label">中危</span>
                <span class="risk-stat-value">{{ baselineStats.medium || 0 }}</span>
              </div>
              <div class="risk-stat-item">
                <span class="risk-stat-label">低危</span>
                <span class="risk-stat-value">{{ baselineStats.low || 0 }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 资产指纹 -->
      <div class="fingerprint-section">
        <div class="fingerprint-header">
          <span class="fingerprint-title">资产指纹</span>
          <a-button type="link" size="small" class="fingerprint-link" @click="$emit('view-detail', 'fingerprint')">详情</a-button>
        </div>
        <div class="fingerprint-grid">
          <div class="fingerprint-item" v-for="item in fingerprintItems" :key="item.key">
            <div class="fingerprint-value">{{ item.value }}</div>
            <div class="fingerprint-label">{{ item.label }}</div>
          </div>
        </div>
      </div>

      <!-- 标签编辑模态框 -->
      <a-modal
        v-model:open="showTagModal"
        title="编辑主机标签"
        @ok="handleSaveTags"
        @cancel="handleCancelTags"
      >
        <div style="margin-bottom: 16px;">
          <div style="margin-bottom: 8px; font-weight: 500;">标签</div>
          <a-select
            v-model:value="editingTags"
            mode="tags"
            placeholder="输入标签后按回车添加"
            style="width: 100%"
            :max-tag-count="10"
          >
          </a-select>
          <div style="margin-top: 8px; color: rgba(0, 0, 0, 0.45); font-size: 12px;">
            提示：输入标签后按回车键添加，最多可添加10个标签，每个标签最多50个字符
          </div>
        </div>
      </a-modal>
    </div>
  </a-spin>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { message } from 'ant-design-vue'
import { hostsApi } from '@/api/hosts'
import type { HostDetail, BaselineScore } from '@/api/types'

const props = defineProps<{
  host: HostDetail | null
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'update:host', host: HostDetail): void
  (e: 'view-detail', tab: string): void
}>()

const score = ref<BaselineScore | null>(null)

const alertCount = ref(0)
const alertStats = ref({
  critical: 0,
  high: 0,
  medium: 0,
  low: 0,
})

const vulnerabilityCount = ref(0)
const vulnStats = ref({
  critical: 0,
  high: 0,
  medium: 0,
  low: 0,
})

const baselineCount = ref(0)
const baselineStats = ref({
  high: 0,
  medium: 0,
  low: 0,
})

const fingerprintItems = ref([
  { key: 'containers', label: '容器', value: 0 },
  { key: 'ports', label: '开放端口', value: 0 },
  { key: 'processes', label: '运行进程', value: 0 },
  { key: 'users', label: '系统用户', value: 0 },
  { key: 'cron', label: '定时任务', value: 0 },
  { key: 'services', label: '系统服务', value: 0 },
  { key: 'packages', label: '系统软件', value: 0 },
  { key: 'integrity', label: '系统完整性校验', value: 0 },
])

const showTagModal = ref(false)
const editingTags = ref<string[]>([])

// 监听标签编辑模态框打开，初始化编辑标签
watch(showTagModal, (open) => {
  if (open && props.host) {
    editingTags.value = props.host.tags ? [...props.host.tags] : []
  }
})

const alertPercent = computed(() => {
  return alertCount.value > 0 ? 100 : 0
})

const alertColor = computed(() => {
  return alertCount.value > 0 ? '#ff9800' : '#d9d9d9'
})

const vulnPercent = computed(() => {
  return vulnerabilityCount.value > 0 ? 100 : 0
})

const vulnColor = computed(() => {
  return vulnerabilityCount.value > 0 ? '#ff9800' : '#d9d9d9'
})

const baselinePercent = computed(() => {
  return baselineCount.value > 0 ? 100 : 0
})

const baselineColor = computed(() => {
  return baselineCount.value > 0 ? '#1890ff' : '#d9d9d9'
})

const loadOverviewData = async () => {
  if (!props.host) return

  try {
    // 加载基线得分
    const scoreData = await hostsApi.getScore(props.host.host_id).catch(() => null)
    if (scoreData) {
      score.value = scoreData
      baselineCount.value = scoreData.fail_count
    }

    // TODO: 加载告警和漏洞数据
    // TODO: 加载资产指纹数据
  } catch (error) {
    console.error('加载概览数据失败:', error)
  }
}

const formatDateTime = (dateStr: string) => {
  if (!dateStr) return '-'
  try {
    const date = new Date(dateStr)
    return date.toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    })
  } catch {
    return dateStr
  }
}

const handleSaveTags = async () => {
  if (!props.host?.host_id) return

  try {
    // 调用API更新标签
    await hostsApi.updateTags(props.host.host_id, editingTags.value)
    
    // 通过 emit 通知父组件更新
    emit('update:host', {
      ...props.host,
      tags: editingTags.value
    })
    
    message.success('标签保存成功')
    showTagModal.value = false
  } catch (error: any) {
    console.error('保存标签失败:', error)
    message.error(error?.message || '保存标签失败，请重试')
  }
}

const handleCancelTags = () => {
  showTagModal.value = false
  editingTags.value = []
}

// 通用的复制文本方法
const copyText = async (text: string, label: string = '内容') => {
  if (!text) return
  
  try {
    await navigator.clipboard.writeText(text)
    message.success(`${label}已复制到剪贴板`)
  } catch (err) {
    // 降级方案：使用传统方法
    const textArea = document.createElement('textarea')
    textArea.value = text
    textArea.style.position = 'fixed'
    textArea.style.opacity = '0'
    document.body.appendChild(textArea)
    textArea.select()
    try {
      document.execCommand('copy')
      message.success(`${label}已复制到剪贴板`)
    } catch {
      message.error('复制失败，请手动复制')
    }
    document.body.removeChild(textArea)
  }
}


onMounted(() => {
  loadOverviewData()
})
</script>

<style scoped>
.host-overview {
  width: 100%;
}

.host-info-card {
  margin-bottom: 16px;
}

.host-info-card :deep(.ant-card-head) {
  border-bottom: 1px solid #f0f0f0;
  padding: 16px 24px;
}

.host-info-card :deep(.ant-card-head-title) {
  font-size: 16px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.85);
}

.host-info-card :deep(.ant-card-body) {
  padding: 24px;
}

.host-info-container {
  display: flex;
  gap: 32px;
  width: 100%;
}

.info-column {
  flex: 1;
  min-width: 0;
}

.info-group {
  display: flex;
  flex-direction: column;
  gap: 0;
}

.info-item {
  display: flex;
  align-items: flex-start;
  padding: 12px 0;
  border-bottom: 1px solid #f5f5f5;
  min-height: 44px;
}

.info-item:last-child {
  border-bottom: none;
}

.info-label {
  flex: 0 0 120px;
  font-size: 14px;
  font-weight: 500;
  color: rgba(0, 0, 0, 0.85);
  text-align: right;
  padding-right: 16px;
  line-height: 20px;
  margin-top: 2px;
}

.info-value {
  flex: 1;
  font-size: 14px;
  color: rgba(0, 0, 0, 0.65);
  line-height: 20px;
  word-break: break-word;
  min-width: 0;
}

.info-value.empty-value {
  color: rgba(0, 0, 0, 0.25);
  font-style: normal;
}

/* 可复制文本通用样式 */
.copyable-text {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  line-height: 1.5;
  cursor: pointer;
  user-select: none;
  transition: color 0.2s;
}

.copyable-text:hover {
  color: #1890ff;
  text-decoration: underline;
}

.cpu-info-text:hover {
  color: #1890ff;
}


.status-tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 2px 8px;
  border: none;
  font-weight: 500;
}

.status-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  display: inline-block;
  flex-shrink: 0;
}

.status-dot.online {
  background-color: #52c41a;
  box-shadow: 0 0 0 2px rgba(82, 196, 26, 0.2);
}

.status-dot.offline {
  background-color: #ff4d4f;
  box-shadow: 0 0 0 2px rgba(255, 77, 79, 0.2);
}

/* 安全态势概览 */
.risk-overview-container {
  display: flex;
  gap: 16px;
  margin-bottom: 16px;
}

.risk-card {
  flex: 1;
  background: #fff;
  border: 1px solid #f0f0f0;
  border-radius: 2px;
  padding: 20px;
  display: flex;
  flex-direction: column;
}

.risk-card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.risk-card-title {
  font-size: 16px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.85);
}

.risk-card-link {
  padding: 0;
  height: auto;
  font-size: 14px;
}

.risk-card-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 20px;
}

.risk-progress-wrapper {
  display: flex;
  justify-content: center;
  align-items: center;
}

.risk-progress :deep(.ant-progress-text) {
  font-size: 12px;
  line-height: 1.4;
}

.risk-stats {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.risk-stat-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
}

.risk-stat-label {
  font-size: 14px;
  color: rgba(0, 0, 0, 0.65);
}

.risk-stat-value {
  font-size: 14px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.85);
}

/* 资产指纹 */
.fingerprint-section {
  background: #fff;
  border: 1px solid #f0f0f0;
  border-radius: 2px;
  padding: 20px;
}

.fingerprint-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.fingerprint-title {
  font-size: 16px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.85);
}

.fingerprint-link {
  padding: 0;
  height: auto;
  font-size: 14px;
}

.fingerprint-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}

.fingerprint-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 20px;
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 2px;
  transition: background-color 0.2s;
  cursor: pointer;
}

.fingerprint-item:hover {
  background: #f5f5f5;
}

.fingerprint-value {
  font-size: 28px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.85);
  margin-bottom: 8px;
  line-height: 1;
}

.fingerprint-label {
  font-size: 14px;
  color: rgba(0, 0, 0, 0.65);
  text-align: center;
}

/* 响应式设计 */
@media (max-width: 1400px) {
  .host-info-container {
    gap: 24px;
  }
  
  .info-label {
    flex: 0 0 100px;
    font-size: 13px;
  }
  
  .info-value {
    font-size: 13px;
  }
  
  .fingerprint-grid {
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
  }
  
  .fingerprint-item {
    padding: 16px;
  }
  
  .fingerprint-value {
    font-size: 24px;
  }
}

@media (max-width: 1200px) {
  .host-info-container {
    flex-direction: column;
    gap: 0;
  }
  
  .info-column {
    margin-bottom: 0;
  }
  
  .info-item {
    border-bottom: 1px solid #f5f5f5;
  }
  
  .info-item:last-child {
    border-bottom: 1px solid #f5f5f5;
  }
  
  .info-group:last-child .info-item:last-child {
    border-bottom: none;
  }
  
  .risk-overview-container {
    flex-direction: column;
  }
  
  .fingerprint-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

@media (max-width: 768px) {
  .fingerprint-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .risk-card-content {
    flex-direction: row;
    align-items: flex-start;
    gap: 24px;
  }
  
  .risk-progress-wrapper {
    flex-shrink: 0;
  }
  
  .risk-stats {
    flex: 1;
  }
}
</style>

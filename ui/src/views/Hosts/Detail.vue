<template>
  <div class="host-detail-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <a-button type="text" @click="handleBack" style="padding: 0; margin-right: 8px">
        <ArrowLeftOutlined />
      </a-button>
      <div class="header-content">
        <h2 style="margin: 0">{{ host?.hostname || '主机详情' }}</h2>
        <div v-if="host?.host_id" class="device-id-header">
          <span class="device-id-label">设备ID：</span>
          <code class="device-id-text">{{ host.host_id }}</code>
          <a-button 
            type="text" 
            size="small" 
            class="copy-btn-header"
            @click="copyDeviceId"
            title="复制设备ID"
          >
            <template #icon>
              <CopyOutlined />
            </template>
          </a-button>
        </div>
      </div>
    </div>

    <!-- 标签页 -->
    <a-tabs v-model:activeKey="activeTab" @change="handleTabChange">
      <a-tab-pane key="overview" tab="主机概览">
        <HostOverview :host="host" :loading="loading" @update:host="host = $event" />
      </a-tab-pane>
      <a-tab-pane key="alerts" :tab="`安全告警(${alertCount})`">
        <SecurityAlerts :host-id="hostId" />
      </a-tab-pane>
      <a-tab-pane key="vulnerabilities" :tab="`漏洞风险(${vulnerabilityCount})`">
        <VulnerabilityRisk :host-id="hostId" />
      </a-tab-pane>
      <a-tab-pane key="baseline" :tab="`基线风险(${baselineCount})`">
        <BaselineRisk :host-id="hostId" />
      </a-tab-pane>
      <a-tab-pane key="runtime" :tab="`运行时安全告警(0)`">
        <RuntimeAlerts :host-id="hostId" />
      </a-tab-pane>
      <a-tab-pane key="antivirus" :tab="`病毒查杀(0)`">
        <AntivirusScan :host-id="hostId" />
      </a-tab-pane>
      <a-tab-pane key="performance" tab="性能监控">
        <PerformanceMonitor :host-id="hostId" />
      </a-tab-pane>
      <a-tab-pane key="fingerprint" tab="资产指纹">
        <AssetFingerprint :host-id="hostId" />
      </a-tab-pane>
    </a-tabs>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ArrowLeftOutlined, CopyOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import { hostsApi } from '@/api/hosts'
import type { HostDetail } from '@/api/types'
import HostOverview from './components/HostOverview.vue'
import SecurityAlerts from './components/SecurityAlerts.vue'
import VulnerabilityRisk from './components/VulnerabilityRisk.vue'
import BaselineRisk from './components/BaselineRisk.vue'
import RuntimeAlerts from './components/RuntimeAlerts.vue'
import AntivirusScan from './components/AntivirusScan.vue'
import PerformanceMonitor from './components/PerformanceMonitor.vue'
import AssetFingerprint from './components/AssetFingerprint.vue'

const router = useRouter()
const route = useRoute()

const loading = ref(false)
const host = ref<HostDetail | null>(null)
const activeTab = ref('overview')
const hostId = ref('')

const alertCount = ref(0)
const vulnerabilityCount = ref(0)
const baselineCount = ref(0)

const loadHostDetail = async () => {
  const id = route.params.hostId as string
  if (!id) return

  hostId.value = id
  loading.value = true
  try {
    const [hostData, scoreData] = await Promise.all([
      hostsApi.get(id),
      hostsApi.getScore(id).catch(() => null),
    ])
    host.value = hostData

    // 计算基线风险数量
    if (scoreData) {
      baselineCount.value = scoreData.fail_count
    }

    // TODO: 加载告警和漏洞数量
  } catch (error) {
    console.error('加载主机详情失败:', error)
  } finally {
    loading.value = false
  }
}

const handleBack = () => {
  router.push('/hosts')
}

const handleTabChange = (key: string) => {
  // 可以在这里加载对应标签页的数据
}

const copyDeviceId = async () => {
  if (!host.value?.host_id) return
  
  try {
    await navigator.clipboard.writeText(host.value.host_id)
    message.success('设备ID已复制到剪贴板')
  } catch (err) {
    // 降级方案：使用传统方法
    const textArea = document.createElement('textarea')
    textArea.value = host.value.host_id
    textArea.style.position = 'fixed'
    textArea.style.opacity = '0'
    document.body.appendChild(textArea)
    textArea.select()
    try {
      document.execCommand('copy')
      message.success('设备ID已复制到剪贴板')
    } catch {
      message.error('复制失败，请手动复制')
    }
    document.body.removeChild(textArea)
  }
}

onMounted(() => {
  loadHostDetail()
})
</script>

<style scoped>
.host-detail-page {
  width: 100%;
}

.page-header {
  display: flex;
  align-items: center;
  margin-bottom: 16px;
}

.header-content {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 16px;
}

.page-header h2 {
  font-size: 20px;
  font-weight: 600;
  margin: 0;
}

.device-id-header {
  display: flex;
  align-items: center;
  gap: 8px;
  background: #fafafa;
  border: 1px solid #e8e8e8;
  border-radius: 4px;
  padding: 4px 12px;
}

.device-id-label {
  font-size: 12px;
  color: rgba(0, 0, 0, 0.65);
  font-weight: 500;
  white-space: nowrap;
}

.device-id-text {
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', 'source-code-pro', monospace;
  font-size: 12px;
  color: rgba(0, 0, 0, 0.85);
  word-break: break-all;
  line-height: 1.5;
  margin: 0;
  padding: 0;
  background: transparent;
  border: none;
}

.copy-btn-header {
  flex-shrink: 0;
  color: rgba(0, 0, 0, 0.45);
  padding: 2px 4px;
  height: auto;
  line-height: 1;
}

.copy-btn-header:hover {
  color: #1890ff;
  background: rgba(24, 144, 255, 0.06);
}
</style>

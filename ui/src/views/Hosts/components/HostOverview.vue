<template>
  <a-spin :spinning="loading">
    <div v-if="host" class="host-overview">
      <!-- 主机基本信息 -->
      <a-card title="主机基本信息" :bordered="false" style="margin-bottom: 16px">
        <a-row :gutter="24">
          <a-col :span="8">
            <a-descriptions :column="1" bordered size="small">
              <a-descriptions-item label="操作系统">
                {{ host.os_family }}:{{ host.os_version }}
              </a-descriptions-item>
              <a-descriptions-item label="主机标签">-</a-descriptions-item>
              <a-descriptions-item label="设备型号">{{ host.device_model || '-' }}</a-descriptions-item>
              <a-descriptions-item label="生产商">{{ host.manufacturer || '-' }}</a-descriptions-item>
              <a-descriptions-item label="系统负载">{{ host.system_load || '-' }}</a-descriptions-item>
            </a-descriptions>
          </a-col>
          <a-col :span="8">
            <a-descriptions :column="1" bordered size="small">
              <a-descriptions-item label="私网IPv4">
                <span v-if="host.ipv4 && host.ipv4.length > 0">
                  {{ host.ipv4[0] }}
                  <a-tag v-if="host.ipv4.length > 1" color="blue" style="margin-left: 4px">
                    +{{ host.ipv4.length - 1 }}
                  </a-tag>
                </span>
                <span v-else>-</span>
              </a-descriptions-item>
              <a-descriptions-item label="私网IPv6">-</a-descriptions-item>
              <a-descriptions-item label="CPU信息">{{ host.cpu_info || '-' }}</a-descriptions-item>
              <a-descriptions-item label="内存大小">{{ host.memory_size || '-' }}</a-descriptions-item>
              <a-descriptions-item label="默认网关">{{ host.default_gateway || '-' }}</a-descriptions-item>
            </a-descriptions>
          </a-col>
          <a-col :span="8">
            <a-descriptions :column="1" bordered size="small">
              <a-descriptions-item label="网络模式">{{ host.network_mode || '-' }}</a-descriptions-item>
              <a-descriptions-item label="客户端状态">
                <a-tag :color="host.status === 'online' ? 'green' : 'red'">
                  <span v-if="host.status === 'online'">● 运行中</span>
                  <span v-else>● 离线</span>
                </a-tag>
              </a-descriptions-item>
              <a-descriptions-item label="CPU使用率">{{ host.cpu_usage || '-' }}</a-descriptions-item>
              <a-descriptions-item label="内存使用率">{{ host.memory_usage || '-' }}</a-descriptions-item>
              <a-descriptions-item label="DNS服务器">
                <span v-if="host.dns_servers && host.dns_servers.length > 0">
                  {{ host.dns_servers[0] }}
                  <a-tag v-if="host.dns_servers.length > 1" color="blue" style="margin-left: 4px">
                    +{{ host.dns_servers.length - 1 }}
                  </a-tag>
                </span>
                <span v-else>-</span>
              </a-descriptions-item>
              <a-descriptions-item label="客户端安装时间">{{ host.created_at }}</a-descriptions-item>
              <a-descriptions-item label="客户端启动时间">{{ host.last_heartbeat }}</a-descriptions-item>
              <a-descriptions-item label="设备序列号">{{ host.device_serial || '-' }}</a-descriptions-item>
              <a-descriptions-item label="设备ID">{{ host.host_id }}</a-descriptions-item>
            </a-descriptions>
          </a-col>
        </a-row>
      </a-card>

      <!-- 安全态势概览 -->
      <a-row :gutter="16" style="margin-bottom: 16px">
        <a-col :span="8">
          <a-card title="安全告警" :bordered="false">
            <template #extra>
              <a-button type="link" size="small" @click="$emit('view-detail', 'alerts')">详情</a-button>
            </template>
            <div style="text-align: center">
              <a-progress
                type="circle"
                :percent="alertPercent"
                :stroke-color="alertColor"
                :size="120"
                :format="() => `${alertCount}个\n未处理告警`"
              />
            </div>
            <a-divider />
            <a-space direction="vertical" style="width: 100%">
              <div style="display: flex; justify-content: space-between">
                <span>紧急</span>
                <span>{{ alertStats.critical || 0 }}</span>
              </div>
              <div style="display: flex; justify-content: space-between">
                <span>高风险</span>
                <span>{{ alertStats.high || 0 }}</span>
              </div>
              <div style="display: flex; justify-content: space-between">
                <span>中风险</span>
                <span>{{ alertStats.medium || 0 }}</span>
              </div>
              <div style="display: flex; justify-content: space-between">
                <span>低风险</span>
                <span>{{ alertStats.low || 0 }}</span>
              </div>
            </a-space>
          </a-card>
        </a-col>
        <a-col :span="8">
          <a-card title="漏洞风险" :bordered="false">
            <template #extra>
              <a-button type="link" size="small" @click="$emit('view-detail', 'vulnerabilities')">详情</a-button>
            </template>
            <div style="text-align: center">
              <a-progress
                type="circle"
                :percent="vulnPercent"
                :stroke-color="vulnColor"
                :size="120"
                :format="() => `${vulnerabilityCount}个\n未处理高可利用漏洞`"
              />
            </div>
            <a-divider />
            <a-space direction="vertical" style="width: 100%">
              <div style="display: flex; justify-content: space-between">
                <span>严重</span>
                <span>{{ vulnStats.critical || 0 }}</span>
              </div>
              <div style="display: flex; justify-content: space-between">
                <span>高危</span>
                <span>{{ vulnStats.high || 0 }}</span>
              </div>
              <div style="display: flex; justify-content: space-between">
                <span>中危</span>
                <span>{{ vulnStats.medium || 0 }}</span>
              </div>
              <div style="display: flex; justify-content: space-between">
                <span>低危</span>
                <span>{{ vulnStats.low || 0 }}</span>
              </div>
            </a-space>
          </a-card>
        </a-col>
        <a-col :span="8">
          <a-card title="基线风险" :bordered="false">
            <template #extra>
              <a-button type="link" size="small" @click="$emit('view-detail', 'baseline')">详情</a-button>
            </template>
            <div style="text-align: center">
              <a-progress
                type="circle"
                :percent="baselinePercent"
                :stroke-color="baselineColor"
                :size="120"
                :format="() => `${baselineCount}个\n待加固基线`"
              />
            </div>
            <a-divider />
            <a-space direction="vertical" style="width: 100%">
              <div style="display: flex; justify-content: space-between">
                <span>高危</span>
                <span>{{ baselineStats.high || 0 }}</span>
              </div>
              <div style="display: flex; justify-content: space-between">
                <span>中危</span>
                <span>{{ baselineStats.medium || 0 }}</span>
              </div>
              <div style="display: flex; justify-content: space-between">
                <span>低危</span>
                <span>{{ baselineStats.low || 0 }}</span>
              </div>
            </a-space>
          </a-card>
        </a-col>
      </a-row>

      <!-- 资产指纹 -->
      <a-card title="资产指纹" :bordered="false">
        <template #extra>
          <a-button type="link" size="small" @click="$emit('view-detail', 'fingerprint')">详情</a-button>
        </template>
        <a-row :gutter="16">
          <a-col :span="3" v-for="item in fingerprintItems" :key="item.key">
            <a-card :bordered="false" style="text-align: center; cursor: pointer" hoverable>
              <div style="font-size: 24px; font-weight: bold; margin-bottom: 8px">{{ item.value }}</div>
              <div style="color: #8c8c8c">{{ item.label }}</div>
            </a-card>
          </a-col>
        </a-row>
      </a-card>
    </div>
  </a-spin>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { hostsApi } from '@/api/hosts'
import type { HostDetail, BaselineScore } from '@/api/types'

const props = defineProps<{
  host: HostDetail | null
  loading: boolean
}>()

const emit = defineEmits<{
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

onMounted(() => {
  loadOverviewData()
})
</script>

<style scoped>
.host-overview {
  width: 100%;
}
</style>

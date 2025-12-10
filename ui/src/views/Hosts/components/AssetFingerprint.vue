<template>
  <div class="asset-fingerprint">
    <!-- 资产统计卡片 -->
    <a-card title="资产指纹" :bordered="false" style="margin-bottom: 16px">
      <a-row :gutter="16">
        <a-col :span="3" v-for="item in fingerprintItems" :key="item.key">
          <a-card
            :bordered="false"
            style="text-align: center; cursor: pointer"
            hoverable
            @click="handleItemClick(item.key)"
          >
            <div style="font-size: 24px; font-weight: bold; margin-bottom: 8px">{{ item.value }}</div>
            <div style="color: #8c8c8c">{{ item.label }}</div>
          </a-card>
        </a-col>
      </a-row>
    </a-card>

    <!-- 资产数据详细展示 -->
    <a-tabs v-model:activeKey="activeTab" @change="handleTabChange">
      <a-tab-pane key="processes" :tab="`运行进程(${fingerprintItems.find((i) => i.key === 'processes')?.value || 0})`">
        <ProcessList :host-id="hostId" />
      </a-tab-pane>
      <a-tab-pane key="ports" :tab="`开放端口(${fingerprintItems.find((i) => i.key === 'ports')?.value || 0})`">
        <PortList :host-id="hostId" />
      </a-tab-pane>
      <a-tab-pane key="users" :tab="`系统用户(${fingerprintItems.find((i) => i.key === 'users')?.value || 0})`">
        <UserList :host-id="hostId" />
      </a-tab-pane>
    </a-tabs>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { assetsApi } from '@/api/assets'
import ProcessList from './ProcessList.vue'
import PortList from './PortList.vue'
import UserList from './UserList.vue'
import { message } from 'ant-design-vue'

const props = defineProps<{
  hostId: string
}>()

const loading = ref(false)
const activeTab = ref('processes')

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

const loadStatistics = async () => {
  if (!props.hostId) return

  loading.value = true
  try {
    const stats = await assetsApi.getStatistics(props.hostId)
    
    // 更新统计数据
    fingerprintItems.value.forEach((item) => {
      if (item.key === 'processes') item.value = stats.processes
      else if (item.key === 'ports') item.value = stats.ports
      else if (item.key === 'users') item.value = stats.users
      else if (item.key === 'containers') item.value = stats.containers
      else if (item.key === 'cron') item.value = stats.cron
      else if (item.key === 'services') item.value = stats.services
      else if (item.key === 'packages') item.value = stats.packages
      else if (item.key === 'integrity') item.value = stats.integrity
    })
  } catch (error) {
    console.error('加载资产统计失败:', error)
    message.error('加载资产统计失败')
  } finally {
    loading.value = false
  }
}

const handleItemClick = (key: string) => {
  // 点击统计卡片时切换到对应的标签页
  if (key === 'processes') activeTab.value = 'processes'
  else if (key === 'ports') activeTab.value = 'ports'
  else if (key === 'users') activeTab.value = 'users'
  // 其他类型后续实现
}

const handleTabChange = (key: string) => {
  activeTab.value = key
}

onMounted(() => {
  loadStatistics()
})
</script>

<style scoped>
.asset-fingerprint {
  width: 100%;
}
</style>

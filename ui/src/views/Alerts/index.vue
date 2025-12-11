<template>
  <div class="alerts-page">
    <h2 class="page-title">告警管理</h2>
    
    <!-- 统计 -->
    <div class="stats">
      <div class="stat-card">
        <div class="stat-value">{{ statistics.active || 0 }}</div>
        <div class="stat-label">活跃告警</div>
      </div>
      <div class="stat-card">
        <div class="stat-value critical">{{ statistics.critical || 0 }}</div>
        <div class="stat-label">严重</div>
      </div>
      <div class="stat-card">
        <div class="stat-value high">{{ statistics.high || 0 }}</div>
        <div class="stat-label">高危</div>
      </div>
      <div class="stat-card">
        <div class="stat-value medium">{{ statistics.medium || 0 }}</div>
        <div class="stat-label">中危</div>
      </div>
    </div>

    <!-- 标签切换 -->
    <div class="tabs-header">
      <div 
        :class="['tab-item', { active: activeTab === 'active' }]"
        @click="activeTab = 'active'; handleTabChange()"
      >
        活跃告警
      </div>
      <div 
        :class="['tab-item', { active: activeTab === 'history' }]"
        @click="activeTab = 'history'; handleTabChange()"
      >
        历史告警
      </div>
    </div>

    <!-- 表格 -->
    <AlertTable
      v-if="activeTab === 'active'"
      :alerts="alerts"
      :loading="loading"
      :pagination="pagination"
      :filters="filters"
      status="active"
      @change="handleTableChange"
      @resolve="handleResolve"
      @ignore="handleIgnore"
      @refresh="loadAlerts"
    />
    <AlertTable
      v-else
      :alerts="alerts"
      :loading="loading"
      :pagination="pagination"
      :filters="filters"
      status="history"
      @change="handleTableChange"
      @refresh="loadAlerts"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { message } from 'ant-design-vue'
import { alertsApi, type Alert, type AlertStatistics } from '@/api/alerts'
import AlertTable from './components/AlertTable.vue'

const activeTab = ref<'active' | 'history'>('active')
const loading = ref(false)
const alerts = ref<Alert[]>([])
const statistics = ref<AlertStatistics>({
  total: 0,
  active: 0,
  resolved: 0,
  ignored: 0,
  critical: 0,
  high: 0,
  medium: 0,
  low: 0,
})

const pagination = ref({
  current: 1,
  pageSize: 20,
  total: 0,
  showSizeChanger: true,
  showTotal: (total: number) => `共 ${total} 条`,
})

const filters = ref({
  severity: undefined as 'critical' | 'high' | 'medium' | 'low' | undefined,
  host_id: undefined as string | undefined,
  category: undefined as string | undefined,
  keyword: undefined as string | undefined,
})

// 根据标签页设置状态过滤
const statusFilter = computed(() => {
  return activeTab.value === 'active' ? 'active' : undefined
})

const loadStatistics = async () => {
  try {
    const data = await alertsApi.statistics()
    statistics.value = data
  } catch (error: any) {
    console.error('加载告警统计失败:', error)
  }
}

const loadAlerts = async () => {
  loading.value = true
  try {
    const params: any = {
      page: pagination.value.current,
      page_size: pagination.value.pageSize,
    }

    // 根据标签页设置状态
    if (activeTab.value === 'active') {
      params.status = 'active'
    } else {
      // 历史告警：已解决或已忽略
      params.status = 'resolved,ignored'
    }

    // 添加其他过滤条件
    if (filters.value.severity) {
      params.severity = filters.value.severity
    }
    if (filters.value.host_id) {
      params.host_id = filters.value.host_id
    }
    if (filters.value.category) {
      params.category = filters.value.category
    }
    if (filters.value.keyword) {
      params.keyword = filters.value.keyword
    }

    const response = await alertsApi.list(params)
    alerts.value = response.items || []
    pagination.value.total = response.total || 0
  } catch (error: any) {
    message.error(error?.message || '加载告警列表失败')
  } finally {
    loading.value = false
  }
}

const handleTabChange = () => {
  pagination.value.current = 1
  loadAlerts()
}

const handleTableChange = (newFilters: any) => {
  filters.value = { ...filters.value, ...newFilters }
  pagination.value.current = 1
  loadAlerts()
}

const handleResolve = async (alert: Alert, reason?: string) => {
  try {
    await alertsApi.resolve(alert.id, reason)
    message.success('告警已解决')
    loadAlerts()
    loadStatistics()
  } catch (error: any) {
    message.error(error?.message || '解决告警失败')
  }
}

const handleIgnore = async (alert: Alert) => {
  try {
    await alertsApi.ignore(alert.id)
    message.success('告警已忽略')
    loadAlerts()
    loadStatistics()
  } catch (error: any) {
    message.error(error?.message || '忽略告警失败')
  }
}

onMounted(() => {
  loadStatistics()
  loadAlerts()
})
</script>

<style scoped lang="less">
.alerts-page {
  padding: 24px;
}

.page-title {
  font-size: 20px;
  font-weight: 500;
  margin: 0 0 24px 0;
  color: #262626;
}

.stats {
  display: flex;
  gap: 16px;
  margin-bottom: 24px;
}

.stat-card {
  flex: 1;
  background: #fff;
  border: 1px solid #e8e8e8;
  border-radius: 4px;
  padding: 20px;
  text-align: center;
  transition: all 0.2s;

  &:hover {
    border-color: #d9d9d9;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  }
}

.stat-value {
  font-size: 32px;
  font-weight: 600;
  color: #262626;
  margin-bottom: 8px;
  line-height: 1;

  &.critical {
    color: #ff4d4f;
  }

  &.high {
    color: #ff7a45;
  }

  &.medium {
    color: #faad14;
  }
}

.stat-label {
  font-size: 14px;
  color: #8c8c8c;
  font-weight: 400;
}

.tabs-header {
  display: flex;
  gap: 0;
  margin-bottom: 24px;
  background: #fff;
  border: 1px solid #e8e8e8;
  border-radius: 4px;
  padding: 4px;
}

.tab-item {
  flex: 1;
  padding: 10px 20px;
  text-align: center;
  cursor: pointer;
  border-radius: 4px;
  font-size: 14px;
  color: #595959;
  transition: all 0.2s;
  font-weight: 400;

  &:hover {
    color: #1890ff;
    background: #f5f5f5;
  }

  &.active {
    background: #1890ff;
    color: #fff;
    font-weight: 500;

    &:hover {
      background: #40a9ff;
      color: #fff;
    }
  }
}
</style>

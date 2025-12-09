<template>
  <a-card title="基线风险" :bordered="false">
    <a-table
      :columns="columns"
      :data-source="results"
      :loading="loading"
      :pagination="{ pageSize: 20 }"
      row-key="result_id"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'status'">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
        <template v-else-if="column.key === 'severity'">
          <a-tag :color="getSeverityColor(record.severity)">
            {{ getSeverityText(record.severity) }}
          </a-tag>
        </template>
      </template>
    </a-table>
  </a-card>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { hostsApi } from '@/api/hosts'
import type { ScanResult } from '@/api/types'

const props = defineProps<{
  hostId: string
}>()

const loading = ref(false)
const results = ref<ScanResult[]>([])

const columns = [
  {
    title: '规则ID',
    dataIndex: 'rule_id',
    key: 'rule_id',
    width: 200,
  },
  {
    title: '类别',
    dataIndex: 'category',
    key: 'category',
    width: 120,
  },
  {
    title: '标题',
    dataIndex: 'title',
    key: 'title',
  },
  {
    title: '严重级别',
    key: 'severity',
    width: 100,
  },
  {
    title: '状态',
    key: 'status',
    width: 100,
  },
  {
    title: '实际值',
    dataIndex: 'actual',
    key: 'actual',
    width: 200,
  },
  {
    title: '期望值',
    dataIndex: 'expected',
    key: 'expected',
    width: 200,
  },
  {
    title: '检查时间',
    dataIndex: 'checked_at',
    key: 'checked_at',
    width: 180,
  },
]

const loadBaselineResults = async () => {
  loading.value = true
  try {
    const hostDetail = await hostsApi.get(props.hostId)
    // 只显示失败的结果
    results.value = hostDetail.baseline_results.filter((r) => r.status === 'fail')
  } catch (error) {
    console.error('加载基线结果失败:', error)
  } finally {
    loading.value = false
  }
}

const getStatusColor = (status: string) => {
  const colors: Record<string, string> = {
    pass: 'green',
    fail: 'red',
    error: 'orange',
    na: 'default',
  }
  return colors[status] || 'default'
}

const getStatusText = (status: string) => {
  const texts: Record<string, string> = {
    pass: '通过',
    fail: '失败',
    error: '错误',
    na: '不适用',
  }
  return texts[status] || status
}

const getSeverityColor = (severity: string) => {
  const colors: Record<string, string> = {
    critical: 'red',
    high: 'orange',
    medium: 'gold',
    low: 'blue',
  }
  return colors[severity] || 'default'
}

const getSeverityText = (severity: string) => {
  const texts: Record<string, string> = {
    critical: '严重',
    high: '高',
    medium: '中',
    low: '低',
  }
  return texts[severity] || severity
}

onMounted(() => {
  loadBaselineResults()
})
</script>

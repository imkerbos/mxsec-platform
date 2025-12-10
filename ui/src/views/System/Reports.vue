<template>
  <div class="reports-page">
    <div class="page-header">
      <h2>统计报表</h2>
      <div class="header-actions">
        <a-range-picker
          v-model:value="dateRange"
          :presets="datePresets"
          format="YYYY-MM-DD"
          @change="handleDateRangeChange"
        />
        <a-button type="primary" @click="refreshData" :loading="loading">
          <template #icon>
            <ReloadOutlined />
          </template>
          刷新数据
        </a-button>
      </div>
    </div>

    <!-- 统计概览卡片 -->
    <a-row :gutter="[16, 16]" class="stats-overview">
      <a-col :xs="24" :sm="12" :md="6" :lg="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="主机总数"
            :value="reportStats.hostStats?.total || 0"
            :value-style="{ color: '#1890ff' }"
          />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6" :lg="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="基线检查总数"
            :value="reportStats.baselineStats?.totalChecks || 0"
            :value-style="{ color: '#52c41a' }"
          />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6" :lg="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="策略总数"
            :value="reportStats.policyStats?.total || 0"
            :value-style="{ color: '#722ed1' }"
          />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6" :lg="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="任务总数"
            :value="reportStats.taskStats?.total || 0"
            :value-style="{ color: '#fa8c16' }"
          />
        </a-card>
      </a-col>
    </a-row>

    <!-- 第一行图表 -->
    <a-row :gutter="[16, 16]" class="charts-row">
      <a-col :xs="24" :sm="24" :md="12" :lg="12">
        <a-card title="主机状态分布" :bordered="false" class="chart-card">
          <v-chart
            :option="hostStatusChartOption"
            :loading="loading"
            style="height: 300px"
            autoresize
          />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="24" :md="12" :lg="12">
        <a-card title="主机风险分布" :bordered="false" class="chart-card">
          <v-chart
            :option="hostRiskChartOption"
            :loading="loading"
            style="height: 300px"
            autoresize
          />
        </a-card>
      </a-col>
    </a-row>

    <!-- 第二行图表 -->
    <a-row :gutter="[16, 16]" class="charts-row">
      <a-col :xs="24" :sm="24" :md="12" :lg="12">
        <a-card title="基线检查结果统计" :bordered="false" class="chart-card">
          <v-chart
            :option="baselineResultChartOption"
            :loading="loading"
            style="height: 300px"
            autoresize
          />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="24" :md="12" :lg="12">
        <a-card title="基线检查严重级别分布" :bordered="false" class="chart-card">
          <v-chart
            :option="severityChartOption"
            :loading="loading"
            style="height: 300px"
            autoresize
          />
        </a-card>
      </a-col>
    </a-row>

    <!-- 第三行图表 -->
    <a-row :gutter="[16, 16]" class="charts-row">
      <a-col :xs="24" :sm="24" :md="12" :lg="12">
        <a-card title="操作系统分布" :bordered="false" class="chart-card">
          <v-chart
            :option="osDistributionChartOption"
            :loading="loading"
            style="height: 300px"
            autoresize
          />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="24" :md="12" :lg="12">
        <a-card title="基线检查类别分布" :bordered="false" class="chart-card">
          <v-chart
            :option="categoryChartOption"
            :loading="loading"
            style="height: 300px"
            autoresize
          />
        </a-card>
      </a-col>
    </a-row>

    <!-- 第四行：趋势图 -->
    <a-row :gutter="[16, 16]" class="charts-row">
      <a-col :xs="24" :sm="24" :md="24" :lg="24">
        <a-card title="基线得分趋势" :bordered="false" class="chart-card">
          <v-chart
            v-if="baselineScoreTrend.dates.length > 0"
            :option="baselineScoreTrendOption"
            :loading="loading"
            style="height: 400px"
            autoresize
          />
          <a-empty
            v-else
            description="暂无数据（后端 API 尚未实现）"
            style="height: 400px; display: flex; align-items: center; justify-content: center"
          />
        </a-card>
      </a-col>
    </a-row>

    <!-- 第五行：检查结果趋势 -->
    <a-row :gutter="[16, 16]" class="charts-row">
      <a-col :xs="24" :sm="24" :md="24" :lg="24">
        <a-card title="检查结果趋势" :bordered="false" class="chart-card">
          <v-chart
            v-if="checkResultTrend.dates.length > 0"
            :option="checkResultTrendOption"
            :loading="loading"
            style="height: 400px"
            autoresize
          />
          <a-empty
            v-else
            description="暂无数据（后端 API 尚未实现）"
            style="height: 400px; display: flex; align-items: center; justify-content: center"
          />
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { ReloadOutlined } from '@ant-design/icons-vue'
import dayjs, { type Dayjs } from 'dayjs'
import { reportsApi, type ReportStats, type BaselineScoreTrend, type CheckResultTrend } from '@/api/reports'
import { hostsApi } from '@/api/hosts'
import { dashboardApi } from '@/api/dashboard'
import type { HostStatusDistribution, HostRiskDistribution } from '@/api/hosts'
import type { EChartsOption } from 'echarts'

const loading = ref(false)
const dateRange = ref<[Dayjs, Dayjs]>([
  dayjs().subtract(7, 'day'),
  dayjs()
])

const datePresets = [
  { label: '最近7天', value: [dayjs().subtract(7, 'day'), dayjs()] },
  { label: '最近30天', value: [dayjs().subtract(30, 'day'), dayjs()] },
  { label: '最近90天', value: [dayjs().subtract(90, 'day'), dayjs()] },
]

const reportStats = ref<ReportStats>({
  hostStats: {
    total: 0,
    online: 0,
    offline: 0,
    byOsFamily: {},
  },
  baselineStats: {
    totalChecks: 0,
    passed: 0,
    failed: 0,
    warning: 0,
    bySeverity: {
      critical: 0,
      high: 0,
      medium: 0,
      low: 0,
    },
    byCategory: {},
  },
  policyStats: {
    total: 0,
    enabled: 0,
    disabled: 0,
    avgPassRate: 0,
  },
  taskStats: {
    total: 0,
    completed: 0,
    running: 0,
    failed: 0,
  },
})

const hostStatusDistribution = ref<HostStatusDistribution>({
  running: 0,
  abnormal: 0,
  offline: 0,
  not_installed: 0,
  uninstalled: 0,
})

const hostRiskDistribution = ref<HostRiskDistribution>({
  host_container_alerts: 0,
  app_runtime_alerts: 0,
  high_exploitable_vulns: 0,
  virus_files: 0,
  high_risk_baselines: 0,
})

const baselineScoreTrend = ref<BaselineScoreTrend>({
  dates: [],
  scores: [],
  passRates: [],
})

const checkResultTrend = ref<CheckResultTrend>({
  dates: [],
  passed: [],
  failed: [],
  warning: [],
})

// 主机状态分布图表配置
const hostStatusChartOption = computed<EChartsOption>(() => ({
  tooltip: {
    trigger: 'item',
    formatter: '{b}: {c} ({d}%)',
  },
  legend: {
    orient: 'vertical',
    left: 'left',
  },
  series: [
    {
      name: '主机状态',
      type: 'pie',
      radius: ['40%', '70%'],
      avoidLabelOverlap: false,
      itemStyle: {
        borderRadius: 10,
        borderColor: '#fff',
        borderWidth: 2,
      },
      label: {
        show: true,
        formatter: '{b}: {c}\n({d}%)',
      },
      emphasis: {
        label: {
          show: true,
          fontSize: 14,
          fontWeight: 'bold',
        },
      },
      data: [
        { value: hostStatusDistribution.value.running, name: '运行中', itemStyle: { color: '#52c41a' } },
        { value: hostStatusDistribution.value.abnormal, name: '异常', itemStyle: { color: '#faad14' } },
        { value: hostStatusDistribution.value.offline, name: '离线', itemStyle: { color: '#ff4d4f' } },
        { value: hostStatusDistribution.value.not_installed, name: '未安装', itemStyle: { color: '#8c8c8c' } },
        { value: hostStatusDistribution.value.uninstalled, name: '已卸载', itemStyle: { color: '#d9d9d9' } },
      ].filter(item => item.value > 0),
    },
  ],
}))

// 主机风险分布图表配置
const hostRiskChartOption = computed<EChartsOption>(() => ({
  tooltip: {
    trigger: 'axis',
    axisPointer: {
      type: 'shadow',
    },
  },
  grid: {
    left: '3%',
    right: '4%',
    bottom: '3%',
    containLabel: true,
  },
  xAxis: {
    type: 'category',
    data: ['主机告警', '运行时告警', '高危漏洞', '病毒文件', '高危基线'],
    axisLabel: {
      rotate: 45,
      interval: 0,
    },
  },
  yAxis: {
    type: 'value',
  },
  series: [
    {
      name: '风险主机数',
      type: 'bar',
      data: [
        hostRiskDistribution.value.host_container_alerts,
        hostRiskDistribution.value.app_runtime_alerts,
        hostRiskDistribution.value.high_exploitable_vulns,
        hostRiskDistribution.value.virus_files,
        hostRiskDistribution.value.high_risk_baselines,
      ],
      itemStyle: {
        color: '#ff4d4f',
      },
    },
  ],
}))

// 基线检查结果统计图表配置
const baselineResultChartOption = computed<EChartsOption>(() => ({
  tooltip: {
    trigger: 'item',
  },
  legend: {
    orient: 'vertical',
    left: 'left',
  },
  series: [
    {
      name: '检查结果',
      type: 'pie',
      radius: '60%',
      data: [
        { value: reportStats.value.baselineStats.passed, name: '通过', itemStyle: { color: '#52c41a' } },
        { value: reportStats.value.baselineStats.failed, name: '失败', itemStyle: { color: '#ff4d4f' } },
        { value: reportStats.value.baselineStats.warning, name: '警告', itemStyle: { color: '#faad14' } },
      ].filter(item => item.value > 0),
      emphasis: {
        itemStyle: {
          shadowBlur: 10,
          shadowOffsetX: 0,
          shadowColor: 'rgba(0, 0, 0, 0.5)',
        },
      },
    },
  ],
}))

// 严重级别分布图表配置
const severityChartOption = computed<EChartsOption>(() => ({
  tooltip: {
    trigger: 'axis',
    axisPointer: {
      type: 'shadow',
    },
  },
  grid: {
    left: '3%',
    right: '4%',
    bottom: '3%',
    containLabel: true,
  },
  xAxis: {
    type: 'category',
    data: ['严重', '高危', '中危', '低危'],
  },
  yAxis: {
    type: 'value',
  },
  series: [
    {
      name: '数量',
      type: 'bar',
      data: [
        reportStats.value.baselineStats.bySeverity.critical,
        reportStats.value.baselineStats.bySeverity.high,
        reportStats.value.baselineStats.bySeverity.medium,
        reportStats.value.baselineStats.bySeverity.low,
      ],
      itemStyle: {
        color: (params: any) => {
          const colors = ['#ff4d4f', '#ff7875', '#ffa940', '#ffc53d']
          return colors[params.dataIndex] || '#1890ff'
        },
      },
    },
  ],
}))

// 操作系统分布图表配置
const osDistributionChartOption = computed<EChartsOption>(() => {
  const osData = Object.entries(reportStats.value.hostStats.byOsFamily).map(([name, value]) => ({
    name,
    value,
  }))
  
  return {
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} ({d}%)',
    },
    legend: {
      orient: 'vertical',
      left: 'left',
    },
    series: [
      {
        name: '操作系统',
        type: 'pie',
        radius: '60%',
        data: osData,
        emphasis: {
          itemStyle: {
            shadowBlur: 10,
            shadowOffsetX: 0,
            shadowColor: 'rgba(0, 0, 0, 0.5)',
          },
        },
      },
    ],
  }
})

// 基线检查类别分布图表配置
const categoryChartOption = computed<EChartsOption>(() => {
  const categoryData = Object.entries(reportStats.value.baselineStats.byCategory).map(([name, value]) => ({
    name,
    value,
  }))
  
  return {
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c}',
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      data: categoryData.map(item => item.name),
      axisLabel: {
        rotate: 45,
        interval: 0,
      },
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        name: '检查项数',
        type: 'bar',
        data: categoryData.map(item => item.value),
        itemStyle: {
          color: '#1890ff',
        },
      },
    ],
  }
})

// 基线得分趋势图表配置
const baselineScoreTrendOption = computed<EChartsOption>(() => ({
  tooltip: {
    trigger: 'axis',
  },
  legend: {
    data: ['基线得分', '通过率'],
  },
  grid: {
    left: '3%',
    right: '4%',
    bottom: '3%',
    containLabel: true,
  },
  xAxis: {
    type: 'category',
    boundaryGap: false,
    data: baselineScoreTrend.value.dates,
  },
  yAxis: [
    {
      type: 'value',
      name: '得分',
      min: 0,
      max: 100,
      position: 'left',
    },
    {
      type: 'value',
      name: '通过率(%)',
      min: 0,
      max: 100,
      position: 'right',
    },
  ],
  series: [
    {
      name: '基线得分',
      type: 'line',
      yAxisIndex: 0,
      data: baselineScoreTrend.value.scores,
      smooth: true,
      itemStyle: {
        color: '#1890ff',
      },
      areaStyle: {
        color: {
          type: 'linear',
          x: 0,
          y: 0,
          x2: 0,
          y2: 1,
          colorStops: [
            { offset: 0, color: 'rgba(24, 144, 255, 0.3)' },
            { offset: 1, color: 'rgba(24, 144, 255, 0.1)' },
          ],
        },
      },
    },
    {
      name: '通过率',
      type: 'line',
      yAxisIndex: 1,
      data: baselineScoreTrend.value.passRates,
      smooth: true,
      itemStyle: {
        color: '#52c41a',
      },
    },
  ],
}))

// 检查结果趋势图表配置
const checkResultTrendOption = computed<EChartsOption>(() => ({
  tooltip: {
    trigger: 'axis',
  },
  legend: {
    data: ['通过', '失败', '警告'],
  },
  grid: {
    left: '3%',
    right: '4%',
    bottom: '3%',
    containLabel: true,
  },
  xAxis: {
    type: 'category',
    boundaryGap: false,
    data: checkResultTrend.value.dates,
  },
  yAxis: {
    type: 'value',
  },
  series: [
    {
      name: '通过',
      type: 'line',
      stack: 'Total',
      data: checkResultTrend.value.passed,
      smooth: true,
      itemStyle: {
        color: '#52c41a',
      },
      areaStyle: {},
    },
    {
      name: '失败',
      type: 'line',
      stack: 'Total',
      data: checkResultTrend.value.failed,
      smooth: true,
      itemStyle: {
        color: '#ff4d4f',
      },
      areaStyle: {},
    },
    {
      name: '警告',
      type: 'line',
      stack: 'Total',
      data: checkResultTrend.value.warning,
      smooth: true,
      itemStyle: {
        color: '#faad14',
      },
      areaStyle: {},
    },
  ],
}))

const handleDateRangeChange = () => {
  refreshData()
}

const refreshData = async () => {
  loading.value = true
  try {
    const startTime = dateRange.value[0].format('YYYY-MM-DD')
    const endTime = dateRange.value[1].format('YYYY-MM-DD')

    // 并行加载所有数据
    const [
      stats,
      statusDist,
      riskDist,
      scoreTrend,
      resultTrend,
    ] = await Promise.all([
      reportsApi.getStats({ start_time: startTime, end_time: endTime }).catch(() => null),
      hostsApi.getStatusDistribution().catch(() => null),
      hostsApi.getRiskDistribution().catch(() => null),
      reportsApi.getBaselineScoreTrend({
        start_time: startTime,
        end_time: endTime,
        interval: 'day',
      }).catch(() => null),
      reportsApi.getCheckResultTrend({
        start_time: startTime,
        end_time: endTime,
        interval: 'day',
      }).catch(() => null),
    ])

    if (stats) {
      reportStats.value = stats
    }

    if (statusDist) {
      hostStatusDistribution.value = statusDist
    }

    if (riskDist) {
      hostRiskDistribution.value = riskDist
    }

    if (scoreTrend) {
      baselineScoreTrend.value = scoreTrend
    }

    if (resultTrend) {
      checkResultTrend.value = resultTrend
    }

    // 如果没有报表统计数据，尝试从 Dashboard API 获取基础数据
    if (!stats) {
      try {
        const dashboardStats = await dashboardApi.getStats()
        reportStats.value.hostStats.total = dashboardStats.hosts
        reportStats.value.hostStats.online = dashboardStats.onlineAgents
        reportStats.value.hostStats.offline = dashboardStats.offlineAgents
        reportStats.value.baselineStats.totalChecks = dashboardStats.baselineFailCount || 0
      } catch (error) {
        console.error('加载 Dashboard 数据失败:', error)
      }
    }
  } catch (error) {
    console.error('加载报表数据失败:', error)
  } finally {
    loading.value = false
  }
}

let refreshInterval: number | null = null

onMounted(() => {
  refreshData()
  // 每5分钟自动刷新一次
  refreshInterval = window.setInterval(() => {
    refreshData()
  }, 5 * 60 * 1000)
})

onUnmounted(() => {
  if (refreshInterval !== null) {
    clearInterval(refreshInterval)
  }
})
</script>

<style scoped>
.reports-page {
  width: 100%;
  padding: 0;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.page-header h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
}

.header-actions {
  display: flex;
  gap: 12px;
  align-items: center;
}

.stats-overview {
  margin-bottom: 16px;
}

.stat-card {
  text-align: center;
}

.charts-row {
  margin-bottom: 16px;
}

.chart-card {
  height: 100%;
}

.chart-card :deep(.ant-card-body) {
  padding: 20px;
}

/* 响应式调整 */
@media (max-width: 768px) {
  .page-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 12px;
  }

  .header-actions {
    width: 100%;
    flex-direction: column;
  }

  .header-actions .ant-picker {
    width: 100%;
  }
}
</style>

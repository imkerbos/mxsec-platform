<template>
  <div class="hosts-page">
    <!-- 主机状态分布和风险分布 -->
    <a-row :gutter="16" style="margin-bottom: 16px" class="distribution-row">
      <!-- 主机状态分布 -->
      <a-col :span="12" class="distribution-col">
        <a-card title="主机状态分布" :bordered="false" class="distribution-card">
          <div class="status-distribution-container">
            <div class="chart-container" @click="handleStatusChartClick">
              <v-chart
                class="status-chart"
                :option="statusChartOption"
                autoresize
              />
              <div class="chart-hint">点击图表查看详情</div>
            </div>
            <div class="legend-container">
              <div class="status-legend">
                <div class="legend-item">
                  <span class="legend-color" style="background: #52c41a"></span>
                  <span>运行中</span>
                  <span class="legend-value">{{ statusDistribution.running }}</span>
                </div>
                <div class="legend-item">
                  <span class="legend-color" style="background: #faad14"></span>
                  <span>运行异常</span>
                  <span class="legend-value">{{ statusDistribution.abnormal }}</span>
                </div>
                <div class="legend-item">
                  <span class="legend-color" style="background: #ff4d4f"></span>
                  <span>离线</span>
                  <span class="legend-value">{{ statusDistribution.offline }}</span>
                </div>
                <div class="legend-item">
                  <span class="legend-color" style="background: #1890ff"></span>
                  <span>未安装</span>
                  <span class="legend-value">{{ statusDistribution.not_installed }}</span>
                </div>
                <div class="legend-item">
                  <span class="legend-color" style="background: #8c8c8c"></span>
                  <span>已卸载</span>
                  <span class="legend-value">{{ statusDistribution.uninstalled }}</span>
                </div>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>

      <!-- 主机风险分布 -->
      <a-col :span="12" class="distribution-col">
        <a-card title="主机风险分布" :bordered="false" class="distribution-card">
          <div class="risk-distribution-container">
            <div class="risk-card">
              <div class="risk-icon" style="border-color: #ff4d4f">
                <ExclamationCircleOutlined style="color: #ff4d4f" />
              </div>
              <div class="risk-content">
                <div class="risk-label">存在主机和容器安全告警</div>
                <div class="risk-value">{{ riskDistribution.host_container_alerts }}</div>
              </div>
            </div>
            <div class="risk-card">
              <div class="risk-icon" style="border-color: #ff4d4f">
                <ExclamationCircleOutlined style="color: #ff4d4f" />
              </div>
              <div class="risk-content">
                <div class="risk-label">存在应用运行时安全告警</div>
                <div class="risk-value">{{ riskDistribution.app_runtime_alerts }}</div>
              </div>
            </div>
            <div class="risk-card">
              <div class="risk-icon" style="border-color: #ff4d4f">
                <ExclamationCircleOutlined style="color: #ff4d4f" />
              </div>
              <div class="risk-content">
                <div class="risk-label">存在高可利用漏洞</div>
                <div class="risk-value">{{ riskDistribution.high_exploitable_vulns }}</div>
              </div>
            </div>
            <div class="risk-card">
              <div class="risk-icon" style="border-color: #ff4d4f">
                <ExclamationCircleOutlined style="color: #ff4d4f" />
              </div>
              <div class="risk-content">
                <div class="risk-label">存在病毒文件</div>
                <div class="risk-value">{{ riskDistribution.virus_files }}</div>
              </div>
            </div>
            <div class="risk-card">
              <div class="risk-icon" style="border-color: #ff4d4f">
                <ExclamationCircleOutlined style="color: #ff4d4f" />
              </div>
              <div class="risk-content">
                <div class="risk-label">存在高危基线</div>
                <div class="risk-value">{{ riskDistribution.high_risk_baselines }}</div>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 主机内容 -->
    <a-card title="主机内容" :bordered="false">
      <!-- 操作按钮和筛选 -->
      <div class="action-bar">
        <div class="action-left">
          <a-space>
            <a-button>Agent离线通知</a-button>
            <a-button>批量导出主机</a-button>
            <a-button>批量添加标签</a-button>
            <a-button>批量下发任务</a-button>
            <a-dropdown>
              <a-button>
                更多
                <DownOutlined />
              </a-button>
              <template #overlay>
                <a-menu>
                  <a-menu-item>批量导入标签</a-menu-item>
                  <a-menu-item>清理离线数据</a-menu-item>
                  <a-menu-item>删除未安装记录</a-menu-item>
                </a-menu>
              </template>
            </a-dropdown>
          </a-space>
        </div>
        <div class="action-right">
          <a-space>
            <span style="color: rgba(0, 0, 0, 0.65)">主机范围:</span>
            <a-select
              v-model:value="filters.hostRange"
              placeholder="全部"
              style="width: 120px"
            >
              <a-select-option value="all">全部</a-select-option>
              <a-select-option value="online">在线</a-select-option>
              <a-select-option value="offline">离线</a-select-option>
            </a-select>
            <a-button @click="loadHosts">
              <template #icon>
                <ReloadOutlined />
              </template>
            </a-button>
          </a-space>
        </div>
      </div>

      <!-- 搜索区域 -->
      <div class="filter-bar">
        <a-input
          v-model:value="filters.search"
          placeholder="请选择筛选条件并搜索"
          style="width: 300px"
          allow-clear
        >
          <template #prefix>
            <SearchOutlined />
          </template>
        </a-input>
        <a-button type="primary" @click="handleSearch">
          <template #icon>
            <SearchOutlined />
          </template>
          搜索
        </a-button>
      </div>

    <!-- 主机列表表格 -->
    <a-table
      :columns="columns"
      :data-source="hosts"
      :loading="loading"
      :pagination="pagination"
      :row-selection="rowSelection"
      @change="handleTableChange"
      row-key="host_id"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'hostname'">
          <a-button type="link" @click="handleViewDetail(record)">
            {{ record.hostname }}
          </a-button>
        </template>
        <template v-else-if="column.key === 'tags'">
          <a-space>
            <a-tag v-for="tag in record.tags" :key="tag">{{ tag }}</a-tag>
            <span v-if="!record.tags || record.tags.length === 0" style="color: #8c8c8c">-</span>
          </a-space>
        </template>
        <template v-else-if="column.key === 'risk'">
          <ScoreDisplay :host-id="record.host_id" />
        </template>
        <template v-else-if="column.key === 'status'">
          <a-tag :color="record.status === 'online' ? 'green' : 'red'">
            {{ record.status === 'online' ? '在线' : '离线' }}
          </a-tag>
        </template>
        <template v-else-if="column.key === 'resource_usage'">
          <div>
            <div>CPU: {{ record.cpu_usage || 0 }}%</div>
            <div>内存: {{ record.memory_usage || 0 }}%</div>
          </div>
        </template>
        <template v-else-if="column.key === 'action'">
          <a-button type="link" @click="handleViewDetail(record)">查看详情</a-button>
        </template>
      </template>
      <template #emptyText>
        <a-empty description="暂无数据" />
      </template>
    </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import {
  ReloadOutlined,
  SearchOutlined,
  DownOutlined,
  ExclamationCircleOutlined,
} from '@ant-design/icons-vue'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { PieChart } from 'echarts/charts'
import {
  TitleComponent,
  TooltipComponent,
  LegendComponent,
} from 'echarts/components'
import VChart from 'vue-echarts'
import { hostsApi, type HostStatusDistribution, type HostRiskDistribution } from '@/api/hosts'
import type { Host } from '@/api/types'
import ScoreDisplay from './components/ScoreDisplay.vue'
import { message } from 'ant-design-vue'

// 注册 ECharts 组件
use([CanvasRenderer, PieChart, TitleComponent, TooltipComponent, LegendComponent])

const router = useRouter()

const loading = ref(false)
const hosts = ref<Host[]>([])
const selectedRowKeys = ref<string[]>([])
const statusDistribution = ref<HostStatusDistribution>({
  running: 0,
  abnormal: 0,
  offline: 0,
  not_installed: 0,
  uninstalled: 0,
})
const riskDistribution = ref<HostRiskDistribution>({
  host_container_alerts: 0,
  app_runtime_alerts: 0,
  high_exploitable_vulns: 0,
  virus_files: 0,
  high_risk_baselines: 0,
})

const filters = reactive({
  hostRange: 'all' as string,
  search: '' as string,
  os_family: undefined as string | undefined,
  status: undefined as string | undefined,
})

const statusTotal = computed(() => {
  return (
    statusDistribution.value.running +
    statusDistribution.value.abnormal +
    statusDistribution.value.offline +
    statusDistribution.value.not_installed +
    statusDistribution.value.uninstalled
  )
})

// 主机状态分布饼图配置
const statusChartOption = computed(() => {
  const data = [
    {
      value: statusDistribution.value.running,
      name: '运行中',
      itemStyle: { color: '#52c41a' },
    },
    {
      value: statusDistribution.value.abnormal,
      name: '运行异常',
      itemStyle: { color: '#faad14' },
    },
    {
      value: statusDistribution.value.offline,
      name: '离线',
      itemStyle: { color: '#ff4d4f' },
    },
    {
      value: statusDistribution.value.not_installed,
      name: '未安装',
      itemStyle: { color: '#1890ff' },
    },
    {
      value: statusDistribution.value.uninstalled,
      name: '已卸载',
      itemStyle: { color: '#8c8c8c' },
    },
  ]

  // 如果所有值都是0，显示一个占位饼图（显示所有分类，但值为0）
  const hasData = data.some((item) => item.value > 0)

  return {
    tooltip: {
      trigger: 'item',
      formatter: (params: any) => {
        if (!hasData) {
          return `${params.name}: 0`
        }
        return `${params.name}: ${params.value} (${params.percent}%)`
      },
    },
    series: [
      {
        name: '主机状态',
        type: 'pie',
        radius: ['40%', '70%'],
        center: ['50%', '50%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 4,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: {
          show: hasData,
          formatter: '{b}: {c}',
          fontSize: 12,
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 14,
            fontWeight: 'bold',
          },
        },
        labelLine: {
          show: hasData,
        },
        // 即使没有数据也显示所有分类的饼图
        data: hasData
          ? data.filter((item) => item.value > 0)
          : data.map((item) => ({
              ...item,
              value: 1, // 每个分类占相等比例（20%）
              itemStyle: { ...item.itemStyle, opacity: 0.5 }, // 降低透明度表示无数据
            })),
        animation: true,
        animationType: 'scale',
        animationEasing: 'elasticOut',
      },
    ],
  }
})

const rowSelection = computed(() => ({
  selectedRowKeys: selectedRowKeys.value,
  onChange: (keys: string[]) => {
    selectedRowKeys.value = keys
  },
}))

const pagination = reactive({
  current: 1,
  pageSize: 20,
  total: 0,
  showSizeChanger: true,
  showTotal: (total: number) => `共 ${total} 条`,
})

const columns = [
  {
    title: '主机名称',
    key: 'hostname',
    width: 200,
  },
  {
    title: '标签',
    key: 'tags',
    width: 150,
  },
  {
    title: '地域',
    dataIndex: 'region',
    key: 'region',
    width: 120,
    customRender: () => '-',
  },
  {
    title: '操作系统',
    key: 'os',
    width: 180,
    customRender: ({ record }: { record: Host }) => {
      return `${record.os_family} ${record.os_version}`
    },
  },
  {
    title: '风险',
    key: 'risk',
    width: 150,
  },
  {
    title: '状态',
    key: 'status',
    width: 100,
  },
  {
    title: '客户端资源使用',
    key: 'resource_usage',
    width: 150,
  },
  {
    title: '更新时间',
    dataIndex: 'last_heartbeat',
    key: 'last_heartbeat',
    width: 180,
  },
  {
    title: '操作',
    key: 'action',
    width: 100,
    fixed: 'right' as const,
  },
]

const loadHosts = async () => {
  loading.value = true
  try {
    const response = await hostsApi.list({
      page: pagination.current,
      page_size: pagination.pageSize,
      os_family: filters.os_family,
      status: filters.status,
    })
    hosts.value = response.items
    pagination.total = response.total
  } catch (error) {
    console.error('加载主机列表失败:', error)
    message.error('加载主机列表失败')
  } finally {
    loading.value = false
  }
}

const loadStatusDistribution = async () => {
  try {
    const data = await hostsApi.getStatusDistribution()
    statusDistribution.value = data
  } catch (error) {
    console.error('加载主机状态分布失败:', error)
  }
}

const loadRiskDistribution = async () => {
  try {
    const data = await hostsApi.getRiskDistribution()
    riskDistribution.value = data
  } catch (error) {
    console.error('加载主机风险分布失败:', error)
  }
}

const handleStatusChartClick = () => {
  // TODO: 实现点击图表查看详情的功能
  message.info('点击图表查看详情功能开发中')
}

const handleSearch = () => {
  pagination.current = 1
  loadHosts()
}

const handleReset = () => {
  filters.hostRange = 'all'
  filters.search = ''
  filters.os_family = undefined
  filters.status = undefined
  pagination.current = 1
  loadHosts()
}

const handleTableChange = (pag: any) => {
  pagination.current = pag.current
  pagination.pageSize = pag.pageSize
  loadHosts()
}

const handleViewDetail = (record: Host) => {
  router.push(`/hosts/${record.host_id}`)
}

onMounted(() => {
  loadHosts()
  loadStatusDistribution()
  loadRiskDistribution()
})
</script>

<style scoped>
.hosts-page {
  width: 100%;
}

.distribution-row {
  display: flex;
  align-items: stretch;
}

.distribution-col {
  display: flex;
}

.distribution-card {
  width: 100%;
  display: flex;
  flex-direction: column;
}

.distribution-card :deep(.ant-card-body) {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.status-distribution-container {
  display: flex;
  align-items: flex-start;
  gap: 24px;
  flex: 1;
  min-height: 280px;
}

.chart-container {
  flex: 1;
  position: relative;
  cursor: pointer;
}

.status-chart {
  width: 100%;
  height: 200px;
}

.chart-hint {
  text-align: center;
  margin-top: 8px;
  color: #8c8c8c;
  font-size: 12px;
}

.legend-container {
  flex: 1;
  min-width: 200px;
}

.status-legend {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 8px;
}

.legend-color {
  width: 12px;
  height: 12px;
  border-radius: 2px;
  display: inline-block;
}

.legend-value {
  margin-left: auto;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.85);
}

.risk-distribution-container {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
  flex: 1;
  align-content: start;
}

.risk-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 1px solid #f0f0f0;
  border-radius: 4px;
  background: #fafafa;
  min-height: 70px;
}

.risk-icon {
  width: 40px;
  height: 40px;
  border: 2px solid;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  flex-shrink: 0;
}

.risk-content {
  flex: 1;
  min-width: 0;
}

.risk-label {
  font-size: 12px;
  color: rgba(0, 0, 0, 0.65);
  margin-bottom: 4px;
  line-height: 1.4;
  word-break: break-word;
}

.risk-value {
  font-size: 20px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.85);
}

.action-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.action-left {
  flex: 1;
}

.action-right {
  display: flex;
  align-items: center;
}

.filter-bar {
  margin-bottom: 16px;
  display: flex;
  gap: 8px;
  align-items: center;
}
</style>

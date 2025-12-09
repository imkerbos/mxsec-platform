<template>
  <div class="policy-detail-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <a-button type="text" @click="handleBack" class="back-btn">
        <ArrowLeftOutlined />
      </a-button>
      <h2 class="page-title">{{ policy?.name || '基线检查详情' }}</h2>
      <div class="header-extra">
        <span class="check-time-text">
          最近检查时间(每日自动检查): {{ lastCheckTime || '-' }}
        </span>
        <a-button type="primary" size="large" @click="handleCheckNow" class="check-now-btn">
          立即检查
        </a-button>
      </div>
    </div>

    <!-- 基线检查概览 -->
    <a-row :gutter="24" class="overview-row">
      <a-col :span="8">
        <a-card :bordered="false" class="overview-card">
          <div class="overview-content">
            <div class="overview-title">最近检查通过率</div>
            <div class="overview-value-wrapper">
              <a-progress
                type="circle"
                :percent="passRate"
                :stroke-color="getPassRateColor(passRate)"
                :size="100"
                :stroke-width="8"
                class="overview-progress"
              >
                <template #format>
                  <div class="progress-text">
                    <span class="progress-percent">{{ passRate }}%</span>
                  </div>
                </template>
              </a-progress>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :span="8">
        <a-card :bordered="false" class="overview-card">
          <div class="overview-content">
            <div class="overview-title">检查主机数</div>
            <div class="overview-value-wrapper">
              <div class="overview-number">{{ hostCount }}</div>
              <div class="overview-stats">
                <div class="stat-item">
                  <span class="stat-dot stat-dot-fail"></span>
                  <span class="stat-label">未通过主机</span>
                  <span class="stat-value">{{ hostCount - hostPassCount }}</span>
                </div>
                <div class="stat-item">
                  <span class="stat-dot stat-dot-pass"></span>
                  <span class="stat-label">通过主机</span>
                  <span class="stat-value">{{ hostPassCount }}</span>
                </div>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :span="8">
        <a-card :bordered="false" class="overview-card">
          <div class="overview-content">
            <div class="overview-title">检查项</div>
            <div class="overview-value-wrapper">
              <div class="overview-number">{{ ruleCount }}</div>
              <div class="overview-stats">
                <div class="stat-item">
                  <span class="stat-dot stat-dot-risk"></span>
                  <span class="stat-label">风险项</span>
                  <span class="stat-value">{{ riskCount }}</span>
                </div>
                <div class="stat-item">
                  <span class="stat-dot stat-dot-safe"></span>
                  <span class="stat-label">通过项</span>
                  <span class="stat-value">{{ ruleCount - riskCount }}</span>
                </div>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 检查详情区 -->
    <a-card :bordered="false" class="detail-card">
      <a-tabs v-model:activeKey="viewMode" @change="handleViewModeChange" class="detail-tabs">
        <a-tab-pane key="rules" tab="检查项视角">
          <div class="detail-content">
            <!-- 左侧：检查项列表 -->
            <div class="left-panel">
              <div class="panel-header">
                <div class="panel-actions">
                  <a-space>
                    <a-button
                      type="primary"
                      :disabled="selectedRuleIds.length === 0"
                      @click="handleBatchRecheck"
                    >
                      批量重新检查
                    </a-button>
                    <a-button
                      :disabled="selectedRuleIds.length === 0"
                      @click="handleBatchExport"
                    >
                      批量导出
                    </a-button>
                  </a-space>
                </div>
                <div class="panel-search">
                  <a-input
                    v-model:value="searchKeyword"
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
                  <a-button @click="loadRules">
                    <template #icon>
                      <ReloadOutlined />
                    </template>
                  </a-button>
                </div>
              </div>
              <a-table
                :columns="ruleColumns"
                :data-source="filteredRules"
                :loading="loading"
                :pagination="{ pageSize: 20, showSizeChanger: true, showTotal: (total: number) => `共 ${total} 条` }"
                :row-selection="{
                  selectedRowKeys: selectedRuleIds,
                  onChange: handleSelectionChange,
                }"
                :customRow="(record: Rule) => ({
                  onClick: (event: MouseEvent) => {
                    // 如果点击的是复选框、按钮或链接，不触发行点击
                    const target = event.target as HTMLElement
                    if (
                      target.closest('.ant-checkbox-wrapper') ||
                      target.closest('.ant-checkbox') ||
                      target.closest('button') ||
                      target.closest('a')
                    ) {
                      return
                    }
                    handleRuleClick(record)
                  },
                })"
                row-key="rule_id"
                class="rule-table"
                :row-class-name="getRowClassName"
              >
                <template #bodyCell="{ column, record }">
                  <template v-if="column.key === 'severity'">
                    <a-tag :color="getSeverityColor(record.severity)" class="severity-tag">
                      {{ getSeverityText(record.severity) }}
                    </a-tag>
                  </template>
                  <template v-else-if="column.key === 'pass_rate'">
                    <div class="pass-rate-cell">
                      <a-progress
                        :percent="getRulePassRate(record.rule_id)"
                        :stroke-color="getPassRateColor(getRulePassRate(record.rule_id))"
                        :show-info="false"
                        size="small"
                        class="pass-rate-progress"
                      />
                      <span class="pass-rate-text">{{ getRulePassRate(record.rule_id) }}%</span>
                    </div>
                  </template>
                  <template v-else-if="column.key === 'action'">
                    <a-button type="link" size="small" @click.stop="handleRecheck(record)" class="action-btn">
                      重新检查
                    </a-button>
                  </template>
                </template>
              </a-table>
            </div>

            <!-- 右侧：选中检查项详情 -->
            <div class="right-panel">
              <div v-if="selectedRule" class="rule-detail">
                <!-- 固定区域：标题、描述、加固建议 -->
                <div class="detail-fixed-section">
                  <h3 class="rule-detail-title">{{ selectedRule.title }}</h3>

                  <!-- 描述 -->
                  <div class="detail-section">
                    <div class="detail-section-label">描述</div>
                    <div v-if="selectedRule.description" class="description-content">
                      <div
                        v-for="(line, index) in formatDescription(selectedRule.description)"
                        :key="index"
                        class="description-line"
                      >
                        {{ line }}
                      </div>
                    </div>
                    <div v-else class="detail-text-empty">-</div>
                  </div>

                  <!-- 加固建议 -->
                  <div class="detail-section">
                    <div class="detail-section-label">加固建议</div>
                    <div v-if="selectedRule.fix_config?.suggestion" class="suggestion-content">
                      <div
                        v-for="(solution, index) in parseSuggestion(selectedRule.fix_config.suggestion)"
                        :key="index"
                        class="solution-item"
                      >
                        <div class="solution-title">{{ solution.title }}</div>
                        <ol v-if="solution.steps.length > 0" class="solution-steps">
                          <li v-for="(step, stepIndex) in solution.steps" :key="stepIndex" class="solution-step">
                            {{ step }}
                          </li>
                        </ol>
                        <div v-else class="solution-text">{{ solution.content }}</div>
                      </div>
                    </div>
                    <div v-else class="detail-text-empty">-</div>
                  </div>
                </div>

                <!-- 可滚动区域：影响的主机 -->
                <div class="detail-scrollable-section">
                  <div class="detail-section">
                    <div class="detail-section-header">
                      <div class="detail-section-label">影响的主机</div>
                      <div class="detail-section-actions">
                        <a-button
                          type="default"
                          size="small"
                          :disabled="selectedHostIds.length === 0"
                          @click="handleBatchExportHosts"
                        >
                          批量导出
                        </a-button>
                        <a-button
                          type="primary"
                          size="small"
                          :disabled="selectedHostIds.length === 0"
                          @click="handleBatchWhitelist"
                        >
                          批量重新检查
                        </a-button>
                      </div>
                    </div>
                    <div class="host-search-bar">
                      <a-input
                        v-model:value="hostSearchKeyword"
                        placeholder="请选择筛选条件并搜索"
                        style="width: 300px"
                        allow-clear
                      >
                        <template #prefix>
                          <SearchOutlined />
                        </template>
                      </a-input>
                      <a-button type="primary" @click="handleHostSearch">
                        <template #icon>
                          <SearchOutlined />
                        </template>
                        搜索
                      </a-button>
                      <a-button @click="loadAffectedHosts">
                        <template #icon>
                          <ReloadOutlined />
                        </template>
                      </a-button>
                    </div>
                    <a-table
                      :columns="hostColumns"
                      :data-source="filteredAffectedHosts"
                      :loading="hostsLoading"
                      :pagination="{ pageSize: 10, showSizeChanger: true, showTotal: (total: number) => `共 ${total} 条` }"
                      :row-selection="{
                        selectedRowKeys: selectedHostIds,
                        onChange: handleHostSelectionChange,
                      }"
                      row-key="host_id"
                      class="host-table"
                      :bordered="false"
                    >
                      <template #bodyCell="{ column, record }">
                        <template v-if="column.key === 'result'">
                          <a-tag :color="getResultColor(record.status)" class="result-tag">
                            {{ getResultText(record.status) }}
                          </a-tag>
                        </template>
                        <template v-else-if="column.key === 'action'">
                          <a-button type="link" size="small" @click="handleWhitelist(record)" class="action-btn">
                            加白名单
                          </a-button>
                        </template>
                      </template>
                      <template #emptyText>
                        <a-empty description="暂无数据" :image="false" />
                      </template>
                    </a-table>
                  </div>
                </div>
              </div>
              <a-empty v-else description="请从左侧选择一个检查项" class="empty-state" />
            </div>
          </div>
        </a-tab-pane>
        <a-tab-pane key="hosts" tab="主机视角">
          <div class="empty-tab-content">
            <a-empty description="主机视角功能待实现" />
          </div>
        </a-tab-pane>
      </a-tabs>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ArrowLeftOutlined, ReloadOutlined, SearchOutlined } from '@ant-design/icons-vue'
import { policiesApi } from '@/api/policies'
import { resultsApi } from '@/api/results'
import type { Policy, Rule, ScanResult } from '@/api/types'
import { message } from 'ant-design-vue'

const router = useRouter()
const route = useRoute()

const loading = ref(false)
const hostsLoading = ref(false)
const policy = ref<Policy | null>(null)
const rules = ref<Rule[]>([])
const selectedRule = ref<Rule | null>(null)
const affectedHosts = ref<any[]>([])
const selectedRuleIds = ref<string[]>([])
const selectedHostIds = ref<string[]>([])
const searchKeyword = ref('')
const hostSearchKeyword = ref('')
const viewMode = ref('rules')
const lastCheckTime = ref('')

// 统计数据
const passRate = ref(0)
const hostCount = ref(0)
const hostPassCount = ref(0)
const ruleCount = ref(0)
const riskCount = ref(0)

const ruleColumns = [
  {
    title: '检查项',
    key: 'title',
    dataIndex: 'title',
    ellipsis: true,
  },
  {
    title: '级别',
    key: 'severity',
    width: 100,
    sorter: (a: Rule, b: Rule) => {
      const severityOrder: Record<string, number> = {
        critical: 4,
        high: 3,
        medium: 2,
        low: 1,
      }
      return (severityOrder[a.severity] || 0) - (severityOrder[b.severity] || 0)
    },
  },
  {
    title: '通过率',
    key: 'pass_rate',
    width: 150,
    sorter: (a: Rule, b: Rule) => {
      return getRulePassRate(a.rule_id) - getRulePassRate(b.rule_id)
    },
  },
  {
    title: '操作',
    key: 'action',
    width: 120,
  },
]

const hostColumns = [
  {
    title: '影响主机',
    key: 'hostname',
    dataIndex: 'hostname',
  },
  {
    title: '标签',
    key: 'tags',
    dataIndex: 'tags',
  },
  {
    title: '检查结果',
    key: 'result',
    width: 120,
  },
  {
    title: '操作',
    key: 'action',
    width: 120,
  },
]

const filteredRules = computed(() => {
  if (!searchKeyword.value) return rules.value
  return rules.value.filter((rule) =>
    rule.title.toLowerCase().includes(searchKeyword.value.toLowerCase())
  )
})

const filteredAffectedHosts = computed(() => {
  if (!hostSearchKeyword.value) return affectedHosts.value
  return affectedHosts.value.filter((host) =>
    host.hostname?.toLowerCase().includes(hostSearchKeyword.value.toLowerCase())
  )
})

// 移除未使用的计算属性

const loadPolicyDetail = async () => {
  const policyId = route.params.policyId as string
  if (!policyId) return

  loading.value = true
  try {
    const data = (await policiesApi.get(policyId)) as unknown as Policy
    policy.value = data
    rules.value = data.rules || []
    ruleCount.value = rules.value.length

    console.log('加载策略详情成功:', {
      policyId,
      ruleCount: rules.value.length,
      rules: rules.value,
    })

    // 如果规则列表不为空且没有选中项，默认选中第一项
    if (rules.value.length > 0 && !selectedRule.value) {
      handleRuleClick(rules.value[0])
    }

    // 加载检查结果统计
    await loadStatistics()
  } catch (error) {
    console.error('加载策略详情失败:', error)
    message.error('加载策略详情失败')
  } finally {
    loading.value = false
  }
}

const loadStatistics = async () => {
  if (!policy.value) return

  try {
    // 加载该策略的所有检查结果
    const resultsResponse = (await resultsApi.list({
      policy_id: policy.value.id,
      page_size: 1000,
    })) as unknown as { total: number; items: ScanResult[] }

    const results = resultsResponse.items
    const hostIds = new Set(results.map((r: ScanResult) => r.host_id))
    hostCount.value = hostIds.size

    // 计算通过率
    const totalResults = results.length
    const passResults = results.filter((r: ScanResult) => r.status === 'pass').length
    passRate.value = totalResults > 0 ? Math.round((passResults / totalResults) * 100) : 0

    // 计算风险项数量
    const failedRules = new Set(
      results.filter((r: ScanResult) => r.status === 'fail').map((r: ScanResult) => r.rule_id)
    )
    riskCount.value = failedRules.size

    // 计算通过的主机数（所有规则都通过的主机）
    const hostResultsMap = new Map<string, ScanResult[]>()
    results.forEach((r: ScanResult) => {
      if (!hostResultsMap.has(r.host_id)) {
        hostResultsMap.set(r.host_id, [])
      }
      hostResultsMap.get(r.host_id)!.push(r)
    })

    let passHostCount = 0
    hostResultsMap.forEach((hostResults) => {
      const allPass = hostResults.every((r) => r.status === 'pass')
      if (allPass) {
        passHostCount++
      }
    })
    hostPassCount.value = passHostCount
  } catch (error) {
    console.error('加载统计信息失败:', error)
  }
}

const loadAffectedHosts = async () => {
  if (!selectedRule.value || !policy.value) return

  hostsLoading.value = true
  try {
    const resultsResponse = (await resultsApi.list({
      policy_id: policy.value.id,
      rule_id: selectedRule.value.rule_id,
      page_size: 1000,
    })) as unknown as { total: number; items: ScanResult[] }

    // 按主机分组
    const hostMap = new Map()
    resultsResponse.items.forEach((result: ScanResult) => {
      if (!hostMap.has(result.host_id)) {
        hostMap.set(result.host_id, {
          host_id: result.host_id,
          hostname: result.host_id, // TODO: 从主机API获取主机名
          status: result.status,
          tags: [],
        })
      }
    })

    affectedHosts.value = Array.from(hostMap.values())
  } catch (error) {
    console.error('加载受影响主机失败:', error)
  } finally {
    hostsLoading.value = false
  }
}

// 存储规则通过率缓存
const rulePassRateCache = ref<Map<string, number>>(new Map())

const getRulePassRate = (_ruleId: string): number => {
  // TODO: 计算该规则的通过率
  // 临时返回随机值用于演示，实际应该从统计数据中获取
  if (!rulePassRateCache.value.has(_ruleId)) {
    rulePassRateCache.value.set(_ruleId, Math.floor(Math.random() * 100))
  }
  return rulePassRateCache.value.get(_ruleId) || 0
}

const getPassRateColor = (rate: number): string => {
  if (rate >= 90) return '#52c41a'
  if (rate >= 70) return '#faad14'
  if (rate >= 50) return '#fa8c16'
  return '#ff4d4f'
}

const getRowClassName = (record: Rule) => {
  return selectedRule.value?.rule_id === record.rule_id ? 'table-row-selected' : ''
}

const handleBatchExport = () => {
  message.info(`批量导出 ${selectedRuleIds.value.length} 个规则`)
  // TODO: 实现批量导出
}

const handleBatchExportHosts = () => {
  message.info(`批量导出 ${selectedHostIds.value.length} 个主机`)
  // TODO: 实现批量导出主机
}

const handleBack = () => {
  router.push('/policies')
}

const handleCheckNow = () => {
  message.info('立即检查功能待实现')
}

const handleViewModeChange = (key: string) => {
  viewMode.value = key
}

const handleRuleClick = (record: Rule) => {
  console.log('点击检查项:', record)
  selectedRule.value = record
  selectedRuleIds.value = [record.rule_id]
  loadAffectedHosts()
}

const handleSelectionChange = (keys: string[]) => {
  selectedRuleIds.value = keys
}

const handleHostSelectionChange = (keys: string[]) => {
  selectedHostIds.value = keys
}

const handleSearch = () => {
  // 搜索已通过filteredRules处理
}

const handleHostSearch = () => {
  // 搜索已通过filteredAffectedHosts处理
}

const handleRecheck = (rule: Rule) => {
  message.info(`重新检查规则: ${rule.title}`)
  // TODO: 实现重新检查
}

const handleBatchRecheck = () => {
  message.info(`批量重新检查 ${selectedRuleIds.value.length} 个规则`)
  // TODO: 实现批量重新检查
}

const handleWhitelist = (host: any) => {
  message.info(`将主机 ${host.hostname} 加入白名单`)
  // TODO: 实现加白名单
}

const handleBatchWhitelist = () => {
  message.info(`批量将 ${selectedHostIds.value.length} 个主机加入白名单`)
  // TODO: 实现批量加白名单
}

const loadRules = () => {
  loadPolicyDetail()
}

const getSeverityColor = (severity: string) => {
  const colors: Record<string, string> = {
    critical: 'red',
    high: 'red',
    medium: 'orange',
    low: 'blue',
  }
  return colors[severity] || 'default'
}

const getSeverityText = (severity: string) => {
  const texts: Record<string, string> = {
    critical: '严重',
    high: '高危',
    medium: '中危',
    low: '低危',
  }
  return texts[severity] || severity
}

const getResultColor = (status: string) => {
  const colors: Record<string, string> = {
    pass: 'green',
    fail: 'red',
    error: 'orange',
    na: 'default',
  }
  return colors[status] || 'default'
}

const getResultText = (status: string) => {
  const texts: Record<string, string> = {
    pass: '通过',
    fail: '失败',
    error: '错误',
    na: '不适用',
  }
  return texts[status] || status
}

// 格式化描述：将描述文本按换行分割，支持多行显示
const formatDescription = (description: string): string[] => {
  if (!description) return []
  return description
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
}

// 解析加固建议：支持多个方案和步骤
interface Solution {
  title: string
  content: string
  steps: string[]
}

const parseSuggestion = (suggestion: string): Solution[] => {
  if (!suggestion) return []

  const solutions: Solution[] = []
  const lines = suggestion.split('\n').map((line) => line.trim()).filter((line) => line.length > 0)

  let currentSolution: Solution | null = null

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]

    // 检测方案标题（支持"方案一"、"方案二"、"方案1"、"方案2"等格式）
    const solutionMatch = line.match(/^方案[一二三四五六七八九十\d]+[：:]\s*(.+)$/)
    if (solutionMatch) {
      // 保存上一个方案
      if (currentSolution) {
        solutions.push(currentSolution)
      }
      // 创建新方案
      currentSolution = {
        title: solutionMatch[1] || solutionMatch[0],
        content: '',
        steps: [],
      }
      continue
    }

    // 如果没有当前方案，创建默认方案
    if (!currentSolution) {
      currentSolution = {
        title: '修复建议',
        content: '',
        steps: [],
      }
    }

    // 检测步骤（支持多种格式：1. 2. ① ② 等）
    // 优先匹配数字编号格式（1. 或 1、）
    const numStepMatch = line.match(/^(\d+)[.、]\s*(.+)$/)
    if (numStepMatch) {
      currentSolution.steps.push(numStepMatch[2])
      continue
    }

    // 匹配中文数字编号（① ② ③ 等）
    const chineseNumMatch = line.match(/^[①②③④⑤⑥⑦⑧⑨⑩][.、]?\s*(.+)$/)
    if (chineseNumMatch) {
      currentSolution.steps.push(chineseNumMatch[1])
      continue
    }

    // 匹配带括号的数字（(1) 或 （1））
    const parenNumMatch = line.match(/^[（(](\d+)[）)]\s*(.+)$/)
    if (parenNumMatch) {
      currentSolution.steps.push(parenNumMatch[2])
      continue
    }

    // 普通文本行
    if (currentSolution.steps.length === 0) {
      // 如果没有步骤，作为内容
      if (currentSolution.content) {
        currentSolution.content += '\n' + line
      } else {
        currentSolution.content = line
      }
    } else {
      // 如果有步骤，可能是步骤的续行（如果行首不是数字或特殊字符）
      if (!line.match(/^[\d①②③④⑤⑥⑦⑧⑨⑩（(]/)) {
        const lastStepIndex = currentSolution.steps.length - 1
        currentSolution.steps[lastStepIndex] += ' ' + line
      } else {
        // 如果行首是数字或特殊字符但不是步骤格式，作为新内容
        if (currentSolution.content) {
          currentSolution.content += '\n' + line
        } else {
          currentSolution.content = line
        }
      }
    }
  }

  // 保存最后一个方案
  if (currentSolution) {
    solutions.push(currentSolution)
  }

  // 如果没有解析出任何方案，返回原始文本作为单个方案
  if (solutions.length === 0) {
    return [
      {
        title: '修复建议',
        content: suggestion,
        steps: [],
      },
    ]
  }

  return solutions
}

onMounted(() => {
  loadPolicyDetail()
})
</script>

<style scoped>
.policy-detail-page {
  width: 100%;
}

/* 页面头部 */
.page-header {
  display: flex;
  align-items: center;
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.back-btn {
  padding: 0;
  margin-right: 12px;
  font-size: 16px;
  color: #595959;
  transition: color 0.3s;
}

.back-btn:hover {
  color: #1890ff;
}

.page-title {
  font-size: 20px;
  font-weight: 600;
  flex: 1;
  margin: 0;
  color: #262626;
}

.header-extra {
  display: flex;
  align-items: center;
  gap: 16px;
}

.check-time-text {
  color: #8c8c8c;
  font-size: 14px;
}

.check-now-btn {
  height: 36px;
  font-weight: 500;
}

/* 概览卡片 */
.overview-row {
  margin-bottom: 16px;
}

.overview-row :deep(.ant-col) {
  display: flex;
}

.overview-card {
  transition: all 0.3s;
  width: 100%;
  display: flex;
  flex-direction: column;
  height: 100%;
}

.overview-card :deep(.ant-card-body) {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 20px;
}

.overview-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 160px;
}

.overview-title {
  font-size: 14px;
  color: #8c8c8c;
  margin-bottom: 16px;
  text-align: center;
  flex-shrink: 0;
}

.overview-value-wrapper {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
}

.overview-progress {
  margin: 0 auto;
  flex-shrink: 0;
}

.progress-text {
  text-align: center;
}

.progress-percent {
  font-size: 28px;
  font-weight: 600;
  color: #262626;
}

.overview-number {
  font-size: 40px;
  font-weight: 600;
  color: #1890ff;
  line-height: 1;
  margin-bottom: 12px;
  flex-shrink: 0;
}

.overview-stats {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
  flex-shrink: 0;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
}

.stat-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.stat-dot-fail {
  background: #ff4d4f;
}

.stat-dot-pass {
  background: #1890ff;
}

.stat-dot-risk {
  background: #ff4d4f;
}

.stat-dot-safe {
  background: #d9d9d9;
}

.stat-label {
  color: #595959;
  flex: 1;
}

.stat-value {
  font-weight: 600;
  color: #262626;
}

/* 详情卡片 */
.detail-tabs :deep(.ant-tabs-nav) {
  margin-bottom: 0;
  padding: 0 24px;
  background: #fafafa;
}

.detail-tabs :deep(.ant-tabs-tab) {
  padding: 16px 24px;
  font-size: 14px;
  font-weight: 500;
}

.detail-tabs :deep(.ant-tabs-content) {
  padding: 24px;
}

.detail-content {
  display: flex;
  gap: 24px;
  min-height: 600px;
}

/* 左侧面板 */
.left-panel {
  flex: 1;
  border-right: 1px solid #f0f0f0;
  padding-right: 24px;
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid #f0f0f0;
  gap: 16px;
}

.panel-actions {
  flex: 1;
}

.panel-search {
  display: flex;
  align-items: center;
  gap: 8px;
}

/* 表格样式 */
.rule-table :deep(.ant-table) {
  background: #fff;
}

.rule-table :deep(.ant-table-thead > tr > th) {
  background: #fafafa;
  font-weight: 600;
  color: #262626;
  border-bottom: 2px solid #f0f0f0;
}

.rule-table :deep(.ant-table-tbody > tr) {
  cursor: pointer;
  transition: all 0.2s;
}

.rule-table :deep(.ant-table-tbody > tr:hover) {
  background: #f5f5f5;
}

.rule-table :deep(.ant-table-tbody > tr.table-row-selected) {
  background: #e6f7ff;
}

.rule-table :deep(.ant-table-tbody > tr.table-row-selected:hover) {
  background: #bae7ff;
}

.pass-rate-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}

.pass-rate-progress {
  flex: 1;
  min-width: 60px;
}

.pass-rate-text {
  font-size: 14px;
  color: #595959;
  min-width: 40px;
  text-align: right;
}

.severity-tag {
  font-weight: 500;
  border: none;
  padding: 2px 8px;
}

.action-btn {
  padding: 0;
  height: auto;
}

/* 右侧面板 */
.right-panel {
  flex: 0 0 480px;
  padding-left: 24px;
  max-height: calc(100vh - 400px);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.rule-detail {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

/* 固定区域：标题、描述、加固建议 */
.detail-fixed-section {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  gap: 32px;
  padding-bottom: 24px;
  border-bottom: 1px solid #f0f0f0;
  margin-bottom: 24px;
}

/* 可滚动区域：影响的主机 */
.detail-scrollable-section {
  flex: 1;
  overflow-y: auto;
  min-height: 0;
  scrollbar-width: thin;
  scrollbar-color: #d9d9d9 transparent;
}

.detail-scrollable-section::-webkit-scrollbar {
  width: 6px;
}

.detail-scrollable-section::-webkit-scrollbar-track {
  background: transparent;
}

.detail-scrollable-section::-webkit-scrollbar-thumb {
  background: #d9d9d9;
  border-radius: 3px;
}

.detail-scrollable-section::-webkit-scrollbar-thumb:hover {
  background: #bfbfbf;
}

.rule-detail-title {
  font-size: 18px;
  font-weight: 600;
  color: #262626;
  margin: 0 0 8px 0;
  line-height: 1.5;
  padding-bottom: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.detail-section {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.detail-section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}

.detail-section-label {
  font-size: 15px;
  font-weight: 600;
  color: #262626;
  margin-bottom: 4px;
}

.detail-section-actions {
  display: flex;
  gap: 8px;
}

.detail-text-empty {
  color: #bfbfbf;
  font-size: 14px;
  line-height: 1.8;
  margin: 0;
  font-style: italic;
}

.description-content {
  color: #595959;
  font-size: 14px;
  line-height: 1.8;
  margin-top: 4px;
}

.description-line {
  margin-bottom: 6px;
}

.description-line:last-child {
  margin-bottom: 0;
}

.suggestion-content {
  color: #595959;
  font-size: 14px;
  line-height: 1.8;
  margin-top: 4px;
}

.solution-item {
  margin-bottom: 20px;
}

.solution-item:last-child {
  margin-bottom: 0;
}

.solution-title {
  font-weight: 600;
  color: #262626;
  font-size: 14px;
  margin-bottom: 10px;
  padding-left: 8px;
  border-left: 3px solid #1890ff;
}

.host-search-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 16px;
}

.solution-steps {
  margin: 0;
  padding-left: 24px;
  color: #595959;
}

.solution-step {
  margin-bottom: 8px;
  line-height: 1.8;
}

.solution-step:last-child {
  margin-bottom: 0;
}

.solution-text {
  color: #595959;
  line-height: 1.8;
  white-space: pre-wrap;
  word-wrap: break-word;
}


.host-table :deep(.ant-table) {
  background: transparent;
}

.host-table :deep(.ant-table-container) {
  border: none;
}

.host-table :deep(.ant-table-thead > tr > th) {
  background: transparent;
  font-weight: 600;
  color: #262626;
  border-bottom: 1px solid #f0f0f0;
  padding: 12px 0;
}

.host-table :deep(.ant-table-tbody > tr > td) {
  border-bottom: 1px solid #f5f5f5;
  padding: 12px 0;
}

.host-table :deep(.ant-table-tbody > tr:last-child > td) {
  border-bottom: none;
}

.result-tag {
  font-weight: 500;
  border: none;
  padding: 2px 8px;
}

.empty-state {
  padding: 60px 0;
}

.empty-tab-content {
  padding: 60px 0;
  text-align: center;
}

/* 响应式 */
@media (max-width: 1400px) {
  .right-panel {
    flex: 0 0 400px;
  }
}

@media (max-width: 1200px) {
  .detail-content {
    flex-direction: column;
  }

  .left-panel {
    border-right: none;
    border-bottom: 1px solid #f0f0f0;
    padding-right: 0;
    padding-bottom: 24px;
  }

  .right-panel {
    flex: 1;
    padding-left: 0;
    padding-top: 24px;
    max-height: none;
  }
}
</style>

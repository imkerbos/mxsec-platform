import apiClient from './client'

// 报表统计数据接口
export interface ReportStats {
  // 主机统计
  hostStats: {
    total: number
    online: number
    offline: number
    byOsFamily: Record<string, number>
  }
  // 基线检查统计
  baselineStats: {
    totalChecks: number
    passed: number
    failed: number
    warning: number
    bySeverity: {
      critical: number
      high: number
      medium: number
      low: number
    }
    byCategory: Record<string, number>
  }
  // 策略统计
  policyStats: {
    total: number
    enabled: number
    disabled: number
    avgPassRate: number
  }
  // 任务统计
  taskStats: {
    total: number
    completed: number
    running: number
    failed: number
  }
}

// 时间序列数据
export interface TimeSeriesData {
  date: string
  value: number
}

// 基线得分趋势
export interface BaselineScoreTrend {
  dates: string[]
  scores: number[]
  passRates: number[]
}

// 检查结果趋势
export interface CheckResultTrend {
  dates: string[]
  passed: number[]
  failed: number[]
  warning: number[]
}

export const reportsApi = {
  // 获取报表统计数据
  getStats: async (params?: {
    start_time?: string
    end_time?: string
  }): Promise<ReportStats> => {
    return apiClient.get('/reports/stats', { params })
  },

  // 获取基线得分趋势
  getBaselineScoreTrend: async (params?: {
    host_id?: string
    policy_id?: string
    start_time?: string
    end_time?: string
    interval?: 'hour' | 'day' | 'week' | 'month'
  }): Promise<BaselineScoreTrend> => {
    return apiClient.get('/reports/baseline-score-trend', { params })
  },

  // 获取检查结果趋势
  getCheckResultTrend: async (params?: {
    host_id?: string
    policy_id?: string
    start_time?: string
    end_time?: string
    interval?: 'hour' | 'day' | 'week' | 'month'
  }): Promise<CheckResultTrend> => {
    return apiClient.get('/reports/check-result-trend', { params })
  },

  // 获取主机状态分布（用于图表）
  getHostStatusDistribution: async () => {
    return apiClient.get('/hosts/status-distribution')
  },

  // 获取主机风险分布（用于图表）
  getHostRiskDistribution: async () => {
    return apiClient.get('/hosts/risk-distribution')
  },
}

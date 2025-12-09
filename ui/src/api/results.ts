import apiClient from './client'
import type { ScanResult, PaginatedResponse } from './types'

export const resultsApi = {
  // 获取检测结果列表
  list: (params?: {
    page?: number
    page_size?: number
    host_id?: string
    rule_id?: string
    policy_id?: string
    task_id?: string
    status?: string
    severity?: string
  }) => {
    return apiClient.get<PaginatedResponse<ScanResult>>('/results', { params })
  },

  // 获取检测结果详情
  get: (resultId: string) => {
    return apiClient.get<ScanResult>(`/results/${resultId}`)
  },
}

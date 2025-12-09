import apiClient from './client'
import type { Host, HostDetail, PaginatedResponse, BaselineScore, BaselineSummary } from './types'

export interface HostStatusDistribution {
  running: number
  abnormal: number
  offline: number
  not_installed: number
  uninstalled: number
}

export interface HostRiskDistribution {
  host_container_alerts: number
  app_runtime_alerts: number
  high_exploitable_vulns: number
  virus_files: number
  high_risk_baselines: number
}

export const hostsApi = {
  // 获取主机列表
  list: (params?: {
    page?: number
    page_size?: number
    os_family?: string
    status?: string
  }) => {
    return apiClient.get<PaginatedResponse<Host>>('/hosts', { params })
  },

  // 获取主机详情
  get: (hostId: string) => {
    return apiClient.get<HostDetail>(`/hosts/${hostId}`)
  },

  // 获取主机基线得分
  getScore: (hostId: string) => {
    return apiClient.get<BaselineScore>(`/results/host/${hostId}/score`)
  },

  // 获取主机基线摘要
  getSummary: (hostId: string) => {
    return apiClient.get<BaselineSummary>(`/results/host/${hostId}/summary`)
  },

  // 获取主机状态分布
  getStatusDistribution: () => {
    return apiClient.get<HostStatusDistribution>('/hosts/status-distribution')
  },

  // 获取主机风险分布
  getRiskDistribution: () => {
    return apiClient.get<HostRiskDistribution>('/hosts/risk-distribution')
  },
}

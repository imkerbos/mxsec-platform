import apiClient from './client'

export interface BaselineRisk {
  name: string
  critical: number
  medium: number
  low: number
}

export interface ServiceStatus {
  database: 'healthy' | 'warning' | 'error'
  agentcenter: 'healthy' | 'warning' | 'error'
  manager: 'healthy' | 'warning' | 'error'
  baseline: 'healthy' | 'warning' | 'error'
}

export interface DashboardStats {
  hosts: number
  clusters: number
  containers: number
  onlineAgents: number
  offlineAgents: number
  onlineAgentsChange?: number
  offlineAgentsChange?: number
  pendingAlerts: number
  pendingVulnerabilities: number
  vulnDbUpdateTime: string
  hotPatchCount?: number
  baselineFailCount: number
  baselineHardeningPercent: number
  baselineRisks?: BaselineRisk[]
  avgCpuUsage?: number
  avgCpuUsageChange?: number
  avgMemoryUsage?: number
  avgMemoryUsageChange?: number
  hostAlertPercent?: number
  vulnHostPercent?: number
  baselineHostPercent?: number
  runtimeAlertPercent?: number
  virusHostPercent?: number
  serviceStatus?: ServiceStatus
}

export const dashboardApi = {
  getStats: async (): Promise<DashboardStats> => {
    return apiClient.get('/dashboard/stats')
  },
}

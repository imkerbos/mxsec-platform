// API 响应类型定义

export interface ApiResponse<T = any> {
  code: number
  message?: string
  data: T
}

export interface PaginatedResponse<T> {
  total: number
  items: T[]
}

// 主机相关类型
export interface Host {
  host_id: string
  hostname: string
  os_family: string
  os_version: string
  kernel_version: string
  arch: string
  ipv4: string[]
  status: 'online' | 'offline'
  last_heartbeat: string
  created_at: string
  updated_at: string
  baseline_score?: number
  baseline_pass_rate?: number
}

export interface HostDetail extends Host {
  baseline_results: ScanResult[]
  device_model?: string
  manufacturer?: string
  system_load?: string
  cpu_info?: string
  memory_size?: string
  default_gateway?: string
  network_mode?: string
  cpu_usage?: string
  memory_usage?: string
  dns_servers?: string[]
  device_serial?: string
}

// 策略相关类型
export interface Policy {
  id: string
  name: string
  version: string
  description: string
  os_family: string[]
  os_version: string
  enabled: boolean
  rule_count?: number
  rules?: Rule[]
  created_at: string
  updated_at: string
}

export interface Rule {
  rule_id: string
  policy_id: string
  category: string
  title: string
  description: string
  severity: 'critical' | 'high' | 'medium' | 'low'
  check_config: CheckConfig
  fix_config: FixConfig
  created_at: string
  updated_at: string
}

export interface CheckConfig {
  type: string
  [key: string]: any
}

export interface FixConfig {
  suggestion?: string
  [key: string]: any
}

// 任务相关类型
export interface ScanTask {
  task_id: string
  name: string
  type: 'manual' | 'scheduled'
  target_type: 'all' | 'host_ids' | 'os_family'
  target_config: {
    host_ids?: string[]
    os_family?: string[]
  }
  policy_id: string
  rule_ids: string[]
  status: 'pending' | 'running' | 'completed' | 'failed'
  created_at: string
  executed_at?: string
  updated_at: string
}

// 检测结果相关类型
export interface ScanResult {
  result_id: string
  host_id: string
  rule_id: string
  policy_id: string
  task_id?: string
  category: string
  title: string
  description: string
  severity: 'critical' | 'high' | 'medium' | 'low'
  status: 'pass' | 'fail' | 'error' | 'na'
  actual?: string
  expected?: string
  fix_suggestion?: string
  checked_at: string
}

export interface BaselineScore {
  host_id: string
  baseline_score: number
  pass_rate: number
  total_rules: number
  pass_count: number
  fail_count: number
  error_count: number
  na_count: number
  calculated_at: string
}

export interface BaselineSummary {
  host_id: string
  by_severity: {
    critical: { pass: number; fail: number; error: number; na: number }
    high: { pass: number; fail: number; error: number; na: number }
    medium: { pass: number; fail: number; error: number; na: number }
    low: { pass: number; fail: number; error: number; na: number }
  }
  by_category: Record<string, { pass: number; fail: number; error: number; na: number }>
}

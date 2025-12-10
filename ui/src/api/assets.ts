import apiClient from './client'
import type {
  PaginatedResponse,
  Process,
  Port,
  AssetUser,
  Software,
  Container,
  App,
  NetInterface,
  Volume,
  Kmod,
  Service,
  Cron,
} from './types'

export const assetsApi = {
  // 获取进程列表
  listProcesses: (params?: {
    host_id?: string
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<Process>>('/assets/processes', { params })
  },

  // 获取端口列表
  listPorts: (params?: {
    host_id?: string
    protocol?: string // tcp/udp
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<Port>>('/assets/ports', { params })
  },

  // 获取账户列表
  listUsers: (params?: {
    host_id?: string
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<AssetUser>>('/assets/users', { params })
  },

  // 获取软件包列表
  listSoftware: (params?: {
    host_id?: string
    package_type?: string
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<Software>>('/assets/software', { params })
  },

  // 获取容器列表
  listContainers: (params?: {
    host_id?: string
    runtime?: string
    status?: string
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<Container>>('/assets/containers', { params })
  },

  // 获取应用列表
  listApps: (params?: {
    host_id?: string
    app_type?: string
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<App>>('/assets/apps', { params })
  },

  // 获取网络接口列表
  listNetInterfaces: (params?: {
    host_id?: string
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<NetInterface>>('/assets/network-interfaces', { params })
  },

  // 获取磁盘列表
  listVolumes: (params?: {
    host_id?: string
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<Volume>>('/assets/volumes', { params })
  },

  // 获取内核模块列表
  listKmods: (params?: {
    host_id?: string
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<Kmod>>('/assets/kmods', { params })
  },

  // 获取系统服务列表
  listServices: (params?: {
    host_id?: string
    service_type?: string
    status?: string
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<Service>>('/assets/services', { params })
  },

  // 获取定时任务列表
  listCrons: (params?: {
    host_id?: string
    user?: string
    cron_type?: string
    page?: number
    page_size?: number
  }) => {
    return apiClient.get<PaginatedResponse<Cron>>('/assets/crons', { params })
  },

  // 获取资产统计信息（用于资产指纹展示）
  getStatistics: async (hostId: string) => {
    const [
      processes,
      ports,
      users,
      containers,
      software,
      services,
      crons,
    ] = await Promise.all([
      assetsApi.listProcesses({ host_id: hostId, page: 1, page_size: 1 }).catch(() => ({ total: 0, items: [] })),
      assetsApi.listPorts({ host_id: hostId, page: 1, page_size: 1 }).catch(() => ({ total: 0, items: [] })),
      assetsApi.listUsers({ host_id: hostId, page: 1, page_size: 1 }).catch(() => ({ total: 0, items: [] })),
      assetsApi.listContainers({ host_id: hostId, page: 1, page_size: 1 }).catch(() => ({ total: 0, items: [] })),
      assetsApi.listSoftware({ host_id: hostId, page: 1, page_size: 1 }).catch(() => ({ total: 0, items: [] })),
      assetsApi.listServices({ host_id: hostId, page: 1, page_size: 1 }).catch(() => ({ total: 0, items: [] })),
      assetsApi.listCrons({ host_id: hostId, page: 1, page_size: 1 }).catch(() => ({ total: 0, items: [] })),
    ])

    return {
      processes: processes.total,
      ports: ports.total,
      users: users.total,
      containers: containers.total,
      packages: software.total,
      services: services.total,
      cron: crons.total,
      integrity: 0, // TODO: 后续实现完整性校验统计
    }
  },
}

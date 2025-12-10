/**
 * API 客户端模块
 * 
 * 提供统一的 HTTP 请求客户端，包含：
 * - 请求拦截器：自动添加认证 Token
 * - 响应拦截器：统一处理错误和业务响应
 * - 全局错误提示：使用 Ant Design Vue message 显示错误信息
 */

import axios, { AxiosInstance } from 'axios'
import { message } from 'ant-design-vue'
import type { ApiResponse } from './types'

/**
 * 创建 axios 实例
 * 
 * 配置：
 * - baseURL: API 基础路径
 * - timeout: 请求超时时间（30秒）
 * - headers: 默认请求头
 */
const apiClient: AxiosInstance = axios.create({
  baseURL: '/api/v1',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
})

/**
 * 请求拦截器
 * 
 * 功能：
 * - 自动从 localStorage 获取认证 Token
 * - 将 Token 添加到请求头的 Authorization 字段
 */
apiClient.interceptors.request.use(
  (config) => {
    // 添加 token 认证信息
    const token = localStorage.getItem('mxcsec_token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

/**
 * 响应拦截器
 * 
 * 功能：
 * - 统一处理业务响应格式（code, message, data）
 * - 自动显示错误提示（使用 Ant Design Vue message）
 * - 处理认证失败（401）自动跳转登录
 * - 处理网络错误和 HTTP 错误
 */
apiClient.interceptors.response.use(
  (response) => {
    const res = response.data as ApiResponse
    if (res.code !== 0) {
      // 处理业务错误
      const errorMessage = res.message || '请求失败'
      console.error('API Error:', errorMessage)
      
      // 显示错误提示（某些错误可能不需要提示，由调用方处理）
      if (res.code !== 401) {
        message.error(errorMessage)
      }
      
      return Promise.reject(new Error(errorMessage))
    }
    return res.data
  },
  (error) => {
    // 处理 HTTP 错误
    if (error.response?.status === 401) {
      // 未授权，清除认证信息并跳转到登录页
      localStorage.removeItem('mxcsec_token')
      localStorage.removeItem('mxcsec_user')
      message.warning('登录已过期，请重新登录')
      window.location.href = '/login'
      return Promise.reject(error)
    }
    
    // 处理网络错误
    if (!error.response) {
      message.error('网络错误，请检查网络连接')
      console.error('Network Error:', error)
      return Promise.reject(error)
    }
    
    // 处理其他 HTTP 错误
    const status = error.response.status
    const errorMessage = error.response?.data?.message || `请求失败 (${status})`
    
    // 根据状态码显示不同的错误提示
    if (status >= 500) {
      message.error('服务器错误，请稍后重试')
    } else if (status === 404) {
      message.error('请求的资源不存在')
    } else if (status === 403) {
      message.error('没有权限执行此操作')
    } else {
      message.error(errorMessage)
    }
    
    console.error('HTTP Error:', error)
    return Promise.reject(error)
  }
)

export default apiClient

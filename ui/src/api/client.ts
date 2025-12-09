import axios, { AxiosInstance, AxiosRequestConfig } from 'axios'
import type { ApiResponse } from './types'

// 创建 axios 实例
const apiClient: AxiosInstance = axios.create({
  baseURL: '/api/v1',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// 请求拦截器
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

// 响应拦截器
apiClient.interceptors.response.use(
  (response) => {
    const res = response.data as ApiResponse
    if (res.code !== 0) {
      // 处理业务错误
      console.error('API Error:', res.message || '请求失败')
      return Promise.reject(new Error(res.message || '请求失败'))
    }
    return res.data
  },
  (error) => {
    // 处理 HTTP 错误
    if (error.response?.status === 401) {
      // 未授权，清除认证信息并跳转到登录页
      localStorage.removeItem('mxcsec_token')
      localStorage.removeItem('mxcsec_user')
      window.location.href = '/login'
    }
    console.error('HTTP Error:', error)
    return Promise.reject(error)
  }
)

export default apiClient

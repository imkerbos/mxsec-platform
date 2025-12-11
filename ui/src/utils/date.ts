/**
 * 日期时间格式化工具函数
 */

/**
 * 格式化日期时间，显示为完整格式
 * @param dateStr ISO 8601 格式的日期字符串
 * @returns 格式化后的日期字符串，格式：YYYY-MM-DD HH:mm
 */
export const formatDateTime = (dateStr: string | null | undefined): string => {
  if (!dateStr) return '-'
  
  try {
    const date = new Date(dateStr)
    if (isNaN(date.getTime())) return '-'
    
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    
    // 始终显示完整日期时间格式：YYYY-MM-DD HH:mm
    return `${year}-${month}-${day} ${hours}:${minutes}`
  } catch (error) {
    console.error('日期格式化失败:', error)
    return '-'
  }
}

/**
 * 格式化完整日期时间，始终显示年份
 * @param dateStr ISO 8601 格式的日期字符串
 * @returns 格式化后的日期字符串，格式：YYYY-MM-DD HH:mm
 */
export const formatFullDateTime = (dateStr: string | null | undefined): string => {
  if (!dateStr) return '-'
  
  try {
    const date = new Date(dateStr)
    if (isNaN(date.getTime())) return '-'
    
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    
    return `${year}-${month}-${day} ${hours}:${minutes}`
  } catch (error) {
    console.error('日期格式化失败:', error)
    return '-'
  }
}

/**
 * 格式化日期，只显示日期部分
 * @param dateStr ISO 8601 格式的日期字符串
 * @returns 格式化后的日期字符串，格式：YYYY-MM-DD
 */
export const formatDate = (dateStr: string | null | undefined): string => {
  if (!dateStr) return '-'
  
  try {
    const date = new Date(dateStr)
    if (isNaN(date.getTime())) return '-'
    
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    
    return `${year}-${month}-${day}`
  } catch (error) {
    console.error('日期格式化失败:', error)
    return '-'
  }
}

/**
 * 格式化相对时间（如：2小时前、3天前）
 * @param dateStr ISO 8601 格式的日期字符串
 * @returns 相对时间字符串
 */
export const formatRelativeTime = (dateStr: string | null | undefined): string => {
  if (!dateStr) return '-'
  
  try {
    const date = new Date(dateStr)
    if (isNaN(date.getTime())) return '-'
    
    const now = new Date()
    const diffMs = now.getTime() - date.getTime()
    const diffSeconds = Math.floor(diffMs / 1000)
    const diffMinutes = Math.floor(diffSeconds / 60)
    const diffHours = Math.floor(diffMinutes / 60)
    const diffDays = Math.floor(diffHours / 24)
    
    if (diffSeconds < 60) {
      return '刚刚'
    } else if (diffMinutes < 60) {
      return `${diffMinutes}分钟前`
    } else if (diffHours < 24) {
      return `${diffHours}小时前`
    } else if (diffDays < 7) {
      return `${diffDays}天前`
    } else {
      // 超过7天，显示具体日期
      return formatDateTime(dateStr)
    }
  } catch (error) {
    console.error('相对时间格式化失败:', error)
    return '-'
  }
}

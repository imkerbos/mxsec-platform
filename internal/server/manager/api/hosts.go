// Package api 提供 HTTP API 处理器
package api

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"github.com/mxcsec-platform/mxcsec-platform/internal/server/manager/biz"
	"github.com/mxcsec-platform/mxcsec-platform/internal/server/model"
)

// HostsHandler 是主机管理 API 处理器
type HostsHandler struct {
	db             *gorm.DB
	logger         *zap.Logger
	scoreCache     *biz.BaselineScoreCache
	metricsService *biz.MetricsService
}

// NewHostsHandler 创建主机处理器
func NewHostsHandler(db *gorm.DB, logger *zap.Logger, scoreCache *biz.BaselineScoreCache, metricsService *biz.MetricsService) *HostsHandler {
	return &HostsHandler{
		db:             db,
		logger:         logger,
		scoreCache:     scoreCache,
		metricsService: metricsService,
	}
}

// HostListItem 主机列表项（包含基线得分）
type HostListItem struct {
	model.Host
	BaselineScore    int     `json:"baseline_score"`
	BaselinePassRate float64 `json:"baseline_pass_rate"`
}

// ListHosts 获取主机列表
// GET /api/v1/hosts
func (h *HostsHandler) ListHosts(c *gin.Context) {
	// 解析查询参数
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	osFamily := c.Query("os_family")
	status := c.Query("status")

	// 构建查询
	query := h.db.Model(&model.Host{})

	// 过滤条件
	if osFamily != "" {
		query = query.Where("os_family = ?", osFamily)
	}
	if status != "" {
		query = query.Where("status = ?", status)
	}

	// 计算总数
	var total int64
	if err := query.Count(&total).Error; err != nil {
		h.logger.Error("查询主机总数失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{
			"code":    500,
			"message": "查询主机列表失败",
		})
		return
	}

	// 分页查询
	var hosts []model.Host
	offset := (page - 1) * pageSize
	if err := query.Offset(offset).Limit(pageSize).Order("last_heartbeat DESC").Find(&hosts).Error; err != nil {
		h.logger.Error("查询主机列表失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{
			"code":    500,
			"message": "查询主机列表失败",
		})
		return
	}

	// 计算每个主机的基线得分
	items := make([]HostListItem, 0, len(hosts))
	for _, host := range hosts {
		item := HostListItem{
			Host:             host,
			BaselineScore:    0,
			BaselinePassRate: 0.0,
		}

		// 如果有得分缓存，使用缓存计算得分
		if h.scoreCache != nil {
			score, err := h.scoreCache.GetHostScore(host.HostID)
			if err != nil {
				h.logger.Warn("计算主机基线得分失败", zap.String("host_id", host.HostID), zap.Error(err))
				// 继续处理，使用默认值 0
			} else if score != nil {
				item.BaselineScore = score.BaselineScore
				item.BaselinePassRate = score.PassRate
			}
		}

		items = append(items, item)
	}

	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"data": gin.H{
			"total": total,
			"items": items,
		},
	})
}

// HostStatusDistribution 主机状态分布统计
type HostStatusDistribution struct {
	Running      int64 `json:"running"`       // 运行中
	Abnormal     int64 `json:"abnormal"`      // 运行异常
	Offline      int64 `json:"offline"`       // 离线
	NotInstalled int64 `json:"not_installed"` // 未安装
	Uninstalled  int64 `json:"uninstalled"`   // 已卸载
}

// HostRiskDistribution 主机风险分布统计
type HostRiskDistribution struct {
	HostContainerAlerts  int64 `json:"host_container_alerts"`  // 存在主机和容器安全告警
	AppRuntimeAlerts     int64 `json:"app_runtime_alerts"`     // 存在应用运行时安全告警
	HighExploitableVulns int64 `json:"high_exploitable_vulns"` // 存在高可利用漏洞
	VirusFiles           int64 `json:"virus_files"`            // 存在病毒文件
	HighRiskBaselines    int64 `json:"high_risk_baselines"`    // 存在高危基线
}

// GetHostStatusDistribution 获取主机状态分布
// GET /api/v1/hosts/status-distribution
func (h *HostsHandler) GetHostStatusDistribution(c *gin.Context) {
	var distribution HostStatusDistribution

	// 运行中（在线）
	h.db.Model(&model.Host{}).Where("status = ?", "online").Count(&distribution.Running)

	// 离线
	h.db.Model(&model.Host{}).Where("status = ?", "offline").Count(&distribution.Offline)

	// 运行异常（暂时用离线超过一定时间的主机表示，后续可扩展）
	// TODO: 实现运行异常的逻辑

	// 未安装和已卸载（暂时返回0，后续扩展）
	// TODO: 实现未安装和已卸载的逻辑

	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"data": distribution,
	})
}

// GetHostRiskDistribution 获取主机风险分布
// GET /api/v1/hosts/risk-distribution
func (h *HostsHandler) GetHostRiskDistribution(c *gin.Context) {
	var distribution HostRiskDistribution

	// 存在高危基线的主机数
	var hostsWithHighRiskBaseline []string
	h.db.Model(&model.ScanResult{}).
		Select("DISTINCT host_id").
		Where("status = ? AND severity IN (?)", "fail", []string{"high", "critical"}).
		Pluck("host_id", &hostsWithHighRiskBaseline)
	distribution.HighRiskBaselines = int64(len(hostsWithHighRiskBaseline))

	// 其他风险类型暂时返回0，后续扩展
	// TODO: 实现主机和容器安全告警统计
	// TODO: 实现应用运行时安全告警统计
	// TODO: 实现高可利用漏洞统计
	// TODO: 实现病毒文件统计

	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"data": distribution,
	})
}

// GetHost 获取主机详情
// GET /api/v1/hosts/:host_id
func (h *HostsHandler) GetHost(c *gin.Context) {
	hostID := c.Param("host_id")

	var host model.Host
	if err := h.db.Where("host_id = ?", hostID).First(&host).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{
				"code":    404,
				"message": "主机不存在",
			})
			return
		}
		h.logger.Error("查询主机失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{
			"code":    500,
			"message": "查询主机失败",
		})
		return
	}

	// 查询基线结果
	var results []model.ScanResult
	h.db.Where("host_id = ?", hostID).
		Order("checked_at DESC").
		Limit(100).
		Find(&results)

	// 查询最新监控数据
	var latestMetric model.HostMetric
	h.db.Where("host_id = ?", hostID).
		Order("collected_at DESC").
		Limit(1).
		First(&latestMetric)

	// 构建响应数据（扁平化结构，符合前端 HostDetail 接口）
	responseData := gin.H{
		"host_id":          host.HostID,
		"hostname":         host.Hostname,
		"os_family":        host.OSFamily,
		"os_version":       host.OSVersion,
		"kernel_version":   host.KernelVersion,
		"arch":             host.Arch,
		"ipv4":             host.IPv4,
		"ipv6":             host.IPv6,
		"status":           string(host.Status),
		"last_heartbeat":   host.LastHeartbeat,
		"created_at":       host.CreatedAt,
		"updated_at":       host.UpdatedAt,
		"baseline_results": results,
	}

	// 添加监控数据
	if latestMetric.ID > 0 {
		if latestMetric.CPUUsage != nil {
			responseData["cpu_usage"] = formatPercent(*latestMetric.CPUUsage)
		}
		if latestMetric.MemUsage != nil {
			responseData["memory_usage"] = formatPercent(*latestMetric.MemUsage)
		}
	}

	// TODO: 从系统信息中获取以下字段（需要 Agent 上报）
	// - device_model: 设备型号
	// - manufacturer: 生产商
	// - cpu_info: CPU信息
	// - memory_size: 内存大小
	// - default_gateway: 默认网关
	// - network_mode: 网络模式
	// - dns_servers: DNS服务器列表
	// - device_serial: 设备序列号
	// - system_load: 系统负载

	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"data": responseData,
	})
}

// formatPercent 格式化百分比
func formatPercent(value float64) string {
	return strconv.FormatFloat(value, 'f', 2, 64) + "%"
}

// formatBytes 格式化字节数
func formatBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return strconv.FormatInt(bytes, 10) + " B"
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return strconv.FormatFloat(float64(bytes)/float64(div), 'f', 2, 64) + " " + []string{"KB", "MB", "GB", "TB"}[exp]
}

// GetHostMetrics 获取主机监控数据
// GET /api/v1/hosts/:host_id/metrics
func (h *HostsHandler) GetHostMetrics(c *gin.Context) {
	hostID := c.Param("host_id")

	// 解析查询参数（可选的时间范围）
	var startTime, endTime *time.Time
	if startStr := c.Query("start_time"); startStr != "" {
		if t, err := time.Parse(time.RFC3339, startStr); err == nil {
			startTime = &t
		}
	}
	if endStr := c.Query("end_time"); endStr != "" {
		if t, err := time.Parse(time.RFC3339, endStr); err == nil {
			endTime = &t
		}
	}

	// 如果没有指定时间范围，默认查询最近 1 小时
	if startTime == nil && endTime == nil {
		now := time.Now()
		oneHourAgo := now.Add(-1 * time.Hour)
		startTime = &oneHourAgo
		endTime = &now
	}

	// 查询监控数据
	metrics, err := h.metricsService.GetHostMetrics(c.Request.Context(), hostID, startTime, endTime)
	if err != nil {
		h.logger.Error("查询主机监控数据失败", zap.String("host_id", hostID), zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{
			"code":    500,
			"message": "查询主机监控数据失败",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code": 0,
		"data": metrics,
	})
}

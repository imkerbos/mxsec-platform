// Package model 提供数据库模型定义
package model

import (
	"database/sql/driver"
	"encoding/json"
	"time"
)

// HostStatus 主机状态
type HostStatus string

const (
	HostStatusOnline  HostStatus = "online"
	HostStatusOffline HostStatus = "offline"
)

// StringArray 字符串数组类型，用于 JSON 字段
type StringArray []string

// Value 实现 driver.Valuer 接口
func (a StringArray) Value() (driver.Value, error) {
	return json.Marshal(a)
}

// Scan 实现 sql.Scanner 接口
func (a *StringArray) Scan(value interface{}) error {
	if value == nil {
		*a = StringArray{}
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		return nil
	}
	return json.Unmarshal(bytes, a)
}

// Host 主机信息模型
type Host struct {
	HostID        string      `gorm:"primaryKey;column:host_id;type:varchar(64);not null" json:"host_id"`
	Hostname      string      `gorm:"column:hostname;type:varchar(255)" json:"hostname"`
	OSFamily      string      `gorm:"column:os_family;type:varchar(50)" json:"os_family"`
	OSVersion     string      `gorm:"column:os_version;type:varchar(50)" json:"os_version"`
	KernelVersion string      `gorm:"column:kernel_version;type:varchar(100)" json:"kernel_version"`
	Arch          string      `gorm:"column:arch;type:varchar(20)" json:"arch"`
	IPv4          StringArray `gorm:"column:ipv4;type:json" json:"ipv4"`
	IPv6          StringArray `gorm:"column:ipv6;type:json" json:"ipv6"`
	Status        HostStatus  `gorm:"column:status;type:varchar(20);default:'offline'" json:"status"`
	LastHeartbeat *time.Time  `gorm:"column:last_heartbeat;type:timestamp" json:"last_heartbeat"`
	// 硬件信息
	DeviceModel  string `gorm:"column:device_model;type:varchar(255)" json:"device_model"`
	Manufacturer string `gorm:"column:manufacturer;type:varchar(255)" json:"manufacturer"`
	DeviceSerial string `gorm:"column:device_serial;type:varchar(255)" json:"device_serial"`
	CPUInfo      string `gorm:"column:cpu_info;type:varchar(500)" json:"cpu_info"`
	MemorySize   string `gorm:"column:memory_size;type:varchar(50)" json:"memory_size"`
	SystemLoad   string `gorm:"column:system_load;type:varchar(100)" json:"system_load"`
	// 网络信息
	DefaultGateway string      `gorm:"column:default_gateway;type:varchar(50)" json:"default_gateway"`
	DNSServers     StringArray `gorm:"column:dns_servers;type:json" json:"dns_servers"`
	NetworkMode    string      `gorm:"column:network_mode;type:varchar(50)" json:"network_mode"`
	// 标签
	Tags      StringArray `gorm:"column:tags;type:json" json:"tags"`
	CreatedAt time.Time   `gorm:"column:created_at;type:timestamp;default:CURRENT_TIMESTAMP" json:"created_at"`
	UpdatedAt time.Time   `gorm:"column:updated_at;type:timestamp;default:CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP" json:"updated_at"`
}

// TableName 指定表名
func (Host) TableName() string {
	return "hosts"
}

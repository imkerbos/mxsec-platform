// Package migration 提供数据库迁移功能
package migration

import (
	"fmt"

	"go.uber.org/zap"
	"gorm.io/gorm"

	"github.com/mxcsec-platform/mxcsec-platform/internal/server/model"
)

// Migrate 执行数据库迁移
func Migrate(db *gorm.DB, logger *zap.Logger) error {
	if logger == nil {
		logger = zap.NewNop()
	}

	logger.Info("开始数据库迁移")

	// 执行自动迁移
	for _, m := range model.AllModels {
		if err := db.AutoMigrate(m); err != nil {
			logger.Error("数据库迁移失败", zap.Error(err), zap.String("model", fmt.Sprintf("%T", m)))
			return fmt.Errorf("迁移模型 %T 失败: %w", m, err)
		}
		logger.Info("模型迁移成功", zap.String("model", fmt.Sprintf("%T", m)))
	}

	logger.Info("数据库迁移完成")
	return nil
}

// Rollback 回滚数据库（谨慎使用）
func Rollback(db *gorm.DB, logger *zap.Logger) error {
	if logger == nil {
		logger = zap.NewNop()
	}

	logger.Warn("开始数据库回滚（删除所有表）")

	// 删除所有表（按依赖顺序）
	tables := []string{
		"scan_results",
		"scan_tasks",
		"rules",
		"policies",
		"processes",
		"ports",
		"asset_users",
		"hosts",
		"users",
	}

	for _, table := range tables {
		if err := db.Exec(fmt.Sprintf("DROP TABLE IF EXISTS %s", table)).Error; err != nil {
			logger.Error("删除表失败", zap.Error(err), zap.String("table", table))
			return fmt.Errorf("删除表 %s 失败: %w", table, err)
		}
		logger.Info("删除表成功", zap.String("table", table))
	}

	logger.Info("数据库回滚完成")
	return nil
}

// Package migration 提供数据库初始化数据功能
package migration

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/mxcsec-platform/mxcsec-platform/internal/server/model"
	"github.com/mxcsec-platform/mxcsec-platform/plugins/baseline/engine"
)

// InitDefaultData 初始化默认数据（策略和规则）
func InitDefaultData(db *gorm.DB, logger *zap.Logger, policyDir string) error {
	if logger == nil {
		logger = zap.NewNop()
	}

	logger.Info("开始初始化默认数据", zap.String("policy_dir", policyDir))

	// 检查是否已有策略数据
	var count int64
	if err := db.Model(&model.Policy{}).Count(&count).Error; err != nil {
		return fmt.Errorf("检查现有数据失败: %w", err)
	}

	if count > 0 {
		logger.Info("数据库中已存在策略数据，跳过策略初始化", zap.Int64("count", count))
	} else {

		// 从示例策略文件加载
		if policyDir == "" {
			// 默认使用项目中的示例策略目录
			policyDir = "plugins/baseline/config/examples"
		}

		policies, err := loadPoliciesFromDir(policyDir, logger)
		if err != nil {
			return fmt.Errorf("加载策略文件失败: %w", err)
		}

		// 保存到数据库
		for _, policy := range policies {
			if err := savePolicyToDB(db, policy, logger); err != nil {
				return fmt.Errorf("保存策略 %s 失败: %w", policy.ID, err)
			}
			logger.Info("策略初始化成功", zap.String("policy_id", policy.ID), zap.String("name", policy.Name))
		}

		logger.Info("默认数据初始化完成", zap.Int("policy_count", len(policies)))
	}

	// 初始化默认用户（始终执行，确保admin用户存在）
	if err := initDefaultUsers(db, logger); err != nil {
		return fmt.Errorf("初始化默认用户失败: %w", err)
	}

	return nil
}

// initDefaultUsers 初始化默认用户
func initDefaultUsers(db *gorm.DB, logger *zap.Logger) error {
	// 检查admin用户是否存在
	var adminUser model.User
	err := db.Where("username = ?", "admin").First(&adminUser).Error

	if err == nil {
		// admin用户已存在，检查状态并确保为active
		if adminUser.Status != model.UserStatusActive {
			adminUser.Status = model.UserStatusActive
			if err := db.Save(&adminUser).Error; err != nil {
				return fmt.Errorf("更新admin用户状态失败: %w", err)
			}
			logger.Info("admin用户状态已更新为active", zap.String("username", adminUser.Username))
		} else {
			logger.Info("admin用户已存在且状态正常", zap.String("username", adminUser.Username))
		}
		return nil
	}

	if err != gorm.ErrRecordNotFound {
		return fmt.Errorf("检查admin用户失败: %w", err)
	}

	// admin用户不存在，创建默认管理员用户（admin/admin123）
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("加密密码失败: %w", err)
	}

	defaultUser := &model.User{
		Username: "admin",
		Password: string(hashedPassword),
		Email:    "admin@example.com",
		Role:     model.UserRoleAdmin,
		Status:   model.UserStatusActive,
	}

	if err := db.Create(defaultUser).Error; err != nil {
		return fmt.Errorf("创建默认用户失败: %w", err)
	}

	logger.Info("默认用户初始化成功", zap.String("username", defaultUser.Username))
	return nil
}

// loadPoliciesFromDir 从目录加载所有策略文件
func loadPoliciesFromDir(dir string, logger *zap.Logger) ([]*engine.Policy, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("读取目录失败: %w", err)
	}

	var policies []*engine.Policy

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		// 只处理 JSON 文件
		if filepath.Ext(entry.Name()) != ".json" {
			continue
		}

		filePath := filepath.Join(dir, entry.Name())
		logger.Info("加载策略文件", zap.String("file", filePath))

		data, err := os.ReadFile(filePath)
		if err != nil {
			logger.Warn("读取策略文件失败", zap.Error(err), zap.String("file", filePath))
			continue
		}

		var policy engine.Policy
		if err := json.Unmarshal(data, &policy); err != nil {
			logger.Warn("解析策略文件失败", zap.Error(err), zap.String("file", filePath))
			continue
		}

		policies = append(policies, &policy)
	}

	return policies, nil
}

// savePolicyToDB 保存策略到数据库
func savePolicyToDB(db *gorm.DB, policy *engine.Policy, logger *zap.Logger) error {
	// 转换 Policy 模型
	dbPolicy := &model.Policy{
		ID:          policy.ID,
		Name:        policy.Name,
		Version:     policy.Version,
		Description: policy.Description,
		OSFamily:    model.StringArray(policy.OSFamily),
		OSVersion:   policy.OSVersion,
		Enabled:     policy.Enabled,
	}

	// 创建策略
	if err := db.Create(dbPolicy).Error; err != nil {
		return fmt.Errorf("创建策略失败: %w", err)
	}

	// 转换并创建规则
	for _, rule := range policy.Rules {
		// 转换 Check 配置
		checkConfig := model.CheckConfig{
			Condition: rule.Check.Condition,
			Rules:     make([]model.CheckRule, len(rule.Check.Rules)),
		}
		for i, cr := range rule.Check.Rules {
			checkRule := model.CheckRule{
				Type:  cr.Type,
				Param: cr.Param,
			}
			// Result 字段可能为空，需要检查
			if cr.Result != "" {
				checkRule.Result = cr.Result
			}
			checkConfig.Rules[i] = checkRule
		}

		// 转换 Fix 配置
		fixConfig := model.FixConfig{
			Suggestion: rule.Fix.Suggestion,
			Command:    rule.Fix.Command,
		}

		dbRule := &model.Rule{
			RuleID:      rule.RuleID,
			PolicyID:    policy.ID,
			Category:    rule.Category,
			Title:       rule.Title,
			Description: rule.Description,
			Severity:    rule.Severity,
			CheckConfig: checkConfig,
			FixConfig:   fixConfig,
		}

		if err := db.Create(dbRule).Error; err != nil {
			return fmt.Errorf("创建规则 %s 失败: %w", rule.RuleID, err)
		}
	}

	return nil
}

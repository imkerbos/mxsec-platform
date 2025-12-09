#!/bin/bash

# Baseline Plugin 示例规则验证脚本
# 用于验证示例规则文件格式和执行

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLES_DIR="${PROJECT_ROOT}/plugins/baseline/config/examples"

echo "=========================================="
echo "Baseline Plugin 示例规则验证"
echo "=========================================="
echo ""

# 1. 验证 JSON 格式
echo "1. 验证 JSON 格式..."
echo "----------------------------------------"

json_files=(
    "ssh-baseline.json"
    "password-policy.json"
    "file-permissions.json"
    "sysctl-security.json"
    "service-status.json"
)

json_errors=0
for file in "${json_files[@]}"; do
    file_path="${EXAMPLES_DIR}/${file}"
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}✗${NC} ${file}: 文件不存在"
        json_errors=$((json_errors + 1))
        continue
    fi
    
    if python3 -m json.tool "$file_path" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} ${file}: JSON 格式正确"
    else
        echo -e "${RED}✗${NC} ${file}: JSON 格式错误"
        json_errors=$((json_errors + 1))
    fi
done

if [ $json_errors -gt 0 ]; then
    echo -e "\n${RED}错误: 发现 ${json_errors} 个 JSON 格式错误${NC}"
    exit 1
fi

echo ""
echo "2. 验证规则文件结构..."
echo "----------------------------------------"

# 使用 Python 验证规则文件结构
python3 << PYTHON_SCRIPT
import json
import sys
import os

examples_dir = "${EXAMPLES_DIR}"
required_fields = {
    "policy": ["id", "name", "version", "description", "os_family", "os_version", "enabled", "rules"],
    "rule": ["rule_id", "category", "title", "description", "severity", "check", "fix"],
    "check": ["condition", "rules"],
    "check_rule": ["type", "param"]
}

errors = 0

def validate_policy(policy_data, filename):
    global errors
    # 验证策略字段
    for field in required_fields["policy"]:
        if field not in policy_data:
            print(f"✗ {filename}: 缺少策略字段 '{field}'")
            errors += 1
            return False
    
    # 验证规则列表
    if not isinstance(policy_data["rules"], list) or len(policy_data["rules"]) == 0:
        print(f"✗ {filename}: 规则列表为空或不是数组")
        errors += 1
        return False
    
    # 验证每条规则
    for i, rule in enumerate(policy_data["rules"]):
        for field in required_fields["rule"]:
            if field not in rule:
                print(f"✗ {filename}: 规则 #{i+1} 缺少字段 '{field}'")
                errors += 1
                return False
        
        # 验证检查项
        if "check" in rule:
            check = rule["check"]
            if "condition" not in check or "rules" not in check:
                print(f"✗ {filename}: 规则 #{i+1} 检查项格式错误")
                errors += 1
                return False
            
            if not isinstance(check["rules"], list) or len(check["rules"]) == 0:
                print(f"✗ {filename}: 规则 #{i+1} 检查规则列表为空")
                errors += 1
                return False
            
            # 验证检查规则
            for j, check_rule in enumerate(check["rules"]):
                if "type" not in check_rule or "param" not in check_rule:
                    print(f"✗ {filename}: 规则 #{i+1} 检查项 #{j+1} 格式错误")
                    errors += 1
                    return False
    
    return True

# 读取所有 JSON 文件
json_files = [
    "ssh-baseline.json",
    "password-policy.json",
    "file-permissions.json",
    "sysctl-security.json",
    "service-status.json"
]

for filename in json_files:
    filepath = os.path.join(examples_dir, filename)
    if not os.path.exists(filepath):
        print(f"✗ {filename}: 文件不存在")
        errors += 1
        continue
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            policy_data = json.load(f)
        
        if validate_policy(policy_data, filename):
            rule_count = len(policy_data.get("rules", []))
            print(f"✓ {filename}: 结构正确 ({rule_count} 条规则)")
    except json.JSONDecodeError as e:
        print(f"✗ {filename}: JSON 解析错误: {e}")
        errors += 1
    except Exception as e:
        print(f"✗ {filename}: 验证错误: {e}")
        errors += 1

if errors > 0:
    sys.exit(1)
PYTHON_SCRIPT

if [ $? -ne 0 ]; then
    echo -e "\n${RED}错误: 规则文件结构验证失败${NC}"
    exit 1
fi

echo ""
echo "3. 运行 Go 测试验证规则执行..."
echo "----------------------------------------"

cd "$PROJECT_ROOT"

# 运行端到端测试
if go test -v ./plugins/baseline/engine -run TestEngine_E2E_LoadAllExamplePolicies 2>&1 | tee /tmp/baseline_test.log; then
    echo -e "\n${GREEN}✓${NC} 规则执行测试通过"
else
    echo -e "\n${RED}✗${NC} 规则执行测试失败"
    echo "查看详细日志: /tmp/baseline_test.log"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}所有验证通过！${NC}"
echo "=========================================="
echo ""
echo "示例规则文件位置: ${EXAMPLES_DIR}"
echo "规则文件列表:"
for file in "${json_files[@]}"; do
    if [ -f "${EXAMPLES_DIR}/${file}" ]; then
        rule_count=$(python3 -c "import json; data=json.load(open('${EXAMPLES_DIR}/${file}')); print(len(data.get('rules', [])))")
        echo "  - ${file} (${rule_count} 条规则)"
    fi
done
echo ""

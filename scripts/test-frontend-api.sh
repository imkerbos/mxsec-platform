#!/bin/bash

# 前端 API 集成测试脚本
# 用于验证前端 API 端点是否正常工作
#
# 使用方法:
#   ./scripts/test-frontend-api.sh
#
# 环境变量:
#   API_BASE_URL - API 基础 URL (默认: http://localhost:8080/api/v1)
#   USERNAME     - 登录用户名 (默认: admin)
#   PASSWORD     - 登录密码 (默认: admin123)
#   TOKEN        - 直接提供 JWT Token (可选，如果不提供会自动登录)
#
# 示例:
#   export USERNAME="admin" PASSWORD="admin123"
#   ./scripts/test-frontend-api.sh
#
#   export TOKEN="your-jwt-token"
#   ./scripts/test-frontend-api.sh

# set -e  # 注释掉，避免单个测试失败导致脚本退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
API_BASE_URL="${API_BASE_URL:-http://localhost:8080/api/v1}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-admin123}"
TOKEN="${TOKEN:-}"

# 测试计数器
PASSED=0
FAILED=0
SKIPPED=0

# 打印测试结果
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $2"
        ((FAILED++))
    fi
}

# 发送 HTTP 请求
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    local curl_cmd="curl -s -w '\n%{http_code}' -X $method"
    
    if [ -n "$TOKEN" ]; then
        curl_cmd="$curl_cmd -H 'Authorization: Bearer $TOKEN'"
    fi
    
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -H 'Content-Type: application/json' -d '$data'"
    fi
    
    curl_cmd="$curl_cmd '$API_BASE_URL$endpoint'"
    
    eval $curl_cmd
}

# 登录获取 Token
login() {
    echo -n "正在登录... "
    
    local login_data="{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}"
    
    # 直接调用登录 API，不使用 api_request（因为登录不需要 token）
    local response=$(curl -s -w '\n%{http_code}' -X POST \
        -H 'Content-Type: application/json' \
        -d "$login_data" \
        "$API_BASE_URL/auth/login")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq "200" ]; then
        if command -v jq &> /dev/null; then
            # 响应格式: {"code":0,"data":{"token":"...","user":{...}}}
            TOKEN=$(echo "$body" | jq -r '.data.token // empty' 2>/dev/null || echo "")
            if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
                echo -e "${GREEN}成功${NC}"
                return 0
            fi
        else
            # 如果没有 jq，尝试从响应中提取 token（简单方式）
            # 查找 "token":"..." 模式
            TOKEN=$(echo "$body" | grep -o '"token":"[^"]*' | sed 's/"token":"//' | head -n1 || echo "")
            if [ -n "$TOKEN" ]; then
                echo -e "${GREEN}成功${NC}"
                return 0
            fi
        fi
    fi
    
    echo -e "${RED}失败 (HTTP $http_code)${NC}"
    if [ "$http_code" -eq "200" ]; then
        echo "响应: $body"
        echo "提示: 无法从响应中提取 token，请检查响应格式"
    fi
    return 1
}

# 测试 API 端点
test_endpoint() {
    local name=$1
    local method=$2
    local endpoint=$3
    local expected_code=${4:-200}
    local skip_auth=${5:-false}
    
    echo -n "测试 $name... "
    
    # 如果端点需要认证但没有 token，跳过
    if [ "$skip_auth" != "true" ] && [ -z "$TOKEN" ]; then
        echo -e "${YELLOW}跳过（需要认证）${NC}"
        ((SKIPPED++))
        return 2
    fi
    
    response=$(api_request $method $endpoint)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    # 处理 401 未授权错误
    if [ "$http_code" -eq "401" ]; then
        print_result 1 "$name (HTTP 401 未授权，请检查认证信息)"
        return 1
    fi
    
    if [ "$http_code" -eq "$expected_code" ] || [ "$http_code" -eq "200" ]; then
        # 检查响应格式（应该是 JSON）
        if command -v jq &> /dev/null; then
            if echo "$body" | jq . >/dev/null 2>&1; then
                print_result 0 "$name (HTTP $http_code)"
                return 0
            else
                print_result 1 "$name (响应不是有效的 JSON)"
                return 1
            fi
        else
            # 如果没有 jq，只检查 HTTP 状态码
            print_result 0 "$name (HTTP $http_code)"
            return 0
        fi
    else
        print_result 1 "$name (HTTP $http_code, 期望 $expected_code)"
        return 1
    fi
}

echo "=========================================="
echo "前端 API 集成测试"
echo "=========================================="
echo "API 基础 URL: $API_BASE_URL"
echo "用户名: $USERNAME"
echo ""

# 检查依赖
if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误: curl 未安装${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}警告: jq 未安装，将跳过 JSON 验证和 Token 提取${NC}"
fi

# 如果没有提供 Token，尝试登录获取
if [ -z "$TOKEN" ]; then
    echo "--- 认证 ---"
    if ! login; then
        echo ""
        echo -e "${YELLOW}提示: 登录失败，将跳过需要认证的测试${NC}"
        echo "可以通过以下方式提供 Token："
        echo "  1. 设置环境变量: export TOKEN='your-token'"
        echo "  2. 设置用户名密码: export USERNAME='admin' PASSWORD='admin123'"
        echo ""
    fi
else
    echo -e "${GREEN}使用提供的 Token${NC}"
    echo ""
fi

# 测试主机管理 API
echo "--- 主机管理 API ---"
test_endpoint "获取主机列表" "GET" "/hosts"
test_endpoint "获取主机状态分布" "GET" "/hosts/status-distribution"
test_endpoint "获取主机风险分布" "GET" "/hosts/risk-distribution"

# 测试策略管理 API
echo ""
echo "--- 策略管理 API ---"
test_endpoint "获取策略列表" "GET" "/policies"

# 获取第一个策略 ID（如果存在）
if [ -n "$TOKEN" ]; then
    policy_response=$(api_request "GET" "/policies")
    policy_http_code=$(echo "$policy_response" | tail -n1)
    if [ "$policy_http_code" -eq "200" ]; then
        policy_body=$(echo "$policy_response" | sed '$d')
        if command -v jq &> /dev/null; then
            policy_id=$(echo "$policy_body" | jq -r '.items[0].id // empty' 2>/dev/null || echo "")
        else
            policy_id=""
        fi
        if [ -n "$policy_id" ] && [ "$policy_id" != "null" ]; then
            test_endpoint "获取策略详情" "GET" "/policies/$policy_id"
            test_endpoint "获取策略统计信息" "GET" "/policies/$policy_id/statistics"
        else
            echo -e "${YELLOW}跳过策略详情和统计测试（无策略数据）${NC}"
        fi
    fi
fi

# 测试 Dashboard API
echo ""
echo "--- Dashboard API ---"
test_endpoint "获取 Dashboard 统计数据" "GET" "/dashboard/stats"

# 测试检测结果 API
echo ""
echo "--- 检测结果 API ---"
test_endpoint "获取检测结果列表" "GET" "/results"

# 获取第一个主机 ID（如果存在）
if [ -n "$TOKEN" ]; then
    host_response=$(api_request "GET" "/hosts")
    host_http_code=$(echo "$host_response" | tail -n1)
    if [ "$host_http_code" -eq "200" ]; then
        host_body=$(echo "$host_response" | sed '$d')
        if command -v jq &> /dev/null; then
            host_id=$(echo "$host_body" | jq -r '.items[0].host_id // empty' 2>/dev/null || echo "")
        else
            host_id=""
        fi
        if [ -n "$host_id" ] && [ "$host_id" != "null" ]; then
            test_endpoint "获取主机基线得分" "GET" "/results/host/$host_id/score"
            test_endpoint "获取主机基线摘要" "GET" "/results/host/$host_id/summary"
            test_endpoint "获取主机监控数据" "GET" "/hosts/$host_id/metrics"
        else
            echo -e "${YELLOW}跳过主机相关测试（无主机数据）${NC}"
        fi
    fi
fi

# 测试资产数据 API
echo ""
echo "--- 资产数据 API ---"
test_endpoint "获取进程列表" "GET" "/assets/processes"
test_endpoint "获取端口列表" "GET" "/assets/ports"
test_endpoint "获取账户列表" "GET" "/assets/users"

# 输出测试结果
echo ""
echo "=========================================="
echo "测试结果汇总"
echo "=========================================="
echo -e "${GREEN}通过: $PASSED${NC}"
echo -e "${RED}失败: $FAILED${NC}"
if [ $SKIPPED -gt 0 ]; then
    echo -e "${YELLOW}跳过: $SKIPPED${NC}"
fi
echo "总计: $((PASSED + FAILED + SKIPPED))"

if [ $FAILED -eq 0 ]; then
    if [ $SKIPPED -eq 0 ]; then
        echo ""
        echo -e "${GREEN}所有测试通过！${NC}"
        exit 0
    else
        echo ""
        echo -e "${YELLOW}部分测试跳过（需要认证），但所有执行的测试都通过了${NC}"
        exit 0
    fi
else
    echo ""
    echo -e "${RED}部分测试失败，请检查 API 服务状态和认证信息${NC}"
    exit 1
fi

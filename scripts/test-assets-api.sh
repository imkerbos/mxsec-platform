#!/bin/bash

# 资产 API 测试脚本
# 用于测试资产数据查询 API

set -e

# 配置
API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"
TOKEN="${TOKEN:-}"

echo "=========================================="
echo "资产 API 测试"
echo "=========================================="
echo "API Base URL: $API_BASE_URL"
echo ""

# 如果没有提供 Token，先登录获取
if [ -z "$TOKEN" ]; then
    echo "1. 登录获取 Token..."
    # 默认用户名和密码：admin/admin123
    USERNAME="${USERNAME:-admin}"
    PASSWORD="${PASSWORD:-admin123}"
    echo "   用户名: $USERNAME"
    LOGIN_RESPONSE=$(curl -s -X POST "$API_BASE_URL/api/v1/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")
    
    TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$TOKEN" ]; then
        echo "登录失败，响应: $LOGIN_RESPONSE"
        exit 1
    fi
    
    echo "✓ 登录成功，Token: ${TOKEN:0:20}..."
    echo ""
fi

# 测试函数
test_api() {
    local method=$1
    local endpoint=$2
    local description=$3
    
    echo "测试: $description"
    echo "  $method $endpoint"
    
    response=$(curl -s -w "\n%{http_code}" -X $method "$API_BASE_URL$endpoint" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ]; then
        echo "  ✓ HTTP $http_code"
        echo "  响应: $(echo $body | jq -c '.' 2>/dev/null || echo $body)"
    else
        echo "  ✗ HTTP $http_code"
        echo "  响应: $body"
        return 1
    fi
    echo ""
}

# 测试资产 API
echo "2. 测试资产 API..."
echo ""

# 测试获取进程列表
test_api "GET" "/api/v1/assets/processes" "获取进程列表（全部）"
test_api "GET" "/api/v1/assets/processes?page=1&page_size=10" "获取进程列表（分页）"

# 测试获取端口列表
test_api "GET" "/api/v1/assets/ports" "获取端口列表（全部）"
test_api "GET" "/api/v1/assets/ports?protocol=tcp" "获取端口列表（TCP）"
test_api "GET" "/api/v1/assets/ports?page=1&page_size=10" "获取端口列表（分页）"

# 测试获取账户列表
test_api "GET" "/api/v1/assets/users" "获取账户列表（全部）"
test_api "GET" "/api/v1/assets/users?page=1&page_size=10" "获取账户列表（分页）"

echo "=========================================="
echo "测试完成！"
echo "=========================================="

#!/bin/bash
# 检查 Agent 注册和 UI 数据展示

set -e

echo "========================================="
echo "检查 Agent 注册和 UI 数据展示"
echo "========================================="
echo ""

# 1. 检查服务状态
echo "1. 检查服务状态..."
docker-compose -f deploy/docker-compose/docker-compose.dev.yml ps
echo ""

# 2. 检查 Agent 日志（最近的心跳和连接信息）
echo "2. 检查 Agent 日志（最近 50 行）..."
docker logs mxcsec-agent-test --tail 50 2>&1 | grep -E "(Agent|connected|heartbeat|error|Error|ERROR|agent_id|AgentID)" || echo "未找到相关日志"
echo ""

# 3. 检查 AgentCenter 日志（连接和心跳处理）
echo "3. 检查 AgentCenter 日志（最近 50 行）..."
docker logs mxsec-agentcenter-dev --tail 50 2>&1 | grep -E "(connected|agent|Agent|heartbeat|Heartbeat|Transfer|connection|handleHeartbeat)" || echo "未找到相关日志"
echo ""

# 4. 检查 Manager 日志（API 请求）
echo "4. 检查 Manager 日志（最近 30 行）..."
docker logs mxsec-manager-dev --tail 30 2>&1 | tail -10
echo ""

# 5. 尝试登录获取 Token
echo "5. 尝试登录获取 Token..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}')

echo "$LOGIN_RESPONSE" | jq . || echo "$LOGIN_RESPONSE"

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.token // empty')
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "⚠️  登录失败，尝试使用默认用户..."
  # 尝试创建默认用户或使用其他方式
  TOKEN=""
else
  echo "✅ 登录成功，Token: ${TOKEN:0:20}..."
fi
echo ""

# 6. 查询主机列表（如果登录成功）
if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
  echo "6. 查询主机列表..."
  curl -s -X GET http://localhost:8080/api/v1/hosts \
    -H "Authorization: Bearer $TOKEN" | jq .
  echo ""
else
  echo "6. 跳过主机列表查询（需要 Token）"
  echo ""
fi

# 7. 查询 Dashboard 统计（如果登录成功）
if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
  echo "7. 查询 Dashboard 统计..."
  curl -s -X GET http://localhost:8080/api/v1/dashboard/stats \
    -H "Authorization: Bearer $TOKEN" | jq .
  echo ""
else
  echo "7. 跳过 Dashboard 查询（需要 Token）"
  echo ""
fi

# 8. 检查数据库中的主机记录（通过 Manager 容器）
echo "8. 检查数据库中的主机记录..."
docker exec mxsec-manager-dev sh -c "cd /workspace && mysql -h host.docker.internal -u root -p123456 mxsec -e 'SELECT host_id, hostname, status, last_heartbeat FROM hosts LIMIT 10;' 2>/dev/null" || echo "无法连接数据库或查询失败"
echo ""

# 9. 检查 UI 是否可访问
echo "9. 检查 UI 是否可访问..."
UI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
if [ "$UI_STATUS" = "200" ]; then
  echo "✅ UI 可访问 (http://localhost:3000)"
else
  echo "⚠️  UI 返回状态码: $UI_STATUS"
fi
echo ""

echo "========================================="
echo "检查完成"
echo "========================================="
echo ""
echo "提示："
echo "- 如果 Agent 未连接，请检查 Agent 日志中的错误信息"
echo "- 如果数据库中没有主机记录，请检查 AgentCenter 是否收到心跳"
echo "- 如果 API 返回 401，请先登录获取 Token"
echo "- UI 地址: http://localhost:3000"
echo "- Manager API: http://localhost:8080"
echo "- AgentCenter gRPC: localhost:6751"

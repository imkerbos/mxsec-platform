#!/bin/bash
# Agent 构建脚本（用于 Air 热重载）
# 环境变量 SERVER_HOST 和 VERSION 由 docker-compose 传递

set -e

cd /workspace

# 设置默认值
SERVER_HOST=${SERVER_HOST:-agentcenter:6751}
VERSION=${VERSION:-dev-test}
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 运行 go mod tidy
go mod tidy

# 构建 Agent
go build -ldflags "\
  -X main.serverHost=$SERVER_HOST \
  -X main.buildVersion=$VERSION \
  -X main.buildTime=$BUILD_TIME" \
  -o ./tmp/agent ./cmd/agent

echo "Agent built successfully: $SERVER_HOST, $VERSION, $BUILD_TIME"

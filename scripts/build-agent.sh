#!/bin/bash

# Agent 构建脚本
# 支持构建时嵌入 Server 地址等信息

set -e

# 配置
SERVER_HOST="${BLS_SERVER_HOST:-localhost:6751}"
VERSION="${BLS_VERSION:-1.0.0}"
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ARCH="${GOARCH:-amd64}"
OS="${GOOS:-linux}"

# 输出目录
OUTPUT_DIR="dist/agent"
mkdir -p "$OUTPUT_DIR"

echo "Building agent..."
echo "  Server: $SERVER_HOST"
echo "  Version: $VERSION"
echo "  Build time: $BUILD_TIME"
echo "  OS/Arch: $OS/$ARCH"
echo ""

# 构建 Agent
go build -ldflags "\
    -X main.serverHost=$SERVER_HOST \
    -X main.buildVersion=$VERSION \
    -X main.buildTime=$BUILD_TIME \
    -s -w" \
    -o "$OUTPUT_DIR/mxcsec-agent-$OS-$ARCH" \
    ./cmd/agent

echo "Build completed: $OUTPUT_DIR/mxcsec-agent-$OS-$ARCH"

# 显示文件信息
ls -lh "$OUTPUT_DIR/mxcsec-agent-$OS-$ARCH"

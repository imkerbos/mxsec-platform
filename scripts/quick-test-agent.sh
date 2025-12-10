#!/bin/bash

# 快速测试 Agent 脚本
# 用于快速启动一个测试 Agent 来生成测试数据

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Matrix Cloud Security Platform${NC}"
echo -e "${GREEN}快速测试 Agent 启动脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查 Server 地址
SERVER_HOST="${BLS_SERVER_HOST:-localhost:6751}"
echo -e "${YELLOW}Server 地址: $SERVER_HOST${NC}"
echo ""

# 检查 Agent 代码是否存在
if [ ! -d "cmd/agent" ]; then
    echo -e "${RED}错误: cmd/agent 目录不存在${NC}"
    echo -e "${YELLOW}提示: Agent 主程序可能尚未实现${NC}"
    echo ""
    echo "请先实现 Agent 主程序，或使用以下方式快速创建："
    echo "1. 创建 cmd/agent/main.go"
    echo "2. 实现 Agent 主程序入口"
    echo "3. 参考 internal/agent 目录下的模块"
    exit 1
fi

# 检查是否已构建
AGENT_BINARY="dist/agent/mxcsec-agent-linux-amd64"
if [ ! -f "$AGENT_BINARY" ]; then
    echo -e "${YELLOW}Agent 二进制文件不存在，开始构建...${NC}"
    echo ""
    
    # 设置构建参数
    export BLS_SERVER_HOST="$SERVER_HOST"
    export BLS_VERSION="dev-test"
    
    # 执行构建
    bash scripts/build-agent.sh
    
    if [ ! -f "$AGENT_BINARY" ]; then
        echo -e "${RED}构建失败！${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Agent 二进制文件已就绪${NC}"
echo ""

# 创建必要目录
echo -e "${YELLOW}创建必要目录...${NC}"
mkdir -p /tmp/mxcsec-agent-test/{lib,log,certs}
AGENT_DATA_DIR="/tmp/mxcsec-agent-test/lib"
AGENT_LOG_DIR="/tmp/mxcsec-agent-test/log"

echo -e "${GREEN}数据目录: $AGENT_DATA_DIR${NC}"
echo -e "${GREEN}日志目录: $AGENT_LOG_DIR${NC}"
echo ""

# 检查证书
CERT_DIR="certs"
if [ ! -d "$CERT_DIR" ]; then
    echo -e "${YELLOW}证书目录不存在，生成测试证书...${NC}"
    bash scripts/generate-certs.sh
fi

# 复制证书到 Agent 数据目录（如果需要）
if [ -d "$CERT_DIR" ]; then
    echo -e "${YELLOW}复制证书文件...${NC}"
    cp -r "$CERT_DIR"/* "$AGENT_DATA_DIR/certs/" 2>/dev/null || true
fi

# 启动 Agent
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}启动 Agent...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}提示:${NC}"
echo "  - 按 Ctrl+C 停止 Agent"
echo "  - 日志文件: $AGENT_LOG_DIR/agent.log"
echo "  - 数据目录: $AGENT_DATA_DIR"
echo ""

# 设置环境变量
export BLS_SERVER_HOST="$SERVER_HOST"
export MXC_SEC_AGENT_DATA_DIR="$AGENT_DATA_DIR"
export MXC_SEC_AGENT_LOG_DIR="$AGENT_LOG_DIR"

# 启动 Agent（前台运行，方便查看日志）
"$AGENT_BINARY" 2>&1 | tee "$AGENT_LOG_DIR/agent.log"

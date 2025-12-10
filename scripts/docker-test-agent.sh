#!/bin/bash

# Docker 方式启动测试 Agent 脚本
# 适用于 macOS 等非 Linux 系统

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Matrix Cloud Security Platform${NC}"
echo -e "${GREEN}Docker 测试 Agent 启动脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}错误: Docker 未运行${NC}"
    echo "请先启动 Docker Desktop"
    exit 1
fi

# 检查 docker-compose 是否可用
if ! command -v docker-compose > /dev/null 2>&1 && ! docker compose version > /dev/null 2>&1; then
    echo -e "${RED}错误: docker-compose 未安装${NC}"
    exit 1
fi

# 确定 docker-compose 命令
if docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# 切换到 docker-compose 目录
cd "$(dirname "$0")/../deploy/docker-compose" || exit 1

# 自动检测使用的 compose 文件
COMPOSE_FILE="docker-compose.yml"
if docker ps --format '{{.Names}}' | grep -qE '(mxsec-manager-dev|mxsec-ui-dev)'; then
    COMPOSE_FILE="docker-compose.dev.yml"
    echo -e "${GREEN}检测到开发环境（make dev-docker-up），使用 docker-compose.dev.yml${NC}"
    echo ""
elif docker ps --format '{{.Names}}' | grep -qE '(mxcsec-manager|mxcsec-ui)'; then
    COMPOSE_FILE="docker-compose.yml"
    echo -e "${GREEN}检测到生产环境，使用 docker-compose.yml${NC}"
    echo ""
fi

echo -e "${YELLOW}检查 Server 服务状态...${NC}"

# 检查 AgentCenter 是否运行（检查多个可能的容器名）
AGENTCENTER_RUNNING=false
if docker ps --format '{{.Names}}' | grep -qE '(mxcsec-agentcenter|mxsec-agentcenter|mxsec-agentcenter-dev)'; then
    AGENTCENTER_RUNNING=true
    echo -e "${GREEN}✓ AgentCenter 服务运行中${NC}"
elif docker ps --format '{{.Names}}' | grep -qE '(mxsec-manager|mxcsec-manager|mxsec-manager-dev)'; then
    # 如果只有 manager，检查是否在同一个容器中运行了 agentcenter
    echo -e "${YELLOW}检测到 Manager 服务，但未检测到独立的 AgentCenter 容器${NC}"
    echo -e "${YELLOW}Agent 需要连接到 AgentCenter (端口 6751)${NC}"
    echo ""
    if [ "$COMPOSE_FILE" = "docker-compose.dev.yml" ]; then
        echo -e "${GREEN}检测到您使用了 make dev-docker-up（docker-compose.dev.yml）${NC}"
        echo "AgentCenter 服务需要单独启动。"
        echo ""
        echo "将使用 docker-compose.dev.yml 启动 AgentCenter..."
        read -p "是否现在启动 AgentCenter 服务？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}启动 AgentCenter 服务...${NC}"
            $DOCKER_COMPOSE -f docker-compose.dev.yml up -d agentcenter
            echo -e "${YELLOW}等待服务启动...${NC}"
            sleep 10
            AGENTCENTER_RUNNING=true
        else
            echo -e "${YELLOW}继续启动 Agent，但可能无法连接到 Server${NC}"
        fi
    else
        echo "检测到您可能使用了 docker-compose.dev.yml（只启动了 manager 和 ui）"
        echo "Agent 需要 AgentCenter 服务才能连接。"
        echo ""
        echo "选项："
        echo "  1. 启动 AgentCenter（推荐）- 使用 docker-compose.dev.yml"
        echo "  2. 使用完整的 docker-compose.yml 启动所有服务"
        echo ""
        read -p "是否现在启动 AgentCenter 服务？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}启动 AgentCenter 服务...${NC}"
            # 优先使用 docker-compose.dev.yml（与用户当前环境一致）
            if [ -f "docker-compose.dev.yml" ]; then
                echo "使用 docker-compose.dev.yml 启动 AgentCenter..."
                $DOCKER_COMPOSE -f docker-compose.dev.yml up -d agentcenter
            elif [ -f "docker-compose.yml" ]; then
                echo "使用 docker-compose.yml 启动 AgentCenter..."
                $DOCKER_COMPOSE -f docker-compose.yml up -d mysql agentcenter
            else
                echo -e "${RED}错误: 未找到 docker-compose 配置文件${NC}"
                exit 1
            fi
            echo -e "${YELLOW}等待服务启动...${NC}"
            sleep 10
            AGENTCENTER_RUNNING=true
        else
            echo -e "${YELLOW}继续启动 Agent，但可能无法连接到 Server${NC}"
        fi
    fi
else
    echo -e "${YELLOW}未检测到 Server 服务${NC}"
    echo ""
    echo "请先启动 Server 服务："
    echo "  方式1: make dev-docker-up (启动 manager 和 ui，然后运行此脚本会自动启动 agentcenter)"
    echo "  方式2: make dev-up (启动完整服务)"
    echo "  方式3: cd deploy/docker-compose && docker-compose -f docker-compose.dev.yml up -d agentcenter manager"
    echo ""
    read -p "是否现在启动 Server 服务？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}启动 Server 服务...${NC}"
        # 优先使用 docker-compose.dev.yml
        if [ -f "docker-compose.dev.yml" ]; then
            $DOCKER_COMPOSE -f docker-compose.dev.yml up -d agentcenter manager
        elif [ -f "docker-compose.yml" ]; then
            $DOCKER_COMPOSE -f docker-compose.yml up -d mysql agentcenter manager
        else
            echo -e "${RED}错误: 未找到 docker-compose 配置文件${NC}"
            exit 1
        fi
        echo -e "${YELLOW}等待服务启动...${NC}"
        sleep 10
        AGENTCENTER_RUNNING=true
    else
        exit 1
    fi
fi

# 检查端口 6751 是否可访问
if command -v nc > /dev/null 2>&1; then
    if nc -z localhost 6751 2>/dev/null; then
        echo -e "${GREEN}✓ AgentCenter 端口 6751 可访问${NC}"
    else
        echo -e "${YELLOW}⚠ 警告: AgentCenter 端口 6751 不可访问${NC}"
        echo "   Agent 可能无法连接到 Server"
    fi
fi

echo ""

# 检查证书
if [ ! -d "certs" ] || [ -z "$(ls -A certs 2>/dev/null)" ]; then
    echo -e "${YELLOW}证书目录不存在或为空，生成证书...${NC}"
    cd ../../..
    bash scripts/generate-certs.sh
    cd deploy/docker-compose
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}启动测试 Agent...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}提示:${NC}"
echo "  - Agent 将在 Docker 容器中运行"
echo "  - 查看日志: $DOCKER_COMPOSE logs -f agent"
echo "  - 停止 Agent: $DOCKER_COMPOSE stop agent"
echo "  - 删除 Agent: $DOCKER_COMPOSE rm -f agent"
echo ""

# 构建并启动 Agent
echo -e "${GREEN}构建 Agent 镜像...${NC}"
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
$DOCKER_COMPOSE -f "$COMPOSE_FILE" build --build-arg BUILD_TIME="$BUILD_TIME" agent

echo -e "${GREEN}启动 Agent 容器...${NC}"
$DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d agent

echo ""
echo -e "${GREEN}Agent 已启动！${NC}"
echo ""
echo -e "${YELLOW}查看日志:${NC}"
echo "  cd deploy/docker-compose"
echo "  $DOCKER_COMPOSE -f $COMPOSE_FILE logs -f agent"
echo ""
echo -e "${YELLOW}查看容器状态:${NC}"
echo "  $DOCKER_COMPOSE -f $COMPOSE_FILE ps agent"
echo ""
echo -e "${YELLOW}停止 Agent:${NC}"
echo "  $DOCKER_COMPOSE -f $COMPOSE_FILE stop agent"
echo ""

# 等待一下，然后显示日志
sleep 2
echo -e "${GREEN}显示 Agent 日志（按 Ctrl+C 退出日志查看，容器会继续运行）:${NC}"
$DOCKER_COMPOSE -f "$COMPOSE_FILE" logs -f agent

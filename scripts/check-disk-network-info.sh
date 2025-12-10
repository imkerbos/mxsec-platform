#!/bin/bash

# 检查主机磁盘和网卡信息采集情况
# 使用方法：./scripts/check-disk-network-info.sh [host_id]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 数据库配置（从环境变量或默认值）
DB_HOST="${DB_HOST:-host.docker.internal}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-123456}"
DB_NAME="${DB_NAME:-mxsec}"

echo -e "${GREEN}=== 检查主机磁盘和网卡信息采集情况 ===${NC}\n"

# 检查数据库连接
echo -e "${YELLOW}1. 检查数据库连接...${NC}"
if ! mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" 2>/dev/null; then
    echo -e "${RED}错误: 无法连接到数据库${NC}"
    echo "请检查数据库配置："
    echo "  DB_HOST=$DB_HOST"
    echo "  DB_USER=$DB_USER"
    echo "  DB_NAME=$DB_NAME"
    exit 1
fi
echo -e "${GREEN}✓ 数据库连接成功${NC}\n"

# 检查表结构
echo -e "${YELLOW}2. 检查 hosts 表结构...${NC}"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE,
    COLUMN_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = '$DB_NAME'
  AND TABLE_NAME = 'hosts'
  AND COLUMN_NAME IN ('disk_info', 'network_interfaces')
ORDER BY COLUMN_NAME;
" 2>/dev/null || {
    echo -e "${RED}错误: 无法查询表结构${NC}"
    exit 1
}

HAS_DISK_INFO=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "
SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = '$DB_NAME'
  AND TABLE_NAME = 'hosts'
  AND COLUMN_NAME = 'disk_info';
" 2>/dev/null)

HAS_NETWORK_INTERFACES=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "
SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = '$DB_NAME'
  AND TABLE_NAME = 'hosts'
  AND COLUMN_NAME = 'network_interfaces';
" 2>/dev/null)

if [ "$HAS_DISK_INFO" -eq 0 ] || [ "$HAS_NETWORK_INTERFACES" -eq 0 ]; then
    echo -e "${RED}警告: 数据库字段不存在！${NC}"
    echo "请重启 AgentCenter 服务以执行数据库迁移，或手动添加字段："
    echo ""
    if [ "$HAS_DISK_INFO" -eq 0 ]; then
        echo "ALTER TABLE hosts ADD COLUMN disk_info TEXT NULL COMMENT '磁盘信息（JSON格式）';"
    fi
    if [ "$HAS_NETWORK_INTERFACES" -eq 0 ]; then
        echo "ALTER TABLE hosts ADD COLUMN network_interfaces TEXT NULL COMMENT '网卡信息（JSON格式）';"
    fi
    echo ""
else
    echo -e "${GREEN}✓ 数据库字段存在${NC}"
fi
echo ""

# 检查主机数据
echo -e "${YELLOW}3. 检查主机数据...${NC}"

if [ -n "$1" ]; then
    HOST_ID="$1"
    echo "检查主机: $HOST_ID"
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT 
    host_id,
    hostname,
    status,
    last_heartbeat,
    CASE 
        WHEN disk_info IS NULL OR disk_info = '' THEN '未采集'
        ELSE CONCAT('已采集 (', LENGTH(disk_info), ' 字符)')
    END AS disk_info_status,
    CASE 
        WHEN network_interfaces IS NULL OR network_interfaces = '' THEN '未采集'
        ELSE CONCAT('已采集 (', LENGTH(network_interfaces), ' 字符)')
    END AS network_interfaces_status
FROM hosts
WHERE host_id = '$HOST_ID';
" 2>/dev/null || {
    echo -e "${RED}错误: 无法查询主机数据${NC}"
    exit 1
}
    
    echo ""
    echo -e "${YELLOW}4. 查看磁盘信息（前500字符）...${NC}"
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "
SELECT 
    CASE 
        WHEN disk_info IS NULL OR disk_info = '' THEN '无数据'
        ELSE LEFT(disk_info, 500)
    END AS disk_info_preview
FROM hosts
WHERE host_id = '$HOST_ID';
" 2>/dev/null | head -20
    
    echo ""
    echo -e "${YELLOW}5. 查看网卡信息（前500字符）...${NC}"
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "
SELECT 
    CASE 
        WHEN network_interfaces IS NULL OR network_interfaces = '' THEN '无数据'
        ELSE LEFT(network_interfaces, 500)
    END AS network_interfaces_preview
FROM hosts
WHERE host_id = '$HOST_ID';
" 2>/dev/null | head -20
else
    echo "所有主机的采集情况："
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT 
    host_id,
    hostname,
    status,
    last_heartbeat,
    CASE 
        WHEN disk_info IS NULL OR disk_info = '' THEN '未采集'
        ELSE CONCAT('已采集 (', LENGTH(disk_info), ' 字符)')
    END AS disk_info_status,
    CASE 
        WHEN network_interfaces IS NULL OR network_interfaces = '' THEN '未采集'
        ELSE CONCAT('已采集 (', LENGTH(network_interfaces), ' 字符)')
    END AS network_interfaces_status
FROM hosts
ORDER BY last_heartbeat DESC
LIMIT 20;
" 2>/dev/null || {
    echo -e "${RED}错误: 无法查询主机数据${NC}"
    exit 1
}
fi

echo ""
echo -e "${GREEN}=== 检查完成 ===${NC}"
echo ""
echo -e "${YELLOW}排查建议：${NC}"
echo "1. 如果字段不存在，请重启 AgentCenter 服务执行数据库迁移"
echo "2. 如果字段存在但数据为空，请检查："
echo "   - Agent 是否已部署最新版本（包含磁盘和网卡采集功能）"
echo "   - Agent 日志中是否有采集相关的错误"
echo "   - AgentCenter 日志中是否有 '收到磁盘信息' 或 '收到网卡信息' 的日志"
echo "3. 查看 AgentCenter 日志："
echo "   docker logs mxsec-agentcenter-dev --tail 100 | grep -E '(disk_info|network_interfaces|收到磁盘|收到网卡)'"

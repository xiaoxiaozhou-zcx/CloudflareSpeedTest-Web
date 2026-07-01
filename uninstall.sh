#!/bin/bash
#
# CloudflareSpeedTest Web UI - 卸载脚本
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-/opt/cfst-web}"

echo -e "${YELLOW}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║   ⚠️  CloudflareSpeedTest Web UI - 卸载          ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# 确认
read -p "确定要卸载吗？(y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "已取消"
    exit 0
fi

cd "${INSTALL_DIR}" 2>/dev/null || { echo -e "${RED}安装目录不存在${NC}"; exit 1; }

# 停止并删除容器
if docker compose version &> /dev/null; then
    docker compose down 2>/dev/null || true
elif command -v docker-compose &> /dev/null; then
    docker-compose down 2>/dev/null || true
fi

# 删除镜像
docker rmi cfst-web:latest 2>/dev/null || true

# 删除安装目录
read -p "是否删除数据目录 ${INSTALL_DIR}/data？(y/N): " del_data
if [[ "$del_data" == "y" || "$del_data" == "Y" ]]; then
    rm -rf "${INSTALL_DIR}"
    echo -e "${GREEN}✅ 已删除所有文件${NC}"
else
    echo -e "${GREEN}✅ 服务已卸载，数据保留在 ${INSTALL_DIR}/data${NC}"
fi

echo -e "${GREEN}✅ 卸载完成${NC}"

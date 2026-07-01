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

read -p "确定要卸载吗？(y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "已取消"
    exit 0
fi

# 停止并禁用服务
echo -e "${CYAN}停止服务...${NC}"
systemctl stop cfst-web 2>/dev/null || true
systemctl disable cfst-web 2>/dev/null || true

# 删除 systemd 服务文件
rm -f /etc/systemd/system/cfst-web.service
systemctl daemon-reload

# 删除安装目录
read -p "是否删除安装目录 ${INSTALL_DIR} 及所有数据？(y/N): " del_all
if [[ "$del_all" == "y" || "$del_all" == "Y" ]]; then
    rm -rf "${INSTALL_DIR}"
    echo -e "${GREEN}✅ 已删除所有文件${NC}"
else
    # 至少删除程序文件，保留数据
    rm -f "${INSTALL_DIR}/cfst" "${INSTALL_DIR}/app.py"
    echo -e "${GREEN}✅ 服务已卸载，数据保留在 ${INSTALL_DIR}/data${NC}"
fi

echo -e "${GREEN}✅ 卸载完成${NC}"

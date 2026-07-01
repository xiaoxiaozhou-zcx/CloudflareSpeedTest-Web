#!/bin/bash
#
# CloudflareSpeedTest Web UI - 飞牛NAS 二进制一键安装脚本
# 无需 Docker，直接运行
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-/opt/cfst-web}"
PORT="${PORT:-8080}"
CFST_VERSION="v2.3.5"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║   ⚡ CloudflareSpeedTest Web UI - 飞牛NAS 安装   ║"
echo "║                                                   ║"
echo "║   二进制版 · 无需 Docker · 一键部署               ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# 检查 Python3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ 未检测到 Python3，请先安装: apt install python3 python3-pip${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python3: $(python3 --version)${NC}"

# 检查 pip
if ! command -v pip3 &> /dev/null && ! python3 -m pip --version &> /dev/null; then
    echo -e "${RED}❌ 未检测到 pip3，请先安装: apt install python3-pip${NC}"
    exit 1
fi
PIP_CMD="pip3"
command -v pip3 &> /dev/null || PIP_CMD="python3 -m pip"
echo -e "${GREEN}✅ pip: $(${PIP_CMD} --version 2>/dev/null | head -1)${NC}"

# 检测架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)  CFST_ARCH="amd64" ;;
    aarch64|arm64) CFST_ARCH="arm64" ;;
    armv7l|armhf)  CFST_ARCH="armv7" ;;
    *)             CFST_ARCH="amd64"; echo -e "${YELLOW}⚠️ 未知架构 ${ARCH}，默认使用 amd64${NC}" ;;
esac
echo -e "${GREEN}✅ 系统架构: ${ARCH} → cfst_linux_${CFST_ARCH}${NC}"

# 创建安装目录
echo ""
echo -e "${CYAN}📁 创建安装目录: ${INSTALL_DIR}${NC}"
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# 创建数据目录
mkdir -p data/results web/static/css web/static/js web/templates config

# ─── 下载 CloudflareSpeedTest ───────────────────────────────────────────
echo ""
echo -e "${CYAN}⬇️  下载 CloudflareSpeedTest ${CFST_VERSION}...${NC}"

DOWNLOAD_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/${CFST_VERSION}/cfst_linux_${CFST_ARCH}.tar.gz"

# 尝试多个镜像
MIRRORS=(
    "${DOWNLOAD_URL}"
    "https://ghfast.top/${DOWNLOAD_URL}"
    "https://gh-proxy.org/${DOWNLOAD_URL}"
    "https://cdn.gh-proxy.org/${DOWNLOAD_URL}"
)

DOWNLOADED=0
for url in "${MIRRORS[@]}"; do
    echo -e "  尝试: ${url}"
    if wget -q --no-check-certificate --timeout=15 -O /tmp/cfst.tar.gz "${url}" 2>/dev/null; then
        DOWNLOADED=1
        break
    fi
done

if [ "$DOWNLOADED" -eq 0 ]; then
    echo -e "${RED}❌ 下载失败，请检查网络或手动下载:${NC}"
    echo -e "   ${DOWNLOAD_URL}"
    echo -e "   下载后放到 ${INSTALL_DIR}/cfst 并赋予执行权限: chmod +x ${INSTALL_DIR}/cfst"
    exit 1
fi

tar -xzf /tmp/cfst.tar.gz -C "${INSTALL_DIR}" 2>/dev/null || true
rm -f /tmp/cfst.tar.gz

# 确保 cfst 存在且可执行
if [ ! -f "${INSTALL_DIR}/cfst" ]; then
    # 有些版本解压出来文件名不同，查找一下
    CFST_BIN=$(find "${INSTALL_DIR}" -name "cfst*" -type f -executable 2>/dev/null | head -1)
    if [ -n "$CFST_BIN" ]; then
        mv "$CFST_BIN" "${INSTALL_DIR}/cfst"
    fi
fi

if [ ! -f "${INSTALL_DIR}/cfst" ]; then
    echo -e "${RED}❌ 找不到 cfst 可执行文件，请手动下载并放到 ${INSTALL_DIR}/cfst${NC}"
    exit 1
fi

chmod +x "${INSTALL_DIR}/cfst"
echo -e "${GREEN}✅ CloudflareSpeedTest 已就绪${NC}"

# ─── 下载 Web UI 文件 ───────────────────────────────────────────────────
echo ""
echo -e "${CYAN}⬇️  下载 Web UI 文件...${NC}"

REPO_RAW="https://raw.githubusercontent.com/xiaoxiaozhou-zcx/CloudflareSpeedTest-Web/main"

FILES=(
    "app.py"
    "requirements.txt"
    "ip.txt"
    "web/templates/index.html"
    "web/static/css/style.css"
    "web/static/js/app.js"
    "config/settings.json"
)

for f in "${FILES[@]}"; do
    dir=$(dirname "${INSTALL_DIR}/${f}")
    mkdir -p "$dir"
    if wget -q --no-check-certificate --timeout=10 -O "${INSTALL_DIR}/${f}" "${REPO_RAW}/${f}" 2>/dev/null; then
        echo -e "  ✅ ${f}"
    else
        echo -e "  ${YELLOW}⚠️  ${f} 下载失败，请手动下载${NC}"
    fi
done

# ─── 安装 Python 依赖 ───────────────────────────────────────────────────
echo ""
echo -e "${CYAN}📦 安装 Python 依赖...${NC}"
${PIP_CMD} install --quiet flask 2>/dev/null || python3 -m pip install --quiet flask 2>/dev/null
echo -e "${GREEN}✅ 依赖安装完成${NC}"

# ─── 写入配置 ───────────────────────────────────────────────────────────
cat > "${INSTALL_DIR}/config/env" << EOF
PORT=${PORT}
CFST_BIN=${INSTALL_DIR}/cfst
DATA_DIR=${INSTALL_DIR}/data
IP_FILE=${INSTALL_DIR}/ip.txt
EOF

# ─── 创建 systemd 服务 ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}🔧 创建 systemd 服务...${NC}"

cat > /etc/systemd/system/cfst-web.service << EOF
[Unit]
Description=CloudflareSpeedTest Web UI
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
EnvironmentFile=${INSTALL_DIR}/config/env
ExecStart=/usr/bin/python3 ${INSTALL_DIR}/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cfst-web
systemctl start cfst-web

echo -e "${GREEN}✅ 服务已启动${NC}"

# ─── 完成 ───────────────────────────────────────────────────────────────
sleep 2

if systemctl is-active --quiet cfst-web; then
    NAS_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         ✅ 安装成功！服务已启动                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  🌐 访问地址: ${CYAN}http://${NAS_IP}:${PORT}${NC}"
    echo ""
    echo -e "  📁 安装目录: ${INSTALL_DIR}"
    echo -e "  📊 测速结果: ${INSTALL_DIR}/data/results/"
    echo ""
    echo -e "  ${YELLOW}常用命令:${NC}"
    echo -e "    查看状态:   ${CYAN}systemctl status cfst-web${NC}"
    echo -e "    查看日志:   ${CYAN}journalctl -u cfst-web -f${NC}"
    echo -e "    重启服务:   ${CYAN}systemctl restart cfst-web${NC}"
    echo -e "    停止服务:   ${CYAN}systemctl stop cfst-web${NC}"
    echo -e "    卸载:       ${CYAN}bash ${INSTALL_DIR}/uninstall.sh${NC}"
    echo ""
else
    echo -e "${RED}❌ 服务启动失败，请查看日志:${NC}"
    journalctl -u cfst-web --no-pager -n 20
    exit 1
fi

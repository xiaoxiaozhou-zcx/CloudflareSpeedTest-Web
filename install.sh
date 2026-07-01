#!/bin/bash
#
# CloudflareSpeedTest Web UI - 飞牛NAS 一键安装脚本
# 使用方法: bash install.sh
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-/opt/cfst-web}"
PORT="${PORT:-8080}"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║   ⚡ CloudflareSpeedTest Web UI - 飞牛NAS 安装   ║"
echo "║                                                   ║"
echo "║   基于 XIU2/CloudflareSpeedTest                  ║"
echo "║   Web 管理界面 · 一键部署                         ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ 未检测到 Docker，请先在飞牛管理界面安装 Docker 套件${NC}"
    exit 1
fi

# 检查 docker compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}❌ 未检测到 docker compose，请更新 Docker 版本${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker 环境检查通过${NC}"
echo ""

# 创建安装目录
echo -e "${CYAN}📁 创建安装目录: ${INSTALL_DIR}${NC}"
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# 创建必要目录
mkdir -p data/results

# 生成 docker-compose.yml
echo -e "${CYAN}📝 生成配置文件...${NC}"
cat > docker-compose.yml << 'COMPOSE'
version: "3.8"

services:
  cloudflare-speedtest:
    image: ghcr.io/${GITHUB_USER:-user}/cfst-web:latest
    container_name: cfst-web
    restart: unless-stopped
    ports:
      - "${PORT:-8080}:8080"
    volumes:
      - ./data:/data
    environment:
      - PORT=8080
      - TZ=Asia/Shanghai
COMPOSE

# 写入端口配置
sed -i "s/\${PORT:-8080}/${PORT}/g" docker-compose.yml

echo -e "${GREEN}✅ 配置文件已生成${NC}"

# 拉取镜像（如果可用）或本地构建
echo ""
echo -e "${CYAN}🐳 拉取 Docker 镜像...${NC}"

# 尝试从 GitHub Container Registry 拉取
if docker pull "ghcr.io/xiu2/cfst-web:latest" 2>/dev/null; then
    sed -i "s|ghcr.io/\${GITHUB_USER:-user}/cfst-web:latest|ghcr.io/xiu2/cfst-web:latest|g" docker-compose.yml
    echo -e "${GREEN}✅ 镜像拉取成功${NC}"
else
    echo -e "${YELLOW}⚠️ 无法拉取远程镜像，将使用本地构建${NC}"

    # 如果当前目录有 Dockerfile 则本地构建
    if [ -f "../Dockerfile" ]; then
        cp -r ../* "${INSTALL_DIR}/"
        ${COMPOSE_CMD} build
    elif [ -f "Dockerfile" ]; then
        ${COMPOSE_CMD} build
    else
        echo -e "${RED}❌ 找不到 Dockerfile，请将项目文件放到 ${INSTALL_DIR} 目录${NC}"
        echo -e "${YELLOW}   或者手动构建: docker build -t cfst-web:latest .${NC}"
        exit 1
    fi

    # 更新 compose 使用本地镜像
    sed -i "s|ghcr.io/\${GITHUB_USER:-user}/cfst-web:latest|cfst-web:latest|g" docker-compose.yml
    echo -e "${GREEN}✅ 本地镜像构建完成${NC}"
fi

# 启动服务
echo ""
echo -e "${CYAN}🚀 启动服务...${NC}"
${COMPOSE_CMD} up -d

# 等待启动
echo -e "${CYAN}⏳ 等待服务启动...${NC}"
sleep 3

# 检查状态
if docker ps | grep -q cfst-web; then
    # 获取飞牛NAS IP
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
    echo -e "    查看日志:   ${CYAN}${COMPOSE_CMD} logs -f${NC}"
    echo -e "    重启服务:   ${CYAN}${COMPOSE_CMD} restart${NC}"
    echo -e "    停止服务:   ${CYAN}${COMPOSE_CMD} down${NC}"
    echo -e "    更新服务:   ${CYAN}${COMPOSE_CMD} pull && ${COMPOSE_CMD} up -d${NC}"
    echo ""
else
    echo -e "${RED}❌ 服务启动失败，请查看日志:${NC}"
    ${COMPOSE_CMD} logs
    exit 1
fi

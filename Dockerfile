FROM python:3.11-slim

LABEL maintainer="CloudflareSpeedTest-Web"
LABEL description="CloudflareSpeedTest Web UI for fnOS NAS"

# 设置工作目录
WORKDIR /app

# 安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 下载 CloudflareSpeedTest
ARG CFST_VERSION=v2.3.5
RUN apt-get update && apt-get install -y --no-install-recommends wget tar && \
    ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then CFST_ARCH="amd64"; \
    elif [ "$ARCH" = "arm64" ]; then CFST_ARCH="arm64"; \
    else CFST_ARCH="amd64"; fi && \
    wget -q --no-check-certificate "https://github.com/XIU2/CloudflareSpeedTest/releases/download/${CFST_VERSION}/cfst_linux_${CFST_ARCH}.tar.gz" -O /tmp/cfst.tar.gz && \
    tar -xzf /tmp/cfst.tar.gz -C /app && \
    chmod +x /app/cfst && \
    rm /tmp/cfst.tar.gz && \
    apt-get purge -y wget && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# 复制应用文件
COPY app.py .
COPY web/ web/
COPY config/ config/

# 如果本地有 ip.txt 则复制（否则程序会使用内置的）
COPY ip.txt ip.txt

# 创建数据目录
RUN mkdir -p /data/results

# 环境变量
ENV PORT=8080
ENV CFST_BIN=/app/cfst
ENV DATA_DIR=/data
ENV IP_FILE=/app/ip.txt

EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/api/health')" || exit 1

CMD ["python", "app.py"]

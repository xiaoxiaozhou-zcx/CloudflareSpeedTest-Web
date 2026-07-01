# CloudflareSpeedTest Web UI

> 🚀 基于 [XIU2/CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest) 的 Web 管理界面，专为飞牛NAS (fnOS) 一键部署设计。

[![Docker](https://img.shields.io/badge/Docker-Ready-blue?logo=docker)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ 功能特性

- 🌐 **Web 管理界面** - 浏览器操作，无需命令行
- ⚡ **实时日志流** - 测速过程实时展示
- 📊 **结果可视化** - 测速结果表格展示，支持排序和筛选
- 📁 **历史记录** - 自动保存每次测速结果
- ⚙️ **灵活配置** - 所有 CloudflareSpeedTest 参数均可在页面配置
- 🐳 **Docker 部署** - 一键安装，开箱即用
- 📱 **响应式设计** - 手机、平板、电脑均可使用

## 📸 界面预览

| 测速控制 | 实时日志 | 结果展示 |
|---------|---------|---------|
| 参数配置一键启动 | 实时查看测速进度 | 表格展示一键导出 |

## 🚀 飞牛NAS 一键安装

### 方法一：SSH 安装（推荐）

1. SSH 登录你的飞牛NAS

2. 执行一键安装脚本：
```bash
curl -fsSL https://raw.githubusercontent.com/xiaoxiaozhou-zcx/CloudflareSpeedTest-Web/main/install.sh | bash
```

3. 安装完成后，浏览器访问 `http://你的NAS-IP:8080`

### 方法二：Docker Compose 手动安装

1. SSH 登录飞牛NAS，创建项目目录：
```bash
mkdir -p /opt/cfst-web && cd /opt/cfst-web
```

2. 下载项目文件：
```bash
git clone https://github.com/xiaoxiaozhou-zcx/CloudflareSpeedTest-Web.git .
```

3. 启动服务：
```bash
docker compose up -d
```

4. 访问 `http://你的NAS-IP:8080`

### 方法三：飞牛 Docker 管理界面

1. 打开飞牛管理界面 → Docker → 镜像
2. 拉取镜像（如果已发布到 Docker Hub / GHCR）
3. 创建容器，映射端口 `8080:8080`，挂载卷 `./data:/data`
4. 启动容器

## 📖 使用说明

### 基本测速

1. 打开 Web 界面
2. 在「测速控制」页面配置参数（或使用默认值）
3. 点击「🚀 开始测速」
4. 实时查看日志输出
5. 测速完成后在「📊 测速结果」查看结果

### 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 测速线程数 | 200 | 并发线程数，路由器等弱设备建议调低 |
| 测速次数 | 4 | 每个 IP 测试次数 |
| 下载测速数量 | 10 | 延迟排序后，对前 N 个 IP 进行下载测速 |
| 下载测速时间 | 10 | 每个 IP 的下载测速最长时间（秒） |
| 测速端口 | 443 | 测速使用的端口 |
| 延迟上限 | 9999 | 只输出低于此延迟的 IP |
| 丢包率上限 | 1.00 | 只输出低于此丢包率的 IP |
| 下载速度下限 | 0 | 只输出高于此速度的 IP |

### 测速模式

- **TCPing（默认）**：使用 TCP 协议测试延迟，速度快
- **HTTPing**：使用 HTTP 协议测试延迟，可获取地区码信息

### IP 配置

在「⚙️ IP 配置」页面可以编辑 IP 段数据文件：
- 支持 CIDR 格式：`104.16.0.0/13`
- 支持单个 IP：`1.1.1.1`
- 每行一个
- 也可以在测速时通过「指定 IP 段」参数直接指定

## 🏗️ 项目结构

```
CloudflareSpeedTest-Web/
├── app.py              # Flask 后端服务
├── Dockerfile          # Docker 镜像构建
├── docker-compose.yml  # Docker Compose 配置
├── install.sh          # 飞牛NAS 一键安装脚本
├── uninstall.sh        # 卸载脚本
├── requirements.txt    # Python 依赖
├── ip.txt              # 默认 Cloudflare IP 段
├── config/
│   └── settings.json   # 默认配置
├── web/
│   ├── templates/
│   │   └── index.html  # 主页面
│   └── static/
│       ├── css/
│       │   └── style.css
│       └── js/
│           └── app.js
└── data/               # 数据目录（挂载卷）
    └── results/        # 测速结果 CSV
```

## 🔧 常用命令

```bash
# 进入项目目录
cd /opt/cfst-web

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 更新镜像
docker compose pull && docker compose up -d

# 完全卸载
bash uninstall.sh
```

## ⚠️ 注意事项

1. **网络模式**：建议使用 `host` 网络模式以获得最准确的测速结果，避免 Docker NAT 影响
2. **代理干扰**：测速时请关闭 NAS 上的代理软件，否则结果不准确
3. **IPv6**：默认使用 IPv4 IP 段，如需 IPv6 请替换 ip.txt 内容
4. **数据持久化**：测速结果保存在 `data/results/` 目录，不会因容器重启丢失

## 📄 License

MIT License - 基于 [XIU2/CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest)

## 🙏 致谢

- [XIU2/CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest) - 核心测速工具
- [Flask](https://flask.palletsprojects.com/) - Web 框架

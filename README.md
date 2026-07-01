# CloudflareSpeedTest Web UI

> 🚀 基于 [XIU2/CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest) 的 Web 管理界面，专为飞牛NAS (fnOS) 一键部署设计。

**二进制版，无需 Docker，一键安装即用。**

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ 功能特性

- 🌐 **Web 管理界面** - 浏览器操作，无需命令行
- ⚡ **实时日志流** - 测速过程实时展示
- 📊 **结果可视化** - 测速结果表格展示，支持排序和筛选
- 📁 **历史记录** - 自动保存每次测速结果
- ⚙️ **灵活配置** - 所有 CloudflareSpeedTest 参数均可在页面配置
- 🔧 **二进制运行** - 无需 Docker，直接下载运行
- 📱 **响应式设计** - 手机、平板、电脑均可使用

## 🚀 飞牛NAS 一键安装

SSH 登录你的飞牛NAS，执行：

```bash
curl -fsSL https://raw.githubusercontent.com/xiaoxiaozhou-zcx/CloudflareSpeedTest-Web/main/install.sh | bash
```

安装完成后，浏览器访问 `http://你的NAS-IP:8080`

> 默认端口 8080，可通过 `PORT=9090 bash install.sh` 自定义端口。

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

## 🔧 常用命令

```bash
# 查看服务状态
systemctl status cfst-web

# 查看实时日志
journalctl -u cfst-web -f

# 重启服务
systemctl restart cfst-web

# 停止服务
systemctl stop cfst-web

# 启动服务
systemctl start cfst-web

# 卸载
bash /opt/cfst-web/uninstall.sh
```

## 📁 安装目录结构

```
/opt/cfst-web/
├── cfst                 # CloudflareSpeedTest 二进制
├── app.py               # Flask Web 服务
├── ip.txt               # Cloudflare IP 段
├── requirements.txt
├── config/
│   ├── settings.json
│   └── env              # 环境变量配置
├── data/
│   └── results/         # 测速结果 CSV
└── web/
    ├── templates/
    │   └── index.html
    └── static/
        ├── css/style.css
        └── js/app.js
```

## ⚠️ 注意事项

1. **代理干扰**：测速时请关闭 NAS 上的代理软件，否则结果不准确
2. **IPv6**：默认使用 IPv4 IP 段，如需 IPv6 请替换 `/opt/cfst-web/ip.txt`
3. **端口冲突**：如果 8080 端口被占用，安装时用 `PORT=其他端口 bash install.sh`
4. **首次测速**：建议先随便跑几个 IP 预热，第二次结果更准

## 📄 License

MIT License - 基于 [XIU2/CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest)

## 🙏 致谢

- [XIU2/CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest) - 核心测速工具
- [Flask](https://flask.palletsprojects.com/) - Web 框架

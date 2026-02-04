# OpenClaw 安装脚本

面向主流 Linux/macOS 的一键安装脚本，支持：
- 自动检测并安装常见依赖
- 通过 nvm 安装 Node 22，并设置为默认
- 交互式生成 OpenClaw 配置文件（模型名/显示名/接入点/token/端口）
- 可选跳过本地 LLM 编译（仅云模型）
- 可选使用国内 npm 镜像加速

## 目录

- `install_openclaw.sh` 安装脚本

## 使用方法

```bash
chmod +x install_openclaw.sh
./install_openclaw.sh
```

脚本会依次提示：
- 是否跳过本地 LLM 编译（只用云模型）
- 是否使用国内 npm 镜像
- 模型名、显示名称、接入点、API Token
- Gateway 端口（默认 3000）
- Workspace 目录（默认 /data/openclaw-workspace，会自动创建）

配置文件会写入：

```
~/.openclaw/openclaw.json
```

安装完成后验证：

```bash
openclaw status
```

## Web UI 访问说明

默认网关绑定 `127.0.0.1`，外部无法直接访问。脚本会输出三种访问方式：

1. SSH 隧道（临时访问）
2. Cloudflare Tunnel（可用临时地址或永久域名）
3. Nginx 反向代理

按脚本提示操作即可。

## 说明

- 如果你只用云模型，建议选择“跳过本地 LLM 编译”，避免 `node-llama-cpp` 编译失败。
- 如需本地 LLM，请不要跳过编译，并确保机器有足够内存与编译依赖。

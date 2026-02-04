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

## 常用命令

```bash
# 查看状态
openclaw status

# 启动网关
openclaw gateway start

# 停止网关
openclaw gateway stop

# 重启网关
openclaw gateway restart
```

## Telegram 通知（通用示例）

下面是一个通用接入思路：OpenClaw 的 Telegram 通道不仅能把消息发到 Telegram，也支持从 Telegram 发送消息到 OpenClaw，实现双向通信。默认行为如下：
- 私聊（DM）默认需要配对（pairing），首次消息会给出配对码，需要批准后才会正常对话。
- 群聊默认仅在 @ 提及时响应（可配置）。

### 1) 在 Telegram 上准备信息

1. **创建 Bot 并获取 Token**
   - 在 Telegram 搜索并打开 `@BotFather`
   - 发送 `/newbot`，按提示创建机器人
   - 创建成功后会得到一个 **Bot Token**（形如 `123456:ABC-DEF...`）

2. **获取 Chat ID（用于发送消息到指定对话）**
   - 先和你的 Bot 发送一条消息
   - 打开以下链接（将 `<BOT_TOKEN>` 换成你的 Token）：
     ```
     https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
     ```
   - 在返回结果中找到 `chat.id`，这就是你的 **Chat ID**

### 2) 在 OpenClaw 配置中写入（示例）

> 下面字段是示意结构，实际字段名称请按你的 OpenClaw 版本或插件文档调整。

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "YOUR_BOT_TOKEN",
      "dmPolicy": "pairing",
      "groups": { "*": { "requireMention": true } }
    }
  }
}
```

### 3) 建议用环境变量替换明文

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "pairing",
      "groups": { "*": { "requireMention": true } }
    }
  }
}
```

然后在系统里设置：

```bash
export TELEGRAM_BOT_TOKEN="xxx"
export TELEGRAM_CHAT_ID="yyy"
```

完成后重启 OpenClaw/网关使配置生效。

### 4) 配对与群聊效果

- 私聊：首次 DM 会出现配对码，需要执行：
  - `openclaw pairing list telegram`
  - `openclaw pairing approve telegram <CODE>`
- 群聊：默认仅 @ 提及时响应（`requireMention: true`）。如果希望群内任意消息都触发，可将该值改为 `false`。

## 说明

- 如果你只用云模型，建议选择“跳过本地 LLM 编译”，避免 `node-llama-cpp` 编译失败。
- 如需本地 LLM，请不要跳过编译，并确保机器有足够内存与编译依赖。

#!/usr/bin/env bash
set -euo pipefail

# install_openclaw.sh
# 目的：在主流 Linux/macOS 上使用 nvm + Node 22 + npm 安装 OpenClaw。
# 说明：
# - 使用国内 npm 镜像加速下载。
# - 设置 NODE_LLAMA_CPP_SKIP_DOWNLOAD=true，跳过本地 LLM（llama.cpp）编译。
# - 通过 OpenClaw 官方安装脚本（npm 方式）完成安装。

# ---- 配置 ----
NVM_VERSION="v0.40.3"
NODE_MAJOR="22"
NPM_REGISTRY="https://registry.npmmirror.com"
OPENCLAW_INSTALLER="https://openclaw.bot/install.sh"

# ---- 0) 识别操作系统 ----
OS_NAME="$(uname -s)"
case "$OS_NAME" in
  Linux) OS_FAMILY="linux" ;;
  Darwin) OS_FAMILY="macos" ;;
  *)
    echo "不支持的操作系统：$OS_NAME"
    exit 1
    ;;
esac

# ---- 0.1) 依赖检测与安装 ----
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# 读取发行版信息（Linux）
OS_ID=""
OS_ID_LIKE=""
if [ "$OS_FAMILY" = "linux" ] && [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_ID_LIKE="${ID_LIKE:-}"
fi

install_linux_pkg() {
  local pkg="$1"
  case "$OS_ID" in
    ubuntu|debian)
      sudo -n apt-get update -y || apt-get update -y
      sudo -n apt-get install -y "$pkg" || apt-get install -y "$pkg"
      ;;
    fedora|centos|rhel|rocky|almalinux|ol)
      if has_cmd dnf; then
        sudo -n dnf install -y "$pkg" || dnf install -y "$pkg"
      else
        sudo -n yum install -y "$pkg" || yum install -y "$pkg"
      fi
      ;;
    opensuse*|sles)
      sudo -n zypper install -y "$pkg" || zypper install -y "$pkg"
      ;;
    arch|manjaro)
      sudo -n pacman -Syu --noconfirm "$pkg" || pacman -Syu --noconfirm "$pkg"
      ;;
    *)
      # 兜底：按 ID_LIKE 处理
      case "$OS_ID_LIKE" in
        *debian*)
          sudo -n apt-get update -y || apt-get update -y
          sudo -n apt-get install -y "$pkg" || apt-get install -y "$pkg"
          ;;
        *rhel*|*fedora*)
          if has_cmd dnf; then
            sudo -n dnf install -y "$pkg" || dnf install -y "$pkg"
          else
            sudo -n yum install -y "$pkg" || yum install -y "$pkg"
          fi
          ;;
        *suse*)
          sudo -n zypper install -y "$pkg" || zypper install -y "$pkg"
          ;;
        *arch*)
          sudo -n pacman -Syu --noconfirm "$pkg" || pacman -Syu --noconfirm "$pkg"
          ;;
        *)
          echo "未识别的发行版：ID=$OS_ID ID_LIKE=$OS_ID_LIKE，无法自动安装 $pkg"
          return 1
          ;;
      esac
      ;;
  esac
}

install_macos_pkg() {
  local pkg="$1"
  if has_cmd brew; then
    brew install "$pkg"
  else
    echo "未检测到 Homebrew，请先安装：/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    return 1
  fi
}

ensure_cmd() {
  local cmd="$1"
  local pkg="${2:-$1}"
  if has_cmd "$cmd"; then
    return 0
  fi
  echo "缺少依赖：$cmd，尝试自动安装..."
  if [ "$OS_FAMILY" = "linux" ]; then
    install_linux_pkg "$pkg"
  else
    install_macos_pkg "$pkg"
  fi
  has_cmd "$cmd"
}

# 基础依赖（nvm/安装脚本需要 curl；git 用于部分安装流程）
ensure_cmd curl curl
ensure_cmd git git

# 常见工具依赖（兼容主流 Linux/macOS）
ensure_cmd tar tar
ensure_cmd unzip unzip
ensure_cmd xz xz
ensure_cmd make make
ensure_cmd gcc gcc
ensure_cmd python3 python3
ensure_cmd perl perl
ensure_cmd pkg-config pkg-config
ensure_cmd cmake cmake
ensure_cmd clang clang

# 常见开发库（不同发行版包名不同）
install_linux_devlibs() {
  if has_cmd dnf || has_cmd yum; then
    install_linux_pkg glibc-devel
    install_linux_pkg zlib-devel
    install_linux_pkg openssl-devel
    install_linux_pkg libstdc++-devel
  elif has_cmd apt-get; then
    install_linux_pkg libc6-dev
    install_linux_pkg zlib1g-dev
    install_linux_pkg libssl-dev
    install_linux_pkg libstdc++-12-dev
  fi
}

if [ "$OS_FAMILY" = "linux" ]; then
  install_linux_devlibs
fi

# ---- 0.2) 安装无头浏览器（OpenClaw 浏览器能力需要） ----
install_headless_browser_linux() {
  # 尝试安装 Chromium（不同发行版包名不同）
  if has_cmd dnf || has_cmd yum; then
    install_linux_pkg chromium || install_linux_pkg chromium-browser || true
  elif has_cmd apt-get; then
    install_linux_pkg chromium || install_linux_pkg chromium-browser || true
  fi
}

install_headless_browser_macos() {
  if has_cmd brew; then
    brew install --cask chromium || true
  fi
}

if [ "$OS_FAMILY" = "linux" ]; then
  install_headless_browser_linux
else
  install_headless_browser_macos
fi

# 根据当前 shell 选择启动文件（尽量兼容 bash/zsh）
SHELL_NAME="$(basename "${SHELL:-}")"
case "$SHELL_NAME" in
  zsh) SHELL_RC="$HOME/.zshrc" ;;
  bash) SHELL_RC="$HOME/.bashrc" ;;
  *)
    # 兜底：优先 .bashrc，不存在则用 .profile
    SHELL_RC="$HOME/.bashrc"
    [ -f "$SHELL_RC" ] || SHELL_RC="$HOME/.profile"
    ;;
esac

# ---- 1) 安装 nvm ----
if [ ! -d "$HOME/.nvm" ]; then
  echo "[1/5] 正在安装 nvm ${NVM_VERSION}..."
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
else
  echo "[1/5] nvm 已安装，跳过。"
fi

# ---- 2) 加载 nvm ----
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1090
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# ---- 3) 安装 Node 22 并设为默认 ----
echo "[2/5] 正在安装 Node.js ${NODE_MAJOR}..."
nvm install "$NODE_MAJOR"
nvm use "$NODE_MAJOR"
nvm alias default "$NODE_MAJOR"

# 确保后续登录时也能找到 nvm/Node（避免出现找不到 openclaw）
if ! grep -q 'NVM_DIR="$HOME/.nvm"' "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" <<'SHELLRC_NVM'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
SHELLRC_NVM
fi

# 确保当前会话 PATH 包含 Node 22 的 bin（避免安装后找不到 openclaw）
NODE_BIN_DIR="$(dirname "$(command -v node)")"
export PATH="${NODE_BIN_DIR}:$PATH"

# ---- 4) 配置 npm 镜像（可选但推荐） ----
echo "[3/5] 正在设置 npm 镜像为 ${NPM_REGISTRY}..."
npm config set registry "$NPM_REGISTRY"

# ---- 5) 让用户选择是否跳过本地 LLM 与是否使用 npm 镜像 ----
echo "[4/5] 选择安装方式："
echo "  1) 跳过本地 LLM 编译（仅使用云模型）"
echo "     说明：避免 node-llama-cpp 编译失败/耗时，但本地 LLM 功能不可用。"
echo "  2) 不跳过（可能会编译本地 LLM）"
echo "     说明：需要较多内存/依赖，可能耗时或失败，但可用本地 LLM。"
read -r -p "请选择 1 或 2（默认 1）： " CHOICE_LLM
CHOICE_LLM="${CHOICE_LLM:-1}"

echo
echo "是否使用国内 npm 镜像加速？"
echo "  1) 使用国内镜像（推荐国内网络）"
echo "     说明：提升下载速度，减少超时。"
echo "  2) 使用默认 npm 官方源"
echo "     说明：不改动默认源。"
read -r -p "请选择 1 或 2（默认 1）： " CHOICE_MIRROR
CHOICE_MIRROR="${CHOICE_MIRROR:-1}"

INSTALL_ENV=""
if [ "$CHOICE_LLM" = "1" ]; then
  INSTALL_ENV="NODE_LLAMA_CPP_SKIP_DOWNLOAD=true"
fi
if [ "$CHOICE_MIRROR" = "1" ]; then
  INSTALL_ENV="${INSTALL_ENV} NPM_CONFIG_REGISTRY=${NPM_REGISTRY}"
fi

echo "[4/5] 正在安装 OpenClaw..."
# 将环境变量传递给安装脚本的 bash 进程
if [ -n "$INSTALL_ENV" ]; then
  curl -fsSL "$OPENCLAW_INSTALLER" | env $INSTALL_ENV bash -s -- --install-method npm
else
  curl -fsSL "$OPENCLAW_INSTALLER" | bash -s -- --install-method npm
fi

# ---- 6) 生成配置文件（按用户输入） ----
echo "[5/5] 请输入模型与接入信息（仅云模型）..."
read -r -p "模型名（例如 qwen3-max-2026-01-23）： " MODEL_ID
read -r -p "显示名称（例如 Qwen3 Max）： " MODEL_NAME
read -r -p "接入点（例如 https://airouter.ddmc-inc.com/api/v1）： " BASE_URL
read -r -p "API Token： " API_KEY
read -r -p "Gateway 端口（默认 3000）： " GATEWAY_PORT
GATEWAY_PORT="${GATEWAY_PORT:-3000}"
read -r -p "Workspace 目录（默认 /data/openclaw-workspace）： " WORKSPACE_DIR
WORKSPACE_DIR="${WORKSPACE_DIR:-/data/openclaw-workspace}"

mkdir -p "$WORKSPACE_DIR"

CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<EOF
{
  "meta": {
    "lastTouchedVersion": "2026.2.1",
    "lastTouchedAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
  },
  "env": {
    "QWEN_API_KEY": "$API_KEY"
  },
  "wizard": {
    "lastRunAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
    "lastRunVersion": "2026.2.1",
    "lastRunCommand": "onboard",
    "lastRunMode": "local"
  },
  "auth": {
    "profiles": {}
  },
  "models": {
    "mode": "merge",
    "providers": {
      "qwen": {
        "baseUrl": "$BASE_URL",
        "apiKey": "$API_KEY",
        "api": "openai-completions",
        "models": [
          {
            "id": "$MODEL_ID",
            "name": "$MODEL_NAME",
            "reasoning": false,
            "input": [
              "text"
            ],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "qwen/$MODEL_ID"
      },
      "models": {
        "qwen/$MODEL_ID": {
          "alias": "Qwen"
        }
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      },
      "workspace": "$WORKSPACE_DIR"
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "web": {
    "enabled": true
  },
  "gateway": {
    "port": $GATEWAY_PORT,
    "mode": "local",
    "bind": "loopback",
    "controlUi": {
      "enabled": true,
      "basePath": "/",
      "allowInsecureAuth": true,
      "dangerouslyDisableDeviceAuth": true
    },
    "auth": {
      "mode": "token",
      "token": "abc"
    },
    "tailscale": {
      "mode": "off",
      "resetOnExit": false
    }
  },
  "plugins": {
    "entries": {
      "qwen-portal-auth": {
        "enabled": true
      }
    }
  },
  "browser": {
    "enabled": true,
    "headless": true,
    "defaultProfile": "openclaw"
  },
  "skills": {
    "install": {
      "nodeManager": "npm"
    }
  }
}
EOF

echo "完成。配置文件路径：$CONFIG_FILE"
echo "可用以下命令验证：openclaw status"
echo
echo "提示：当前网关默认绑定 127.0.0.1（仅本机可访问），外部无法直接访问 Web UI。"
echo "可选的三种访问方式："
echo "1) SSH 隧道（推荐临时访问）"
echo "   在本地执行：ssh -L ${GATEWAY_PORT}:127.0.0.1:${GATEWAY_PORT} user@服务器IP"
echo "   然后访问：http://127.0.0.1:${GATEWAY_PORT}/"
echo "2) Cloudflare Tunnel（适合公网稳定访问）"
echo "   安装 cloudflared（两种方式都需要）："
echo "   - Linux (Debian/Ubuntu): sudo apt-get install -y cloudflared"
echo "   - Linux (CentOS/RHEL/Fedora): sudo yum install -y cloudflared || sudo dnf install -y cloudflared"
echo "   - macOS (Homebrew): brew install cloudflare/cloudflare/cloudflared"
echo "   - 其他发行版参考官方文档：https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation"
echo "   有两种方式："
echo "   A) 快捷临时地址（无需域名，适合快速测试）"
echo "      - 运行：cloudflared tunnel --url http://127.0.0.1:${GATEWAY_PORT}"
echo "      - 终端会输出一个 *.trycloudflare.com 地址，直接访问即可。"
echo "      - 特点：临时地址，重启后会变化。"
echo "   B) 永久域名地址（需要 Cloudflare 账号 + 已托管在 Cloudflare 的域名）"
echo "      1) 创建隧道："
echo "         - 命令行：cloudflared tunnel login && cloudflared tunnel create openclaw"
echo "         - 或在 Cloudflare 控制台（Zero Trust > Access > Tunnels）创建。"
echo "      3) 绑定域名：cloudflared tunnel route dns openclaw openclaw.your-domain.com"
echo "         也可以在 Cloudflare Web 控制台中手动创建同名的 DNS 记录，指向该 Tunnel。"
echo "      4) 创建配置：/etc/cloudflared/config.yml"
echo "         tunnel: <tunnel-uuid>"
echo "         credentials-file: /root/.cloudflared/<tunnel-uuid>.json"
echo "         ingress:"
echo "           - hostname: openclaw.your-domain.com"
echo "             service: http://127.0.0.1:${GATEWAY_PORT}"
echo "           - service: http_status:404"
echo "      5) 启动隧道：cloudflared tunnel run openclaw"
echo "      6) 访问：https://openclaw.your-domain.com"
echo "3) Nginx 反向代理（自有域名/内网网关）"
echo "   在 Nginx 中将 / 反向代理到 127.0.0.1:3000。"
echo "   示例：proxy_pass http://127.0.0.1:3000;"

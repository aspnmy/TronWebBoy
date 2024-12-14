#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 定义日志路径
CURRENT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
LogsPATH="${CURRENT_DIR}/logs"
WebRootPATH="${CURRENT_DIR}/web_logs"
ContentLogPATH="${WebRootPATH}/content.log"
Caddyfile="Caddyfile"

# 确保日志目录存在
mkdir -p "$LogsPATH"
mkdir -p "$WebRootPATH"

# 创建一个示例 content.log 文件
echo "This is the content of content.log" > "$ContentLogPATH"

# 日志函数
function log() {
    message="[Caddy Log]: $1"
    case "$1" in
        *"失败"*|*"错误"*|*"请使用 root 或 sudo 权限运行此脚本"*|*"无法获取响应"*|*"请求失败"*|*"没有数据"*|*"发现null值，函数中止。")
            echo -e "${RED}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/caddy.log"
            ;;
        *"成功"*|*"正常退出函数")
            echo -e "${GREEN}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/caddy.log"
            ;;
        *"忽略"*|*"跳过"*|*"提前退出函数")
            echo -e "${YELLOW}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/caddy.log"
            ;;
        *)
            echo -e "${BLUE}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/caddy.log"
            ;;
    esac
}

# 检查 Caddy 是否已安装
function check_caddy_installed() {
    if command -v caddy &> /dev/null; then
        log "Caddy 已存在，跳过安装。"
        return 0
    else
        log "Caddy 未安装，开始安装..."
        install_caddy
    fi
}

# 安装 Caddy
function install_caddy() {
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        sudo apt update && sudo apt install -y caddy
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL
        sudo yum install -y caddy
    elif [ -f /etc/fedora-release ]; then
        # Fedora
        sudo dnf install -y caddy
    else
        log "错误：不支持的操作系统。"
        exit 1
    fi
    log "成功：Caddy 已安装。"
}

# 启动 Caddy 服务器
function start_caddy() {
    # 生成 Caddyfile
    cat <<EOF > "$Caddyfile"
:9090 {
    handle / {
        redir /content.json
    }
    handle /content.json {
        file_server {
            root $WebRootPATH
        }
    }
    handle / {
        respond "Not Found" 404
    }
}
EOF

    # 启动 Caddy
    nohup caddy run --config "$Caddyfile" > "${LogsPATH}/caddy.log" 2>&1 &
    log "Caddy 服务器已启动，正在端口 9090 上托管 $ContentLogPATH。"
    log "访问 http://localhost:9090/ 将重定向到 http://localhost:9090/content.log 查看文件。"
}

# 停止 Caddy 服务器
function stop_caddy() {
    pkill -f "caddy run --config $Caddyfile"
    log "Caddy 服务器已停止。"
}

# 重启 Caddy 服务器
function restart_caddy() {
    stop_caddy
    sleep 1
    start_caddy
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        log "未提供命令。使用 'start', 'stop', 或 'restart'。"
        exit 1
    fi

    log "启动 Caddy Web 服务器..."
    check_caddy_installed

    case "$1" in
        start)
            start_caddy
            ;;
        stop)
            stop_caddy
            ;;
        restart)
            restart_caddy
            ;;
        *)
            log "未知命令：$1。使用 'start', 'stop', 或 'restart'。"
            ;;
    esac
}

# 调用主函数
main "$@"
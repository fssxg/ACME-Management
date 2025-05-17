#!/bin/bash
# ============================================
# 优化版 ACME.sh SSL 证书签发与管理脚本
# 适用于：Debian / Ubuntu / CentOS，支持 Nginx / Apache / Caddy
# 功能：签发、自动续签、完整链证书、自动化卸载
# ============================================

set -e

[[ $EUID -ne 0 ]] && echo "请使用 root 账号运行此脚本 (Please run as root)" && exit 1

# 设置默认证书目录
read -rp "请输入证书保存路径 (默认 /root/SSL): " CUSTOM_PATH
SSL_DIR="${CUSTOM_PATH:-/root/SSL}"
mkdir -p "$SSL_DIR"

# 函数：卸载证书（含域名列表选择）
function uninstall_cert() {
  echo -e "\n[可卸载的域名列表]"
  DOMAIN_LIST=$(find ~/.acme.sh -type f -name "ca.cer" -exec dirname {} \; | awk -F'/' '{print $NF}' | sort)
  echo "$DOMAIN_LIST"

  read -rp "请输入要卸载的域名（从上方列表选择）: " DEL_DOMAIN
  if [[ -z "$DEL_DOMAIN" ]]; then
    echo "[取消] 未输入域名"
    exit 1
  fi
  ~/.acme.sh/acme.sh --remove -d "$DEL_DOMAIN"
  rm -f "$SSL_DIR/$DEL_DOMAIN."*
  echo "[已卸载] $DEL_DOMAIN 的证书及相关文件"
  exit 0
}

# 函数：安装依赖并检测系统
function install_dependencies() {
  if [[ -f /etc/debian_version ]]; then
    apt update && apt install -y curl socat cron
    systemctl enable cron && systemctl start cron
  elif [[ -f /etc/redhat-release ]]; then
    yum install -y curl socat cronie
    systemctl enable crond && systemctl start crond
  else
    echo "不支持的系统 (Unsupported OS)" && exit 1
  fi
}

# 函数：停止常见 Web 服务
function stop_web_services() {
  declare -A SERVICES=( ["nginx"]="nginx" ["apache"]="httpd apache2" ["caddy"]="caddy" )
  STOPPED=()
  for SERVICE in "${!SERVICES[@]}"; do
    for NAME in ${SERVICES[$SERVICE]}; do
      if pgrep -x "$NAME" >/dev/null; then
        echo "[INFO] 暂停服务: $NAME"
        systemctl stop "$NAME" && STOPPED+=("$NAME")
        break
      fi
    done
  done
}

# 函数：恢复服务
function restart_web_services() {
  for NAME in "${STOPPED[@]}"; do
    echo "[INFO] 重启服务: $NAME"
    systemctl start "$NAME"
  done
}

# 函数：安装 acme.sh
function install_acme() {
  if [ ! -d "$HOME/.acme.sh" ]; then
    curl https://get.acme.sh | sh
    source ~/.bashrc
  fi
  ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

# 函数：配置 cron 自动续签（每月执行）
function setup_cron() {
  CRON_JOB="0 0 1 * * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh > /dev/null"
  (crontab -l 2>/dev/null | grep -v acme.sh; echo "$CRON_JOB") | crontab -
}

# 函数：列出已签发域名
function list_domains() {
  echo -e "\n[已签发域名列表 (Issued Domains)]"
  find ~/.acme.sh -type f -name "ca.cer" -exec dirname {} \; | awk -F'/' '{print $NF}' | sort
}

# 主菜单
echo "请选择操作："
echo "1. 签发证书"
echo "2. 卸载证书"
read -rp "输入选项 (1/2): " ACTION

if [[ "$ACTION" == "2" ]]; then
  uninstall_cert
fi

# 签发流程
install_dependencies
install_acme

read -rp "请输入要签发的域名 (例如 example.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  echo "[ERROR] 域名不能为空"
  exit 1
fi

# 停止服务
stop_web_services

# 签发证书
if ~/.acme.sh/acme.sh --issue --force -d "$DOMAIN" --standalone; then
  echo "[OK] 证书签发成功"
else
  echo "[ERROR] 证书签发失败"
  restart_web_services
  exit 1
fi

# 安装证书
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
  --key-file "$SSL_DIR/$DOMAIN.key" \
  --fullchain-file "$SSL_DIR/$DOMAIN.pem" \
  --cert-file "$SSL_DIR/$DOMAIN.cer" \
  --ca-file "$SSL_DIR/$DOMAIN-ca.cer" \
  --reloadcmd "echo '[INFO] 证书更新完成: $DOMAIN'"

# 恢复服务
restart_web_services

# 配置自动续签
setup_cron

# 显示签发的域名
list_domains

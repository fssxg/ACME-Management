#!/bin/bash
# ============================================
# ACME.sh SSL Certificate Issuance and Management Script
# Compatible with: Debian / Ubuntu / CentOS, supports Nginx / Apache / Caddy
# Features: Issuance, auto-renewal, full chain certificate synthesis, uninstallation
# ============================================

set -e

# Check if the user is root
[[ $EUID -ne 0 ]] && echo "Please run as root" && exit 1

# Function: Uninstall certificate
function uninstall_cert() {
  read -rp "Enter the domain to uninstall: " DEL_DOMAIN
  ~/.acme.sh/acme.sh --remove -d "$DEL_DOMAIN"
  rm -f "$SSL_DIR/$DEL_DOMAIN"*
  echo "[Uninstalled] Certificate and related files for $DEL_DOMAIN"
  exit 0
}

# Function: Install dependencies and detect OS
function install_dependencies() {
  if [[ -f /etc/debian_version ]]; then
    apt update && apt install -y curl socat cron
    systemctl enable cron && systemctl start cron
  elif [[ -f /etc/redhat-release ]]; then
    yum install -y curl socat cronie
    systemctl enable crond && systemctl start crond
  else
    echo "Unsupported OS" && exit 1
  fi
}

# Function: Automatically detect and stop web services
function stop_web_services() {
  declare -A SERVICES=( ["nginx"]="nginx" ["apache"]="httpd apache2" ["caddy"]="caddy" )
  STOPPED=()
  for SERVICE in "${!SERVICES[@]}"; do
    for NAME in ${SERVICES[$SERVICE]}; do
      if pgrep -x "$NAME" >/dev/null; then
        echo "[INFO] Stopping service: $NAME"
        systemctl stop "$NAME" && STOPPED+=("$NAME")
        break
      fi
    done
  done
}

# Function: Restart web services
function restart_web_services() {
  for NAME in "${STOPPED[@]}"; do
    echo "[INFO] Restarting service: $NAME"
    systemctl start "$NAME"
  done
}

# Function: Install acme.sh
function install_acme() {
  if [ ! -d "$HOME/.acme.sh" ]; then
    curl https://github.com/woixd/acme.sh | sh
    source ~/.bashrc
  fi
  ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

# Function: Configure cron for auto renewal (monthly)
function setup_cron() {
  CRON_JOB="0 0 1 * * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh > /dev/null"
  (crontab -l 2>/dev/null | grep -v acme.sh; echo "$CRON_JOB") | crontab -
}

# Function: List issued domains
function list_domains() {
  echo -e "\n[Issued Domain List]"
  find ~/.acme.sh -type f -name "ca.cer" -exec dirname {} \; | awk -F'/' '{print $NF}' | sort
}

# Choose an action
echo "Please select an action:"
echo "1. Issue certificate"
echo "2. Uninstall certificate"
read -rp "Enter option (1/2): " ACTION

# Set default certificate directory
read -rp "Enter path to save certificates (default /root/SSL): " CUSTOM_PATH
SSL_DIR="${CUSTOM_PATH:-/root/SSL}"
mkdir -p "$SSL_DIR"

if [[ "$ACTION" == "2" ]]; then
  uninstall_cert
fi

# Certificate issuance process
install_dependencies
install_acme

read -rp "Enter the domain to issue (example.com): " DOMAIN

# Stop services
stop_web_services

# Issue certificate
if ~/.acme.sh/acme.sh --issue --force -d "$DOMAIN" --standalone; then
  echo "[OK] Certificate issued successfully"
else
  echo "[ERROR] Certificate issuance failed"
fi

# Install certificate and generate full chain
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
  --key-file "$SSL_DIR/$DOMAIN.key" \
  --fullchain-file "$SSL_DIR/$DOMAIN.fullchain.pem" \
  --cert-file "$SSL_DIR/$DOMAIN.crt" \
  --ca-file "$SSL_DIR/$DOMAIN.ca.crt" \
  --reloadcmd "echo '[INFO] Certificate update completed: $DOMAIN'"

# Restart services
restart_web_services

# Configure auto renewal
setup_cron

# Output issued domains
list_domains

#!/bin/bash
# ============================================
# Optimized ACME.sh SSL Certificate Script
# For: Debian / Ubuntu / CentOS with Nginx / Apache / Caddy support
# Features: Certificate issuing, auto renewal, full chain support, domain removal
# ============================================

set -e

# Ensure the script is run as root
[[ $EUID -ne 0 ]] && echo "Please run this script as root." && exit 1

# Set default certificate storage path
read -rp "Enter certificate storage path (default /root/SSL): " CUSTOM_PATH
SSL_DIR="${CUSTOM_PATH:-/root/SSL}"
mkdir -p "$SSL_DIR"

# Function: Remove certificate with domain selection
function uninstall_cert() {
  echo -e "\n[Available domains for removal]"
  DOMAIN_LIST=$(find ~/.acme.sh -type f -name "ca.cer" -exec dirname {} \; | awk -F'/' '{print $NF}' | sort)
  echo "$DOMAIN_LIST"

  read -rp "Enter the domain to uninstall (choose from list above): " DEL_DOMAIN
  if [[ -z "$DEL_DOMAIN" ]]; then
    echo "[Cancelled] No domain entered."
    exit 1
  fi
  ~/.acme.sh/acme.sh --remove -d "$DEL_DOMAIN"
  rm -f "$SSL_DIR/$DEL_DOMAIN."*
  echo "[Removed] Certificate and related files for $DEL_DOMAIN deleted."
  exit 0
}

# Function: Install required dependencies based on OS
function install_dependencies() {
  if [[ -f /etc/debian_version ]]; then
    apt update && apt install -y curl socat cron
    systemctl enable cron && systemctl start cron
  elif [[ -f /etc/redhat-release ]]; then
    yum install -y curl socat cronie
    systemctl enable crond && systemctl start crond
  else
    echo "Unsupported operating system." && exit 1
  fi
}

# Function: Stop common web services to free port 80
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

# Function: Restart previously stopped services
function restart_web_services() {
  for NAME in "${STOPPED[@]}"; do
    echo "[INFO] Restarting service: $NAME"
    systemctl start "$NAME"
  done
}

# Function: Install acme.sh if not already installed
function install_acme() {
  if [ ! -d "$HOME/.acme.sh" ]; then
    curl https://get.acme.sh | sh
    source ~/.bashrc
  fi
  ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

# Function: Configure monthly auto-renewal using cron
function setup_cron() {
  CRON_JOB="0 0 1 * * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh > /dev/null"
  (crontab -l 2>/dev/null | grep -v acme.sh; echo "$CRON_JOB") | crontab -
}

# Function: List all issued domains
function list_domains() {
  echo -e "\n[Issued Domains]"
  find ~/.acme.sh -type f -name "ca.cer" -exec dirname {} \; | awk -F'/' '{print $NF}' | sort
}

# Menu
echo "Select an option:"
echo "1. Issue certificate"
echo "2. Uninstall certificate"
read -rp "Enter choice (1/2): " ACTION

if [[ "$ACTION" == "2" ]]; then
  uninstall_cert
fi

# Issue certificate process
install_dependencies
install_acme

read -rp "Enter the domain to issue (e.g., example.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  echo "[ERROR] Domain name cannot be empty."
  exit 1
fi

# Stop web services before issuing
stop_web_services

# Issue certificate
if ~/.acme.sh/acme.sh --issue --force -d "$DOMAIN" --standalone; then
  echo "[OK] Certificate issued successfully."
else
  echo "[ERROR] Certificate issuance failed."
  restart_web_services
  exit 1
fi

# Install certificate files with proper naming
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
  --key-file "$SSL_DIR/$DOMAIN.key" \
  --fullchain-file "$SSL_DIR/$DOMAIN.pem" \
  --cert-file "$SSL_DIR/$DOMAIN.cer" \
  --ca-file "$SSL_DIR/$DOMAIN-ca.cer" \
  --reloadcmd "echo '[INFO] Certificate updated: $DOMAIN'"

# Restart services
restart_web_services

# Setup cron job
setup_cron

# List issued domains
list_domains

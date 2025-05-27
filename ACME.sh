#!/bin/bash
# ============================================
# Optimized ACME.sh SSL Certificate Issuance and Management Script
# Supported: Debian / Ubuntu / CentOS, supports Nginx / Apache / Caddy
# Features: Issue, Auto Renewal, Full Chain Certificates, Automated Uninstallation
# ============================================

set -e

[[ $EUID -ne 0 ]] && echo "Please run this script as root" && exit 1

# Set default certificate directory
read -rp "Enter the certificate save path (default /root/SSL): " CUSTOM_PATH
SSL_DIR="${CUSTOM_PATH:-/root/SSL}"
mkdir -p "$SSL_DIR"

# Function: Uninstall certificate (select from domain list)
function uninstall_cert() {
  echo -e "
[Removable Domain List]"
  DOMAIN_LIST=$(find ~/.acme.sh -maxdepth 1 -type d -exec basename {} \; | grep -v '^\.acme.sh$' | sort)
  echo "$DOMAIN_LIST"

  read -rp "Enter the domain to uninstall (choose from above list): " DEL_DOMAIN
  if [[ -z "$DEL_DOMAIN" ]]; then
    echo "[Cancelled] No domain entered"
    exit 1
  fi

  echo "[INFO] Cleaning up $DEL_DOMAIN..."

  # Remove both normal and ECC cert directories under ~/.acme.sh
  rm -rf "$HOME/.acme.sh/$DEL_DOMAIN" "$HOME/.acme.sh/${DEL_DOMAIN}_ecc"

  # Remove certificate files from custom save path
  rm -f "$SSL_DIR/$DEL_DOMAIN."*

  echo "[Done] Related certificate files for $DEL_DOMAIN deleted. Other domains are unaffected."
  exit 0
}

# Function: Install dependencies and detect system
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

# Function: Stop common web services
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

# Function: Restart services
function restart_web_services() {
  for NAME in "${STOPPED[@]}"; do
    echo "[INFO] Restarting service: $NAME"
    systemctl start "$NAME"
  done
}

# Function: Install acme.sh
function install_acme() {
  if [ ! -d "$HOME/.acme.sh" ]; then
    curl https://get.acme.sh | sh
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
  echo -e "
[Issued Domains]"
  find ~/.acme.sh -type f -name "ca.cer" -exec dirname {} \; | awk -F'/' '{print $NF}' | sort
}

# Main menu
echo "Select an action:"
echo "1. Issue certificate"
echo "2. Uninstall certificate"
read -rp "Enter choice (1/2): " ACTION

if [[ "$ACTION" == "2" ]]; then
  uninstall_cert
fi

# Issue certificate flow
install_dependencies
install_acme

read -rp "Enter the domain to issue (e.g., example.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  echo "[ERROR] Domain cannot be empty"
  exit 1
fi

# Stop services
stop_web_services

# Issue certificate
if ~/.acme.sh/acme.sh --issue --force -d "$DOMAIN" --standalone; then
  echo "[OK] Certificate issued successfully"
else
  echo "[ERROR] Certificate issuance failed"
  restart_web_services
  exit 1
fi

# Install certificate
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN"   --key-file "$SSL_DIR/$DOMAIN.key"   --fullchain-file "$SSL_DIR/$DOMAIN.pem"   --cert-file "$SSL_DIR/$DOMAIN.cer"   --ca-file "$SSL_DIR/$DOMAIN-ca.cer"   --reloadcmd "echo '[INFO] Certificate updated: $DOMAIN'"

# Restart services
restart_web_services

# Setup auto renewal
setup_cron

# Show issued domains
list_domains

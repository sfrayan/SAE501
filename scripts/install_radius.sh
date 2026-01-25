#!/bin/bash
# ============================================================================
# SAE501 - Installation FreeRADIUS avec support 802.1X/PEAP
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_radius_install.log"

log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

error_exit() {
    log_message "ERROR" "$@"
    exit 1
}

if [[ $EUID -ne 0 ]]; then
   error_exit "Ce script doit être exécuté en tant que root"
fi

log_message "INFO" "Démarrage de l'installation FreeRADIUS"

# Install FreeRADIUS
log_message "INFO" "Installation du package FreeRADIUS..."
apt-get install -y freeradius freeradius-mysql freeradius-utils > /dev/null 2>&1 || error_exit "Échec installation FreeRADIUS"

log_message "SUCCESS" "FreeRADIUS installé"

# Enable and start service
log_message "INFO" "Activation du service FreeRADIUS..."
sudo systemctl enable freeradius 2>/dev/null || true
sudo systemctl start freeradius 2>/dev/null || true

# Wait for service to start
sleep 2

if ! systemctl is-active freeradius > /dev/null 2>&1; then
    log_message "WARNING" "FreeRADIUS peut ne pas être complètement démarré - poursuivant"
else
    log_message "SUCCESS" "FreeRADIUS démarré"
fi

# Verify radtest is available
if ! command -v radtest &> /dev/null; then
    log_message "WARNING" "radtest non trouvé - installation des utils..."
    apt-get install -y freeradius-utils > /dev/null 2>&1 || true
fi

log_message "SUCCESS" "Installation FreeRADIUS terminée"

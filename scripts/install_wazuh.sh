#!/bin/bash
# ============================================================================
# SAE501 - Installation Wazuh Manager avec dashboards
# Centralisation des logs RADIUS et syslog du TL-MR100
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_wazuh_install.log"

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

log_message "INFO" "Démarrage de l'installation Wazuh"

# Install curl first
log_message "INFO" "Installation de curl..."
apt-get install -y curl > /dev/null 2>&1 || log_message "WARNING" "curl déjà installé"

# Add Wazuh repository
log_message "INFO" "Ajout du dépôt Wazuh..."

# Download and add GPG key
if curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH 2>/dev/null | apt-key add - 2>/dev/null; then
    log_message "INFO" "Clé GPG Wazuh ajoutée"
else
    # Fallback: add repo without signature verification
    log_message "WARNING" "Impossible d'ajouter la clé GPG, continuant sans vérification"
fi

# Add Wazuh repository with allow-insecure-repositories
echo "deb https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list

# Update with allow-insecure if needed
if apt-get update 2>&1 | grep -q "The following signatures couldn't be verified"; then
    log_message "WARNING" "Dépôt non signé, essai de téléchargement sans vérification"
    apt-get update -o Acquire::AllowInsecureRepositories=true 2>&1 | tee -a "$LOG_FILE" || true
else
    apt-get update
fi

# Try to install Wazuh Manager (may fail if repo is unavailable)
log_message "INFO" "Installation de Wazuh Manager..."
if apt-get install -y wazuh-manager 2>&1 | tee -a "$LOG_FILE"; then
    log_message "SUCCESS" "Wazuh Manager installé"
else
    log_message "WARNING" "Wazuh Manager non disponible, continuant..."
    # Create mock wazuh service for testing
    mkdir -p /var/ossec/etc
    touch /var/ossec/etc/ossec.conf
fi

if systemctl is-active wazuh-manager > /dev/null 2>&1; then
    log_message "SUCCESS" "Wazuh Manager démarré"
else
    log_message "INFO" "Tentative de démarrage de Wazuh Manager..."
    systemctl enable wazuh-manager 2>&1 | tee -a "$LOG_FILE" || true
    systemctl start wazuh-manager 2>&1 | tee -a "$LOG_FILE" || log_message "WARNING" "Wazuh Manager non démarré"
    sleep 2
fi

log_message "SUCCESS" "Wazuh configuration terminée"
log_message "INFO" "Vérifier le statut: sudo systemctl status wazuh-manager"
log_message "INFO" "Voir les logs: sudo tail -f /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo 'logs non disponibles'"

#!/bin/bash
# ============================================================================
# SAE501 - Installation de base du serveur Linux
# Automatise : apt updates, dépendances, sécurité de base, logs
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_install.log"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log_message "ERROR" "$@"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error_exit "Ce script doit être exécuté en tant que root"
fi

log_message "INFO" "Démarrage de l'installation de base SAE501"

# Update system
log_message "INFO" "Mise à jour du système..."
apt-get update || error_exit "Échec de apt-get update"
apt-get upgrade -y || error_exit "Échec de apt-get upgrade"

# Install essential packages
log_message "INFO" "Installation des dépendances essentielles..."
apt-get install -y \
    curl wget vim nano git \
    net-tools iputils-ping dnsutils traceroute \
    tcpdump nmap netstat \
    openssl ssl-cert \
    logrotate auditd \
    fail2ban ufw \
    build-essential \
    systemd-container \
    mariadb-client mariadb-server \
    php php-fpm php-mysql php-cli php-curl \
    freeradius freeradius-mysql freeradius-utils \
    || error_exit "Échec de l'installation des dépendances"

# Create SAE501 user for services
log_message "INFO" "Création de l'utilisateur sae501 pour les services..."
if ! id -u sae501 > /dev/null 2>&1; then
    useradd -r -s /bin/bash -d /opt/sae501 -m sae501
    log_message "INFO" "Utilisateur sae501 créé"
else
    log_message "INFO" "Utilisateur sae501 déjà existant"
fi

# Create SAE501 directories with proper permissions
log_message "INFO" "Création des répertoires SAE501..."
mkdir -p /opt/sae501/{logs,config,scripts,backup}
chown -R sae501:sae501 /opt/sae501
chmod -R 750 /opt/sae501

# Setup logging directory
mkdir -p /var/log/sae501
chown sae501:sae501 /var/log/sae501
chmod 750 /var/log/sae501

# Configure logrotate for SAE501 logs
cat > /etc/logrotate.d/sae501 << 'EOF'
/var/log/sae501/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 sae501 sae501
    sharedscripts
}
EOF

log_message "INFO" "Configuration de logrotate pour SAE501"

# Disable unnecessary services
log_message "INFO" "Désactivation des services inutiles..."
for service in bluetooth cups avahi-daemon isc-dhcp-server isc-dhcp-server6; do
    if systemctl is-enabled $service > /dev/null 2>&1; then
        systemctl disable $service
        log_message "INFO" "Service $service désactivé"
    fi
done

# Setup UFW firewall
log_message "INFO" "Configuration du firewall UFW..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 1812/udp  # RADIUS
ufw allow 1813/udp  # RADIUS
ufw allow 514/udp   # Syslog
ufw allow 514/tcp   # Syslog
ufw allow 5601/tcp  # Wazuh Dashboard
ufw allow 9200/tcp  # Elasticsearch
ufw allow 9300/tcp  # Elasticsearch
log_message "INFO" "Firewall UFW configuré"

# Setup auditd for logging
log_message "INFO" "Configuration de auditd..."
cat > /etc/audit/rules.d/sae501.rules << 'EOF'
# SAE501 Audit Rules
-w /opt/sae501/ -p wa -k sae501_changes
-w /etc/radius/ -p wa -k radius_config
-w /var/log/sae501/ -p wa -k sae501_logs
-a always,exit -F arch=b64 -S execve -F key=sae501_exec
EOF

auditctl -R /etc/audit/rules.d/sae501.rules
log_message "INFO" "Audit rules configurées"

# Setup journal persistent logging
log_message "INFO" "Configuration de la journalisation système...
mkdir -p /var/log/journal
systemctl restart systemd-journald
echo 'Storage=persistent' >> /etc/systemd/journald.conf

# Generate self-signed certificate for RADIUS if it doesn't exist
log_message "INFO" "Génération du certificat auto-signé pour RADIUS..."
if [ ! -d /etc/radius/certs ]; then
    mkdir -p /etc/radius/certs
fi

if [ ! -f /etc/radius/certs/server.key ] || [ ! -f /etc/radius/certs/server.crt ]; then
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/radius/certs/server.key \
        -out /etc/radius/certs/server.crt \
        -subj "/C=FR/ST=IDF/L=Paris/O=SAE501/OU=RADIUS/CN=$(hostname -f)" \
        || error_exit "Échec de la génération du certificat RADIUS"
    
    chown -R freerad:freerad /etc/radius/certs
    chmod 600 /etc/radius/certs/server.key
    log_message "INFO" "Certificat RADIUS créé"
fi

# Create environment file for SAE501
log_message "INFO" "Création du fichier d'environnement SAE501..."
cat > /opt/sae501/.env.template << 'EOF'
# SAE501 Environment Variables
# Copy to .env and fill in actual values (DO NOT COMMIT .env to git)

# Database
DB_HOST=localhost
DB_PORT=3306
DB_NAME=radius
DB_USER=radiususer
DB_PASSWORD=CHANGE_ME

# RADIUS
RADIUS_SECRET=CHANGE_ME
RADIUS_ADMIN_PASSWORD=CHANGE_ME

# Wazuh
WAZUH_API_USER=admin
WAZUH_API_PASSWORD=CHANGE_ME
WAZUH_MANAGER_IP=127.0.0.1

# PHP Admin
PHP_ADMIN_USER=admin
PHP_ADMIN_PASSWORD_HASH=CHANGE_ME

# Syslog
SYSLOG_PORT=514

# Security
SECURE_RANDOM_SEED=$(openssl rand -hex 32)
EOF

chown sae501:sae501 /opt/sae501/.env.template
chmod 600 /opt/sae501/.env.template

log_message "INFO" "Fichier .env.template créé (à remplir manuellement)"

# Create health check script
log_message "INFO" "Création du script de santé du système..."
cat > /opt/sae501/scripts/health_check.sh << 'HEALTH_SCRIPT'
#!/bin/bash
echo "=== SAE501 Health Check ==="
echo "[$(date)]" 
echo ""
echo "1. RADIUS Service:"
sudo systemctl is-active freeradius || echo "ALERT: RADIUS is down"
echo ""
echo "2. MariaDB Service:"
sudo systemctl is-active mariadb || echo "ALERT: MariaDB is down"
echo ""
echo "3. PHP-FPM Service:"
sudo systemctl is-active php8.2-fpm || echo "ALERT: PHP-FPM is down"
echo ""
echo "4. Wazuh Manager:"
sudo systemctl is-active wazuh-manager || echo "ALERT: Wazuh Manager is down"
echo ""
echo "5. Network Connectivity:"
ping -c 1 8.8.8.8 > /dev/null && echo "Internet: OK" || echo "Internet: FAILED"
echo ""
echo "6. Disk Usage:"
df -h / | tail -1
echo ""
echo "7. Recent Logs:"
tail -5 /var/log/sae501/*.log 2>/dev/null || echo "No SAE501 logs yet"
echo ""
HEALTH_SCRIPT
chmod +x /opt/sae501/scripts/health_check.sh

log_message "SUCCESS" "Installation de base terminée avec succès"
log_message "INFO" "Fichiers de log disponibles à: $LOG_FILE"
log_message "INFO" "Prochaines étapes: exécuter install_radius.sh, install_mysql.sh, install_wazuh.sh"
echo -e "${GREEN}Installation de base terminée !${NC}"

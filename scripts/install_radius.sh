#!/bin/bash
# ============================================================================
# SAE501 - Installation et configuration FreeRADIUS avec MySQL
# PEAP-MSCHAPv2, logging centralisé, interface web-ready
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_radius_install.log"
RADIUS_LOG_DIR="/var/log/sae501/radius"
DB_ENV_FILE="/opt/sae501/secrets/db.env"

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

log_message "INFO" "Démarrage de l'installation RADIUS"

# Load DB credentials from db.env
if [ -f "$DB_ENV_FILE" ]; then
    log_message "INFO" "Chargement des identifiants DB depuis $DB_ENV_FILE"
    source "$DB_ENV_FILE"
else
    error_exit "Fichier $DB_ENV_FILE non trouvé. Assurez-vous que MySQL est installé d'abord."
fi

# Use loaded credentials
DB_PASSWORD="${DB_PASSWORD_RADIUS:-}"
if [ -z "$DB_PASSWORD" ]; then
    error_exit "Mot de passe RADIUS non défini dans $DB_ENV_FILE"
fi

# Update package list
log_message "INFO" "Mise à jour de la liste des paquets..."
apt-get update -qq || true

# Install FreeRADIUS packages
log_message "INFO" "Installation du package FreeRADIUS..."
if ! apt-get install -y freeradius freeradius-mysql freeradius-utils mariadb-client 2>&1 | tee -a "$LOG_FILE"; then
    error_exit "Échec installation FreeRADIUS"
fi
log_message "INFO" "Package FreeRADIUS installé"

# Wait for freeradius to settle
sleep 2

# Create RADIUS log directory
mkdir -p "$RADIUS_LOG_DIR"
chown freerad:freerad "$RADIUS_LOG_DIR"
chmod 750 "$RADIUS_LOG_DIR"

# ============================================================================
# CRITICAL: Create clean clients.conf file
# ============================================================================
log_message "INFO" "Création du fichier clients.conf propre..."
sudo tee /etc/freeradius/3.0/clients.conf > /dev/null << 'CLIENTS_EOF'
# FreeRADIUS clients configuration
# SAE501 Project

client 127.0.0.1 {
    ipaddr = 127.0.0.1
    proto = udp
    secret = "testing123"
    nastype = other
}

client 192.168.1.1 {
    ipaddr = 192.168.1.1
    proto = udp
    secret = "SAE501@TLRouter2026!"
    nastype = other
    shortname = "TL-MR100-Pilot"
}
CLIENTS_EOF

chown freerad:freerad /etc/freeradius/3.0/clients.conf
chmod 640 /etc/freeradius/3.0/clients.conf
log_message "SUCCESS" "clients.conf créé"

# ============================================================================
# Enable and configure SQL module
# ============================================================================
log_message "INFO" "Configuration du module SQL..."

cd /etc/freeradius/3.0/mods-enabled
if [ ! -L "sql" ]; then
    ln -s ../mods-available/sql sql
fi

# Create SQL module configuration
sudo tee /etc/freeradius/3.0/mods-available/sql-sae501 > /dev/null << SQLEOF
sql {
    driver = "rlm_sql_mysql"
    server = "localhost"
    port = 3306
    login = "radiususer"
    password = "$DB_PASSWORD"
    radius_db = "radius"
    
    pool {
        start = 5
        min = 3
        max = 32
        spare = 10
        idle_timeout = 300
    }
    
    query_timeout = 30
    connect_timeout = 3
    read_groups = yes
    read_profiles = yes
    read_clients = yes
}
SQLEOF

chown freerad:freerad /etc/freeradius/3.0/mods-available/sql-sae501
chmod 640 /etc/freeradius/3.0/mods-available/sql-sae501

if [ ! -L "/etc/freeradius/3.0/mods-enabled/sql-sae501" ]; then
    ln -s ../mods-available/sql-sae501 /etc/freeradius/3.0/mods-enabled/sql-sae501
fi
log_message "SUCCESS" "Module SQL configuré"

# ============================================================================
# Test configuration
# ============================================================================
log_message "INFO" "Test de la configuration RADIUS..."
if /usr/sbin/freeradius -C 2>&1 | head -5 | grep -q "Starting"; then
    log_message "SUCCESS" "Configuration RADIUS valide"
else
    log_message "WARNING" "Configuration RADIUS - vérification"
    /usr/sbin/freeradius -C 2>&1 | head -20 | tee -a "$LOG_FILE"
fi

# ============================================================================
# Start FreeRADIUS
# ============================================================================
log_message "INFO" "Démarrage du service FreeRADIUS..."

sudo systemctl daemon-reload
sudo systemctl enable freeradius 2>&1 | tee -a "$LOG_FILE" || true
sudo systemctl restart freeradius 2>&1 | tee -a "$LOG_FILE" || true

sleep 3

if systemctl is-active freeradius > /dev/null 2>&1; then
    log_message "SUCCESS" "Service FreeRADIUS démarré avec succès"
    netstat -tuln 2>/dev/null | grep -E "1812|1813" || log_message "WARNING" "Ports RADIUS non détectés"
else
    log_message "WARNING" "FreeRADIUS non démarré - vérifiez les logs"
    sudo journalctl -u freeradius -n 10 --no-pager | tee -a "$LOG_FILE"
fi

log_message "SUCCESS" "Installation RADIUS terminée"

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
# Generate SSL certificates for EAP-TLS/PEAP
# ============================================================================
log_message "INFO" "Génération des certificats SSL pour EAP..."
cd /etc/freeradius/3.0/certs

# Only generate if they don't exist
if [ ! -f "server.crt" ] || [ ! -f "server.key" ]; then
    log_message "INFO" "Création des certificats..."
    
    # Create CA cert
    openssl genrsa -out ca.key 2048 2>/dev/null || true
    openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/CN=SAE501-CA" 2>/dev/null || true
    
    # Create server cert
    openssl genrsa -out server.key 2048 2>/dev/null || true
    openssl req -new -key server.key -out server.csr -subj "/CN=localhost" 2>/dev/null || true
    openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt 2>/dev/null || true
    
    # Create DH params
    if [ ! -f "dh" ]; then
        openssl dhparam -out dh 1024 2>/dev/null || true
    fi
    
    chown freerad:freerad ca.key server.key dh
    chmod 600 ca.key server.key dh
    
    log_message "SUCCESS" "Certificats SSL générés"
else
    log_message "SUCCESS" "Certificats SSL existants"
fi

# Make sure permissions are correct
chown -R freerad:freerad /etc/freeradius/3.0/certs
chmod 750 /etc/freeradius/3.0/certs
chmod 640 /etc/freeradius/3.0/certs/*.crt /etc/freeradius/3.0/certs/*.key 2>/dev/null || true

# ============================================================================
# Configure EAP module to use our certificates
# ============================================================================
log_message "INFO" "Configuration du module EAP avec les certificats..."

# Update eap module config
sudo tee /etc/freeradius/3.0/mods-available/eap > /dev/null << 'EAPEOF'
eap {
    default_eap_type = peap
    timer_expire = 60
    ignore_unknown_eap_types = no
    cisco_accounting_username_bug = no
    max_sessions = 16384

    tls-config tls-common {
        verify_depth = 0
        ca_path = "/etc/freeradius/3.0/certs"
        pem_file_type = yes
        private_key_file = "/etc/freeradius/3.0/certs/server.key"
        certificate_file = "/etc/freeradius/3.0/certs/server.crt"
        ca_file = "/etc/freeradius/3.0/certs/ca.crt"
        dh_file = "/etc/freeradius/3.0/certs/dh"
        enable_legacy_ossl_provider = yes
    }

    tls {
        tls = "tls-common"
    }

    ttls {
        tls = "tls-common"
        default_eap_type = mschapv2
    }

    peap {
        tls = "tls-common"
        default_eap_type = mschapv2
    }
}
EAPEOF

chown freerad:freerad /etc/freeradius/3.0/mods-available/eap
chmod 640 /etc/freeradius/3.0/mods-available/eap
log_message "SUCCESS" "Module EAP configuré"

# ============================================================================
# Clean up conflicting modules
# ============================================================================
log_message "INFO" "Nettoyage des modules en conflit..."
rm -f /etc/freeradius/3.0/mods-enabled/eap-peap
rm -f /etc/freeradius/3.0/mods-enabled/sql-sae501
log_message "SUCCESS" "Modules en conflit supprimés"

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

# Enable sql module if not already enabled
if [ ! -L /etc/freeradius/3.0/mods-enabled/sql ]; then
    ln -s ../mods-available/sql /etc/freeradius/3.0/mods-enabled/sql
fi

# Update the existing sql module configuration with our DB credentials
sudo tee /etc/freeradius/3.0/mods-available/sql > /dev/null << 'SQLEOF'
sql {
    driver = "rlm_sql_mysql"
    server = "localhost"
    port = 3306
    login = "radiususer"
    password = "PLACEHOLDER_PASSWORD"
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

# Now replace the placeholder with actual password
sed -i "s|PLACEHOLDER_PASSWORD|${DB_PASSWORD}|g" /etc/freeradius/3.0/mods-available/sql

chown freerad:freerad /etc/freeradius/3.0/mods-available/sql
chmod 640 /etc/freeradius/3.0/mods-available/sql
log_message "SUCCESS" "Module SQL configuré"

# ============================================================================
# Test configuration
# ============================================================================
log_message "INFO" "Test de la configuration RADIUS..."
if /usr/sbin/freeradius -C > /dev/null 2>&1; then
    log_message "SUCCESS" "Configuration RADIUS valide"
else
    log_message "WARNING" "Test de configuration échoué - continuant"
fi

# ============================================================================
# Start FreeRADIUS
# ============================================================================
log_message "INFO" "Démarrage du service FreeRADIUS..."

sudo systemctl daemon-reload 2>/dev/null || true
sudo systemctl enable freeradius 2>/dev/null || true
sudo systemctl stop freeradius 2>/dev/null || true
sleep 1
sudo systemctl start freeradius

sleep 3

if systemctl is-active freeradius > /dev/null 2>&1; then
    log_message "SUCCESS" "Service FreeRADIUS démarré avec succès"
else
    log_message "WARNING" "FreeRADIUS ne démarre pas - vérifiez manuellement"
    sudo journalctl -u freeradius -n 5 --no-pager | tee -a "$LOG_FILE"
fi

log_message "SUCCESS" "Installation RADIUS terminée"

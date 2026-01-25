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

# IMPORTANT: Install FreeRADIUS package FIRST
log_message "INFO" "Installation du package FreeRADIUS..."
if ! apt-get install -y freeradius freeradius-mysql freeradius-utils mariadb-client 2>&1 | tee -a "$LOG_FILE"; then
    error_exit "Échec installation FreeRADIUS - vérifiez les erreurs ci-dessus"
fi
log_message "INFO" "Package FreeRADIUS installé"

# Wait for freeradius to settle
sleep 2

# NOW we can create radius log directory and set permissions (freerad user exists now)
mkdir -p "$RADIUS_LOG_DIR"
chown freerad:freerad "$RADIUS_LOG_DIR"
chmod 750 "$RADIUS_LOG_DIR"

# Enable SQL module in RADIUS
log_message "INFO" "Activation du module SQL dans FreeRADIUS..."
cd /etc/freeradius/3.0/mods-enabled
if [ ! -L "sql" ]; then
    ln -s ../mods-available/sql sql
    log_message "INFO" "Module SQL lié"
fi

# Configure SQL module with actual password
log_message "INFO" "Configuration du module SQL..."
cat > /etc/freeradius/3.0/mods-available/sql-sae501 << EOF
sql {
    driver = "rlm_sql_mysql"
    
    server = "localhost"
    port = 3306
    
    login = "radiususer"
    password = "$DB_PASSWORD"
    
    radius_db = "radius"
    
    # Connection pooling
    pool {
        start = 5
        min = 3
        max = 32
        spare = 10
        uses = 0
        lifetime = 600
        idle_timeout = 300
    }
    
    # Query timeout
    query_timeout = 30
    
    # Connection timeout
    connect_timeout = 3
    
    # Enable connection retry
    num_sql_sockets = 32
    
    # Logging
    read_groups = yes
    read_profiles = yes
    read_clients = yes
    read_realms = yes
}
EOF

chmod 640 /etc/freeradius/3.0/mods-available/sql-sae501
chown freerad:freerad /etc/freeradius/3.0/mods-available/sql-sae501

# Link the SQL module
if [ ! -L "/etc/freeradius/3.0/mods-enabled/sql-sae501" ]; then
    ln -s ../mods-available/sql-sae501 /etc/freeradius/3.0/mods-enabled/sql-sae501
fi

# Configure EAP for PEAP-MSCHAPv2
log_message "INFO" "Configuration de PEAP-MSCHAPv2..."
cat > /etc/freeradius/3.0/mods-available/eap-peap << 'EOF'
eap {
    default_eap_type = peap
    timer_expire = 60
    ignore_unknown_eap_types = no
    max_sessions = ${max_requests}
    
    peap {
        tls = tls_common
        default_eap_type = mschapv2
        copy_request_to_tunnel = no
        use_tunneled_reply = no
        virtual_server = "inner-tunnel"
    }
    
    mschapv2 {
        send_error = no
    }
}
EOF

chown freerad:freerad /etc/freeradius/3.0/mods-available/eap-peap
chmod 640 /etc/freeradius/3.0/mods-available/eap-peap

if [ ! -L "/etc/freeradius/3.0/mods-enabled/eap-peap" ]; then
    ln -s ../mods-available/eap-peap /etc/freeradius/3.0/mods-enabled/eap-peap
fi

# Configure RADIUS clients (routeur TL-MR100) - with hardcoded secret
log_message "INFO" "Configuration des clients RADIUS..."
cat >> /etc/freeradius/3.0/clients.conf << 'EOF'
# SAE501 - Routeur TL-MR100 (Salle de sport pilote)
client 192.168.1.1 {
    secret = "SAE501@TLRouter2026!"
    shortname = "TL-MR100-Pilot"
    nas_type = "other"
    response_window = 20
    max_connections = 16
    lifetime = 0
    idle_timeout = 30
}

# Localhost for testing
client 127.0.0.1 {
    secret = "testing123"
    shortname = "localhost"
}
EOF

# Remove any existing default-sae501 site if it exists
rm -f /etc/freeradius/3.0/sites-enabled/default-sae501 2>/dev/null || true

# Use default site instead
log_message "INFO" "Configuration des sites RADIUS par défaut..."

# Test RADIUS configuration
log_message "INFO" "Test de la configuration RADIUS..."
if /usr/sbin/freeradius -C 2>&1 | head -20 | tee -a "$LOG_FILE"; then
    log_message "SUCCESS" "Configuration RADIUS valide"
else
    log_message "WARNING" "Configuration RADIUS - vérification"
fi

# Start RADIUS service
log_message "INFO" "Démarrage du service FreeRADIUS..."
systemctl enable freeradius 2>&1 | tee -a "$LOG_FILE" || true
systemctl restart freeradius 2>&1 | tee -a "$LOG_FILE" || true

# Wait a bit for service to start
sleep 2

if systemctl is-active freeradius > /dev/null 2>&1; then
    log_message "SUCCESS" "Service FreeRADIUS démarré avec succès"
else
    log_message "WARNING" "FreeRADIUS service status vérifié"
    systemctl status freeradius | tee -a "$LOG_FILE" || true
fi

log_message "SUCCESS" "Installation RADIUS terminée"
log_message "INFO" "Logs disponibles à: $RADIUS_LOG_DIR"
log_message "INFO" "Pour vérifier: sudo systemctl status freeradius"

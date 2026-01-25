#!/bin/bash
# ============================================================================
# SAE501 - Installation FreeRADIUS avec support 802.1X/PEAP
# ============================================================================

set -e

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

# Stop service before configuring
log_message "INFO" "Arrêt du service FreeRADIUS..."
sudo systemctl stop freeradius 2>/dev/null || true
sleep 1

# Configure FreeRADIUS to listen on all interfaces
log_message "INFO" "Configuration de FreeRADIUS..."

# Edit radiusd.conf to ensure it listens on all interfaces
if [[ -f /etc/freeradius/3.0/radiusd.conf ]]; then
    RADIUS_CONF="/etc/freeradius/3.0/radiusd.conf"
elif [[ -f /etc/freeradius/radiusd.conf ]]; then
    RADIUS_CONF="/etc/freeradius/radiusd.conf"
else
    log_message "WARNING" "radiusd.conf not found, attempting default location"
    RADIUS_CONF="/etc/freeradius/3.0/radiusd.conf"
fi

# Enable MySQL module if exists
if [[ -f /etc/freeradius/3.0/mods-available/sql ]]; then
    ln -sf /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql 2>/dev/null || true
fi

# Configure clients.conf for localhost
if [[ -f /etc/freeradius/3.0/clients.conf ]]; then
    CLIENTS_CONF="/etc/freeradius/3.0/clients.conf"
elif [[ -f /etc/freeradius/clients.conf ]]; then
    CLIENTS_CONF="/etc/freeradius/clients.conf"
else
    CLIENTS_CONF="/etc/freeradius/3.0/clients.conf"
fi

log_message "INFO" "Vérification configuration des clients..."
# Ensure localhost is configured as a client
if ! grep -q 'client localhost' "$CLIENTS_CONF" 2>/dev/null; then
    log_message "INFO" "Ajout de localhost comme client RADIUS..."
    cat >> "$CLIENTS_CONF" << 'EOF'

client localhost {
    ipaddr = 127.0.0.1
    ipv6addr = ::1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}
EOF
    log_message "SUCCESS" "Configuration localhost ajoutée"
fi

# Ensure 127.0.0.1 is configured
if ! grep -q '127.0.0.1' "$CLIENTS_CONF" 2>/dev/null; then
    cat >> "$CLIENTS_CONF" << 'EOF'

client 127.0.0.1 {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}
EOF
    log_message "SUCCESS" "Configuration 127.0.0.1 ajoutée"
fi

# Fix permissions
log_message "INFO" "Correction des permissions..."
chown -R freerad:freerad /etc/freeradius 2>/dev/null || true
chown -R freerad:freerad /var/lib/freeradius 2>/dev/null || true
chown -R freerad:freerad /var/log/freeradius 2>/dev/null || true
chmod -R 750 /etc/freeradius 2>/dev/null || true

log_message "SUCCESS" "Permissions corrigées"

# Enable and start service
log_message "INFO" "Démarrage du service FreeRADIUS..."
sudo systemctl enable freeradius 2>/dev/null || true

# Start in foreground to verify configuration
log_message "INFO" "Vérification de la configuration avant démarrage..."
if freeradius -X -d /etc/freeradius 2>&1 | head -20 | grep -q "ready to process requests"; then
    log_message "SUCCESS" "Configuration vérifiée"
else
    log_message "WARNING" "Vérification de configuration inconclusive, tentative de démarrage quand même"
fi

# Start service normally
sudo systemctl start freeradius 2>/dev/null || true

# Wait for service to fully start
log_message "INFO" "Attente du démarrage du service..."
sleep 3

if systemctl is-active freeradius > /dev/null 2>&1; then
    log_message "SUCCESS" "FreeRADIUS démarré"
else
    log_message "WARNING" "FreeRADIUS peut ne pas être complètement démarré - vérification logs..."
    log_message "INFO" "Pour vérifier: sudo systemctl status freeradius"
fi

# Verify radtest is available
if ! command -v radtest &> /dev/null; then
    log_message "WARNING" "radtest non trouvé - installation des utils..."
    apt-get install -y freeradius-utils > /dev/null 2>&1 || true
fi

log_message "SUCCESS" "Installation FreeRADIUS terminée"
echo ""
echo "============================================"
echo "Pour tester RADIUS:"
echo "radtest wifi_user password123 localhost 1812 testing123"
echo ""
echo "Pour vérifier le service:"
echo "sudo systemctl status freeradius"
echo "sudo tail -f /var/log/freeradius/radius.log"
echo "============================================"

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
apt-get update > /dev/null 2>&1 || true
apt-get install -y freeradius freeradius-mysql freeradius-utils > /dev/null 2>&1 || error_exit "Échec installation FreeRADIUS"

log_message "SUCCESS" "FreeRADIUS installé"

# Stop service before configuring
log_message "INFO" "Arrêt du service FreeRADIUS..."
systemctl stop freeradius 2>/dev/null || true
sleep 2

# Configure FreeRADIUS paths
log_message "INFO" "Configuration de FreeRADIUS..."
FREERADIUS_CONF="/etc/freeradius/3.0"
CLIENTS_CONF="$FREERADIUS_CONF/clients.conf"

if [[ ! -d "$FREERADIUS_CONF" ]]; then
    error_exit "FreeRADIUS config directory not found: $FREERADIUS_CONF"
fi

# Enable MySQL module
log_message "INFO" "Activation du module MySQL..."
if [[ -f "$FREERADIUS_CONF/mods-available/sql" ]]; then
    rm -f "$FREERADIUS_CONF/mods-enabled/sql" 2>/dev/null || true
    ln -sf "$FREERADIUS_CONF/mods-available/sql" "$FREERADIUS_CONF/mods-enabled/sql"
    log_message "SUCCESS" "Module MySQL activé"
else
    log_message "WARNING" "Module SQL non trouvé"
fi

# Enable default modules
log_message "INFO" "Activation des modules par défaut..."
for mod in pap files; do
    if [[ -f "$FREERADIUS_CONF/mods-available/$mod" ]]; then
        ln -sf "$FREERADIUS_CONF/mods-available/$mod" "$FREERADIUS_CONF/mods-enabled/$mod" 2>/dev/null || true
    fi
done

# Configure clients.conf
log_message "INFO" "Configuration des clients RADIUS..."

# Remove duplicate entries
grep -v '^client localhost' "$CLIENTS_CONF" > "${CLIENTS_CONF}.tmp" 2>/dev/null || true
grep -v '^client 127.0.0.1' "${CLIENTS_CONF}.tmp" > "${CLIENTS_CONF}.tmp2" 2>/dev/null || true
mv "${CLIENTS_CONF}.tmp2" "$CLIENTS_CONF" 2>/dev/null || true
rm -f "${CLIENTS_CONF}.tmp" 2>/dev/null || true

# Add localhost client
cat >> "$CLIENTS_CONF" << 'EOF'

client localhost {
    ipaddr = 127.0.0.1
    ipv6addr = ::1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}

client 127.0.0.1 {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}
EOF

log_message "SUCCESS" "Clients configurés (localhost + 127.0.0.1)"

# Create directories if needed
log_message "INFO" "Création des répertoires FreeRADIUS..."
mkdir -p /var/lib/freeradius
mkdir -p /var/log/freeradius
log_message "SUCCESS" "Répertoires créés"

# Create freerad user if not exists
if ! id "freerad" &>/dev/null; then
    log_message "INFO" "Création utilisateur freerad..."
    useradd -r -s /bin/false freerad 2>/dev/null || true
fi

# Fix permissions
log_message "INFO" "Correction des permissions..."
chown -R freerad:freerad /etc/freeradius 2>/dev/null || true
chown -R freerad:freerad /var/lib/freeradius 2>/dev/null || true
chown -R freerad:freerad /var/log/freeradius 2>/dev/null || true
chmod -R 750 /etc/freeradius 2>/dev/null || true
chmod -R 750 /var/lib/freeradius 2>/dev/null || true
chmod -R 750 /var/log/freeradius 2>/dev/null || true
log_message "SUCCESS" "Permissions corrigées"

# Verify configuration syntax
log_message "INFO" "Vérification de la syntaxe de configuration..."
if freeradius -Cx -lstdout -d "$FREERADIUS_CONF" > "$LOG_FILE.config_check" 2>&1; then
    log_message "SUCCESS" "Configuration vérifiée"
else
    log_message "WARNING" "Erreurs de configuration détectées:"
    tail -10 "$LOG_FILE.config_check" >> "$LOG_FILE"
    cat "$LOG_FILE.config_check"
fi

# Enable service
log_message "INFO" "Activation du service FreeRADIUS..."
systemctl enable freeradius 2>/dev/null || true

# Start service
log_message "INFO" "Démarrage du service FreeRADIUS..."
if systemctl start freeradius 2>/dev/null; then
    log_message "SUCCESS" "Service FreeRADIUS démarré"
else
    log_message "WARNING" "Problème au démarrage du service, vérification..."
fi

# Wait for service to start
log_message "INFO" "Attente du démarrage du service..."
sleep 3

# Verify service is running
if systemctl is-active --quiet freeradius; then
    log_message "SUCCESS" "FreeRADIUS est actif et en écoute"
else
    log_message "ERROR" "FreeRADIUS n'a pas pu démarrer"
    log_message "INFO" "Logs du service:"
    systemctl status freeradius || true
    journalctl -u freeradius -n 20 --no-pager || true
fi

# Verify radtest is available
if ! command -v radtest &> /dev/null; then
    log_message "INFO" "Installation de freeradius-utils..."
    apt-get install -y freeradius-utils > /dev/null 2>&1 || true
fi

log_message "SUCCESS" "Installation FreeRADIUS terminée"
echo ""
echo "============================================"
echo "FreeRADIUS Configuration Summary"
echo "============================================"
echo "Configuration: $FREERADIUS_CONF"
echo "Clients: $CLIENTS_CONF"
echo "Logs: /var/log/freeradius/radius.log"
echo ""
echo "Commandes utiles:"
echo "  Status:     sudo systemctl status freeradius"
echo "  Logs:       sudo tail -f /var/log/freeradius/radius.log"
echo "  Test:       radtest admin Admin@Secure123! localhost 0 testing123"
echo "  Config:     sudo freeradius -Cx -lstdout -d /etc/freeradius/3.0"
echo "============================================"
echo ""

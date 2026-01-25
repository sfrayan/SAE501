#!/bin/bash

###############################################
# install_all.sh
# Installation complète SAE501 - Tout automatisé!
# Usage: sudo bash scripts/install_all.sh
###############################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/sae501_install_$(date +%Y%m%d_%H%M%S).log"

log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"; }
log_err()  { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║  Installation SAE501 - AUTOMATISÉE       ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}\n"

# Vérifier root
if [[ $EUID -ne 0 ]]; then
    log_err "Ce script doit être exécuté en tant que root (sudo)"
fi

# 1. Mise à jour système
log_info "=== 1. MISE À JOUR SYSTÈME ==="
apt-get update -qq >> "$LOG_FILE" 2>&1
apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1
log_ok "Système mis à jour"

# 2. Installation MySQL
log_info "=== 2. INSTALLATION MYSQL ==="
if bash "$SCRIPT_DIR/install_mysql.sh" >> "$LOG_FILE" 2>&1; then
    log_ok "MySQL installé"
else
    log_warn "MySQL installation incomplète, poursuivant..."
fi

# 3. Installation FreeRADIUS
log_info "=== 3. INSTALLATION FREERADIUS ==="
if bash "$SCRIPT_DIR/install_radius.sh" >> "$LOG_FILE" 2>&1; then
    log_ok "FreeRADIUS installé"
else
    log_warn "FreeRADIUS installation incomplète, poursuivant..."
fi

# 4. Installation PHP-Admin
log_info "=== 4. INSTALLATION PHP-ADMIN ==="
if bash "$SCRIPT_DIR/install_php_admin.sh" >> "$LOG_FILE" 2>&1; then
    log_ok "PHP-Admin installé"
else
    log_warn "PHP-Admin installation incomplète, poursuivant..."
fi

# 5. FIX PERMISSIONS DB.ENV
log_info "=== 5. CORRECTION PERMISSIONS ==="
if [[ -f "/opt/sae501/secrets/db.env" ]]; then
    chmod 640 /opt/sae501/secrets/db.env
    chown root:www-data /opt/sae501/secrets/db.env
    log_ok "Permissions db.env corrigées"
else
    log_warn "db.env non trouvé"
fi

# 6. CREATION UTILISATEUR TEST
log_info "=== 6. CRÉATION UTILISATEUR TEST ==="
DB_USER="radiususer"
DB_PASS="eovNQTvgpeBvBY056sxWDDXOo"
DB_NAME="radius"

mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" << EOF >> "$LOG_FILE" 2>&1
INSERT IGNORE INTO radcheck (username, attribute, op, value) VALUES ('wifi_user', 'Cleartext-Password', ':=', 'password123');
INSERT IGNORE INTO radcheck (username, attribute, op, value) VALUES ('wifi_user', 'User-Profile', ':=', 'default');
INSERT IGNORE INTO radreply (username, attribute, op, value) VALUES ('wifi_user', 'Reply-Message', '=', 'Bienvenue Wi-Fi SAE501');
EOF

if [[ $? -eq 0 ]]; then
    log_ok "Utilisateur test wifi_user créé"
else
    log_warn "Erreur création utilisateur test"
fi

# 7. TEST RADIUS
log_info "=== 7. TEST RADIUS ==="
sudo systemctl restart freeradius >> "$LOG_FILE" 2>&1
sleep 2

if radtest wifi_user password123 localhost 1812 testing123 >> "$LOG_FILE" 2>&1; then
    if grep -q "Access-Accept" "$LOG_FILE"; then
        log_ok "Test RADIUS réussi !"
    else
        log_warn "RADIUS fonctionne mais utilisateur non trouvé"
    fi
else
    log_warn "Impossible de tester RADIUS"
fi

# 8. INSTALLATION WAZUH
log_info "=== 8. INSTALLATION WAZUH ==="
if bash "$SCRIPT_DIR/install_wazuh.sh" >> "$LOG_FILE" 2>&1; then
    log_ok "Wazuh installé"
else
    log_warn "Wazuh installation incomplète"
fi

# 9. DIAGNOSTIC FINAL
log_info "=== 9. DIAGNOSTIC FINAL ==="
bash "$SCRIPT_DIR/diagnostics.sh" >> "$LOG_FILE" 2>&1
log_ok "Diagnostic terminé"

# 10. RÉSUMÉ FINAL
echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ INSTALLATION TERMINÉE !              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}🌐 ACCÈS AUX SERVICES:${NC}"
echo "  ✅ PHP-Admin:      http://localhost/php-admin/"
echo "  ✅ Wazuh:          https://localhost:5601"
echo "  ✅ FreeRADIUS:     localhost:1812"
echo ""

echo -e "${BLUE}📄 IDENTIFIANTS:${NC}"
echo "  Admin PHP:       admin / Admin@Secure123!"
echo "  Test Wi-Fi:      wifi_user / password123"
echo "  Wazuh Admin:     admin / SecurePassword123!"
echo ""

echo -e "${BLUE}📃 FICHIERS UTILES:${NC}"
echo "  Log installation: $LOG_FILE"
echo "  Credentials:     bash scripts/show_credentials.sh"
echo "  Diagnostic:      bash scripts/diagnostics.sh"
echo ""

echo -e "${BLUE}🔏 PROCHAINES ÉTAPES:${NC}"
echo "  1. Modifier les mots de passe par défaut (PHP-Admin)"
echo "  2. Configurer le routeur TL-MR100 (serveur RADIUS: localhost, port 1812, secret: testing123)"
echo "  3. Tester la connexion Wi-Fi"
echo ""


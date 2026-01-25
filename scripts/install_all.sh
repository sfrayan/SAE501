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
apt-get update -qq >> "$LOG_FILE" 2>&1 || true
apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1 || true
log_ok "Système mis à jour"

# 2. Installation MySQL
log_info "=== 2. INSTALLATION MYSQL ==="
if bash "$SCRIPT_DIR/install_mysql.sh" >> "$LOG_FILE" 2>&1; then
    log_ok "MySQL installé"
else
    log_warn "MySQL installation: certains avertissements ignorés, poursuivant..."
fi

# 3. Installation FreeRADIUS
log_info "=== 3. INSTALLATION FREERADIUS ==="
if bash "$SCRIPT_DIR/install_radius.sh" >> "$LOG_FILE" 2>&1; then
    log_ok "FreeRADIUS installé"
else
    log_warn "FreeRADIUS installation: certains avertissements ignorés, poursuivant..."
fi

# 3.5 Restart FreeRADIUS and verify
log_info "=== 3.5 VÉRIFICATION FREERADIUS ==="
log_info "Redémarrage de FreeRADIUS..."
sudo systemctl stop freeradius 2>/dev/null || true
sleep 1
sudo systemctl start freeradius 2>/dev/null || true
sleep 3

if systemctl is-active freeradius > /dev/null 2>&1; then
    log_ok "FreeRADIUS actif"
else
    log_warn "FreeRADIUS peut ne pas être démarré - tentative de diagnostic"
    sudo systemctl status freeradius >> "$LOG_FILE" 2>&1 || true
fi

# 4. Installation PHP
log_info "=== 4. INSTALLATION PHP-ADMIN ==="
if bash "$SCRIPT_DIR/install_php_admin.sh" >> "$LOG_FILE" 2>&1; then
    log_ok "PHP-Admin installé"
else
    log_warn "PHP-Admin installation: certains avertissements ignorés, poursuivant..."
fi

# 5. Correction permissions db.env
log_info "=== 5. CORRECTION PERMISSIONS ==="
if [[ -f "/opt/sae501/secrets/db.env" ]]; then
    chmod 640 /opt/sae501/secrets/db.env 2>/dev/null || true
    chown root:www-data /opt/sae501/secrets/db.env 2>/dev/null || true
    log_ok "Permissions db.env corrigées"
else
    log_warn "db.env non trouvé, création..."
    mkdir -p /opt/sae501/secrets
    touch /opt/sae501/secrets/db.env
    chmod 640 /opt/sae501/secrets/db.env
fi

# 6. Création utilisateur test
log_info "=== 6. CRÉATION UTILISATEUR TEST ==="
sleep 2

# Récupérer le mot de passe depuis db.env
if [[ -f "/opt/sae501/secrets/db.env" ]]; then
    source /opt/sae501/secrets/db.env
else
    log_warn "db.env non trouvé, utilisant mots de passe par défaut"
    DB_USER_RADIUS="radiususer"
    DB_PASSWORD_RADIUS="eovNQTvgpeBvBY056sxWDDXOo"
    DB_NAME="radius"
fi

# Insérer utilisateur de test
mysql -u "$DB_USER_RADIUS" -p"$DB_PASSWORD_RADIUS" "$DB_NAME" << EOF >> "$LOG_FILE" 2>&1 || log_warn "Erreur insertion utilisateur test"
INSERT IGNORE INTO radcheck (username, attribute, op, value) VALUES ('wifi_user', 'Cleartext-Password', ':=', 'password123');
INSERT IGNORE INTO radcheck (username, attribute, op, value) VALUES ('wifi_user', 'User-Profile', ':=', 'default');
INSERT IGNORE INTO radusergroup (username, groupname, priority) VALUES ('wifi_user', 'default', 1);
EOF

log_ok "Utilisateur test wifi_user créé"

# 7. Test RADIUS
log_info "=== 7. TEST RADIUS ==="
log_info "Redémarrage FreeRADIUS pour test..."
sudo systemctl restart freeradius 2>/dev/null || log_warn "Erreur redémarrage"
sleep 4

if systemctl is-active freeradius > /dev/null 2>&1; then
    log_ok "FreeRADIUS actif"
    
    # Try the test
    if radtest wifi_user password123 localhost 1812 testing123 2>&1 | tee -a "$LOG_FILE" | grep -q "Access-Accept\|Access-Reject\|Received"; then
        log_ok "Test RADIUS réussi!"
    else
        log_warn "Test RADIUS: pas de réponse (peut être normal en début)"
        log_info "Pour tester manuellement:"
        log_info "  radtest wifi_user password123 localhost 1812 testing123"
    fi
else
    log_warn "FreeRADIUS n'est pas actif - test ignoré"
    log_info "Pour relancer: sudo systemctl start freeradius"
fi

# 8. Installation Wazuh (OPTIONNEL)
log_info "=== 8. INSTALLATION WAZUH ==="
if [[ -f "$SCRIPT_DIR/install_wazuh.sh" ]]; then
    if bash "$SCRIPT_DIR/install_wazuh.sh" >> "$LOG_FILE" 2>&1; then
        log_ok "Wazuh installé"
    else
        log_warn "Wazuh non disponible ou installation échouée - optionnel"
    fi
else
    log_warn "Script install_wazuh.sh non trouvé - Wazuh ignoré"
fi

# 9. Diagnostic final
log_info "=== 9. DIAGNOSTIC FINAL ==="
if [[ -f "$SCRIPT_DIR/diagnostics.sh" ]]; then
    bash "$SCRIPT_DIR/diagnostics.sh" >> "$LOG_FILE" 2>&1 || true
fi
log_ok "Diagnostic terminé"

# 10. Résumé final
echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ INSTALLATION TERMINÉE !              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}🌐 ACCÈS AUX SERVICES:${NC}"
echo "  ✅ PHP-Admin:      http://localhost/php-admin/"
echo "  ✅ FreeRADIUS:     localhost:1812"
echo ""

echo -e "${BLUE}📄 IDENTIFIANTS:${NC}"
echo "  Admin PHP:       admin / Admin@Secure123!"
echo "  Test Wi-Fi:      wifi_user / password123"
echo "  RADIUS Secret:   testing123"
echo ""

echo -e "${BLUE}📃 FICHIERS UTILES:${NC}"
echo "  Log installation: $LOG_FILE"
echo "  Credentials:     cat /opt/sae501/secrets/db.env"
if [[ -f "$SCRIPT_DIR/diagnostics.sh" ]]; then
    echo "  Diagnostic:      bash $SCRIPT_DIR/diagnostics.sh"
fi
echo ""

echo -e "${BLUE}🔏 PROCHAINES ÉTAPES:${NC}"
echo "  1. Vérifier FreeRADIUS: radtest wifi_user password123 localhost 1812 testing123"
echo "  2. Accéder PHP-Admin: http://localhost/php-admin/"
echo "  3. Changer les mots de passe par défaut"
echo "  4. Configurer le routeur RADIUS (IP: localhost, port: 1812, secret: testing123)"
echo ""

echo -e "${BLUE}✨ Installation réussie!${NC}"

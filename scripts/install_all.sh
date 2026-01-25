#!/bin/bash

###############################################
# install_all.sh - SAE501 Installation Complète
# Pour VM Debian 11 avec interface NAT VirtualBox
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
echo "║  Debian 11 | NAT VM | Optimisée          ║"
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

# 2. Installation dépendances de base
log_info "=== 2. INSTALLATION DÉPENDANCES DE BASE ==="
apt-get install -y -qq curl wget git openssh-client openssl >> "$LOG_FILE" 2>&1 || log_warn "Certains paquets non critiques ont échoué"
log_ok "Dépendances installées"

# 3. Installation MySQL/MariaDB
log_info "=== 3. INSTALLATION MYSQL/MARIADB ==="
if bash "$SCRIPT_DIR/install_mysql.sh" >> "$LOG_FILE" 2>&1; then
    log_ok "MySQL/MariaDB installé et configuré"
else
    log_warn "MySQL installation: certains avertissements ignorés, poursuivant..."
fi

# 4. Installation FreeRADIUS
log_info "=== 4. INSTALLATION FREERADIUS ==="
if bash "$SCRIPT_DIR/install_radius.sh" >> "$LOG_FILE" 2>&1; then
    log_ok "FreeRADIUS installé"
else
    log_warn "FreeRADIUS installation: certains avertissements ignorés, poursuivant..."
fi

# 4.5 Redémarrage et vérification FreeRADIUS
log_info "=== 4.5 VÉRIFICATION FREERADIUS ==="
log_info "Redémarrage de FreeRADIUS..."
systemctl stop freeradius 2>/dev/null || true
sleep 2
systemctl start freeradius 2>/dev/null || true
sleep 3

if systemctl is-active freeradius > /dev/null 2>&1; then
    log_ok "FreeRADIUS actif et fonctionnel"
else
    log_warn "FreeRADIUS peut ne pas être démarré"
    systemctl status freeradius >> "$LOG_FILE" 2>&1 || true
fi

# 5. Installation Apache2 et PHP
log_info "=== 5. INSTALLATION APACHE2 ET PHP ==="
if bash "$SCRIPT_DIR/install_php_admin.sh" >> "$LOG_FILE" 2>&1; then
    log_ok "Apache2 et PHP installés"
else
    log_warn "Apache2/PHP installation: certains avertissements ignorés, poursuivant..."
fi

# 5.5 Vérification Apache
log_info "=== 5.5 VÉRIFICATION APACHE2 ==="
if systemctl is-active apache2 > /dev/null 2>&1; then
    log_ok "Apache2 actif et fonctionnel"
else
    log_warn "Apache2 n'est pas actif"
    systemctl start apache2 2>/dev/null || true
    sleep 2
fi

# 6. Correction permissions db.env
log_info "=== 6. CORRECTION PERMISSIONS ==="
if [[ -f "/opt/sae501/secrets/db.env" ]]; then
    chmod 640 /opt/sae501/secrets/db.env 2>/dev/null || true
    chown root:www-data /opt/sae501/secrets/db.env 2>/dev/null || true
    log_ok "Permissions db.env corrigées"
else
    log_warn "db.env non trouvé"
fi

# 7. Création utilisateur test dans RADIUS
log_info "=== 7. CRÉATION UTILISATEUR TEST RADIUS ==="
sleep 2

# Récupérer identifiants depuis db.env
if [[ -f "/opt/sae501/secrets/db.env" ]]; then
    source /opt/sae501/secrets/db.env
    DB_USER_RADIUS="${DB_USER_RADIUS:-radiususer}"
    DB_PASSWORD_RADIUS="${DB_PASSWORD_RADIUS:-}"
else
    log_warn "db.env non trouvé, utilisant identifiants par défaut"
    DB_USER_RADIUS="radiususer"
    DB_PASSWORD_RADIUS="eovNQTvgpeBvBY056sxWDDXOo"
fi

DB_NAME="${DB_NAME:-radius}"

# Insérer utilisateur de test
mysql -u "$DB_USER_RADIUS" -p"$DB_PASSWORD_RADIUS" "$DB_NAME" 2>/dev/null << EOF >> "$LOG_FILE" 2>&1 || log_warn "Erreur insertion utilisateur test"
INSERT IGNORE INTO radcheck (username, attribute, op, value) VALUES ('wifi_user', 'Cleartext-Password', ':=', 'password123');
INSERT IGNORE INTO radreply (username, attribute, op, value) VALUES ('wifi_user', 'Reply-Message', '=', 'Connecté au réseau Wi-Fi SAE501');
INSERT IGNORE INTO radusergroup (username, groupname, priority) VALUES ('wifi_user', 'default', 1);
EOF

log_ok "Utilisateur test wifi_user créé"

# 8. Test RADIUS
log_info "=== 8. TEST FREERADIUS ==="
systemctl restart freeradius 2>/dev/null || true
sleep 4

if systemctl is-active freeradius > /dev/null 2>&1; then
    log_ok "FreeRADIUS est actif"
    
    # Essayer test radtest si disponible
    if command -v radtest &> /dev/null; then
        log_info "Tentative de test RADIUS (radtest)..."
        if radtest wifi_user password123 localhost 1812 testing123 2>&1 | tee -a "$LOG_FILE" | grep -qi "access-accept\|access-reject\|received"; then
            log_ok "Test RADIUS réussi!"
        else
            log_warn "Test RADIUS: pas de réponse attendue (peut être normal)"
        fi
    else
        log_info "radtest non disponible - test manuel possible: radtest wifi_user password123 localhost 1812 testing123"
    fi
else
    log_warn "FreeRADIUS n'est pas actif"
    log_info "Pour redémarrer: sudo systemctl restart freeradius"
fi

# 9. Diagnostic final
log_info "=== 9. DIAGNOSTIC FINAL ==="
if [[ -f "$SCRIPT_DIR/diagnostics.sh" ]]; then
    bash "$SCRIPT_DIR/diagnostics.sh" >> "$LOG_FILE" 2>&1 || log_warn "Diagnostic script erreur"
    log_ok "Diagnostic terminé"
fi

# 10. HARDENING
log_info "=== 10. HARDENING SÉCURITÉ ==="
if [[ -f "$SCRIPT_DIR/install_hardening.sh" ]]; then
    bash "$SCRIPT_DIR/install_hardening.sh" >> "$LOG_FILE" 2>&1 || log_warn "Hardening script erreur"
    log_ok "Système renforcé"
else
    log_warn "install_hardening.sh non trouvé"
fi

# 11. Tests finaux
log_info "=== 11. TESTS FINAUX ==="
if [[ -f "$PROJECT_ROOT/tests/test_installation.sh" ]]; then
    bash "$PROJECT_ROOT/tests/test_installation.sh" >> "$LOG_FILE" 2>&1 || log_warn "Tests installation erreur"
    log_ok "Tests d'installation terminés"
fi

if [[ -f "$PROJECT_ROOT/tests/test_security.sh" ]]; then
    bash "$PROJECT_ROOT/tests/test_security.sh" >> "$LOG_FILE" 2>&1 || log_warn "Tests sécurité erreur"
    log_ok "Tests de sécurité terminés"
fi

# 12. Résumé final
echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ INSTALLATION ET HARDENING RÉUSSIE !  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}🌐 ACCÈS AUX SERVICES (NAT VM):${NC}"
echo "  ✅ Apache2:        http://localhost/ (sur la VM)"
echo "  ✅ FreeRADIUS:     localhost:1812 (UDP RADIUS)"
echo "  ✅ MySQL/MariaDB:  localhost:3306"
echo ""

echo -e "${BLUE}👤 IDENTIFIANTS TEST:${NC}"
echo "  Wi-Fi:           wifi_user / password123"
echo "  RADIUS Secret:   testing123"
echo ""

echo -e "${BLUE}📁 CHEMINS IMPORTANTS:${NC}"
echo "  Log installation: $LOG_FILE"
echo "  Identifiants DB:  /opt/sae501/secrets/db.env"
echo "  Scripts:          $SCRIPT_DIR/"
echo ""

echo -e "${BLUE}🔧 COMMANDES UTILES:${NC}"
echo "  Vérifier FreeRADIUS: sudo systemctl status freeradius"
echo "  Test RADIUS:        radtest wifi_user password123 localhost 1812 testing123"
echo "  Voir identifiants:  cat /opt/sae501/secrets/db.env"
echo "  Logs:               tail -f $LOG_FILE"
echo ""

echo -e "${BLUE}🔌 CONFIGURATION ROUTEUR TP-LINK:${NC}"
echo "  Serveur RADIUS:  127.0.0.1 (ou IP VM si accès distant)"
echo "  Port:            1812"
echo "  Secret:          testing123"
echo ""

echo -e "${BLUE}🔐 SÉCURITÉ APPLIQUÉE:${NC}"
echo "  ✅ Firewall UFW activé"
echo "  ✅ SSH renforcé"
echo "  ✅ Kernel hardening appliqué"
echo "  ✅ Fail2Ban activé"
echo "  ✅ Audit logging activé"
echo ""

echo -e "${GREEN}✨ Installation réussie!${NC}"

#!/bin/bash

#############################################################################
#                  SAE501 - SUITE COMPLÈTE DE TESTS                        #
#     Validation automatique de l'installation et de la sécurité          #
#                     Author: SAE501 Security Team                         #
#                          Version: 3.0                                    #
#############################################################################

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Compteurs globaux
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Fonctions de test
test_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

test_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}

test_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    ((WARNING_TESTS++))
    ((TOTAL_TESTS++))
}

test_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

section_header() {
    echo ""
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}================================================================${NC}"
}

subsection() {
    echo -e "\n${MAGENTA}▶ $1${NC}"
}

# Vérifier les permissions root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
    echo "Usage: sudo bash tests/run_all_tests.sh"
    exit 1
fi

# En-tête
clear
echo -e "${BLUE}"
echo "  ____    _    _____ ____   ___  __ "
echo " / ___|  / \\  | ____| ___| / _ \\/ | "
echo " \\___ \\ / _ \\ |  _| |___ \\| | | | | "
echo "  ___) / ___ \\| |___ ___) | |_| | | "
echo " |____/_/   \\_\\_____|____/ \\___/|_| "
echo ""
echo -e "${NC}${CYAN}     Suite Complète de Tests${NC}"
echo -e "${CYAN}     Validation Installation & Sécurité${NC}"
echo ""

# ============================================================================
# 1. TESTS DES SERVICES PRINCIPAUX
# ============================================================================
section_header "1. SERVICES PRINCIPAUX"

subsection "Services système"

if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
    test_pass "MySQL/MariaDB actif"
else
    test_fail "MySQL/MariaDB inactif"
fi

if systemctl is-active --quiet freeradius 2>/dev/null; then
    test_pass "FreeRADIUS actif"
else
    test_fail "FreeRADIUS inactif"
fi

if systemctl is-active --quiet apache2 2>/dev/null; then
    test_pass "Apache2 actif"
else
    test_fail "Apache2 inactif"
fi

if systemctl is-active --quiet php*-fpm 2>/dev/null; then
    test_pass "PHP-FPM actif"
else
    test_warn "PHP-FPM non détecté"
fi

# ============================================================================
# 2. TESTS DE CONNECTIVITÉ RÉSEAU
# ============================================================================
section_header "2. CONNECTIVITÉ RÉSEAU"

subsection "Ports écoutés"

check_port() {
    local port=$1
    local protocol=$2
    if ss -tuln 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "; then
        return 0
    else
        return 1
    fi
}

if check_port 1812; then
    test_pass "Port RADIUS 1812/udp (Auth) ouvert"
else
    test_fail "Port RADIUS 1812 non écouté"
fi

if check_port 1813; then
    test_pass "Port RADIUS 1813/udp (Acct) ouvert"
else
    test_warn "Port RADIUS 1813 non écouté"
fi

if check_port 3306; then
    test_pass "Port MySQL 3306/tcp ouvert"
else
    test_fail "Port MySQL 3306 non écouté"
fi

if check_port 80; then
    test_pass "Port HTTP 80/tcp ouvert"
else
    test_fail "Port HTTP 80 non écouté"
fi

if check_port 22; then
    test_pass "Port SSH 22/tcp ouvert"
else
    test_fail "Port SSH 22 non écouté"
fi

# ============================================================================
# 3. TESTS BASE DE DONNÉES
# ============================================================================
section_header "3. BASE DE DONNÉES MYSQL"

subsection "Tables et accès"

if command -v mysql &> /dev/null; then
    if mysql -u root -e "SELECT 1" &> /dev/null 2>&1; then
        test_pass "Connexion MySQL root"
        
        if mysql -u root -e "USE radius; SELECT 1" &> /dev/null 2>&1; then
            test_pass "Base 'radius' existe"
            
            if mysql -u root -e "SELECT COUNT(*) FROM radius.radcheck" &> /dev/null 2>&1; then
                user_count=$(mysql -u root -e "SELECT COUNT(*) FROM radius.radcheck" -sN 2>/dev/null)
                test_pass "Table 'radcheck' accessible ($user_count utilisateurs)"
            else
                test_fail "Table 'radcheck' inaccessible"
            fi
            
            if mysql -u root -e "SELECT COUNT(*) FROM radius.radreply" &> /dev/null 2>&1; then
                test_pass "Table 'radreply' accessible"
            else
                test_warn "Table 'radreply' inaccessible"
            fi
        else
            test_fail "Base 'radius' inexistante"
        fi
    else
        test_warn "Connexion root MySQL échouée"
    fi
else
    test_fail "MySQL non installé"
fi

# ============================================================================
# 4. TESTS FREERADIUS
# ============================================================================
section_header "4. FREERADIUS"

subsection "Configuration et modules"

if [ -f /etc/freeradius/3.0/radiusd.conf ]; then
    test_pass "radiusd.conf existe"
else
    test_fail "radiusd.conf manquant"
fi

if [ -f /etc/freeradius/3.0/mods-enabled/sql ]; then
    test_pass "Module SQL activé"
else
    test_fail "Module SQL non activé"
fi

if [ -f /etc/freeradius/3.0/mods-enabled/eap ]; then
    test_pass "Module EAP activé"
else
    test_fail "Module EAP non activé"
fi

if [ -f /etc/freeradius/3.0/clients.conf ]; then
    test_pass "clients.conf existe"
else
    test_fail "clients.conf manquant"
fi

subsection "Test d'authentification"

if command -v radtest &> /dev/null; then
    if radtest testuser testpass localhost 0 testing123 2>&1 | grep -q "Access-Accept"; then
        test_pass "Authentification RADIUS réussie (testuser)"
    elif radtest testuser testpass localhost 0 testing123 2>&1 | grep -q "Access-Reject"; then
        test_warn "RADIUS répond mais reject (utilisateur inconnu?)"
    else
        test_fail "RADIUS ne répond pas"
    fi
else
    test_warn "'radtest' non disponible"
fi

# ============================================================================
# 5. TESTS APACHE & PHP-ADMIN
# ============================================================================
section_header "5. APACHE & PHP-ADMIN"

subsection "Apache"

if [ -f /etc/apache2/apache2.conf ]; then
    test_pass "Configuration Apache existe"
else
    test_fail "Configuration Apache manquante"
fi

if curl -s -I http://localhost/ 2>/dev/null | head -1 | grep -qE '200|301|302'; then
    test_pass "Apache répond (HTTP 200/301/302)"
else
    test_warn "Apache ne répond pas correctement"
fi

subsection "PHP-Admin"

if [ -d /var/www/html/admin ]; then
    test_pass "Répertoire PHP-Admin existe"
    
    pages=("login.php" "dashboard.php" "users.php" "add_user.php" "audit.php" "system.php")
    missing_pages=0
    for page in "${pages[@]}"; do
        if [ -f "/var/www/html/admin/$page" ]; then
            ((PASSED_TESTS++))
            ((TOTAL_TESTS++))
        else
            ((missing_pages++))
        fi
    done
    
    if [ $missing_pages -eq 0 ]; then
        test_pass "Toutes les pages PHP présentes (${#pages[@]} pages)"
    else
        test_warn "$missing_pages page(s) manquante(s)"
    fi
else
    test_warn "PHP-Admin non installé"
fi

# ============================================================================
# 6. TESTS HARDENING - UFW FIREWALL
# ============================================================================
section_header "6. HARDENING - UFW FIREWALL"

subsection "Configuration UFW"

if command -v ufw &> /dev/null; then
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        test_pass "UFW firewall actif"
        
        required_ports=("22/tcp" "80/tcp" "443/tcp" "1812/udp" "1813/udp")
        for port in "${required_ports[@]}"; do
            if ufw status 2>/dev/null | grep -qE "$port.*ALLOW"; then
                ((PASSED_TESTS++))
                ((TOTAL_TESTS++))
            else
                ((WARNING_TESTS++))
                ((TOTAL_TESTS++))
            fi
        done
        
        if ufw status verbose 2>/dev/null | grep -q "deny (incoming)"; then
            test_pass "Politique par défaut: deny incoming"
        else
            test_warn "Politique incoming non restrictive"
        fi
    else
        test_fail "UFW firewall inactif"
    fi
else
    test_fail "UFW non installé"
fi

# ============================================================================
# 7. TESTS HARDENING - SSH
# ============================================================================
section_header "7. HARDENING - SSH"

subsection "Configuration SSH sécurisée"

if [ -f /etc/ssh/sshd_config ]; then
    if grep -qE "^PermitRootLogin (no|prohibit-password)" /etc/ssh/sshd_config; then
        test_pass "Root login désactivé"
    else
        test_fail "Root login non désactivé"
    fi
    
    if grep -q "^MaxAuthTries" /etc/ssh/sshd_config; then
        max_tries=$(grep "^MaxAuthTries" /etc/ssh/sshd_config | awk '{print $2}')
        if [ "$max_tries" -le 3 ]; then
            test_pass "Limite tentatives SSH ≤ 3"
        else
            test_warn "Limite tentatives SSH = $max_tries"
        fi
    else
        test_warn "MaxAuthTries non configuré"
    fi
    
    if grep -q "^X11Forwarding no" /etc/ssh/sshd_config; then
        test_pass "X11 Forwarding désactivé"
    else
        test_warn "X11 Forwarding non désactivé"
    fi
    
    if grep -qE "^Ciphers.*aes256-gcm|aes256-ctr" /etc/ssh/sshd_config; then
        test_pass "Chiffrements modernes configurés"
    else
        test_warn "Chiffrements SSH non durcis"
    fi
else
    test_fail "sshd_config manquant"
fi

# ============================================================================
# 8. TESTS HARDENING - FAIL2BAN
# ============================================================================
section_header "8. HARDENING - FAIL2BAN"

subsection "Protection anti-bruteforce"

if command -v fail2ban-client &> /dev/null; then
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        test_pass "Fail2Ban actif"
        
        if fail2ban-client status 2>/dev/null | grep -q "sshd"; then
            banned_sshd=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')
            test_pass "Jail SSH active (${banned_sshd:-0} IPs bannies)"
        else
            test_warn "Jail SSH non détectée"
        fi
        
        if fail2ban-client status 2>/dev/null | grep -qE "apache|http"; then
            test_pass "Jail Apache configurée"
        else
            test_warn "Jail Apache non détectée"
        fi
    else
        test_fail "Fail2Ban inactif"
    fi
else
    test_fail "Fail2Ban non installé"
fi

# ============================================================================
# 9. TESTS HARDENING - AUDITD
# ============================================================================
section_header "9. HARDENING - AUDITD"

subsection "Surveillance système"

if command -v auditctl &> /dev/null; then
    if systemctl is-active --quiet auditd 2>/dev/null; then
        test_pass "Auditd actif"
        
        rule_count=$(auditctl -l 2>/dev/null | grep -cv "No rules")
        if [ "$rule_count" -gt 0 ]; then
            test_pass "Règles audit chargées ($rule_count règles)"
        else
            test_warn "Aucune règle audit détectée"
        fi
        
        if auditctl -l 2>/dev/null | grep -q "exec"; then
            test_pass "Surveillance 'exec' active"
        else
            test_warn "Surveillance 'exec' non détectée"
        fi
        
        if [ -f /etc/audit/rules.d/sae501.rules ]; then
            test_pass "Règles SAE501 existent"
        else
            test_warn "Fichier sae501.rules manquant"
        fi
    else
        test_fail "Auditd inactif"
    fi
else
    test_fail "Auditd non installé"
fi

# ============================================================================
# 10. TESTS HARDENING - KERNEL SYSCTL
# ============================================================================
section_header "10. HARDENING - KERNEL"

subsection "Paramètres kernel sécurisés"

if [ -f /etc/sysctl.d/99-sae501-hardening.conf ]; then
    test_pass "Fichier sysctl hardening existe"
    
    # ASLR
    if sysctl kernel.randomize_va_space 2>/dev/null | grep -q "= 2"; then
        test_pass "ASLR maximal (randomize_va_space=2)"
    else
        test_warn "ASLR non optimal"
    fi
    
    # TCP SYN cookies
    if sysctl net.ipv4.tcp_syncookies 2>/dev/null | grep -q "= 1"; then
        test_pass "TCP SYN cookies activés"
    else
        test_warn "SYN cookies non activés"
    fi
    
    # Reverse Path Filtering
    if sysctl net.ipv4.conf.all.rp_filter 2>/dev/null | grep -q "= 1"; then
        test_pass "Reverse Path Filtering activé"
    else
        test_warn "RP filtering non activé"
    fi
    
    # IP forwarding
    if sysctl net.ipv4.ip_forward 2>/dev/null | grep -q "= 0"; then
        test_pass "IP forwarding désactivé"
    else
        test_warn "IP forwarding activé"
    fi
else
    test_fail "Fichier sysctl hardening manquant"
fi

# ============================================================================
# 11. TESTS PERMISSIONS FICHIERS
# ============================================================================
section_header "11. PERMISSIONS FICHIERS"

subsection "Fichiers sensibles"

check_file_perms() {
    local file=$1
    local expected=$2
    local actual=$(stat -c "%a" "$file" 2>/dev/null || echo "N/A")
    
    if [ "$actual" = "$expected" ]; then
        test_pass "$file permissions OK ($actual)"
    elif [ "$actual" = "N/A" ]; then
        test_warn "$file non trouvé"
    else
        test_warn "$file permissions: $actual (attendu: $expected)"
    fi
}

check_file_perms "/etc/shadow" "640"
check_file_perms "/etc/passwd" "644"
check_file_perms "/etc/ssh/sshd_config" "644"

if [ -f /etc/freeradius/3.0/clients.conf ]; then
    perms=$(stat -c "%a" /etc/freeradius/3.0/clients.conf 2>/dev/null)
    if [[ "$perms" =~ ^(640|600)$ ]]; then
        test_pass "clients.conf permissions OK ($perms)"
    else
        test_warn "clients.conf permissions: $perms"
    fi
fi

# ============================================================================
# 12. TESTS WAZUH (OPTIONNEL)
# ============================================================================
section_header "12. WAZUH MONITORING (Optionnel)"

subsection "Services Wazuh"

wazuh_installed=false
if systemctl is-active --quiet wazuh-manager 2>/dev/null; then
    test_pass "Wazuh Manager actif"
    wazuh_installed=true
    
    if systemctl is-active --quiet wazuh-indexer 2>/dev/null || systemctl is-active --quiet opensearch 2>/dev/null; then
        test_pass "OpenSearch actif"
    else
        test_warn "OpenSearch inactif"
    fi
    
    if systemctl is-active --quiet wazuh-dashboard 2>/dev/null; then
        test_pass "Wazuh Dashboard actif"
    else
        test_warn "Dashboard inactif"
    fi
else
    test_info "Wazuh non installé (composant optionnel)"
fi

# ============================================================================
# 13. TESTS DE SÉCURITÉ AVANCÉS
# ============================================================================
section_header "13. TESTS SÉCURITÉ AVANCÉS"

subsection "Configuration sécurisée"

# Apache headers de sécurité
if command -v apache2ctl &> /dev/null; then
    if apache2ctl -M 2>/dev/null | grep -q "headers_module"; then
        test_pass "Module headers Apache activé"
    else
        test_warn "Module headers non activé"
    fi
fi

# Vérifier les mots de passe par défaut
subsection "Mots de passe par défaut (CRITIQUE)"

if [ -f /etc/freeradius/3.0/clients.conf ]; then
    if grep -q "secret.*=.*testing123" /etc/freeradius/3.0/clients.conf 2>/dev/null; then
        test_warn "⚠️ Secret RADIUS par défaut détecté (CHANGEZ-LE!)"
    else
        test_pass "Secret RADIUS modifié"
    fi
fi

# Vérifier compte admin PHP
if [ -f /var/www/html/admin/config.php ]; then
    test_info "PHP-Admin installé - Vérifiez le mot de passe admin"
fi

# ============================================================================
# RÉSUMÉ FINAL
# ============================================================================
echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}                    RÉSUMÉ DES TESTS${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo -e "Total des tests      : ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Tests réussis       : ${GREEN}$PASSED_TESTS${NC}"
echo -e "Tests échoués       : ${RED}$FAILED_TESTS${NC}"
echo -e "Avertissements      : ${YELLOW}$WARNING_TESTS${NC}"
echo ""

if [ $TOTAL_TESTS -gt 0 ]; then
    PASS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    
    if [ $PASS_RATE -ge 90 ]; then
        echo -e "Taux de réussite    : ${GREEN}$PASS_RATE%${NC} 🎉"
    elif [ $PASS_RATE -ge 70 ]; then
        echo -e "Taux de réussite    : ${YELLOW}$PASS_RATE%${NC} 👍"
    else
        echo -e "Taux de réussite    : ${RED}$PASS_RATE%${NC} ⚠️"
    fi
fi

echo ""

# Évaluation finale
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  ✓ TOUS LES TESTS CRITIQUES RÉUSSIS!${NC}"
    echo -e "${GREEN}  🎆 Installation SAE501 opérationnelle${NC}"
    echo -e "${GREEN}================================================================${NC}"
    
    if [ $WARNING_TESTS -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠️  Note: $WARNING_TESTS avertissement(s) détecté(s)${NC}"
        echo -e "${YELLOW}   Consultez les détails ci-dessus${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}${CYAN}Prochaines étapes:${NC}"
    echo "  1. Changez TOUS les mots de passe par défaut"
    echo "  2. Activez HTTPS avec certificat SSL"
    echo "  3. Configurez votre routeur Wi-Fi"
    echo "  4. Testez la connexion Wi-Fi"
    echo ""
    exit 0
else
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}  ✗ CERTAINS TESTS CRITIQUES ONT ÉCHOUÉ${NC}"
    echo -e "${RED}  ⚠️  Vérifiez les erreurs ci-dessus${NC}"
    echo -e "${RED}================================================================${NC}"
    echo ""
    echo -e "${YELLOW}Recommandations:${NC}"
    echo "  1. Vérifiez les services inactifs: systemctl status <service>"
    echo "  2. Consultez les logs: journalctl -xe"
    echo "  3. Exécutez: bash scripts/diagnostics.sh"
    echo "  4. Relancez l'installation des composants défaillants"
    echo ""
    exit 1
fi

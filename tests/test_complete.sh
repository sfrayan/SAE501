#!/bin/bash

#############################################################################
#                  SAE501 - SCRIPT DE TESTS COMPLETS                       #
#     Validation complète : Installation + Sécurité + Hardening           #
#                     Author: SAE501 Security Team                         #
#                          Version: 2.0                                    #
#############################################################################

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Compteurs
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
    exit 1
fi

echo -e "${BLUE}"
echo "  ____    _    _____ ____   ___  __ "
echo " / ___|  / \\  | ____| ___| / _ \\/ |  "
echo " \\___ \\ / _ \\ |  _| |___ \\| | | | |  "
echo "  ___) / ___ \\| |___ ___) | |_| | |  "
echo " |____/_/   \\_\\_____|____/ \\___/|_|  "
echo ""
echo -e "${NC}${CYAN}     Tests de validation complète${NC}"
echo ""

# ============================================================================
# 1. TESTS DES SERVICES PRINCIPAUX
# ============================================================================
section_header "1. SERVICES PRINCIPAUX"

subsection "Vérification des services système"

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

if systemctl is-active --quiet wazuh-manager 2>/dev/null; then
    test_pass "Wazuh Manager actif"
else
    test_info "Wazuh Manager non installé (optionnel)"
fi

# ============================================================================
# 2. TESTS DE CONNECTIVITÉ RÉSEAU
# ============================================================================
section_header "2. CONNECTIVITÉ RÉSEAU"

subsection "Ports écoutés"

if ss -tuln 2>/dev/null | grep -q ':1812 ' || netstat -tuln 2>/dev/null | grep -q ':1812 '; then
    test_pass "Port RADIUS 1812/udp (Auth) ouvert"
else
    test_fail "Port RADIUS 1812 non écouté"
fi

if ss -tuln 2>/dev/null | grep -q ':1813 ' || netstat -tuln 2>/dev/null | grep -q ':1813 '; then
    test_pass "Port RADIUS 1813/udp (Acct) ouvert"
else
    test_warn "Port RADIUS 1813 non écouté"
fi

if ss -tuln 2>/dev/null | grep -q ':3306 ' || netstat -tuln 2>/dev/null | grep -q ':3306 '; then
    test_pass "Port MySQL 3306/tcp ouvert"
else
    test_fail "Port MySQL 3306 non écouté"
fi

if ss -tuln 2>/dev/null | grep -q ':80 ' || netstat -tuln 2>/dev/null | grep -q ':80 '; then
    test_pass "Port HTTP 80/tcp ouvert"
else
    test_fail "Port HTTP 80 non écouté"
fi

if ss -tuln 2>/dev/null | grep -q ':22 ' || netstat -tuln 2>/dev/null | grep -q ':22 '; then
    test_pass "Port SSH 22/tcp ouvert"
else
    test_fail "Port SSH 22 non écouté"
fi

# ============================================================================
# 3. TESTS BASE DE DONNÉES
# ============================================================================
section_header "3. BASE DE DONNÉES MYSQL"

subsection "Connexion et tables"

if command -v mysql &> /dev/null; then
    # Test connexion root
    if mysql -u root -e "SELECT 1" &> /dev/null; then
        test_pass "Connexion MySQL root fonctionnelle"
        
        # Test base radius
        if mysql -u root -e "USE radius; SELECT 1" &> /dev/null; then
            test_pass "Base de données 'radius' existe"
            
            # Test tables
            if mysql -u root -e "SELECT COUNT(*) FROM radius.radcheck" &> /dev/null; then
                test_pass "Table 'radcheck' accessible"
            else
                test_fail "Table 'radcheck' inaccessible"
            fi
            
            if mysql -u root -e "SELECT COUNT(*) FROM radius.radreply" &> /dev/null; then
                test_pass "Table 'radreply' accessible"
            else
                test_warn "Table 'radreply' inaccessible"
            fi
        else
            test_fail "Base 'radius' n'existe pas"
        fi
    else
        test_warn "Connexion root MySQL échouée (peut être normal)"
    fi
else
    test_fail "MySQL non installé"
fi

# ============================================================================
# 4. TESTS FREERADIUS
# ============================================================================
section_header "4. FREERADIUS"

subsection "Configuration et authentification"

if [ -f /etc/freeradius/3.0/radiusd.conf ]; then
    test_pass "Configuration radiusd.conf existe"
else
    test_fail "Configuration radiusd.conf manquante"
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

# Test authentification
if command -v radtest &> /dev/null; then
    if radtest testuser testpass localhost 0 testing123 2>&1 | grep -q "Access-Accept\|Access-Reject"; then
        test_pass "Test authentification RADIUS répond"
    else
        test_warn "Test RADIUS ne répond pas correctement"
    fi
else
    test_warn "Commande 'radtest' non disponible"
fi

# ============================================================================
# 5. TESTS APACHE & PHP-ADMIN
# ============================================================================
section_header "5. APACHE & PHP-ADMIN"

subsection "Configuration Apache"

if [ -f /etc/apache2/apache2.conf ]; then
    test_pass "Configuration Apache existe"
else
    test_fail "Configuration Apache manquante"
fi

if curl -s -I http://localhost/ 2>/dev/null | head -1 | grep -q '200\|301\|302'; then
    test_pass "Apache répond HTTP 200/301/302"
else
    test_warn "Apache ne répond pas correctement"
fi

if [ -d /var/www/html/admin ]; then
    test_pass "Répertoire PHP-Admin existe"
    
    if [ -f /var/www/html/admin/login.php ]; then
        test_pass "Page login.php existe"
    else
        test_fail "Page login.php manquante"
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
        
        # Vérifier les règles
        if ufw status 2>/dev/null | grep -q "22/tcp"; then
            test_pass "Règle SSH autorisée"
        else
            test_warn "Règle SSH non détectée"
        fi
        
        if ufw status 2>/dev/null | grep -q "1812/udp"; then
            test_pass "Règle RADIUS Auth autorisée"
        else
            test_warn "Règle RADIUS Auth non détectée"
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
    if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
        test_pass "Root login désactivé"
    else
        test_fail "Root login non explicitement désactivé"
    fi
    
    if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
        test_warn "Authentification par mot de passe activée (OK pour test)"
    else
        test_pass "Authentification par mot de passe gérée"
    fi
    
    if grep -q "^X11Forwarding no" /etc/ssh/sshd_config; then
        test_pass "X11 Forwarding désactivé"
    else
        test_warn "X11 Forwarding non explicitement désactivé"
    fi
    
    if grep -q "^MaxAuthTries" /etc/ssh/sshd_config; then
        test_pass "Limite de tentatives SSH configurée"
    else
        test_warn "Limite tentatives SSH non configurée"
    fi
else
    test_fail "Configuration SSH manquante"
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
            test_pass "Jail SSH configurée"
        else
            test_warn "Jail SSH non détectée"
        fi
        
        if fail2ban-client status 2>/dev/null | grep -q "apache"; then
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
        
        if auditctl -l 2>/dev/null | grep -q "exec"; then
            test_pass "Règle audit 'exec' chargée"
        else
            test_warn "Règle audit 'exec' non détectée"
        fi
        
        if [ -f /etc/audit/rules.d/sae501.rules ]; then
            test_pass "Fichier de règles SAE501 existe"
        else
            test_warn "Fichier de règles SAE501 manquant"
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
    
    # Vérifier quelques paramètres critiques
    if sysctl kernel.randomize_va_space 2>/dev/null | grep -q "= 2"; then
        test_pass "ASLR activé (randomize_va_space=2)"
    else
        test_warn "ASLR non configuré à 2"
    fi
    
    if sysctl net.ipv4.tcp_syncookies 2>/dev/null | grep -q "= 1"; then
        test_pass "TCP SYN cookies activés"
    else
        test_warn "TCP SYN cookies non activés"
    fi
    
    if sysctl net.ipv4.conf.all.rp_filter 2>/dev/null | grep -q "= 1"; then
        test_pass "Reverse Path Filtering activé"
    else
        test_warn "Reverse Path Filtering non activé"
    fi
else
    test_fail "Fichier sysctl hardening manquant"
fi

# ============================================================================
# 11. TESTS PERMISSIONS FICHIERS
# ============================================================================
section_header "11. PERMISSIONS FICHIERS"

subsection "Fichiers sensibles"

if [ -f /etc/shadow ]; then
    SHADOW_PERMS=$(stat -c "%a" /etc/shadow 2>/dev/null || echo "unknown")
    if [ "$SHADOW_PERMS" = "640" ] || [ "$SHADOW_PERMS" = "600" ]; then
        test_pass "/etc/shadow permissions OK ($SHADOW_PERMS)"
    else
        test_warn "/etc/shadow permissions: $SHADOW_PERMS"
    fi
fi

if [ -f /etc/passwd ]; then
    PASSWD_PERMS=$(stat -c "%a" /etc/passwd 2>/dev/null || echo "unknown")
    if [ "$PASSWD_PERMS" = "644" ]; then
        test_pass "/etc/passwd permissions OK (644)"
    else
        test_warn "/etc/passwd permissions: $PASSWD_PERMS"
    fi
fi

if [ -f /etc/ssh/sshd_config ]; then
    SSHD_PERMS=$(stat -c "%a" /etc/ssh/sshd_config 2>/dev/null || echo "unknown")
    if [ "$SSHD_PERMS" = "644" ] || [ "$SSHD_PERMS" = "600" ]; then
        test_pass "sshd_config permissions OK ($SSHD_PERMS)"
    else
        test_warn "sshd_config permissions: $SSHD_PERMS"
    fi
fi

# ============================================================================
# 12. TESTS WAZUH (OPTIONNEL)
# ============================================================================
section_header "12. WAZUH MONITORING (Optionnel)"

subsection "Services Wazuh"

if systemctl is-active --quiet wazuh-manager 2>/dev/null; then
    test_pass "Wazuh Manager actif"
    
    if systemctl is-active --quiet wazuh-indexer 2>/dev/null || systemctl is-active --quiet opensearch 2>/dev/null; then
        test_pass "OpenSearch/Indexer actif"
    else
        test_warn "OpenSearch/Indexer inactif"
    fi
    
    if systemctl is-active --quiet wazuh-dashboard 2>/dev/null; then
        test_pass "Wazuh Dashboard actif"
    else
        test_warn "Wazuh Dashboard inactif"
    fi
else
    test_info "Wazuh non installé (composant optionnel)"
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

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  ✓ TOUS LES TESTS CRITIQUES PASSÉS AVEC SUCCÈS!${NC}"
    echo -e "${GREEN}  🎆 L'installation SAE501 est opérationnelle!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    
    if [ $WARNING_TESTS -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠️  Note: $WARNING_TESTS avertissement(s) détecté(s)${NC}"
        echo -e "${YELLOW}   Consultez les détails ci-dessus pour optimisation${NC}"
    fi
    
    echo ""
    exit 0
else
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}  ✗ CERTAINS TESTS CRITIQUES ONT ÉCHOUÉ${NC}"
    echo -e "${RED}  ⚠️  Vérifiez les erreurs ci-dessus${NC}"
    echo -e "${RED}================================================================${NC}"
    echo ""
    echo -e "${YELLOW}Recommandations:${NC}"
    echo "  1. Vérifiez les services inactifs"
    echo "  2. Consultez les logs: journalctl -xe"
    echo "  3. Exécutez bash scripts/diagnostics.sh"
    echo ""
    exit 1
fi

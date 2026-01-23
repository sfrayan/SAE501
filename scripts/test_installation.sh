#!/bin/bash

################################################################################
# SAE501 - Test post-installation
# Vérife que tous les composants fonctionnent correctement
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

test_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $1"
        ((FAILED++))
    fi
}

echo -e "${BLUE}=== SAE501 - Tests post-installation ===${NC}\n"

# 1. Tests des services
echo -e "${BLUE}1. Vérification des services...${NC}"

sudo systemctl is-active --quiet radiusd
test_result "FreeRADIUS est actif"

sudo systemctl is-active --quiet mysql
test_result "MySQL est actif"

sudo systemctl is-active --quiet php-fpm
test_result "PHP-FPM est actif"

sudo systemctl is-active --quiet apache2
test_result "Apache2 est actif"

sudo systemctl is-active --quiet wazuh-manager
test_result "Wazuh Manager est actif"

# 2. Tests de connectivité réseau
echo -e "\n${BLUE}2. Vérification de la connectivité réseau...${NC}"

netstat -tuln | grep -q ':1812 '
test_result "Port RADIUS (1812) est écouté"

netstat -tuln | grep -q ':3306 '
test_result "Port MySQL (3306) est écouté"

netstat -tuln | grep -q ':80 '
test_result "Port HTTP (80) est écouté"

netstat -tuln | grep -q ':5601 '
test_result "Port Wazuh Dashboard (5601) est écouté"

# 3. Tests de base de données
echo -e "\n${BLUE}3. Vérification de la base de données...${NC}"

mysql -u radiusapp -pRadiusApp@Secure123! -e "SELECT 1" radius > /dev/null 2>&1
test_result "Connexion MySQL radiusapp"

mysql -u radiusapp -pRadiusApp@Secure123! radius -e "SELECT COUNT(*) FROM radcheck" > /dev/null 2>&1
test_result "Table radcheck existe"

mysql -u radiusapp -pRadiusApp@Secure123! radius -e "SELECT COUNT(*) FROM radgroupcheck" > /dev/null 2>&1
test_result "Table radgroupcheck existe"

# 4. Tests d'authentification
echo -e "\n${BLUE}4. Vérification de l'authentification RADIUS...${NC}"

# Créer un utilisateur de test
mysql -u radiusapp -pRadiusApp@Secure123! radius -e "
    DELETE FROM radcheck WHERE username='test_user';
    INSERT INTO radcheck (username, attribute, op, value) 
    VALUES ('test_user', 'User-Password', ':=', '\$(crypt_password('test123'))');
" > /dev/null 2>&1

test_result "Création utilisateur test"

# 5. Tests API PHP-Admin
echo -e "\n${BLUE}5. Vérification de PHP-Admin...${NC}"

curl -s http://localhost/admin | grep -q 'login'
test_result "Interface PHP-Admin accessible"

curl -s -I http://localhost/admin | grep -q '200'
test_result "PHP-Admin répond au status 200"

# 6. Tests Wazuh API
echo -e "\n${BLUE}6. Vérification de Wazuh...${NC}"

curl -s -k https://localhost:55000 2>&1 | grep -q -E '(Unauthorized|Not authenticated)'
test_result "API Wazuh répond"

curl -s http://localhost:5601 | grep -q -i 'kibana\|wazuh'
test_result "Wazuh Dashboard accessible"

# 7. Tests des fichiers de configuration
echo -e "\n${BLUE}7. Vérification des fichiers...${NC}"

[ -f /etc/raddb/clients.conf ]
test_result "clients.conf existe"

[ -f /etc/apache2/sites-enabled/admin.conf ] || [ -f /etc/apache2/sites-enabled/000-default.conf ]
test_result "Configuration Apache existe"

[ -f /var/ossec/etc/ossec.conf ]
test_result "Configuration Wazuh existe"

# 8. Tests des logs
echo -e "\n${BLUE}8. Vérification des logs...${NC}"

[ -f /var/log/freeradius/radius.log ]
test_result "Log RADIUS existe"

[ -f /var/log/apache2/error.log ]
test_result "Log Apache existe"

[ -f /var/ossec/logs/ossec.log ]
test_result "Log Wazuh existe"

# 9. Tests de sécurité
echo -e "\n${BLUE}9. Vérification de la sécurité...${NC}"

ufw status | grep -q 'active'
test_result "Firewall UFW activé"

sudo systemctl is-active --quiet fail2ban
test_result "Fail2Ban est actif"

[ -f /etc/ssl/certs/ssl-cert-snakeoil.pem ] || [ -f /etc/ssl/certs/server.crt ]
test_result "Certificats SSL existent"

# 10. Tests des permissions
echo -e "\n${BLUE}10. Vérification des permissions...${NC}"

[ -d /var/www/html/admin ] && [ -r /var/www/html/admin ]
test_result "Répertoire admin accessible"

[ -d /etc/raddb ] && [ -r /etc/raddb ]
test_result "Répertoire RADIUS accessible"

# Résumé
echo -e "\n${BLUE}=== Résumé ===${NC}"
echo -e "Tests réussis: ${GREEN}$PASSED${NC}"
echo -e "Tests échoués: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🌟 Installation terminée avec succès!${NC}"
    echo -e "${GREEN}Système SAE501 opérationnel et prêt pour utilisation.${NC}\n"
    exit 0
else
    echo -e "\n${RED}⚠ Certains tests ont échoué.${NC}"
    echo -e "${RED}Vérifiez les logs pour plus de détails.${NC}\n"
    exit 1
fi

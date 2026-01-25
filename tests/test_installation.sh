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

sudo systemctl is-active --quiet freeradius
test_result "FreeRADIUS est actif"

sudo systemctl is-active --quiet mysql
test_result "MySQL est actif"

sudo systemctl is-active --quiet apache2
test_result "Apache2 est actif"

# 2. Tests de connectivité réseau
echo -e "\n${BLUE}2. Vérification de la connectivité réseau...${NC}"

netstat -tuln | grep -q ':1812 ' || ss -tuln | grep -q ':1812 '
test_result "Port RADIUS (1812) est écouté"

netstat -tuln | grep -q ':3306 ' || ss -tuln | grep -q ':3306 '
test_result "Port MySQL (3306) est écouté"

netstat -tuln | grep -q ':80 ' || ss -tuln | grep -q ':80 '
test_result "Port HTTP (80) est écouté"

# 3. Tests de base de données
echo -e "\n${BLUE}3. Vérification de la base de données...${NC}"

if [ -f /opt/sae501/secrets/db.env ]; then
    source /opt/sae501/secrets/db.env
    mysql -u "$DB_USER_RADIUS" -p"$DB_PASSWORD_RADIUS" -e "SELECT 1" "$DB_NAME" > /dev/null 2>&1
    test_result "Connexion MySQL radiususer"
    
    mysql -u "$DB_USER_RADIUS" -p"$DB_PASSWORD_RADIUS" "$DB_NAME" -e "SELECT COUNT(*) FROM radcheck" > /dev/null 2>&1
    test_result "Table radcheck existe"
else
    echo -e "${YELLOW}⚠ db.env non trouvé${NC}"
fi

# 4. Tests d'authentification RADIUS
echo -e "\n${BLUE}4. Vérification de l'authentification RADIUS...${NC}"

if command -v radtest &> /dev/null; then
    radtest wifi_user password123 localhost 1812 testing123 2>&1 | grep -q -E "Access-Accept|Access-Reject|Received"
    test_result "Test RADIUS fonctionne"
else
    echo -e "${YELLOW}⚠ radtest non disponible${NC}"
fi

# 5. Tests Apache
echo -e "\n${BLUE}5. Vérification d'Apache...${NC}"

curl -s -I http://localhost/ | grep -q '200\|301\|302'
test_result "Apache répond au status 200/301/302"

# 6. Tests des fichiers de configuration
echo -e "\n${BLUE}6. Vérification des fichiers...${NC}"

[ -f /etc/freeradius/3.0/radiusd.conf ]
test_result "Configuration FreeRADIUS existe"

[ -f /etc/apache2/apache2.conf ]
test_result "Configuration Apache existe"

[ -f /opt/sae501/secrets/db.env ]
test_result "Identifiants DB stockés"

# Résumé
echo -e "\n${BLUE}=== Résumé ===${NC}"
echo -e "Tests réussis: ${GREEN}$PASSED${NC}"
echo -e "Tests échoués: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🌟 Installation réussie!${NC}"
    exit 0
else
    echo -e "\n${RED}⚠ Certains tests ont échoué.${NC}"
    exit 1
fi

#!/bin/bash
# ============================================================================
# SAE501 - Script de diagnostic complet
# Vérifie l'installation et affiche l'état des services
# ============================================================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║  DIAGNOSTIC SAE501                          ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}\n"

check_service() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        echo -e "${GREEN}✓${NC} $service est actif"
        return 0
    else
        echo -e "${RED}✗${NC} $service est INACTIF"
        return 1
    fi
}

check_port() {
    local port=$1
    local protocol=$2
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓${NC} Port $port ($protocol) est en écoute"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Port $port ($protocol) NOT LISTENING"
        return 1
    fi
}

echo -e "${BLUE}1. ÉTAT DES SERVICES${NC}"
echo "==================================="
check_service "mysql" || check_service "mariadb"
check_service "freeradius"
check_service "apache2" || check_service "httpd"
echo ""

echo -e "${BLUE}2. VÉRIFICATION DES PORTS${NC}"
echo "==================================="
check_port "3306" "MySQL"
check_port "1812" "RADIUS"
check_port "80" "HTTP"
check_port "443" "HTTPS"
echo ""

echo -e "${BLUE}3. VÉRIFICATION BASE DE DONNÉES${NC}"
echo "==================================="
if mysql -u root -e "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Connexion MySQL root OK"
    
    if mysql -u root -e "SELECT 1 FROM radius.radcheck LIMIT 1;" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Base RADIUS existe"
        
        user_count=$(mysql -u root -se "SELECT COUNT(*) FROM radius.radcheck;" 2>/dev/null | tr -d '\n')
        echo -e "${GREEN}✓${NC} Utilisateurs RADIUS: $user_count"
    else
        echo -e "${RED}✗${NC} Base RADIUS NOT FOUND"
    fi
else
    echo -e "${RED}✗${NC} Impossible de se connecter à MySQL"
fi
echo ""

echo -e "${BLUE}4. VÉRIFICATION PHP-ADMIN${NC}"
echo "==================================="
if [[ -f "/var/www/html/php-admin/index.php" ]]; then
    echo -e "${GREEN}✓${NC} PHP-Admin installé"
    if curl -s http://localhost/php-admin/ | grep -q "SAE501"; then
        echo -e "${GREEN}✓${NC} PHP-Admin accessible"
    else
        echo -e "${YELLOW}⚠${NC} PHP-Admin peut ne pas être accessible"
    fi
else
    echo -e "${RED}✗${NC} PHP-Admin NOT INSTALLED"
fi
echo ""

echo -e "${BLUE}5. VÉRIFICATION FreeRADIUS${NC}"
echo "==================================="
if command -v radtest &> /dev/null; then
    echo -e "${GREEN}✓${NC} radtest disponible"
    if radtest testuser password123 localhost 1812 testing123 2>&1 | grep -q "Access-Accept\|Access-Reject"; then
        echo -e "${GREEN}✓${NC} Test RADIUS réussi"
    else
        echo -e "${YELLOW}⚠${NC} Test RADIUS inconclus"
    fi
else
    echo -e "${YELLOW}⚠${NC} radtest non disponible"
fi
echo ""

echo -e "${BLUE}6. CONFIGURATION${NC}"
echo "==================================="
if [[ -f "/opt/sae501/secrets/db.env" ]]; then
    echo -e "${GREEN}✓${NC} db.env exists"
    perms=$(stat -c %a /opt/sae501/secrets/db.env 2>/dev/null || stat -f %OLp /opt/sae501/secrets/db.env 2>/dev/null)
    if [[ "$perms" == "640" ]] || [[ "$perms" == "0640" ]]; then
        echo -e "${GREEN}✓${NC} Permissions db.env OK (640)"
    else
        echo -e "${YELLOW}⚠${NC} Permissions db.env: $perms (recommandé: 640)"
    fi
else
    echo -e "${RED}✗${NC} db.env NOT FOUND"
fi
echo ""

echo -e "${BLUE}7. ESPÉRANCE DE SERVICES${NC}"
echo "==================================="
echo -e "${GREEN}PHP-Admin:${NC} http://localhost/php-admin/"
echo -e "${GREEN}Admin user:${NC} admin / Admin@Secure123!"
echo -e "${GREEN}Test user:${NC} wifi_user / password123"
echo -e "${GREEN}FreeRADIUS:${NC} localhost:1812 (secret: testing123)"
echo ""

echo -e "${BLUE}8. PRÙCHAINÉS ÉTAPES${NC}"
echo "==================================="
echo "1. Accédez à http://localhost/php-admin/"
echo "2. Connectez-vous avec admin/Admin@Secure123!"
echo "3. Gérez les utilisateurs Wi-Fi"
echo "4. Testez RADIUS avec: radtest wifi_user password123 localhost 1812 testing123"
echo ""

echo -e "${GREEN}✓ Diagnostic terminé!${NC}"

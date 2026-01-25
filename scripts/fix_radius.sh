#!/bin/bash
# ============================================================================
# SAE501 - Script de Correction FreeRADIUS
# Diagnostique et corrige les problèmes courants
# ============================================================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CORRECTION FreeRADIUS - SAE501         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✗${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${BLUE}1. VÉRIFICATION FREERADIUS${NC}"
echo "==================================="

if systemctl is-active freeradius > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} FreeRADIUS est actif"
else
    echo -e "${RED}✗${NC} FreeRADIUS est INACTIF"
    echo -e "${YELLOW}Tentative de démarrage...${NC}"
    systemctl start freeradius
    sleep 2
    if systemctl is-active freeradius > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} FreeRADIUS démarré avec succès"
    else
        echo -e "${RED}✗${NC} Impossible de démarrer FreeRADIUS"
        echo -e "${YELLOW}Logs:${NC}"
        systemctl status freeradius || true
    fi
fi

echo ""
echo -e "${BLUE}2. VÉRIFICATION CONFIGURATION${NC}"
echo "==================================="

# Vérifier clients.conf
if [[ -f /etc/freeradius/3.0/clients.conf ]]; then
    CLIENTS_CONF="/etc/freeradius/3.0/clients.conf"
elif [[ -f /etc/freeradius/clients.conf ]]; then
    CLIENTS_CONF="/etc/freeradius/clients.conf"
else
    CLIENTS_CONF="/etc/freeradius/3.0/clients.conf"
fi

echo "Client configuration: $CLIENTS_CONF"

if grep -q 'client localhost' "$CLIENTS_CONF" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Client localhost configuré"
else
    echo -e "${RED}✗${NC} Client localhost NOT configuré - Ajout en cours..."
    cat >> "$CLIENTS_CONF" << 'EOF'

client localhost {
    ipaddr = 127.0.0.1
    ipv6addr = ::1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}
EOF
    echo -e "${GREEN}✓${NC} Client localhost ajouté"
fi

if grep -q '127.0.0.1' "$CLIENTS_CONF" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Client 127.0.0.1 configuré"
else
    echo -e "${RED}✗${NC} Client 127.0.0.1 NOT configuré - Ajout en cours..."
    cat >> "$CLIENTS_CONF" << 'EOF'

client 127.0.0.1 {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}
EOF
    echo -e "${GREEN}✓${NC} Client 127.0.0.1 ajouté"
fi

echo ""
echo -e "${BLUE}3. CORRECTION PERMISSIONS${NC}"
echo "==================================="

chown -R freerad:freerad /etc/freeradius 2>/dev/null && echo -e "${GREEN}✓${NC} Permissions /etc/freeradius corrigées"
chown -R freerad:freerad /var/lib/freeradius 2>/dev/null && echo -e "${GREEN}✓${NC} Permissions /var/lib/freeradius corrigées"
chown -R freerad:freerad /var/log/freeradius 2>/dev/null && echo -e "${GREEN}✓${NC} Permissions /var/log/freeradius corrigées"

echo ""
echo -e "${BLUE}4. REDÉMARRAGE SERVICE${NC}"
echo "==================================="

systemctl stop freeradius 2>/dev/null || true
echo -e "${YELLOW}Arrêt du service...${NC}"
sleep 1

systemctl start freeradius 2>/dev/null || true
echo -e "${YELLOW}Redémarrage du service...${NC}"
sleep 3

if systemctl is-active freeradius > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} FreeRADIUS actif"
else
    echo -e "${RED}✗${NC} FreeRADIUS n'est pas actif"
fi

echo ""
echo -e "${BLUE}5. TEST RADIUS${NC}"
echo "==================================="

if command -v radtest &> /dev/null; then
    echo -e "${YELLOW}Exécution du test RADIUS...${NC}"
    echo "Commande: radtest wifi_user password123 localhost 1812 testing123"
    echo ""
    
    if radtest wifi_user password123 localhost 1812 testing123 2>&1 | tee /tmp/radtest_output.log; then
        echo -e "${GREEN}✓${NC} Test RADIUS réussi"
    else
        echo -e "${YELLOW}⚠${NC} Sortie du test RADIUS - vérification logs"
        if grep -q "Access-Accept" /tmp/radtest_output.log 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Authentification réussie (Access-Accept)"
        elif grep -q "Received" /tmp/radtest_output.log 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Réponse RADIUS reçue"
        elif grep -q "No reply" /tmp/radtest_output.log 2>/dev/null; then
            echo -e "${RED}✗${NC} Pas de réponse du serveur"
            echo -e "${YELLOW}Causes possibles:${NC}"
            echo "  1. FreeRADIUS n'écoute pas sur le port 1812"
            echo "  2. Configuration cliente incorrect"
            echo "  3. Utilisateur wifi_user pas créé dans la base"
        fi
    fi
else
    echo -e "${RED}✗${NC} radtest non disponible"
fi

echo ""
echo -e "${BLUE}6. VÉRIFICATION PORTS${NC}"
echo "==================================="

if netstat -tuln 2>/dev/null | grep -q ":1812 "; then
    echo -e "${GREEN}✓${NC} Port 1812 en écoute"
else
    echo -e "${YELLOW}⚠${NC} Port 1812 n'est pas en écoute (PEUT ÈTRE NORMAL - UDP)"
    echo -e "${YELLOW}Vérification avec lsof:${NC}"
    lsof -i :1812 2>/dev/null || echo "Pas de processus sur le port 1812"
fi

echo ""
echo -e "${BLUE}7. LOGS FREERADIUS${NC}"
echo "==================================="
echo "Dernières lignes des logs:"
echo ""
tail -10 /var/log/freeradius/radius.log 2>/dev/null || echo "Pas de log disponible"

echo ""
echo -e "${GREEN}✓ CORRECTION TERMINÉE!${NC}"
echo ""
echo -e "${YELLOW}Pour tester manuellement:${NC}"
echo "  radtest wifi_user password123 localhost 1812 testing123"
echo ""
echo -e "${YELLOW}Pour voir les logs en temps réel:${NC}"
echo "  sudo tail -f /var/log/freeradius/radius.log"
echo ""
echo -e "${YELLOW}Pour vérifier le service:${NC}"
echo "  sudo systemctl status freeradius"
echo ""

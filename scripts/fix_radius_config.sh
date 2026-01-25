#!/bin/bash
# ============================================================================
# SAE501 - Script de réparation de la configuration FreeRADIUS
# Corrige les problèmes de configuration courants
# ============================================================================

set -euo pipefail

echo ""
echo "========================================"
echo "Réparation FreeRADIUS"
echo "========================================"
echo ""

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Ce script doit être exécuté en tant que root"
   exit 1
fi

echo "[1/5] Arrêt du service FreeRADIUS..."
sudo systemctl stop freeradius 2>/dev/null || true
sleep 1
echo "[OK] FreeRADIUS arrêté"
echo ""

echo "[2/5] Nettoyage des modules en conflit..."
rm -f /etc/freeradius/3.0/mods-enabled/eap-peap
rm -f /etc/freeradius/3.0/mods-enabled/sql-sae501  
echo "[OK] Modules supprimés"
echo ""

echo "[3/5] Verification de EAP..."
if [ -f "/etc/freeradius/3.0/mods-available/eap" ]; then
    if grep -q 'virtual_server = "inner-tunnel"' /etc/freeradius/3.0/mods-available/eap; then
        echo "[OK] EAP est correct"
    else
        echo "[WARNING] EAP n'a pas virtual_server, correction en cours..."
        # Le fichier eap.conf du repo devrait avoir virtual_server
        echo "[HINT] Vérifiez que /opt/SAE501/config/eap.conf a 'virtual_server = \"inner-tunnel\"'"
    fi
else
    echo "[ERROR] Module EAP non trouvé"
fi
echo ""

echo "[4/5] Vérification de SQL..."
if [ -f "/etc/freeradius/3.0/mods-available/sql" ]; then
    if grep -q 'driver = "rlm_sql_mysql"' /etc/freeradius/3.0/mods-available/sql; then
        echo "[OK] SQL est correct"
    else
        echo "[ERROR] SQL n'a pas le bon driver"
    fi
    
    if grep -q 'authorize_check_query\|authorize_reply_query' /etc/freeradius/3.0/mods-available/sql; then
        echo "[WARNING] SQL contient des queries personnalisées qui peuvent causer des erreurs"
        echo "[INFO] Les queries personnalisées ont été supprimées de la version corrigée"
    fi
else
    echo "[ERROR] Module SQL non trouvé"
fi
echo ""

echo "[5/5] Démarrage de FreeRADIUS..."
sudo systemctl start freeradius || true
sleep 2

if sudo systemctl is-active freeradius > /dev/null 2>&1; then
    echo "[OK] FreeRADIUS démarré avec succès"
    echo ""
    echo "========================================"
    echo "Réparation terminée !"
    echo "========================================"
else
    echo "[ERROR] FreeRADIUS ne démarre toujours pas"
    echo ""
    echo "Diagnostic complet:"
    sudo /usr/sbin/freeradius -X 2>&1 | head -50
    exit 1
fi

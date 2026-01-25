#!/bin/bash
# ============================================================================
# SAE501 - Installation propre après correction de bugs
# Réinstalle tout en partant d'une ardoise vierge
# ============================================================================

set -euo pipefail

echo ""
echo "========================================"
echo "Installation PROPRE SAE501"
echo "========================================"
echo ""

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Ce script doit être exécuté en tant que root"
   exit 1
fi

echo "[AVERTISSEMENT] Cette procédure va:"
echo "  - Arrêter FreeRADIUS"
echo "  - Supprimer les données RADIUS"
echo "  - Réinitialiser MySQL"
echo "  - Réinstaller tous les services"
echo ""
read -p "Continuer? (oui/non) " response

if [ "$response" != "oui" ]; then
    echo "Annulation."
    exit 0
fi

echo ""
echo "[1/6] Arrêt des services..."
sudo systemctl stop freeradius 2>/dev/null || true
sudo systemctl stop mysql 2>/dev/null || true
sudo systemctl stop mariadb 2>/dev/null || true
echo "[OK]"
echo ""

echo "[2/6] Nettoyage des données RADIUS..."
sudo mysql -u root -pécho "DROP DATABASE IF EXISTS radius;" 2>/dev/null || true
echo "[OK]"
echo ""

echo "[3/6] Suppression des configs FreeRADIUS..."
rm -f /etc/freeradius/3.0/mods-enabled/sql*
rm -f /etc/freeradius/3.0/mods-enabled/eap*
echo "[OK]"
echo ""

echo "[4/6] Démarrage de MySQL..."
sudo systemctl start mysql || sudo systemctl start mariadb
sleep 2
echo "[OK]"
echo ""

echo "[5/6] Installation complète..."
SCRIPT_DIR="$(cd "$(dirname \"${BASH_SOURCE[0]}\")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo ""
echo "Exécution: sudo bash $PROJECT_ROOT/scripts/install_all.sh"
echo ""
sudo bash "$PROJECT_ROOT/scripts/install_all.sh"

echo ""
echo "[6/6] Fin"
echo ""
echo "========================================"
echo "Installation terminée !"
echo "========================================"
echo ""
echo "Voir les accès:"
echo "  bash $PROJECT_ROOT/scripts/show_credentials.sh"
echo ""
echo "Vérifier:"
echo "  bash $PROJECT_ROOT/scripts/test_installation.sh"
echo ""

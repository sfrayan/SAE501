#!/bin/bash
#############################################################################
# QUICK_RUN.sh - Lance l'installation SAE501 en une commande
# Usage:
#   chmod +x scripts/QUICK_RUN.sh
#   sudo bash scripts/QUICK_RUN.sh
#############################################################################

set -e

echo ""
echo "✨✨✨ SAE501 INSTALLATION RAPIDE ✨✨✨"
echo ""

# Vérifier root
if [[ $EUID -ne 0 ]]; then
    echo "[❌] Ce script doit être exécuté en tant que root"
    echo "Lancez avec: sudo bash scripts/QUICK_RUN.sh"
    exit 1
fi

echo "[✅] Vérification root: OK"
echo ""
echo "[✨] Début de l'installation dans 3 secondes..."
sleep 3
echo ""

# Lancer l'installation complète
bash "$(dirname "$0")/install_all.sh"

echo ""
echo "[✅] Installation terminée!"
echo ""
echo "Commandes utiles:"
echo "  - Vérifier FreeRADIUS:  sudo systemctl status freeradius"
echo "  - Vérifier Apache:       sudo systemctl status apache2"
echo "  - Vérifier MySQL:        sudo systemctl status mysql"
echo "  - Vérifier tout:        bash scripts/diagnostics.sh"
echo ""

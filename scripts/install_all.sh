#!/bin/bash

################################################################################
# SAE501 - Installation complète de tous les services
# Automatise l'installation de RADIUS, PHP-Admin et Wazuh en une seule commande
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RADIUS_CONFIG="$PROJECT_DIR/radius"
PHP_ADMIN_DIR="$PROJECT_DIR/php-admin"
WAZUH_CONFIG="$PROJECT_DIR/wazuh"
DOCS_DIR="$PROJECT_DIR/docs"

# Identifiants par défaut (DOIVENT être changés en production)
RADIUS_USER="radiusadmin"
RADIUS_PASS="Radius@Secure123!"
DB_ROOT_PASS="MySQL@Root123!"
DB_USER="radiusapp"
DB_PASS="RadiusApp@Secure123!"
PHP_ADMIN_USER="admin"
PHP_ADMIN_PASS="Admin@Secure123!"

echo -e "${BLUE}============================================"
echo -e "SAE501 - Installation complète${NC}"
echo -e "${BLUE}============================================${NC}\n"

# Vérification des droits root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Erreur: Ce script doit être exécuté en tant que root${NC}"
    exit 1
fi

# Mise à jour du système
echo -e "${BLUE}[1/5] Mise à jour du système...${NC}"
apt-get update -qq
apt-get upgrade -y -qq

# Installation de RADIUS
echo -e "${BLUE}[2/5] Installation de FreeRADIUS...${NC}"
if bash "$SCRIPT_DIR/install_radius.sh" "$RADIUS_USER" "$RADIUS_PASS" "$DB_ROOT_PASS" "$DB_USER" "$DB_PASS"; then
    echo -e "${GREEN}✓ FreeRADIUS installé avec succès${NC}"
else
    echo -e "${RED}✗ Erreur lors de l'installation de FreeRADIUS${NC}"
    exit 1
fi

# Installation de PHP-Admin
echo -e "${BLUE}[3/5] Installation de PHP-Admin...${NC}"
if bash "$SCRIPT_DIR/install_php_admin.sh" "$PHP_ADMIN_USER" "$PHP_ADMIN_PASS" "$DB_USER" "$DB_PASS"; then
    echo -e "${GREEN}✓ PHP-Admin installé avec succès${NC}"
else
    echo -e "${RED}✗ Erreur lors de l'installation de PHP-Admin${NC}"
    exit 1
fi

# Installation de Wazuh
echo -e "${BLUE}[4/5] Installation de Wazuh...${NC}"
if bash "$SCRIPT_DIR/install_wazuh.sh"; then
    echo -e "${GREEN}✓ Wazuh installé avec succès${NC}"
else
    echo -e "${RED}✗ Erreur lors de l'installation de Wazuh${NC}"
    exit 1
fi

# Hardening du système
echo -e "${BLUE}[5/5] Hardening du système...${NC}"
if bash "$SCRIPT_DIR/install_hardening.sh"; then
    echo -e "${GREEN}✓ Hardening appliqué avec succès${NC}"
else
    echo -e "${RED}✗ Erreur lors du hardening${NC}"
    # Ne pas quitter, le hardening n'est pas critique
fi

# Diagnostic final
echo -e "\n${BLUE}=== Diagnostic final ===${NC}"
bash "$SCRIPT_DIR/diagnostics.sh"

# Afficher les identifiants et URLs
echo -e "\n${GREEN}=== Installation terminée ===${NC}"
echo -e "\n${YELLOW}Identifiants et accès:${NC}"
echo -e "${BLUE}RADIUS:${NC}"
echo "  Utilisateur: $RADIUS_USER"
echo "  Mot de passe: $RADIUS_PASS (CHANGEZ-LE EN PRODUCTION)"
echo -e "${BLUE}Base de données:${NC}"
echo "  Utilisateur: $DB_USER"
echo "  Mot de passe: $DB_PASS (CHANGEZ-LE EN PRODUCTION)"
echo -e "${BLUE}PHP-Admin:${NC}"
echo "  URL: http://localhost/admin"
echo "  Utilisateur: $PHP_ADMIN_USER"
echo "  Mot de passe: $PHP_ADMIN_PASS (CHANGEZ-LE EN PRODUCTION)"
echo -e "${BLUE}Wazuh Dashboard:${NC}"
echo "  URL: http://localhost:5601"
echo "  Utilisateur: admin"
echo "  Mot de passe: SecurePassword123! (CHANGEZ-LE EN PRODUCTION)"

echo -e "\n${YELLOW}⚠  IMPORTANT EN PRODUCTION:${NC}"
echo "  1. Changez TOUS les mots de passe par défaut"
echo "  2. Activez SSL/TLS pour HTTPS"
echo "  3. Configurez les pare-feu appropriatement"
echo "  4. Lisez la documentation dans $DOCS_DIR"
echo "  5. Consultez les logs: systemctl status radiusd"
echo "  6. Tests: bash $SCRIPT_DIR/diagnostics.sh"

echo -e "\n${GREEN}Setup terminé! Le système est opérationnel.${NC}\n"

exit 0

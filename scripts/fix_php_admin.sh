#!/bin/bash

###############################################
# fix_php_admin.sh
# Diagnostic et correction de PHP-Admin
# Usage: sudo bash scripts/fix_php_admin.sh
###############################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PHP_ADMIN_SRC="$PROJECT_ROOT/php-admin"
PHP_ADMIN_DEST="/var/www/html/php-admin"
PAGES_DEST="$PHP_ADMIN_DEST/pages"
LOG_FILE="/tmp/fix_php_admin_$(date +%Y%m%d_%H%M%S).log"

log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"; }
log_err()  { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║  Correction PHP-Admin pour SAE 5.01    ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}\n"

# 1. Vérifier root
if [[ $EUID -ne 0 ]]; then
    log_err "Ce script doit être exécuté en tant que root (sudo)"
fi

# 2. Diagnostic
log_info "=== DIAGNOSTIC ==="

log_info "Vérifiant la structure des répertoires..."
if [[ ! -d "$PHP_ADMIN_SRC" ]]; then
    log_err "Répertoire source non trouvé: $PHP_ADMIN_SRC"
fi
log_ok "Répertoire source OK"

if [[ ! -d "$PHP_ADMIN_DEST" ]]; then
    log_warn "Répertoire destination n'existe pas, création en cours..."
    mkdir -p "$PHP_ADMIN_DEST"
fi

if [[ ! -d "$PAGES_DEST" ]]; then
    log_warn "Répertoire pages n'existe pas, création en cours..."
    mkdir -p "$PAGES_DEST"
fi

# 3. Nettoyer et copier les fichiers
log_info "Nettoyage des fichiers existants..."
rm -rf "$PHP_ADMIN_DEST"/*
log_ok "Fichiers nettoyés"

log_info "Copie des fichiers PHP-Admin..."
cp -v "$PHP_ADMIN_SRC"/*.php "$PHP_ADMIN_DEST/" >> "$LOG_FILE" 2>&1
log_ok "Fichiers PHP copiés"

if [[ -d "$PHP_ADMIN_SRC/pages" ]]; then
    cp -v "$PHP_ADMIN_SRC/pages"/*.php "$PAGES_DEST/" >> "$LOG_FILE" 2>&1
    log_ok "Pages copiées"
else
    log_warn "Aucun fichier de pages trouvé à copier"
fi

# 4. Configurer les permissions
log_info "Configuration des permissions..."
chown -R www-data:www-data "$PHP_ADMIN_DEST"
chmod -R 755 "$PHP_ADMIN_DEST"
chmod 644 "$PHP_ADMIN_DEST"/*.php
if [[ -d "$PAGES_DEST" ]]; then
    chmod 644 "$PAGES_DEST"/*.php 2>/dev/null || true
fi
log_ok "Permissions configurées"

# 5. Créer un fichier de démarrage simple
log_info "Création d'une page de démarrage simple..."
cat > "$PHP_ADMIN_DEST/test.php" << 'EOF'
<?php
session_start();

// Informations de connexion
$db_host = 'localhost';
$db_user = 'radiususer';
$db_pass = 'eovNQTvgpeBvBY056sxWDDXOo';
$db_name = 'radius';

echo "<h1>Test PHP-Admin</h1>";
echo "<p>Informations détectées:</p>";
echo "<ul>";
echo "<li>PHP Version: " . phpversion() . "</li>";
echo "<li>MySQL Extension: " . (extension_loaded('mysqli') ? 'OK' : 'MANQUANT') . "</li>";
echo "<li>Sessions: " . (ini_get('session.save_path') ? ini_get('session.save_path') : '/tmp') . "</li>";
echo "</ul>";

// Test de connexion MySQL
echo "<h2>Test de connexion MySQL</h2>";
try {
    $conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
    if ($conn->connect_error) {
        echo "<p style='color: red;'>Erreur: " . $conn->connect_error . "</p>";
    } else {
        echo "<p style='color: green;'>Connexion réussie!</p>";
        $conn->close();
    }
} catch (Exception $e) {
    echo "<p style='color: red;'>Exception: " . $e->getMessage() . "</p>";
}

echo "<p><a href='/php-admin/'>← Retour à PHP-Admin</a></p>";
?>
EOF
log_ok "Page de test créée"

# 6. Activer PHP-FPM et Apache2
log_info "Activation des services..."
sudo systemctl enable php-fpm >> "$LOG_FILE" 2>&1 || true
sudo systemctl restart php-fpm >> "$LOG_FILE" 2>&1 || true
sudo systemctl enable apache2 >> "$LOG_FILE" 2>&1
sudo systemctl restart apache2 >> "$LOG_FILE" 2>&1
log_ok "Services redémarrés"

# 7. Vérifier les ports
log_info "Vérification des ports..."
if netstat -tuln 2>/dev/null | grep -q ":80 "; then
    log_ok "Apache écoute sur le port 80"
else
    log_warn "Apache n'écoute pas sur le port 80"
fi

# 8. Résumé
echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Correction appliquée!              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

echo "📋 Informations:"
echo "  Source: $PHP_ADMIN_SRC"
echo "  Destination: $PHP_ADMIN_DEST"
echo "  Log: $LOG_FILE"
echo ""
echo "🌐 Accès:"
echo "  Test: http://localhost/php-admin/test.php"
echo "  Admin: http://localhost/php-admin/"
echo ""
echo "🧪 Commandes de diagnostic:"
echo "  Logs Apache: sudo tail -f /var/log/apache2/error.log"
echo "  Logs PHP: sudo tail -f /var/log/php-fpm.log"
echo "  Vérifier fichiers: ls -la $PHP_ADMIN_DEST/"
echo ""

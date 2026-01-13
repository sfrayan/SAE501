#!/bin/bash

###############################################
# install_radius_simple.sh
# Installation FreeRADIUS simplifiée pour Debian 11
# Usage: sudo bash scripts/install_radius_simple.sh
###############################################

set -e  # Arrêter si erreur
set -u  # Erreur si variable non définie

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/install_radius_$(date +%Y%m%d_%H%M%S).log"

# Fonctions
log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"; }
log_err()  { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

# Vérifier root
if [[ $EUID -ne 0 ]]; then
    log_err "Ce script doit être exécuté en tant que root (sudo)"
fi

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║  Installation FreeRADIUS pour SAE 5.01 ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}\n"

# 1. Vérifier MySQL/MariaDB
log_info "Vérification MySQL/MariaDB..."
if ! systemctl is-active --quiet mysql 2>/dev/null && ! systemctl is-active --quiet mariadb 2>/dev/null; then
    log_warn "MySQL/MariaDB n'est pas en cours d'exécution"
    log_info "Installation de MariaDB..."
    apt-get update -qq
    apt-get install -y mariadb-server >> "$LOG_FILE" 2>&1
    systemctl start mariadb
    log_ok "MariaDB installé et démarré"
else
    log_ok "MySQL/MariaDB actif"
fi

# 2. Installer FreeRADIUS
log_info "Installation de FreeRADIUS..."
apt-get install -y freeradius freeradius-mysql freeradius-utils \
    >> "$LOG_FILE" 2>&1
log_ok "FreeRADIUS installé"

# 3. Créer utilisateur MySQL et base RADIUS
log_info "Configuration base de données RADIUS..."
mysql -u root << 'EOF' >> "$LOG_FILE" 2>&1
-- Créer utilisateur si n'existe pas
CREATE USER IF NOT EXISTS 'radius_app'@'localhost' IDENTIFIED BY 'Secure!Pass@123';
GRANT ALL PRIVILEGES ON radius.* TO 'radius_app'@'localhost';
FLUSH PRIVILEGES;

-- Créer base de données
CREATE DATABASE IF NOT EXISTS radius;
USE radius;
EOF
log_ok "Utilisateur MySQL 'radius_app' créé"

# 4. Importer schéma RADIUS
log_info "Création tables RADIUS..."
if [[ -f "$PROJECT_ROOT/radius/sql/create_tables.sql" ]]; then
    mysql -u root radius < "$PROJECT_ROOT/radius/sql/create_tables.sql" >> "$LOG_FILE" 2>&1
    log_ok "Tables RADIUS créées"
else
    log_warn "Fichier create_tables.sql non trouvé - créer tables manuellement"
fi

# 5. Créer utilisateurs test en base
log_info "Ajout utilisateurs de test..."
mysql -u radius_app -p'Secure!Pass@123' radius << 'EOF' >> "$LOG_FILE" 2>&1
DELETE FROM radcheck; -- Réinitialiser
INSERT INTO radcheck VALUES
    (NULL, 'alice@gym.fr', 'Cleartext-Password', ':=', 'Alice@123!'),
    (NULL, 'bob@gym.fr', 'Cleartext-Password', ':=', 'Bob@456!'),
    (NULL, 'charlie@gym.fr', 'Cleartext-Password', ':=', 'Charlie@789!'),
    (NULL, 'david@gym.fr', 'Cleartext-Password', ':=', 'David@2026!');
EOF
log_ok "Utilisateurs de test créés"

# 6. Configurer clients RADIUS
log_info "Configuration des clients RADIUS..."
cat > /etc/freeradius/3.0/clients.conf << 'EOF'
# Localhost (pour tests)
client 127.0.0.1 {
    ipaddr = 127.0.0.1/32
    secret = testing123
}

# Réseau LAN (192.168.10.0/24) - pour routeur TL-MR100
client 192.168.10.0/24 {
    ipaddr = 192.168.10.0/24
    secret = Pj8K2qL9xR5wM3nP7dF4vB6tH1sQ9cZ2
}
EOF
log_ok "Clients RADIUS configurés"

# 7. Générer certificats TLS (pour PEAP)
log_info "Génération certificats TLS..."
cd /etc/freeradius/3.0/certs
make >> "$LOG_FILE" 2>&1 || log_warn "Certificats possiblement déjà générés"
cd - > /dev/null
log_ok "Certificats prêts"

# 8. Configurer permissions
log_info "Configuration des permissions..."
chown -R root:freerad /etc/freeradius/3.0
chmod -R 750 /etc/freeradius/3.0
chmod 640 /etc/freeradius/3.0/clients.conf
mkdir -p /var/log/freeradius
chown freerad:freerad /var/log/freeradius
chmod 750 /var/log/freeradius
log_ok "Permissions configurées"

# 9. Démarrer FreeRADIUS
log_info "Démarrage de FreeRADIUS..."
systemctl enable freeradius >> "$LOG_FILE" 2>&1
systemctl restart freeradius >> "$LOG_FILE" 2>&1
sleep 2

if systemctl is-active --quiet freeradius; then
    log_ok "FreeRADIUS en cours d'exécution"
else
    log_err "Erreur démarrage FreeRADIUS - voir logs: sudo journalctl -u freeradius"
fi

# 10. Test authentification
log_info "Test authentification RADIUS..."
if radtest alice@gym.fr Alice@123! 127.0.0.1 1812 testing123 >> "$LOG_FILE" 2>&1; then
    log_ok "Test d'authentification RÉUSSI ✓"
else
    log_warn "Test échoué - vérifier logs: sudo journalctl -u freeradius -n 30"
fi

# 11. Firewall
log_info "Configuration firewall (UFW)..."
if command -v ufw &>/dev/null; then
    ufw allow 1812/udp >> "$LOG_FILE" 2>&1 || true
    ufw allow 1813/udp >> "$LOG_FILE" 2>&1 || true
    ufw allow 3306/tcp >> "$LOG_FILE" 2>&1 || true
    log_ok "Ports ouverts: 1812-1813 UDP, 3306 TCP"
fi

# Résumé
echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Installation réussie!               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

echo "📊 Statut:"
echo "  • FreeRADIUS: $(systemctl is-active freeradius)"
echo "  • MariaDB:    $(systemctl is-active mariadb || systemctl is-active mysql)"
echo "  • Logs: $LOG_FILE"
echo ""
echo "🧪 Tester:"
echo "  $ radtest alice@gym.fr Alice@123! 127.0.0.1 1812 testing123"
echo ""
echo "📈 Voir utilisateurs en base:"
echo "  $ mysql -u radius_app -pSecure!Pass@123 radius -e 'SELECT username FROM radcheck;'"
echo ""
echo "🔧 Redémarrer le service:"
echo "  $ sudo systemctl restart freeradius"
echo ""
echo "📝 Voir les logs:"
echo "  $ sudo tail -f /var/log/freeradius/radius.log"
echo ""
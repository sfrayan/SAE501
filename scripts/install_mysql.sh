#!/bin/bash
# ============================================================================
# SAE501 - Installation et initialisation MariaDB/MySQL pour RADIUS
# Base de données sécurisée, utilisateur limité, audit activé
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_mysql_install.log"

log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

error_exit() {
    log_message "ERROR" "$@"
    exit 1
}

if [[ $EUID -ne 0 ]]; then
   error_exit "Ce script doit être exécuté en tant que root"
fi

log_message "INFO" "Démarrage de l'installation MariaDB/MySQL"

# Install MySQL/MariaDB
log_message "INFO" "Installation du package MySQL/MariaDB..."
apt-get install -y mariadb-server > /dev/null 2>&1 || apt-get install -y mysql-server > /dev/null 2>&1 || error_exit "Échec installation MySQL"

# Generate random password for radiususer
RADIUS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

log_message "INFO" "Mots de passe générés aléatoirement"

# Determine service name (mariadb or mysql)
SERVICE_NAME="mysql"
if systemctl list-unit-files | grep -q mariadb.service; then
    SERVICE_NAME="mariadb"
fi

log_message "INFO" "Service détecté: $SERVICE_NAME"

# Start service
log_message "INFO" "Démarrage de $SERVICE_NAME..."
sudo systemctl enable "$SERVICE_NAME" 2>/dev/null || true
sudo systemctl restart "$SERVICE_NAME" 2>/dev/null || true

if ! systemctl is-active "$SERVICE_NAME" > /dev/null 2>&1; then
    error_exit "Échec du démarrage de $SERVICE_NAME"
fi

log_message "SUCCESS" "$SERVICE_NAME démarré"

# Wait for MySQL to be ready
sleep 3

# Clean up any existing installation
log_message "INFO" "Nettoyage des installations précédentes..."
mysql -u root << MYSQL_CLEANUP
DROP DATABASE IF EXISTS radius;
DROP USER IF EXISTS 'radiususer'@'localhost';
DROP USER IF EXISTS 'sae501_php'@'localhost';
FLUSH PRIVILEGES;
MYSQL_CLEANUP

log_message "INFO" "Données précédentes nettoyées"

# Secure MariaDB installation
log_message "INFO" "Sécurisation de MariaDB/MySQL..."
mysql -u root << MYSQL_SECURE_SCRIPT
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove root remote login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Flush privileges
FLUSH PRIVILEGES;
MYSQL_SECURE_SCRIPT

log_message "SUCCESS" "MariaDB/MySQL sécurisée"

# Create radius database and user
log_message "INFO" "Création de la base de données RADIUS et utilisateur..."
mysql -u root << MYSQL_CREATE_DB
CREATE DATABASE IF NOT EXISTS radius DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'radiususer'@'localhost' IDENTIFIED BY '$RADIUS_PASSWORD';
GRANT ALL PRIVILEGES ON radius.* TO 'radiususer'@'localhost';
FLUSH PRIVILEGES;
MYSQL_CREATE_DB

log_message "SUCCESS" "Base de données RADIUS créée"
log_message "SUCCESS" "Utilisateur radiususer créé (mot de passe: $RADIUS_PASSWORD)"

# Wait for user to be available
log_message "INFO" "Attente de la disponibilité du nouvel utilisateur..."
sleep 2

# Test connection before continuing
log_message "INFO" "Vérification de la connexion radiususer..."
for i in {1..5}; do
    if mysql -u radiususer -p"$RADIUS_PASSWORD" radius -e "SELECT 1;" > /dev/null 2>&1; then
        log_message "SUCCESS" "Connexion radiususer OK"
        break
    elif [ $i -lt 5 ]; then
        log_message "WARNING" "Tentative $i/5 - En attente..."
        sleep 1
    else
        error_exit "Impossible de se connecter avec radiususer après 5 tentatives"
    fi
done

# Create RADIUS schema tables (FreeRADIUS schema) - INCLUDES NAS TABLE
log_message "INFO" "Création du schéma RADIUS..."
mysql -u radiususer -p"$RADIUS_PASSWORD" radius << 'MYSQL_RADIUS_SCHEMA'
CREATE TABLE IF NOT EXISTS nas (
  id int(10) unsigned NOT NULL auto_increment,
  nasname varchar(128) NOT NULL,
  shortname varchar(32),
  type varchar(30) NOT NULL default 'other',
  ports int(5),
  secret varchar(60) NOT NULL default 'secret',
  server varchar(64),
  community varchar(50),
  description varchar(200) default 'RADIUS Client',
  PRIMARY KEY  (id),
  KEY nasname (nasname)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS radcheck (
  id int(11) unsigned NOT NULL auto_increment,
  username varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL default '==',
  value varchar(253) NOT NULL default '',
  PRIMARY KEY  (id),
  KEY username (username(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS radreply (
  id int(11) unsigned NOT NULL auto_increment,
  username varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL default '=',
  value varchar(253) NOT NULL default '',
  PRIMARY KEY  (id),
  KEY username (username(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS radusergroup (
  username varchar(64) NOT NULL default '',
  groupname varchar(64) NOT NULL default '',
  priority int(11) NOT NULL default '1',
  PRIMARY KEY  (username,groupname),
  KEY username (username(32)),
  KEY groupname (groupname(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS radgroupcheck (
  id int(11) unsigned NOT NULL auto_increment,
  groupname varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL default '==',
  value varchar(253) NOT NULL default '',
  PRIMARY KEY  (id),
  KEY groupname (groupname(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS radgroupreply (
  id int(11) unsigned NOT NULL auto_increment,
  groupname varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL default '=',
  value varchar(253) NOT NULL default '',
  PRIMARY KEY  (id),
  KEY groupname (groupname(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS radacct (
  radacctid bigint(21) NOT NULL auto_increment,
  acctsessionid varchar(64) NOT NULL default '',
  acctuniqueid varchar(32) NOT NULL default '',
  username varchar(64) NOT NULL default '',
  realm varchar(64) default '',
  nasipaddress varchar(15) NOT NULL default '',
  nasportid varchar(15) default NULL,
  nasporttype varchar(32) default NULL,
  acctstarttime datetime NULL default NULL,
  acctupdatetime datetime NULL default NULL,
  acctstoptime datetime NULL default NULL,
  acctsessiontime int(12) default NULL,
  acctauthentic varchar(32) default NULL,
  connectinfo_start varchar(50) default NULL,
  connectinfo_stop varchar(50) default NULL,
  acctinputoctets bigint(20) default NULL,
  acctoutputoctets bigint(20) default NULL,
  calledstationid varchar(50) default NULL,
  callingstationid varchar(50) default NULL,
  acctterminatecause varchar(32) default NULL,
  servicetype varchar(32) default NULL,
  framedprotocol varchar(32) default NULL,
  framedipaddress varchar(15) default NULL,
  acctstartdelay int(12) default NULL,
  acctstopdelay int(12) default NULL,
  xascendsessionsupported int(1) default NULL,
  PRIMARY KEY  (radacctid),
  UNIQUE KEY acctuniqueid (acctuniqueid),
  KEY username (username),
  KEY framedipaddress (framedipaddress),
  KEY acctsessionid (acctsessionid),
  KEY acctstarttime (acctstarttime),
  KEY acctstoptime (acctstoptime),
  KEY nasipaddress (nasipaddress)
) ENGINE=Innodb DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS radpostauth (
  id int(11) unsigned NOT NULL auto_increment,
  username varchar(64) NOT NULL default '',
  pass varchar(64) NOT NULL default '',
  reply varchar(32) NOT NULL default '',
  authdate timestamp NOT NULL default CURRENT_TIMESTAMP,
  PRIMARY KEY  (id),
  KEY username (username(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
MYSQL_RADIUS_SCHEMA

log_message "SUCCESS" "Schéma RADIUS créé"

# Create additional tables for SAE501
log_message "INFO" "Création des tables SAE501 supplémentaires..."
mysql -u radiususer -p"$RADIUS_PASSWORD" radius << MYSQL_CREATE_TABLES

-- Table for audit logs of admin actions
CREATE TABLE IF NOT EXISTS admin_audit (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    admin_user VARCHAR(255) NOT NULL,
    action VARCHAR(50) NOT NULL,
    target_user VARCHAR(255),
    details TEXT,
    ip_address VARCHAR(45),
    KEY idx_timestamp (timestamp),
    KEY idx_admin_user (admin_user),
    KEY idx_action (action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table for tracking authentication attempts
CREATE TABLE IF NOT EXISTS auth_attempts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(255) NOT NULL,
    status ENUM('success', 'failure') NOT NULL,
    nas_ip_address VARCHAR(45),
    caller_station_id VARCHAR(50),
    failure_reason VARCHAR(255),
    KEY idx_timestamp (timestamp),
    KEY idx_username (username),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table for user status tracking
CREATE TABLE IF NOT EXISTS user_status (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME,
    login_count INT DEFAULT 0,
    KEY idx_active (active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

MYSQL_CREATE_TABLES

log_message "SUCCESS" "Tables SAE501 créées"

# Create MariaDB user for PHP admin interface
log_message "INFO" "Création de l'utilisateur PHP admin..."
mysql -u root << MYSQL_CREATE_PHPUSER
CREATE USER 'sae501_php'@'localhost' IDENTIFIED BY '$ADMIN_PASSWORD';
GRANT SELECT, INSERT, UPDATE ON radius.radcheck TO 'sae501_php'@'localhost';
GRANT SELECT, INSERT, UPDATE ON radius.radreply TO 'sae501_php'@'localhost';
GRANT SELECT, INSERT, UPDATE ON radius.radusergroup TO 'sae501_php'@'localhost';
GRANT SELECT, INSERT ON radius.admin_audit TO 'sae501_php'@'localhost';
GRANT SELECT, INSERT ON radius.auth_attempts TO 'sae501_php'@'localhost';
GRANT SELECT, UPDATE ON radius.user_status TO 'sae501_php'@'localhost';
GRANT SELECT ON radius.* TO 'sae501_php'@'localhost';
FLUSH PRIVILEGES;
MYSQL_CREATE_PHPUSER

log_message "SUCCESS" "Utilisateur PHP admin créé"

# Wait for PHP user to be available
sleep 1

# Configure MySQL for network binding
log_message "INFO" "Configuration MySQL pour écoute réseau..."
mkdir -p /etc/mysql/mysql.conf.d

cat > /etc/mysql/mysql.conf.d/sae501-network.cnf << 'EOF'
# SAE501 - MySQL Network Configuration
# Permet l'accès réseau à MySQL (essentiel pour FreeRADIUS)

[mysqld]
# Network binding - écoute sur toutes les interfaces
bind-address = 0.0.0.0

# Security
symbolic-links = 0
local-infile = 0

# Performance
max_connections = 200
connect_timeout = 10
wait_timeout = 600
max_allowed_packet = 64M
EOF

log_message "SUCCESS" "Configuration réseau MySQL créée"

# Comment bind-address in default config if present
if [ -f "/etc/mysql/mysql.conf.d/mysqld.cnf" ]; then
    log_message "INFO" "Désactivation bind-address par défaut..."
    sed -i 's/^bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf 2>/dev/null || true
fi

# Restart MySQL to apply network configuration
log_message "INFO" "Redémarrage MySQL avec configuration réseau..."
systemctl restart "$SERVICE_NAME"
sleep 3

# Verify MySQL is listening on network
MYSQL_LISTEN=$(ss -tlnp | grep 3306 || echo "")
if echo "$MYSQL_LISTEN" | grep -qE "(0.0.0.0:3306|\*:3306)"; then
    log_message "SUCCESS" "MySQL écoute sur 0.0.0.0:3306 (toutes interfaces)"
else
    log_message "WARNING" "MySQL binding: $MYSQL_LISTEN"
fi

# Store credentials securely
log_message "INFO" "Stockage sécurisé des identifiants..."
mkdir -p /opt/sae501/secrets
cat > /opt/sae501/secrets/db.env << EOF
DB_HOST=localhost
DB_PORT=3306
DB_NAME=radius
DB_USER_RADIUS=radiususer
DB_PASSWORD_RADIUS='$RADIUS_PASSWORD'
DB_USER_PHP=sae501_php
DB_PASSWORD_PHP='$ADMIN_PASSWORD'
EOF

# Create group if it doesn't exist
if ! grep -q "^www-data:" /etc/group; then
    groupadd www-data 2>/dev/null || true
fi

chown root:www-data /opt/sae501/secrets/db.env 2>/dev/null || chown root:root /opt/sae501/secrets/db.env
chmod 640 /opt/sae501/secrets/db.env
log_message "SUCCESS" "Identifiants stockés dans /opt/sae501/secrets/db.env"

# Test connection with new users
log_message "INFO" "Test de connexion avec radiususer..."
if mysql -u radiususer -p"$RADIUS_PASSWORD" radius -e "SELECT COUNT(*) FROM radcheck;" > /dev/null 2>&1; then
    log_message "SUCCESS" "Connexion radiususer OK"
else
    error_exit "Impossible de se connecter avec radiususer"
fi

log_message "INFO" "Test de connexion avec sae501_php..."
if mysql -u sae501_php -p"$ADMIN_PASSWORD" radius -e "SELECT COUNT(*) FROM radcheck;" > /dev/null 2>&1; then
    log_message "SUCCESS" "Connexion sae501_php OK"
else
    error_exit "Impossible de se connecter avec sae501_php"
fi

# Insert a test user
log_message "INFO" "Création d'un utilisateur de test..."
mysql -u radiususer -p"$RADIUS_PASSWORD" radius << MYSQL_TEST_USER
INSERT IGNORE INTO radcheck (username, attribute, op, value) VALUES ('testuser', 'Cleartext-Password', ':=', 'testpass');
INSERT IGNORE INTO user_status (username, active) VALUES ('testuser', TRUE);
MYSQL_TEST_USER

log_message "SUCCESS" "Utilisateur testuser créé"

log_message "SUCCESS" "Installation MariaDB/MySQL terminée"
echo ""
echo "============================================"
echo "IDENTIFIANTS IMPORTANTS - A SAUVEGARDER"
echo "============================================"
echo "radiususer password: $RADIUS_PASSWORD"
echo "sae501_php password: $ADMIN_PASSWORD"
echo ""
echo "Les identifiants sont également stockés dans:"
echo "/opt/sae501/secrets/db.env (permissions: 640)"
echo ""
echo "MySQL écoute sur: 0.0.0.0:3306 (réseau)"
echo "============================================"

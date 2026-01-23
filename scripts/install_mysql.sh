#!/bin/bash
# ============================================================================
# SAE501 - Installation et initialisation MariaDB pour RADIUS
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

log_message "INFO" "Démarrage de l'installation MariaDB"

# Generate random password for radiususer
RADIUS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

log_message "INFO" "Mots de passe générés aléatoirement"

# Start MariaDB
log_message "INFO" "Démarrage de MariaDB..."
systemctl enable mariadb
systemctl restart mariadb

if ! systemctl is-active mariadb > /dev/null 2>&1; then
    error_exit "Échec du démarrage de MariaDB"
fi

log_message "SUCCESS" "MariaDB démarré"

# Secure MariaDB installation
log_message "INFO" "Sécurisation de MariaDB..."
mysql -u root << MYSQL_SECURE_SCRIPT
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove root remote login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Flush privileges
FLUSH PRIVILEGES;
MYSQL_SECURE_SCRIPT

log_message "SUCCESS" "MariaDB sécurisée"

# Create radius database
log_message "INFO" "Création de la base de données RADIUS..."
mysql -u root << MYSQL_CREATE_DB
CREATE DATABASE IF NOT EXISTS radius DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'radiususer'@'localhost' IDENTIFIED BY '$RADIUS_PASSWORD';
GRANT ALL PRIVILEGES ON radius.* TO 'radiususer'@'localhost';
FLUSH PRIVILEGES;
MYSQL_CREATE_DB

log_message "SUCCESS" "Base de données RADIUS créée"
log_message "SUCCESS" "Utilisateur radiususer créé (mot de passe: $RADIUS_PASSWORD)"

# Import RADIUS schema
log_message "INFO" "Import du schéma FreeRADIUS..."
if [ -f /etc/freeradius/3.0/mods-config/sql/mysql/schema.sql ]; then
    mysql -u radiususer -p"$RADIUS_PASSWORD" radius < /etc/freeradius/3.0/mods-config/sql/mysql/schema.sql
    log_message "SUCCESS" "Schéma RADIUS importé"
else
    error_exit "Schéma RADIUS non trouvé"
fi

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
CREATE USER IF NOT EXISTS 'sae501_php'@'localhost' IDENTIFIED BY '$ADMIN_PASSWORD';
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

chown root:sae501 /opt/sae501/secrets/db.env
chmod 640 /opt/sae501/secrets/db.env
log_message "SUCCESS" "Identifiants stockés dans /opt/sae501/secrets/db.env"

# Enable general query log for audit (can be disabled in production for performance)
log_message "INFO" "Configuration de la journalisation MariaDB..."
mysql -u root << MYSQL_LOGGING
SET GLOBAL general_log = 'ON';
SET GLOBAL log_output = 'TABLE';
SET GLOBAL general_log_file = '/var/log/mariadb_general.log';
MYSQL_LOGGING

# Create slow query log
log_message "INFO" "Configuration du slow query log..."
mysql -u root << MYSQL_SLOW_LOG
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL slow_query_log_file = '/var/log/mariadb_slow.log';
SET GLOBAL long_query_time = 2;
MYSQL_SLOW_LOG

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
INSERT IGNORE INTO radcheck (username, attribute, op, value) VALUES ('testuser', 'User-Password', ':=', 'password123');
INSERT IGNORE INTO user_status (username, active) VALUES ('testuser', TRUE);
MYSQL_TEST_USER

log_message "SUCCESS" "Utilisateur testuser créé"

log_message "SUCCESS" "Installation MariaDB terminée"
echo ""
echo "============================================"
echo "IDENTIFIANTS IMPORTANTS - A SAUVEGARDER"
echo "============================================"
echo "radiususer password: $RADIUS_PASSWORD"
echo "sae501_php password: $ADMIN_PASSWORD"
echo ""
echo "Les identifiants sont également stockés dans:"
echo "/opt/sae501/secrets/db.env (permissions: 640)"
echo "============================================"

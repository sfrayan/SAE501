#!/bin/bash
# ============================================================================
# SAE501 - Import FreeRADIUS Schema
# Imports the complete RADIUS schema including nas, radacct, radcheck, etc.
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_radius_schema_install.log"

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

log_message "INFO" "Démarrage de l'importation du schéma RADIUS"

# Load DB credentials
DB_ENV_FILE="/opt/sae501/secrets/db.env"
if [ -f "$DB_ENV_FILE" ]; then
    source "$DB_ENV_FILE"
else
    error_exit "Fichier $DB_ENV_FILE non trouvé"
fi

DB_PASSWORD="${DB_PASSWORD_RADIUS:-}"
if [ -z "$DB_PASSWORD" ]; then
    error_exit "Mot de passe RADIUS non défini"
fi

# Create temporary SQL file with FreeRADIUS schema
TEMP_SQL=$(mktemp)
trap "rm -f $TEMP_SQL" EXIT

log_message "INFO" "Création du schéma RADIUS complet..."

# FreeRADIUS MySQL schema
cat > "$TEMP_SQL" << 'SCHEMA_EOF'
-- FreeRADIUS MySQL schema
-- Complete schema for RADIUS accounting and authentication

-- Create nas table (NAS/Client devices)
CREATE TABLE IF NOT EXISTS nas (
  id int(10) unsigned NOT NULL auto_increment,
  nasname varchar(128) NOT NULL,
  shortname varchar(32),
  type varchar(30) DEFAULT 'other',
  ports int(5),
  secret varchar(60) NOT NULL DEFAULT 'testing123',
  server varchar(64),
  community varchar(50),
  description varchar(200) DEFAULT 'RADIUS Client',
  PRIMARY KEY  (id),
  KEY nasname (nasname)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create radacct table (Accounting records)
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
  acctstoptime datetime NULL default NULL,
  acctsessiontime int(12) unsigned default NULL,
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
  PRIMARY KEY (radacctid),
  KEY username (username),
  KEY framedipaddress (framedipaddress),
  KEY acctsessionid (acctsessionid),
  KEY acctuniqueid (acctuniqueid),
  KEY acctstarttime (acctstarttime),
  KEY acctstoptime (acctstoptime),
  KEY nasipaddress (nasipaddress)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create radpostauth table (Post-auth logging)
CREATE TABLE IF NOT EXISTS radpostauth (
  id int(11) unsigned NOT NULL auto_increment,
  username varchar(64) NOT NULL default '',
  pass varchar(64) NOT NULL default '',
  reply varchar(32) NOT NULL default '',
  authdate timestamp NOT NULL default CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create radusergroup table (User to group mapping)
CREATE TABLE IF NOT EXISTS radusergroup (
  username varchar(64) NOT NULL default '',
  groupname varchar(64) NOT NULL default '',
  priority int(11) NOT NULL default '1',
  KEY username (username),
  KEY groupname (groupname)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create radgroupreply table (Group reply attributes)
CREATE TABLE IF NOT EXISTS radgroupreply (
  groupname varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL default '=',
  value varchar(253) NOT NULL default '',
  KEY groupname (groupname)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create radgroupcheck table (Group check attributes)
CREATE TABLE IF NOT EXISTS radgroupcheck (
  groupname varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL default '=',
  value varchar(253) NOT NULL default '',
  KEY groupname (groupname)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create radcheck table (User check attributes)
CREATE TABLE IF NOT EXISTS radcheck (
  id int(11) unsigned NOT NULL auto_increment,
  username varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL default '=',
  value varchar(253) NOT NULL default '',
  PRIMARY KEY (id),
  KEY username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create radreply table (User reply attributes)
CREATE TABLE IF NOT EXISTS radreply (
  id int(11) unsigned NOT NULL auto_increment,
  username varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL default '=',
  value varchar(253) NOT NULL default '',
  PRIMARY KEY (id),
  KEY username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert default NAS entry for localhost testing
REPLACE INTO nas (nasname, shortname, type, secret, description) 
VALUES ('127.0.0.1', 'localhost', 'other', 'testing123', 'Local testing NAS');

-- Insert TL-Router pilot
REPLACE INTO nas (nasname, shortname, type, secret, description) 
VALUES ('192.168.1.1', 'TL-MR100-Pilot', 'other', 'SAE501@TLRouter2026!', 'TP-Link MR100 Pilot');
SCHEMA_EOF

# Import schema
log_message "INFO" "Import du schéma dans la base de données..."
if mysql -u radiususer -p"$DB_PASSWORD" radius < "$TEMP_SQL" 2>&1 | tee -a "$LOG_FILE"; then
    log_message "SUCCESS" "Schéma RADIUS importé avec succès"
else
    log_message "WARNING" "Erreur lors de l'import (tables peuvent déjà exister)"
fi

# Verify tables
log_message "INFO" "Vérification des tables..."
if mysql -u radiususer -p"$DB_PASSWORD" radius -e "SHOW TABLES;" | grep -q "nas"; then
    log_message "SUCCESS" "Table 'nas' confirmée"
else
    log_message "ERROR" "Table 'nas' manquante !"
    exit 1
fi

log_message "SUCCESS" "Installation du schéma terminée"

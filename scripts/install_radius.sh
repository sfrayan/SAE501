#!/bin/bash
# ============================================================================
# SAE501 - Installation et configuration FreeRADIUS avec MySQL
# PEAP-MSCHAPv2, logging centralisé, interface web-ready
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_radius_install.log"
RADIUS_LOG_DIR="/var/log/sae501/radius"

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

log_message "INFO" "Démarrage de l'installation RADIUS"

# Create radius log directory
mkdir -p "$RADIUS_LOG_DIR"
chown freerad:freerad "$RADIUS_LOG_DIR"
chmod 750 "$RADIUS_LOG_DIR"

# Enable SQL module in RADIUS
log_message "INFO" "Activation du module SQL dans FreeRADIUS..."
cd /etc/freeradius/3.0/mods-enabled
if [ ! -L "sql" ]; then
    ln -s ../mods-available/sql sql
    log_message "INFO" "Module SQL lié"
fi

# Configure SQL module
log_message "INFO" "Configuration du module SQL..."
cat > /etc/freeradius/3.0/mods-available/sql-sae501 << 'EOF'
sql {
    driver = "rlm_sql_mysql"
    
    server = "localhost"
    port = 3306
    
    login = "radiususer"
    password = "${env:DB_PASSWORD}"
    
    radius_db = "radius"
    
    # Connection pooling
    pool {
        start = 5
        min = 3
        max = 32
        spare = 10
        uses = 0
        lifetime = 600
        idle_timeout = 300
    }
    
    # Query timeout
    query_timeout = 30
    
    # Connection timeout
    connect_timeout = 3
    
    # Enable connection retry
    num_sql_sockets = 32
    
    # Logging
    read_groups = yes
    read_profiles = yes
    read_clients = yes
    read_realms = yes
    
    # Reference queries
    authorize_check_query = "SELECT id, UserName, Attribute, Value, op FROM ${authcheck_table} WHERE username = '%{User-Name}' ORDER BY id"
    authorize_reply_query = "SELECT id, UserName, Attribute, Value, op FROM ${authreply_table} WHERE username = '%{User-Name}' ORDER BY id"
    
    accounting_onoff_query = "UPDATE ${acct_table1} SET acctstoptime=FROM_UNIXTIME(%{Acct-Unique-Session-Id}), acctsessiontime=unix_timestamp(now())-unix_timestamp(acctstarttime), acctterminatecause='%{Acct-Terminate-Cause}', acctstopdelay=%{Acct-Delay-Time}:-1 WHERE acctsessionid='%{Acct-Session-Id}' AND username='%{User-Name}' AND NASIPAddress='%{NAS-IP-Address}'"
    
    # Insert accounting records
    accounting_update_query = "UPDATE ${acct_table1} SET framedipaddress='%{Framed-IP-Address}', acctsessiontime=unix_timestamp(now())-unix_timestamp(acctstarttime), acctinputoctets='%{Acct-Input-Octets}', acctoutputoctets='%{Acct-Output-Octets}' WHERE acctsessionid='%{Acct-Session-Id}' AND username='%{User-Name}' AND NASIPAddress='%{NAS-IP-Address}'"
    
    accounting_start_query = "INSERT INTO ${acct_table1} (acctsessionid, acctuniqueid, username, realm, nasipaddress, nasportid, nasporttype, acctstarttime, acctupdatetime, acctstoptime, acctsessiontime, acctauthentic, connectinfo_start, connectinfo_stop, acctinputoctets, acctoutputoctets, calledstationid, callingstationid, acctterminatecause, serviceType, framedprotocol, framedipaddress, acctstartdelay, acctstopdelay, xascendsessionsupported) VALUES ('%{Acct-Session-Id}', '%{Acct-Unique-Session-Id}', '%{User-Name}', '%{Realm}', '%{NAS-IP-Address}', '%{NAS-Port}', '%{NAS-Port-Type}', FROM_UNIXTIME(%{Event-Timestamp}), FROM_UNIXTIME(%{Event-Timestamp}), NULL, '0', '%{Acct-Authentic}', '%{Connect-Info}', '', '0', '0', '%{Called-Station-Id}', '%{Calling-Station-Id}', '', '%{Service-Type}', '%{Framed-Protocol}', '', '%{Acct-Delay-Time}:-1', '0', '1')"
    
    accounting_stop_query = "UPDATE ${acct_table1} SET acctstoptime=FROM_UNIXTIME(%{Event-Timestamp}), acctsessiontime='%{Acct-Session-Time}', acctinputoctets='%{Acct-Input-Octets}', acctoutputoctets='%{Acct-Output-Octets}', acctterminatecause='%{Acct-Terminate-Cause}', acctstopdelay='%{Acct-Delay-Time}:-1', connectinfo_stop='%{Connect-Info}' WHERE acctsessionid='%{Acct-Session-Id}' AND username='%{User-Name}' AND NASIPAddress='%{NAS-IP-Address}'"
}
EOF

chmod 640 /etc/freeradius/3.0/mods-available/sql-sae501
chown freerad:freerad /etc/freeradius/3.0/mods-available/sql-sae501

# Link the SQL module
if [ ! -L "/etc/freeradius/3.0/mods-enabled/sql-sae501" ]; then
    ln -s ../mods-available/sql-sae501 /etc/freeradius/3.0/mods-enabled/sql-sae501
fi

# Configure EAP for PEAP-MSCHAPv2
log_message "INFO" "Configuration de PEAP-MSCHAPv2..."
cat > /etc/freeradius/3.0/mods-available/eap-peap << 'EOF'
eap {
    default_eap_type = peap
    timer_expire = 60
    ignore_unknown_eap_types = no
    cisco_accounting_username_bug = no
    max_sessions = ${max_requests}
    
    peap {
        tls = tls_common
        default_eap_type = mschapv2
        copy_request_to_tunnel = no
        use_tunneled_reply = no
        virtual_server = "inner-tunnel"
    }
    
    mschapv2 {
        send_error = no
    }
}
EOF

chown freerad:freerad /etc/freeradius/3.0/mods-available/eap-peap
chmod 640 /etc/freeradius/3.0/mods-available/eap-peap

if [ ! -L "/etc/freeradius/3.0/mods-enabled/eap-peap" ]; then
    ln -s ../mods-available/eap-peap /etc/freeradius/3.0/mods-enabled/eap-peap
fi

# Configure RADIUS clients (routeur TL-MR100)
log_message "INFO" "Configuration des clients RADIUS..."
cat >> /etc/freeradius/3.0/clients.conf << 'EOF'
# SAE501 - Routeur TL-MR100 (Salle de sport pilote)
client 192.168.1.1 {
    secret = "${env:RADIUS_SECRET}"
    shortname = "TL-MR100-Pilot"
    nas_type = "other"
    
    # Logging for each request
    response_window = 20
    max_connections = 16
    lifetime = 0
    idle_timeout = 30
}
EOF

# Setup default site configuration with logging
log_message "INFO" "Configuration des sites RADIUS par défaut..."
cat > /etc/freeradius/3.0/sites-enabled/default-sae501 << 'EOF'
server default-sae501 {
    listen {
        type = auth
        port = 1812
        bind = 0.0.0.0
    }
    
    listen {
        type = acct
        port = 1813
        bind = 0.0.0.0
    }
    
    authorize {
        preprocess
        auth_log
        chap
        mschap
        digest
        
        # Query user from SQL database
        sql-sae501
        
        # If user not found, check files
        files
        
        -sql
        expiration
        logintime
        pap
        eap {
            ok = return
        }
    }
    
    authenticate {
        Auth-Type PAP {
            pap
        }
        Auth-Type CHAP {
            chap
        }
        Auth-Type MS-CHAP {
            mschap
        }
        mschap
        digest
        eap
    }
    
    preacct {
        preprocess
        acct_unique
        suffix
        files
    }
    
    accounting {
        detail
        
        # Log to SQL
        sql-sae501
        
        radutmp
        exec
    }
    
    session {
        sql-sae501
    }
    
    post-auth {
        reply_log
        exec
        remove_reply_message_if_eap
        Post-Auth-Type REJECT {
            attr_filter.access_reject
            eap
            remove_reply_message_if_eap
        }
        Post-Auth-Type Challenge {
            eap
        }
    }
    
    pre-proxy {
        suffix
    }
    
    post-proxy {
        eap
    }
}
EOF

chown freerad:freerad /etc/freeradius/3.0/sites-enabled/default-sae501
chmod 640 /etc/freeradius/3.0/sites-enabled/default-sae501

# Create auth and reply log files
cat > /etc/freeradius/3.0/mods-available/auth_log << 'EOF'
auth_log {
    filename = "/var/log/sae501/radius/auth.log"
}
EOF

cat > /etc/freeradius/3.0/mods-available/reply_log << 'EOF'
reply_log {
    filename = "/var/log/sae501/radius/reply.log"
}
EOF

ln -sf ../mods-available/auth_log /etc/freeradius/3.0/mods-enabled/auth_log 2>/dev/null
ln -sf ../mods-available/reply_log /etc/freeradius/3.0/mods-enabled/reply_log 2>/dev/null

# Create log files with proper permissions
touch "$RADIUS_LOG_DIR"/auth.log "$RADIUS_LOG_DIR"/reply.log "$RADIUS_LOG_DIR"/accounting.log
chown freerad:freerad "$RADIUS_LOG_DIR"/*.log
chmod 640 "$RADIUS_LOG_DIR"/*.log

# Test RADIUS configuration
log_message "INFO" "Test de la configuration RADIUS..."
if radiusd -C 2>&1 | tee -a "$LOG_FILE"; then
    log_message "SUCCESS" "Configuration RADIUS valide"
else
    error_exit "Configuration RADIUS invalide"
fi

# Start RADIUS service
log_message "INFO" "Démarrage du service FreeRADIUS..."
systemctl enable freeradius
systemctl restart freeradius

if systemctl is-active freeradius > /dev/null 2>&1; then
    log_message "SUCCESS" "Service FreeRADIUS démarré avec succès"
else
    error_exit "Échec du démarrage de FreeRADIUS"
fi

# Test RADIUS authentication
log_message "INFO" "Test de la connexion RADIUS sur localhost..."
echo "User-Name = 'testuser', User-Password = 'testpass'" | radclient -f - localhost:1812 auth "${RADIUS_SECRET:-testing123}" 2>&1 | tee -a "$LOG_FILE" || true

log_message "SUCCESS" "Installation RADIUS terminée"
log_message "INFO" "Logs disponibles à: $RADIUS_LOG_DIR"
log_message "INFO" "Vérifier: /var/log/sae501/radius/auth.log et reply.log"

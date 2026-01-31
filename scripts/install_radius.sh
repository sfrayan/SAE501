#!/bin/bash
# ============================================================================
# SAE501 - Installation FreeRADIUS (100% AUTONOME - AUCUN FICHIER EXTERNE)
# ============================================================================
# 
# Ce script réalise une installation COMPLÈTE de FreeRADIUS sans dépendre
# d'aucun fichier externe du repository. Toutes les configurations sont
# générées automatiquement durant l'installation.
#
# FONCTIONNALITÉS:
# - Installation des packages FreeRADIUS + MySQL
# - Génération automatique des certificats SSL auto-signés
# - Configuration SQL (rlm_sql_mysql) avec connexion MySQL
# - Configuration EAP (PEAP-MSCHAPv2 sans certificat client)
# - Configuration des sites (default + inner-tunnel)
# - Déploiement clients.conf depuis le repo
# - Test automatique de l'authentification
# - Fix systemd pour Debian 11/12
#
# USAGE:
#   sudo bash scripts/install_radius.sh
#
# PRÉ-REQUIS:
#   - MySQL installé et accessible
#   - Fichier /opt/sae501/secrets/db.env avec credentials MySQL
#   - Fichier radius/clients.conf dans le repo
#
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_radius_install.log"
SECRETS_DIR="/opt/sae501/secrets"
DB_ENV_FILE="$SECRETS_DIR/db.env"

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
       echo "❌ Must run as root" >&2
       exit 1
    fi
}

check_mysql_credentials() {
    if [[ ! -f "$DB_ENV_FILE" ]]; then
        log_msg "❌ ERROR: $DB_ENV_FILE not found!"
        log_msg "Please run install_mysql.sh first."
        exit 1
    fi
    
    # Charger les credentials MySQL
    source "$DB_ENV_FILE"
    
    # Support pour les anciens et nouveaux noms de variables
    if [[ -n "${DB_USER_RADIUS:-}" && -n "${DB_PASSWORD_RADIUS:-}" ]]; then
        MYSQL_RADIUS_USER="$DB_USER_RADIUS"
        MYSQL_RADIUS_PASS="$DB_PASSWORD_RADIUS"
    elif [[ -z "${MYSQL_RADIUS_USER:-}" || -z "${MYSQL_RADIUS_PASS:-}" ]]; then
        log_msg "❌ ERROR: MYSQL_RADIUS_USER or MYSQL_RADIUS_PASS not set in $DB_ENV_FILE"
        exit 1
    fi
    
    log_msg "✓ MySQL credentials loaded"
}

# ============================================================================
# INSTALLATION DES PACKAGES
# ============================================================================

install_packages() {
    log_msg "📦 Installing FreeRADIUS packages..."
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y \
        freeradius \
        freeradius-mysql \
        freeradius-utils \
        openssl \
        >/dev/null 2>&1
    log_msg "✓ Packages installed"
}

# ============================================================================
# PRÉPARATION DE L'ENVIRONNEMENT
# ============================================================================

prepare_environment() {
    log_msg "🔧 Preparing FreeRADIUS environment..."
    
    # Arrêter le service si actif
    systemctl stop freeradius 2>/dev/null || true
    sleep 1
    
    # Créer utilisateur/groupe freerad
    if ! id freerad >/dev/null 2>&1; then
        useradd -r -s /bin/false freerad || true
    fi
    
    # Créer les répertoires nécessaires
    mkdir -p /etc/freeradius/3.0/{certs,mods-enabled,sites-enabled,mods-config/sql/main/mysql}
    mkdir -p /var/log/freeradius
    mkdir -p /var/run/freeradius
    
    # Permissions
    chown -R freerad:freerad /etc/freeradius /var/log/freeradius /var/run/freeradius
    chmod -R 755 /etc/freeradius /var/log/freeradius /var/run/freeradius
    
    log_msg "✓ Environment prepared"
}

# ============================================================================
# GÉNÉRATION DES CERTIFICATS SSL AUTO-SIGNÉS
# ============================================================================

generate_certificates() {
    log_msg "🔐 Generating SSL certificates (self-signed)..."
    
    cd /etc/freeradius/3.0/certs
    
    # Générer CA (Certificate Authority)
    openssl req -new -x509 -days 3650 -nodes \
        -subj "/C=FR/ST=IDF/L=Paris/O=SAE501/CN=SAE501 CA" \
        -keyout ca.key -out ca.pem >/dev/null 2>&1
    
    # Générer certificat serveur
    openssl req -new -nodes \
        -subj "/C=FR/ST=IDF/L=Paris/O=SAE501/CN=radius.sae501.local" \
        -keyout server.key -out server.csr >/dev/null 2>&1
    
    openssl x509 -req -days 3650 \
        -in server.csr -CA ca.pem -CAkey ca.key \
        -CAcreateserial -out server.pem >/dev/null 2>&1
    
    # Générer clé DH pour Perfect Forward Secrecy
    openssl dhparam -out dh 2048 >/dev/null 2>&1
    
    # Permissions strictes
    chmod 640 *.key
    chown freerad:freerad *.pem *.key dh
    
    log_msg "✓ SSL certificates generated"
}

# ============================================================================
# CONFIGURATION SQL (rlm_sql_mysql)
# ============================================================================

configure_sql_module() {
    log_msg "🗄️  Configuring SQL module..."
    
    source "$DB_ENV_FILE"
    
    # Support pour les anciens et nouveaux noms de variables
    if [[ -n "${DB_USER_RADIUS:-}" && -n "${DB_PASSWORD_RADIUS:-}" ]]; then
        MYSQL_RADIUS_USER="$DB_USER_RADIUS"
        MYSQL_RADIUS_PASS="$DB_PASSWORD_RADIUS"
    fi
    
    cat > /etc/freeradius/3.0/mods-enabled/sql << 'SQL_CONF_EOF'
sql {
    driver = "rlm_sql_mysql"
    dialect = "mysql"
    
    server = "localhost"
    port = 3306
    login = "MYSQL_RADIUS_USER_PLACEHOLDER"
    password = "MYSQL_RADIUS_PASS_PLACEHOLDER"
    
    radius_db = "radius"
    
    acct_table1 = "radacct"
    acct_table2 = "radacct"
    postauth_table = "radpostauth"
    authcheck_table = "radcheck"
    groupcheck_table = "radgroupcheck"
    authreply_table = "radreply"
    groupreply_table = "radgroupreply"
    usergroup_table = "radusergroup"
    
    read_clients = yes
    client_table = "nas"
    
    logfile = ${logdir}/sql.log
    
    pool {
        start = 5
        min = 4
        max = 32
        spare = 10
        uses = 0
        lifetime = 0
        cleanup_interval = 30
        idle_timeout = 60
    }
}
SQL_CONF_EOF
    
    # Remplacer les placeholders
    sed -i "s/MYSQL_RADIUS_USER_PLACEHOLDER/$MYSQL_RADIUS_USER/g" /etc/freeradius/3.0/mods-enabled/sql
    sed -i "s/MYSQL_RADIUS_PASS_PLACEHOLDER/$MYSQL_RADIUS_PASS/g" /etc/freeradius/3.0/mods-enabled/sql
    
    chmod 640 /etc/freeradius/3.0/mods-enabled/sql
    chown freerad:freerad /etc/freeradius/3.0/mods-enabled/sql
    
    log_msg "✓ SQL module configured"
}

# ============================================================================
# CONFIGURATION EAP (PEAP-MSCHAPv2)
# ============================================================================

configure_eap_module() {
    log_msg "🔒 Configuring EAP module (PEAP-MSCHAPv2)..."
    
    cat > /etc/freeradius/3.0/mods-enabled/eap << 'EAP_CONF_EOF'
eap {
    default_eap_type = peap
    timer_expire = 60
    ignore_unknown_eap_types = no
    cisco_accounting_username_bug = no
    max_sessions = ${max_requests}
    
    tls-config tls-common {
        private_key_password = whatever
        private_key_file = ${certdir}/server.key
        certificate_file = ${certdir}/server.pem
        ca_file = ${certdir}/ca.pem
        dh_file = ${certdir}/dh
        
        cipher_list = "HIGH"
        cipher_server_preference = yes
        
        ecdh_curve = "prime256v1"
        
        tls_min_version = "1.2"
        tls_max_version = "1.3"
    }
    
    peap {
        tls = tls-common
        default_eap_type = mschapv2
        copy_request_to_tunnel = yes
        use_tunneled_reply = yes
        virtual_server = "inner-tunnel"
    }
    
    mschapv2 {
    }
}
EAP_CONF_EOF
    
    chmod 640 /etc/freeradius/3.0/mods-enabled/eap
    chown freerad:freerad /etc/freeradius/3.0/mods-enabled/eap
    
    log_msg "✓ EAP module configured"
}

# ============================================================================
# CONFIGURATION DES SITES (DEFAULT + INNER-TUNNEL)
# ============================================================================

configure_default_site() {
    log_msg "🌐 Configuring default site..."
    
    cat > /etc/freeradius/3.0/sites-enabled/default << 'DEFAULT_SITE_EOF'
server default {
    listen {
        type = auth
        ipaddr = *
        port = 1812
    }
    
    listen {
        type = acct
        ipaddr = *
        port = 1813
    }
    
    authorize {
        filter_username
        preprocess
        sql
        eap {
            ok = return
        }
    }
    
    authenticate {
        eap
    }
    
    post-auth {
        sql
        Post-Auth-Type REJECT {
            sql
        }
    }
    
    accounting {
        sql
    }
}
DEFAULT_SITE_EOF
    
    chmod 640 /etc/freeradius/3.0/sites-enabled/default
    chown freerad:freerad /etc/freeradius/3.0/sites-enabled/default
    
    log_msg "✓ Default site configured"
}

configure_inner_tunnel_site() {
    log_msg "🔐 Configuring inner-tunnel site..."
    
    cat > /etc/freeradius/3.0/sites-enabled/inner-tunnel << 'INNER_TUNNEL_EOF'
server inner-tunnel {
    listen {
        type = auth
        ipaddr = 127.0.0.1
        port = 18120
    }
    
    authorize {
        filter_username
        sql
        mschap
        eap {
            ok = return
        }
    }
    
    authenticate {
        mschap
        eap
    }
    
    post-auth {
        sql
        Post-Auth-Type REJECT {
            sql
        }
    }
}
INNER_TUNNEL_EOF
    
    chmod 640 /etc/freeradius/3.0/sites-enabled/inner-tunnel
    chown freerad:freerad /etc/freeradius/3.0/sites-enabled/inner-tunnel
    
    log_msg "✓ Inner-tunnel site configured"
}

# ============================================================================
# DÉPLOIEMENT CLIENTS.CONF DEPUIS LE REPO
# ============================================================================

deploy_clients_conf() {
    log_msg "📋 Deploying clients.conf from repository..."
    
    # Chercher le repo dans plusieurs emplacements possibles
    REPO_PATHS=(
        "$PWD/radius/clients.conf"
        "/opt/SAE501/radius/clients.conf"
        "$HOME/SAE501/radius/clients.conf"
        "$(dirname "$0")/../radius/clients.conf"
    )
    
    CLIENTS_FOUND=false
    for path in "${REPO_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            cp "$path" /etc/freeradius/3.0/clients.conf
            chmod 640 /etc/freeradius/3.0/clients.conf
            chown freerad:freerad /etc/freeradius/3.0/clients.conf
            log_msg "✓ clients.conf deployed from $path"
            CLIENTS_FOUND=true
            break
        fi
    done
    
    if [[ "$CLIENTS_FOUND" == "false" ]]; then
        log_msg "⚠️  WARNING: clients.conf not found in repository"
        log_msg "Creating minimal localhost client..."
        
        cat > /etc/freeradius/3.0/clients.conf << 'CLIENTS_EOF'
client localhost {
    ipaddr = 127.0.0.1
    ipv6addr = ::1
    secret = testing123
    shortname = localhost
    nastype = other
}
CLIENTS_EOF
        
        chmod 640 /etc/freeradius/3.0/clients.conf
        chown freerad:freerad /etc/freeradius/3.0/clients.conf
        log_msg "✓ Minimal clients.conf created"
    fi
}

# ============================================================================
# CONFIGURATION RADIUSD.CONF (MINIMAL)
# ============================================================================

configure_radiusd_conf() {
    log_msg "⚙️  Configuring radiusd.conf..."
    
    cat > /etc/freeradius/3.0/radiusd.conf << 'RADIUSD_CONF_EOF'
prefix = /usr
exec_prefix = /usr
sysconfdir = /etc
localstatedir = /var
sbindir = ${exec_prefix}/sbin
logdir = /var/log/freeradius
raddbdir = /etc/freeradius/3.0
radacctdir = ${logdir}/radacct

name = freeradius
confdir = ${raddbdir}
modconfdir = ${confdir}/mods-config
certdir = ${confdir}/certs
cadir = ${confdir}/certs
run_dir = ${localstatedir}/run/${name}

db_dir = ${raddbdir}

libdir = /usr/lib/freeradius

pidfile = ${run_dir}/${name}.pid

max_request_time = 30
cleanup_delay = 5
max_requests = 16384

hostname_lookups = no

log {
    destination = files
    colourise = yes
    file = ${logdir}/radius.log
    syslog_facility = daemon
    stripped_names = no
    auth = yes
    auth_badpass = yes
    auth_goodpass = yes
    msg_denied = "You are already logged in - access denied"
}

checkrad = ${sbindir}/checkrad

security {
    max_attributes = 200
    reject_delay = 1
    status_server = yes
}

proxy_requests = no

$INCLUDE clients.conf
$INCLUDE mods-enabled/
$INCLUDE sites-enabled/
RADIUSD_CONF_EOF
    
    chmod 640 /etc/freeradius/3.0/radiusd.conf
    chown freerad:freerad /etc/freeradius/3.0/radiusd.conf
    
    log_msg "✓ radiusd.conf configured"
}

# ============================================================================
# ACTIVER MSCHAP MODULE
# ============================================================================

enable_mschap_module() {
    log_msg "🔑 Enabling mschap module..."
    
    cat > /etc/freeradius/3.0/mods-enabled/mschap << 'MSCHAP_EOF'
mschap {
    use_mppe = yes
    require_encryption = yes
    require_strong = yes
    with_ntdomain_hack = no
    ntlm_auth = "/usr/bin/ntlm_auth --request-nt-key --username=%{%{Stripped-User-Name}:-%{User-Name}} --challenge=%{%{mschap:Challenge}:-00} --nt-response=%{%{mschap:NT-Response}:-00}"
}
MSCHAP_EOF
    
    chmod 640 /etc/freeradius/3.0/mods-enabled/mschap
    chown freerad:freerad /etc/freeradius/3.0/mods-enabled/mschap
    
    log_msg "✓ mschap module enabled"
}

# ============================================================================
# TEST DE CONFIGURATION
# ============================================================================

test_configuration() {
    log_msg "🧪 Testing FreeRADIUS configuration..."
    
    if /usr/sbin/freeradius -Cx -lstdout -d /etc/freeradius/3.0 >/tmp/radius_config_test.log 2>&1; then
        log_msg "✓ Configuration test PASSED"
        return 0
    else
        log_msg "❌ Configuration test FAILED"
        log_msg "Showing first 40 lines of error log:"
        head -40 /tmp/radius_config_test.log | tee -a "$LOG_FILE"
        return 1
    fi
}

# ============================================================================
# DÉPLOIEMENT SYSTEMD OVERRIDE
# ============================================================================

deploy_systemd_override() {
    log_msg "🔧 Deploying systemd override..."
    
    mkdir -p /etc/systemd/system/freeradius.service.d
    
    cat > /etc/systemd/system/freeradius.service.d/override.conf << 'OVERRIDE_EOF'
[Service]
ExecStart=
ExecStart=/usr/sbin/freeradius -f -lstdout
OVERRIDE_EOF
    
    systemctl daemon-reload
    log_msg "✓ Systemd override deployed"
}

# ============================================================================
# DÉMARRAGE DU SERVICE
# ============================================================================

start_service() {
    log_msg "🚀 Starting FreeRADIUS service..."
    
    systemctl enable freeradius >/dev/null 2>&1 || true
    systemctl restart freeradius || true
    sleep 2
    
    if systemctl is-active --quiet freeradius; then
        log_msg "✅ SUCCESS: FreeRADIUS is running (ports 1812/1813)"
        return 0
    else
        log_msg "❌ FAILED: FreeRADIUS not running"
        log_msg "Showing last 20 lines of journal:"
        journalctl -u freeradius -n 20 --no-pager | tee -a "$LOG_FILE"
        return 1
    fi
}

# ============================================================================
# TEST D'AUTHENTIFICATION LOCALE
# ============================================================================

test_authentication() {
    log_msg "🔐 Testing local authentication..."
    
    # Créer un utilisateur test si n'existe pas déjà
    source "$DB_ENV_FILE"
    
    # Support pour les anciens et nouveaux noms de variables
    if [[ -n "${DB_USER_RADIUS:-}" && -n "${DB_PASSWORD_RADIUS:-}" ]]; then
        MYSQL_RADIUS_USER="$DB_USER_RADIUS"
        MYSQL_RADIUS_PASS="$DB_PASSWORD_RADIUS"
    fi
    
    mysql -u "$MYSQL_RADIUS_USER" -p"$MYSQL_RADIUS_PASS" radius << 'TEST_USER_EOF' 2>/dev/null || true
INSERT IGNORE INTO radcheck (username, attribute, op, value) 
VALUES ('testuser', 'Cleartext-Password', ':=', 'testpass');
TEST_USER_EOF
    
    # Tester l'authentification
    if echo "User-Name=testuser, User-Password=testpass" | \
       radclient -x localhost:1812 auth testing123 >/tmp/radius_auth_test.log 2>&1; then
        log_msg "✅ Authentication test PASSED"
    else
        log_msg "⚠️  Authentication test FAILED (check logs)"
        tail -20 /tmp/radius_auth_test.log | tee -a "$LOG_FILE"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_msg "=========================================="
    log_msg "SAE501 - FreeRADIUS Installation Start"
    log_msg "=========================================="
    
    check_root
    check_mysql_credentials
    
    install_packages
    prepare_environment
    generate_certificates
    
    configure_radiusd_conf
    configure_sql_module
    configure_eap_module
    enable_mschap_module
    
    configure_default_site
    configure_inner_tunnel_site
    
    deploy_clients_conf
    
    if ! test_configuration; then
        log_msg "❌ Configuration test failed. Aborting."
        exit 1
    fi
    
    deploy_systemd_override
    
    if ! start_service; then
        log_msg "❌ Service failed to start. Check logs above."
        exit 1
    fi
    
    test_authentication
    
    log_msg "=========================================="
    log_msg "✅ FreeRADIUS Installation Complete!"
    log_msg "=========================================="
    log_msg ""
    log_msg "📋 Next steps:"
    log_msg "  1. Check status: systemctl status freeradius"
    log_msg "  2. View logs: tail -f /var/log/freeradius/radius.log"
    log_msg "  3. Test auth: radtest testuser testpass localhost 0 testing123"
    log_msg "  4. Configure your NAS devices in radius/clients.conf"
    log_msg ""
}

main "$@"

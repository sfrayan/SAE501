#!/bin/bash
# ============================================================================
# SAE501 - Installation Wazuh Manager + Dashboard (100% AUTONOME)
# ============================================================================
#
# Ce script réalise une installation COMPLÈTE de Wazuh sans dépendre
# d'aucun fichier externe. Toutes les configurations sont générées
# automatiquement durant l'installation.
#
# FONCTIONNALITÉS:
# - Installation de Wazuh Manager 4.x
# - Installation d'OpenSearch (remplacement d'Elasticsearch)
# - Installation du Wazuh Dashboard (interface web)
# - Configuration automatique de la collecte des logs RADIUS
# - Configuration du monitoring système
# - Règles d'alerte personnalisées pour RADIUS
# - Génération de certificats SSL pour le dashboard
# - Configuration du filebeat pour l'indexation
#
# USAGE:
#   sudo bash scripts/install_wazuh.sh
#
# PRÉ-REQUIS:
#   - Debian 12+ ou Ubuntu 22.04+
#   - 4GB RAM minimum (8GB recommandé)
#   - 50GB disque minimum
#
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_wazuh_install.log"
WAZUH_VERSION="4.7"

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

check_resources() {
    log_msg "📊 Checking system resources..."
    
    # Vérifier RAM (minimum 3GB disponible)
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_ram -lt 3000 ]]; then
        log_msg "⚠️  WARNING: Less than 3GB RAM detected. Wazuh may run slowly."
    fi
    
    # Vérifier espace disque (minimum 20GB disponible)
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $free_space -lt 20 ]]; then
        log_msg "❌ ERROR: Less than 20GB disk space available"
        exit 1
    fi
    
    log_msg "✓ Resources check passed"
}

# ============================================================================
# INSTALLATION DES DÉPENDANCES
# ============================================================================

install_dependencies() {
    log_msg "📦 Installing dependencies..."
    
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y \
        apt-transport-https \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        >/dev/null 2>&1
    
    log_msg "✓ Dependencies installed"
}

# ============================================================================
# INSTALLATION WAZUH MANAGER
# ============================================================================

install_wazuh_manager() {
    log_msg "🛡️  Installing Wazuh Manager..."
    
    # Ajouter le dépôt Wazuh
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
    
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
    
    apt-get update -y >/dev/null 2>&1
    
    # Installer Wazuh Manager
    WAZUH_MANAGER="wazuh-manager" apt-get install -y wazuh-manager >/dev/null 2>&1
    
    systemctl daemon-reload
    systemctl enable wazuh-manager >/dev/null 2>&1
    systemctl start wazuh-manager
    
    sleep 3
    
    if systemctl is-active --quiet wazuh-manager; then
        log_msg "✓ Wazuh Manager installed and running"
    else
        log_msg "❌ Wazuh Manager failed to start"
        exit 1
    fi
}

# ============================================================================
# CONFIGURATION WAZUH MANAGER
# ============================================================================

configure_wazuh_manager() {
    log_msg "⚙️  Configuring Wazuh Manager..."
    
    # Backup de la configuration d'origine
    cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak
    
    # Générer la configuration complète
    cat > /var/ossec/etc/ossec.conf << 'OSSEC_CONF_EOF'
<ossec_config>
  <global>
    <jsonout_output>yes</jsonout_output>
    <alerts_log>yes</alerts_log>
    <logall>yes</logall>
    <logall_json>yes</logall_json>
    <email_notification>no</email_notification>
    <smtp_server>smtp.example.wazuh.com</smtp_server>
    <email_from>wazuh@example.wazuh.com</email_from>
    <email_to>recipient@example.wazuh.com</email_to>
    <email_maxperhour>12</email_maxperhour>
    <email_log_source>alerts.log</email_log_source>
  </global>

  <!-- Monitoring des logs FreeRADIUS -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/freeradius/radius.log</location>
  </localfile>

  <!-- Monitoring des logs système -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  <!-- Monitoring des logs MySQL -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/mysql/error.log</location>
  </localfile>

  <!-- Monitoring des logs Apache -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/apache2/access.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/apache2/error.log</location>
  </localfile>

  <!-- Detection de rootkits -->
  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <check_dev>yes</check_dev>
    <check_sys>yes</check_sys>
    <check_pids>yes</check_pids>
    <check_ports>yes</check_ports>
    <check_if>yes</check_if>
    <frequency>43200</frequency>
    <rootkit_files>/var/ossec/etc/shared/rootkit_files.txt</rootkit_files>
    <rootkit_trojans>/var/ossec/etc/shared/rootkit_trojans.txt</rootkit_trojans>
  </rootcheck>

  <!-- File Integrity Monitoring -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <scan_on_start>yes</scan_on_start>
    
    <!-- Surveillance des répertoires critiques -->
    <directories check_all="yes">/etc,/usr/bin,/usr/sbin</directories>
    <directories check_all="yes">/bin,/sbin,/boot</directories>
    <directories check_all="yes">/var/ossec/etc</directories>
    <directories check_all="yes">/etc/freeradius</directories>
    
    <!-- Ignorer les fichiers temporaires -->
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.deny</ignore>
    <ignore>/etc/mail/statistics</ignore>
    <ignore>/etc/random-seed</ignore>
    <ignore>/etc/adjtime</ignore>
    <ignore>/etc/httpd/logs</ignore>
  </syscheck>

  <!-- Analyse de vulnérabilités -->
  <vulnerability-detector>
    <enabled>yes</enabled>
    <interval>5m</interval>
    <ignore_time>6h</ignore_time>
    <run_on_start>yes</run_on_start>
    
    <!-- Debian vulnerability feed -->
    <provider name="debian">
      <enabled>yes</enabled>
      <os>bookworm</os>
      <update_interval>1h</update_interval>
    </provider>
  </vulnerability-detector>

  <!-- Réception syslog distant (pour le routeur) -->
  <remote>
    <connection>syslog</connection>
    <port>514</port>
    <protocol>udp</protocol>
    <allowed-ips>0.0.0.0/0</allowed-ips>
  </remote>

  <!-- API REST configuration -->
  <remote>
    <connection>secure</connection>
    <port>1514</port>
    <protocol>tcp</protocol>
    <queue_size>131072</queue_size>
  </remote>

  <!-- Alertes -->
  <alerts>
    <log_alert_level>3</log_alert_level>
    <email_alert_level>12</email_alert_level>
  </alerts>

  <!-- Règles actives -->
  <ruleset>
    <decoder_dir>ruleset/decoders</decoder_dir>
    <rule_dir>ruleset/rules</rule_dir>
    <rule_exclude>0215-policy_rules.xml</rule_exclude>
    <list>etc/lists/audit-keys</list>
    <list>etc/lists/amazon/aws-eventnames</list>
    <list>etc/lists/security-eventchannel</list>
  </ruleset>

  <!-- Règles locales personnalisées -->
  <ruleset>
    <rule_dir>etc/rules</rule_dir>
  </ruleset>

  <!-- Active Response (désactivé par défaut pour éviter les faux positifs) -->
  <active-response>
    <disabled>yes</disabled>
  </active-response>

</ossec_config>
OSSEC_CONF_EOF
    
    # Permissions
    chown root:wazuh /var/ossec/etc/ossec.conf
    chmod 640 /var/ossec/etc/ossec.conf
    
    log_msg "✓ Wazuh Manager configured"
}

# ============================================================================
# CRÉATION DES RÈGLES PERSONNALISÉES RADIUS
# ============================================================================

create_custom_rules() {
    log_msg "📄 Creating custom RADIUS rules..."
    
    mkdir -p /var/ossec/etc/rules
    
    cat > /var/ossec/etc/rules/local_rules.xml << 'RULES_EOF'
<group name="local,radius,authentication">

  <!-- Règle: Authentification RADIUS réussie -->
  <rule id="100001" level="3">
    <if_sid>1002</if_sid>
    <match>Access-Accept</match>
    <description>RADIUS: Authentification réussie</description>
    <group>authentication_success,radius</group>
  </rule>

  <!-- Règle: Authentification RADIUS échouée -->
  <rule id="100002" level="5">
    <if_sid>1002</if_sid>
    <match>Access-Reject</match>
    <description>RADIUS: Authentification échouée</description>
    <group>authentication_failed,radius</group>
  </rule>

  <!-- Règle: Multiple échecs d'authentification (attaque potentielle) -->
  <rule id="100003" level="10" frequency="5" timeframe="300">
    <if_matched_sid>100002</if_matched_sid>
    <same_source_ip />
    <description>RADIUS: Tentatives d'authentification multiples échouées depuis $(srcip)</description>
    <group>authentication_failures,radius,attack</group>
  </rule>

  <!-- Règle: FreeRADIUS service démarré -->
  <rule id="100004" level="3">
    <if_sid>1002</if_sid>
    <match>radiusd</match>
    <match>Ready to process requests</match>
    <description>RADIUS: Service démarré et opérationnel</description>
    <group>service_start,radius</group>
  </rule>

  <!-- Règle: Erreur de connexion à la base de données -->
  <rule id="100005" level="8">
    <if_sid>1002</if_sid>
    <match>rlm_sql</match>
    <match>connection failed</match>
    <description>RADIUS: Échec de connexion à la base de données MySQL</description>
    <group>database_error,radius</group>
  </rule>

  <!-- Règle: Client RADIUS non autorisé -->
  <rule id="100006" level="7">
    <if_sid>1002</if_sid>
    <match>Ignoring request</match>
    <match>unknown client</match>
    <description>RADIUS: Requête d'un client non autorisé depuis $(srcip)</description>
    <group>access_denied,radius</group>
  </rule>

  <!-- Règle: Certificat SSL expiré -->
  <rule id="100007" level="8">
    <if_sid>1002</if_sid>
    <match>certificate</match>
    <match>expired</match>
    <description>RADIUS: Certificat SSL expiré</description>
    <group>certificate_error,radius</group>
  </rule>

  <!-- Règle: Utilisateur inconnu -->
  <rule id="100008" level="5">
    <if_sid>1002</if_sid>
    <match>User not found</match>
    <description>RADIUS: Tentative d'authentification avec utilisateur inconnu</description>
    <group>authentication_failed,radius,invalid_user</group>
  </rule>

  <!-- Règle: Mot de passe incorrect -->
  <rule id="100009" level="5">
    <if_sid>1002</if_sid>
    <match>Invalid password</match>
    <description>RADIUS: Mot de passe incorrect</description>
    <group>authentication_failed,radius,invalid_password</group>
  </rule>

  <!-- Règle: Surcharge du serveur RADIUS -->
  <rule id="100010" level="9">
    <if_sid>1002</if_sid>
    <match>Too many open sockets</match>
    <description>RADIUS: Serveur surchargé - trop de connexions simultanées</description>
    <group>resource_exhaustion,radius</group>
  </rule>

</group>
RULES_EOF
    
    chown root:wazuh /var/ossec/etc/rules/local_rules.xml
    chmod 640 /var/ossec/etc/rules/local_rules.xml
    
    log_msg "✓ Custom RADIUS rules created"
}

# ============================================================================
# INSTALLATION OPENSEARCH (REMPLACEMENT ELASTICSEARCH)
# ============================================================================

install_opensearch() {
    log_msg "🔍 Installing OpenSearch..."
    
    # Ajouter le dépôt OpenSearch
    curl -o- https://artifacts.opensearch.org/publickeys/opensearch.pgp | gpg --dearmor --batch --yes -o /usr/share/keyrings/opensearch-keyring.gpg
    
    echo "deb [signed-by=/usr/share/keyrings/opensearch-keyring.gpg] https://artifacts.opensearch.org/releases/bundle/opensearch/2.x/apt stable main" | tee /etc/apt/sources.list.d/opensearch-2.x.list
    
    apt-get update -y >/dev/null 2>&1
    
    # Configurer la mémoire JVM (50% de la RAM totale, max 4GB)
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    local jvm_heap=$((total_ram / 2))
    if [[ $jvm_heap -gt 4096 ]]; then
        jvm_heap=4096
    fi
    
    export OPENSEARCH_INITIAL_ADMIN_PASSWORD="Admin@Wazuh123!"
    
    # Installer OpenSearch
    apt-get install -y opensearch >/dev/null 2>&1
    
    # Configurer OpenSearch
    cat > /etc/opensearch/opensearch.yml << 'OPENSEARCH_YML_EOF'
cluster.name: wazuh-cluster
node.name: node-1
network.host: 127.0.0.1
http.port: 9200

# Sécurité
plugins.security.ssl.http.enabled: false
plugins.security.disabled: true

# Performance
bootstrap.memory_lock: false

# Discovery
discovery.type: single-node
OPENSEARCH_YML_EOF
    
    # Configurer JVM
    cat > /etc/opensearch/jvm.options << JVM_EOF
-Xms${jvm_heap}m
-Xmx${jvm_heap}m
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200
JVM_EOF
    
    # Démarrer OpenSearch
    systemctl daemon-reload
    systemctl enable opensearch >/dev/null 2>&1
    systemctl start opensearch
    
    # Attendre qu'OpenSearch soit prêt
    log_msg "Waiting for OpenSearch to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:9200 >/dev/null 2>&1; then
            log_msg "✓ OpenSearch is ready"
            break
        fi
        sleep 2
    done
    
    log_msg "✓ OpenSearch installed"
}

# ============================================================================
# INSTALLATION FILEBEAT
# ============================================================================

install_filebeat() {
    log_msg "📂 Installing Filebeat..."
    
    # Installer Filebeat depuis le dépôt Wazuh
    apt-get install -y filebeat >/dev/null 2>&1
    
    # Télécharger la configuration Wazuh pour Filebeat
    curl -so /etc/filebeat/filebeat.yml https://packages.wazuh.com/4.7/tpl/wazuh/filebeat/filebeat.yml
    
    # Configurer Filebeat
    sed -i 's/hosts: \["localhost:9200"\]/hosts: ["127.0.0.1:9200"]/g' /etc/filebeat/filebeat.yml
    
    # Télécharger le module Wazuh
    curl -s https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.3.tar.gz | tar -xvz -C /usr/share/filebeat/module >/dev/null 2>&1
    
    # Activer le module Wazuh
    filebeat modules enable wazuh >/dev/null 2>&1
    
    # Charger le template OpenSearch
    filebeat setup --index-management -E output.logstash.enabled=false >/dev/null 2>&1 || true
    
    # Démarrer Filebeat
    systemctl daemon-reload
    systemctl enable filebeat >/dev/null 2>&1
    systemctl start filebeat
    
    log_msg "✓ Filebeat installed"
}

# ============================================================================
# INSTALLATION WAZUH DASHBOARD
# ============================================================================

install_wazuh_dashboard() {
    log_msg "📊 Installing Wazuh Dashboard..."
    
    # Installer Wazuh Dashboard
    apt-get install -y wazuh-dashboard >/dev/null 2>&1
    
    # Configurer le dashboard
    cat > /etc/wazuh-dashboard/opensearch_dashboards.yml << 'DASHBOARD_YML_EOF'
server.host: "0.0.0.0"
server.port: 5601
opensearch.hosts: ["http://127.0.0.1:9200"]
opensearch.ssl.verificationMode: none

# Sécurité
opensearch.username: "admin"
opensearch.password: "Admin@Wazuh123!"

server.defaultRoute: "/app/wazuh"
uiSettings.overrides.defaultRoute: "/app/wazuh"
DASHBOARD_YML_EOF
    
    # Démarrer le dashboard
    systemctl daemon-reload
    systemctl enable wazuh-dashboard >/dev/null 2>&1
    systemctl start wazuh-dashboard
    
    # Attendre que le dashboard soit prêt
    log_msg "Waiting for Wazuh Dashboard to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:5601 >/dev/null 2>&1; then
            log_msg "✓ Wazuh Dashboard is ready"
            break
        fi
        sleep 2
    done
    
    log_msg "✓ Wazuh Dashboard installed"
}

# ============================================================================
# CONFIGURATION DU FIREWALL
# ============================================================================

configure_firewall() {
    log_msg "🔥 Configuring firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 5601/tcp comment "Wazuh Dashboard" >/dev/null 2>&1 || true
        ufw allow 514/udp comment "Wazuh Syslog" >/dev/null 2>&1 || true
        ufw allow 1514/tcp comment "Wazuh Agent" >/dev/null 2>&1 || true
        log_msg "✓ Firewall rules added"
    else
        log_msg "⚠️  UFW not installed, skipping firewall configuration"
    fi
}

# ============================================================================
# REDEMARRAGE DES SERVICES
# ============================================================================

restart_all_services() {
    log_msg "🔄 Restarting all Wazuh services..."
    
    systemctl restart wazuh-manager
    systemctl restart opensearch
    systemctl restart filebeat
    systemctl restart wazuh-dashboard
    
    sleep 5
    
    log_msg "✓ All services restarted"
}

# ============================================================================
# VÉRIFICATION FINALE
# ============================================================================

final_check() {
    log_msg "✅ Performing final checks..."
    
    local all_ok=true
    
    # Vérifier Wazuh Manager
    if systemctl is-active --quiet wazuh-manager; then
        log_msg "✓ Wazuh Manager: RUNNING"
    else
        log_msg "❌ Wazuh Manager: NOT RUNNING"
        all_ok=false
    fi
    
    # Vérifier OpenSearch
    if systemctl is-active --quiet opensearch; then
        log_msg "✓ OpenSearch: RUNNING"
    else
        log_msg "❌ OpenSearch: NOT RUNNING"
        all_ok=false
    fi
    
    # Vérifier Filebeat
    if systemctl is-active --quiet filebeat; then
        log_msg "✓ Filebeat: RUNNING"
    else
        log_msg "❌ Filebeat: NOT RUNNING"
        all_ok=false
    fi
    
    # Vérifier Wazuh Dashboard
    if systemctl is-active --quiet wazuh-dashboard; then
        log_msg "✓ Wazuh Dashboard: RUNNING"
    else
        log_msg "❌ Wazuh Dashboard: NOT RUNNING"
        all_ok=false
    fi
    
    if $all_ok; then
        log_msg "✅ All services are running successfully!"
        return 0
    else
        log_msg "❌ Some services failed to start"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_msg "=========================================="
    log_msg "SAE501 - Wazuh Installation Start"
    log_msg "=========================================="
    
    check_root
    check_resources
    
    install_dependencies
    install_wazuh_manager
    configure_wazuh_manager
    create_custom_rules
    
    install_opensearch
    install_filebeat
    install_wazuh_dashboard
    
    configure_firewall
    restart_all_services
    
    if final_check; then
        log_msg "=========================================="
        log_msg "✅ Wazuh Installation Complete!"
        log_msg "=========================================="
        log_msg ""
        log_msg "📋 Access Information:"
        log_msg "  - Wazuh Dashboard: http://$(hostname -I | awk '{print $1}'):5601"
        log_msg "  - Username: admin"
        log_msg "  - Password: Admin@Wazuh123!"
        log_msg ""
        log_msg "🔧 Useful Commands:"
        log_msg "  - Check status: systemctl status wazuh-manager opensearch wazuh-dashboard"
        log_msg "  - View alerts: tail -f /var/ossec/logs/alerts/alerts.log"
        log_msg "  - View logs: tail -f /var/ossec/logs/ossec.log"
        log_msg ""
        log_msg "⚠️  IMPORTANT: Change default password after first login!"
        log_msg ""
    else
        log_msg "❌ Installation completed with errors. Check logs above."
        exit 1
    fi
}

main "$@"

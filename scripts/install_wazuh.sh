#!/bin/bash
# ============================================================================
# SAE501 - Installation Wazuh Manager avec dashboards
# Centralisation des logs RADIUS et syslog du TL-MR100
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_wazuh_install.log"

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

log_message "INFO" "Démarrage de l'installation Wazuh"

# Add Wazuh repository
log_message "INFO" "Ajout du dépôt Wazuh..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add - 2>/dev/null || true
echo "deb https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list

apt-get update

# Install Wazuh Manager
log_message "INFO" "Installation de Wazuh Manager..."
apt-get install -y wazuh-manager

if ! systemctl is-active wazuh-manager > /dev/null 2>&1; then
    log_message "INFO" "Démarrage de Wazuh Manager..."
    systemctl enable wazuh-manager
    systemctl start wazuh-manager
    sleep 5
fi

log_message "SUCCESS" "Wazuh Manager démarré"

# Install Wazuh Agent on localhost
log_message "INFO" "Installation de l'agent Wazuh local..."
apt-get install -y wazuh-agent

# Configure agent to report to local manager
cat > /var/ossec/etc/ossec.conf << 'EOF'
<ossec_config>
  <client>
    <server-ip>127.0.0.1</server-ip>
  </client>
  
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/sae501/radius/auth.log</location>
    <label>radius-auth</label>
  </localfile>
  
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/sae501/radius/reply.log</location>
    <label>radius-reply</label>
  </localfile>
  
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>
  
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>
  
  <localfile>
    <log_format>json</log_format>
    <location>/var/log/sae501/php_admin_audit.log</location>
    <label>sae501-admin</label>
  </localfile>
</ossec_config>
EOF

chown root:wazuh /var/ossec/etc/ossec.conf
chmod 640 /var/ossec/etc/ossec.conf

systemctl enable wazuh-agent
systemctl restart wazuh-agent

log_message "SUCCESS" "Agent Wazuh configuré"

# Configure syslog receiver for TL-MR100 logs
log_message "INFO" "Configuration de la réception syslog..."
cat > /var/ossec/etc/decoders/mr100.xml << 'EOF'
<decoders>
  <decoder name="mr100-decoder">
    <plugin_decoder>PF_DECODER_INIT</plugin_decoder>
  </decoder>
  
  <decoder name="mr100-router">
    <parent>mr100-decoder</parent>
    <regex offset="after_parent">^[\w\s]+: (\w+)(\[\d+\])?\: (.*)</regex>
    <order>log_type, pid, log_message</order>
  </decoder>
</decoders>
EOF

chown root:wazuh /var/ossec/etc/decoders/mr100.xml
chmod 640 /var/ossec/etc/decoders/mr100.xml

# Configure syslog input in Wazuh
cat > /var/ossec/etc/ruleset/rules/mr100.xml << 'EOF'
<group name="mr100">
  <rule id="100001" level="3">
    <match>mr100</match>
    <description>TP-Link MR100 router event</description>
  </rule>
  
  <rule id="100002" level="5">
    <match>mr100</match>
    <match>authentication failure</match>
    <description>MR100 Authentication failure</description>
  </rule>
  
  <rule id="100003" level="4">
    <match>mr100</match>
    <match>wireless.*connection</match>
    <description>MR100 Wireless connection event</description>
  </rule>
  
  <rule id="100004" level="6">
    <match>mr100</match>
    <match>firewall|ddos|attack</match>
    <description>MR100 Security event</description>
  </rule>
</group>
EOF

chown root:wazuh /var/ossec/etc/ruleset/rules/mr100.xml
chmod 640 /var/ossec/etc/ruleset/rules/mr100.xml

# Create custom alerts for RADIUS
cat > /var/ossec/etc/ruleset/rules/radius.xml << 'EOF'
<group name="radius_auth">
  <rule id="101001" level="3">
    <match>User-Name</match>
    <description>RADIUS authentication attempt</description>
  </rule>
  
  <rule id="101002" level="5">
    <match>REJECT</match>
    <description>RADIUS authentication rejected</description>
  </rule>
  
  <rule id="101003" level="3">
    <match>ACCEPT</match>
    <description>RADIUS authentication accepted</description>
  </rule>
  
  <rule id="101004" level="7">
    <match>Access-Reject</match>
    <match>Access-Reject</match>
    <match>Access-Reject</match>
    <description>Multiple RADIUS rejections - possible attack</description>
    <frequency>3</frequency>
    <timeframe>60</timeframe>
  </rule>
</group>
EOF

chown root:wazuh /var/ossec/etc/ruleset/rules/radius.xml
chmod 640 /var/ossec/etc/ruleset/rules/radius.xml

# Restart Wazuh to load new rules
log_message "INFO" "Redémarrage de Wazuh Manager..."
systemctl restart wazuh-manager
sleep 3

# Verify installation
if systemctl is-active wazuh-manager > /dev/null 2>&1; then
    log_message "SUCCESS" "Wazuh Manager opérationnel"
else
    error_exit "Échec du démarrage de Wazuh Manager"
fi

# Create syslog listener for remote devices
log_message "INFO" "Configuration du listener syslog..."

# Check if rsyslog is running, add syslog input to Wazuh manager config
cat >> /var/ossec/etc/ossec.conf << 'EOF'

<!-- Remote syslog input for network devices (TL-MR100) -->
<remote>
  <connection>syslog</connection>
  <port>514</port>
  <protocol>tcp</protocol>
  <allowed-ips>0.0.0.0/0</allowed-ips>
  <log_format>syslog</log_format>
</remote>

EOF

log_message "INFO" "Listener syslog configuré sur le port 514"

# Create monitoring summary
log_message "SUCCESS" "Installation Wazuh terminée"
log_message "INFO" "Wazuh Manager est maintenant en cours d'exécution"
log_message "INFO" "Agent local configuré pour monitorer:"
log_message "INFO" "  - /var/log/sae501/radius/auth.log"
log_message "INFO" "  - /var/log/sae501/radius/reply.log"
log_message "INFO" "  - /var/log/sae501/php_admin_audit.log"
log_message "INFO" "  - /var/log/auth.log (système)"
log_message "INFO" "  - /var/log/syslog (système)"
log_message "INFO" "Listener syslog activé sur le port 514 pour les périphériques réseau"
log_message "INFO" "Vérifier le statut: sudo systemctl status wazuh-manager"
log_message "INFO" "Voir les logs: sudo tail -f /var/ossec/logs/alerts/alerts.log"

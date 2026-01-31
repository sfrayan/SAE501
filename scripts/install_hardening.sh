#!/bin/bash

#############################################################################
#                    SAE501 - SYSTÈME HARDENING COMPLET                    #
#       Configuration sécurité automatisée - Prêt pour production         #
#                     Author: SAE501 Security Team                         #
#                          Version: 2.0                                    #
#############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

log_info "========================================"
log_info "   HARDENING SÉCURITÉ AUTOMATISÉ"
log_info "========================================"
echo ""

# ============================================================================
# 1. MISE À JOUR SYSTÈME
# ============================================================================
log_info "[1/9] Mise à jour du système..."
apt-get update > /dev/null 2>&1
apt-get upgrade -y > /dev/null 2>&1
apt-get autoremove -y > /dev/null 2>&1
log_success "Système mis à jour"

# ============================================================================
# 2. UFW FIREWALL - CONFIGURATION SÉCURISÉE
# ============================================================================
log_info "[2/9] Configuration UFW Firewall..."

if ! command -v ufw &> /dev/null; then
    apt-get install -y ufw > /dev/null 2>&1
fi

ufw --force reset > /dev/null 2>&1 || true
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# Règles essentielles
ufw allow 22/tcp comment "SSH" > /dev/null
ufw allow 80/tcp comment "HTTP" > /dev/null
ufw allow 443/tcp comment "HTTPS" > /dev/null
ufw allow 1812/udp comment "RADIUS Auth" > /dev/null
ufw allow 1813/udp comment "RADIUS Acct" > /dev/null
ufw allow from 127.0.0.1 to 127.0.0.1 port 3306 comment "MySQL local" > /dev/null
ufw allow 5601/tcp comment "Wazuh Dashboard" > /dev/null

# Activer UFW
ufw --force enable > /dev/null
log_success "Firewall UFW configuré et activé"

# ============================================================================
# 3. SSH HARDENING COMPLET
# ============================================================================
log_info "[3/9] Durcissement SSH..."

# Backup
[ ! -f /etc/ssh/sshd_config.bak ] && cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

cat > /etc/ssh/sshd_config << 'EOFSSH'
# SAE501 - SSH Hardened Configuration
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Host Keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Security
Protocol 2
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 10

# Authentication
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Authorization
AllowUsers *@*
DenyUsers root
X11Forwarding no
PermitTunnel no
AllowAgentForwarding no
AllowTcpForwarding no

# Keepalive
ClientAliveInterval 300
ClientAliveCountMax 2

# Cryptographie moderne
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Banner
Banner /etc/issue.net

# SFTP
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO
EOFSSH

# Banner SSH
cat > /etc/issue.net << 'EOFBANNER'
###############################################################
#                   ACCÈS AUTORISÉ UNIQUEMENT                #
#                                                             #
# L'accès non autorisé à ce système est interdit et sera     #
# poursuivi conformément à la loi. En accédant à ce système, #
# vous acceptez que vos actions puissent être surveillées.   #
###############################################################
EOFBANNER

systemctl restart ssh > /dev/null 2>&1 || systemctl restart sshd > /dev/null 2>&1
log_success "SSH durci et redémarré"

# ============================================================================
# 4. PARAMÈTRES KERNEL SÉCURISÉS
# ============================================================================
log_info "[4/9] Application des paramètres kernel..."

cat > /etc/sysctl.d/99-sae501-hardening.conf << 'EOFKERNEL'
# SAE501 - Kernel Hardening

# Protection kernel
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.printk = 3 3 3 3
kernel.unprivileged_bpf_disabled = 1
kernel.unprivileged_userns_clone = 0
kernel.yama.ptrace_scope = 2

# Core dumps désactivés
kernel.core_uses_pid = 1
fs.suid_dumpable = 0

# ASLR maximum
kernel.randomize_va_space = 2

# Protection PID
kernel.pid_max = 2097152
kernel.perf_event_paranoid = 3
kernel.sysrq = 0

# Panic config
kernel.panic = 60
kernel.panic_on_oops = 0

# Sécurité réseau IPv4
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 15

# Sécurité IPv6
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.forwarding = 0

# Système de fichiers
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_fifos = 2
EOFKERNEL

sysctl -p /etc/sysctl.d/99-sae501-hardening.conf > /dev/null 2>&1
log_success "Paramètres kernel appliqués"

# ============================================================================
# 5. FAIL2BAN - PROTECTION BRUTEFORCE
# ============================================================================
log_info "[5/9] Configuration Fail2Ban..."

if ! command -v fail2ban-client &> /dev/null; then
    apt-get install -y fail2ban > /dev/null 2>&1
fi

cat > /etc/fail2ban/jail.local << 'EOFFAIL2BAN'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sender = root@localhost
action = %(action_mwl)s
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[sshd-ddos]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 10
findtime = 600
bantime = 3600

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
action = %(action_mwl)s
bantime = 604800
findtime = 86400
maxretry = 5

[apache-auth]
enabled = true
port = http,https
logpath = /var/log/apache2/error.log
maxretry = 5

[apache-badbots]
enabled = true
port = http,https
logpath = /var/log/apache2/access.log
maxretry = 3
bantime = 7200

[apache-noscript]
enabled = true
port = http,https
logpath = /var/log/apache2/error.log
maxretry = 5

[apache-overflows]
enabled = true
port = http,https
logpath = /var/log/apache2/error.log
maxretry = 2
bantime = 7200
EOFFAIL2BAN

systemctl enable fail2ban > /dev/null 2>&1
systemctl restart fail2ban > /dev/null 2>&1
log_success "Fail2Ban configuré"

# ============================================================================
# 6. AUDITD - LOGGING AVANCÉ
# ============================================================================
log_info "[6/9] Configuration auditd..."

if ! command -v auditctl &> /dev/null; then
    apt-get install -y auditd > /dev/null 2>&1
fi

cat > /etc/audit/rules.d/sae501.rules << 'EOFAUDIT'
# SAE501 - Audit Rules
-D
-b 8192
-f 1

# Surveillance des commandes système
-a always,exit -F arch=b64 -S execve -k exec
-a always,exit -F arch=b32 -S execve -k exec

# Surveillance des fichiers critiques
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes
-w /var/log/auth.log -p wa -k auth_log_changes
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes
-w /etc/mysql/ -p wa -k mysql_config_changes
-w /etc/freeradius/ -p wa -k radius_config_changes
-w /etc/apache2/ -p wa -k apache_config_changes

# Surveillance utilisateurs/groupes
-w /etc/group -p wa -k group_modifications
-w /etc/passwd -p wa -k passwd_modifications
-w /etc/gshadow -p wa -k gshadow_modifications
-w /etc/shadow -p wa -k shadow_modifications
-w /etc/security/opasswd -p wa -k password_history

# Surveillance modifications réseau
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k network_modifications
-w /etc/hosts -p wa -k network_modifications
-w /etc/network/ -p wa -k network_modifications

# Surveillance des montages
-a always,exit -F arch=b64 -S mount -S umount2 -k mounts

# Surveillance des modifications de fichiers importants
-w /bin/ -p wa -k binaries
-w /sbin/ -p wa -k binaries
-w /usr/bin/ -p wa -k binaries
-w /usr/sbin/ -p wa -k binaries

# Immutabilité
-e 2
EOFAUDIT

systemctl enable auditd > /dev/null 2>&1
systemctl restart auditd > /dev/null 2>&1
augenrules --load > /dev/null 2>&1 || true
log_success "Auditd configuré"

# ============================================================================
# 7. MYSQL HARDENING
# ============================================================================
log_info "[7/9] Durcissement MySQL..."

if command -v mysql &> /dev/null; then
    # Nettoyage sécurité
    mysql -u root << 'EOFMYSQL' 2>/dev/null || true
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOFMYSQL

    # Configuration hardening
    cat > /etc/mysql/mysql.conf.d/sae501-hardening.cnf << 'EOFMYSQLCONF'
[mysqld]
# Sécurité
symbolic-links = 0
local-infile = 0
skip-external-locking = 1
skip-name-resolve = 1
max_connect_errors = 10
max_connections = 150

# Logging
log_error = /var/log/mysql/error.log
log_error_verbosity = 3
general_log = 0
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2

# Binary logging
log_bin = /var/log/mysql/mysql-bin.log
expire_logs_days = 14
sync_binlog = 1

# InnoDB
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 1

# Performance Schema (surveillance)
performance_schema = ON
EOFMYSQLCONF

    systemctl restart mysql > /dev/null 2>&1
    log_success "MySQL durci"
else
    log_warning "MySQL non trouvé, hardening MySQL ignoré"
fi

# ============================================================================
# 8. APACHE HARDENING
# ============================================================================
log_info "[8/9] Durcissement Apache..."

if command -v apache2 &> /dev/null; then
    # Désactiver modules dangereux
    a2dismod status autoindex -f > /dev/null 2>&1 || true
    
    # Activer modules sécurité
    a2enmod headers ssl rewrite > /dev/null 2>&1
    
    # Configuration sécurité
    cat > /etc/apache2/conf-available/security-hardening.conf << 'EOFAPACHE'
# SAE501 - Apache Security Hardening

# Masquer les informations serveur
ServerTokens Prod
ServerSignature Off
TraceEnable Off

# Headers de sécurité
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"
    Header always unset X-Powered-By
    Header always unset Server
</IfModule>

# Désactiver listage répertoires
<Directory />
    Options -Indexes -FollowSymLinks
    AllowOverride None
    Require all denied
</Directory>

<Directory /var/www/>
    Options -Indexes -FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>

# Limiter taille uploads
LimitRequestBody 10485760

# Timeouts
Timeout 60
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
EOFAPACHE

    a2enconf security-hardening > /dev/null 2>&1
    systemctl restart apache2 > /dev/null 2>&1
    log_success "Apache durci"
else
    log_warning "Apache non trouvé"
fi

# ============================================================================
# 9. PERMISSIONS FICHIERS
# ============================================================================
log_info "[9/9] Durcissement des permissions..."

# Fichiers système
chmod 644 /etc/passwd
chmod 640 /etc/shadow
chmod 644 /etc/group
chmod 640 /etc/gshadow
chmod 644 /etc/ssh/sshd_config
chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true

# Cron et at
chmod 700 /var/spool/cron/crontabs 2>/dev/null || true
chmod 700 /var/spool/at 2>/dev/null || true

# Logs sensibles
chmod 640 /var/log/auth.log* 2>/dev/null || true
chmod 640 /var/log/syslog* 2>/dev/null || true

log_success "Permissions durcies"

# ============================================================================
# 10. CONFIGURATION UTILISATEUR SÉCURISÉE
# ============================================================================
log_info "Configuration des politiques utilisateurs..."

# Politique mot de passe PAM
cat > /etc/security/pwquality.conf << 'EOFPWQUALITY'
# SAE501 - Password Quality Requirements
minlen = 12
minclass = 3
maxrepeat = 3
maxsequence = 3
gecosmatch = 0
dictonlycheck = 1
usercheck = 1
enforcing = 1
retry = 3
EOFPWQUALITY

# Limites utilisateurs
cat >> /etc/security/limits.conf << 'EOFLIMITS'

# SAE501 - Security Limits
* soft core 0
* hard core 0
* soft nproc 1024
* hard nproc 2048
* soft nofile 8192
* hard nofile 16384
EOFLIMITS

log_success "Politiques utilisateurs configurées"

# ============================================================================
# RÉSUMÉ FINAL
# ============================================================================
echo ""
log_info "=========================================="
log_success "   HARDENING TERMINÉ AVEC SUCCÈS!"
log_info "=========================================="
echo ""
log_info "✅ Configuration appliquée:"
echo ""
log_info "  🔥 UFW Firewall actif"
log_info "  🔐 SSH durci (port 22)"
log_info "  🛡️  Kernel sécurisé"
log_info "  🗄️  MySQL durci"
log_info "  🌐 Apache sécurisé"
log_info "  🚫 Fail2Ban actif"
log_info "  📝 Auditd configuré"
log_info "  📂 Permissions durcies"
log_info "  👤 Politiques utilisateurs"
echo ""
log_info "📋 Vérifications:"
echo ""
echo "  # État firewall:"
echo "  ufw status verbose"
echo ""
echo "  # Bans actifs:"
echo "  fail2ban-client status"
echo ""
echo "  # Logs audit:"
echo "  ausearch -k exec | tail -20"
echo ""
log_warning "⚠️  IMPORTANT - CHANGEZ LES MOTS DE PASSE PAR DÉFAUT!"
log_warning "⚠️  Consultez le README pour les étapes post-installation"
echo ""
log_success "Système prêt pour la production! 🚀"
echo ""

exit 0

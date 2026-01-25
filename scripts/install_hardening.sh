#!/bin/bash

#############################################################################
#                    SAE501 - SYSTEM HARDENING SCRIPT                      #
#            Comprehensive security configuration and hardening            #
#                     Author: SAE501 Security Team                         #
#                          Version: 1.0                                    #
#############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

log_info "Starting system hardening..."

# ============================================================================
# 1. UFW FIREWALL CONFIGURATION
# ============================================================================
log_info "Configuring UFW Firewall..."

# Install UFW if not present
if ! command -v ufw &> /dev/null; then
    apt-get update && apt-get install -y ufw > /dev/null
    log_success "UFW installed"
fi

# Reset to defaults (this will ask for confirmation)
ufw --force reset > /dev/null 2>&1 || true

# Default policies
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# Allow SSH FIRST (port 22) - before enabling UFW
ufw allow 22/tcp comment "SSH" > /dev/null

# Allow HTTP/HTTPS
ufw allow 80/tcp comment "HTTP" > /dev/null
ufw allow 443/tcp comment "HTTPS" > /dev/null

# Allow RADIUS (ports 1812-1813)
ufw allow 1812/udp comment "RADIUS Auth" > /dev/null
ufw allow 1813/udp comment "RADIUS Acct" > /dev/null

# Allow MySQL (port 3306) - only from localhost by default
ufw allow from 127.0.0.1 to 127.0.0.1 port 3306 comment "MySQL localhost" > /dev/null

# Enable UFW
ufw --force enable > /dev/null
log_success "UFW Firewall configured and enabled"

# ============================================================================
# 2. SSH HARDENING
# ============================================================================
log_info "Hardening SSH configuration..."

# Backup original SSH config
if [ ! -f /etc/ssh/sshd_config.bak ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    log_success "SSH config backed up"
fi

# Configure SSH security settings (but keep working authentication)
cat > /etc/ssh/sshd_config << 'EOF'
# This is the ssh server system-wide configuration file.
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# HostKeys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Security Settings
Protocol 2
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 10

# Authentication - allow password for now, but secure it
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

# Ciphers and Algorithms (Modern + Secure)
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Banner
Banner /etc/issue.net

# Subsystem
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO
EOF

# Create SSH banner
cat > /etc/issue.net << 'EOF'
###############################################################
#                   AUTHORIZED ACCESS ONLY                   #
#                                                             #
# Unauthorized access to this system is forbidden and will   #
# be prosecuted by law. By accessing this system, you agree  #
# that your actions may be monitored and recorded.           #
###############################################################
EOF

# Restart SSH service (use ssh, not sshd on Debian)
sudo systemctl restart ssh > /dev/null 2>&1 || sudo systemctl restart sshd > /dev/null 2>&1 || true
log_success "SSH hardened and restarted"

# ============================================================================
# 3. KERNEL SECURITY PARAMETERS
# ============================================================================
log_info "Hardening kernel parameters..."

# Backup sysctl config
if [ ! -f /etc/sysctl.d/99-sae501-hardening.conf.bak ]; then
    if [ -f /etc/sysctl.d/99-hardening.conf ]; then
        cp /etc/sysctl.d/99-hardening.conf /etc/sysctl.d/99-sae501-hardening.conf.bak 2>/dev/null || true
    fi
fi

# Apply hardening settings
cat >> /etc/sysctl.d/99-sae501-hardening.conf << 'EOF'

# SAE501 Security Hardening
# ============================

# Kernel protection
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.printk = 3 3 3 3
kernel.unprivileged_ns_clone = 0

# Core dumps disabled
kernel.core_uses_pid = 1
fs.suid_dumpable = 0

# ASLR - Address Space Layout Randomization
kernel.randomize_va_space = 2

# PID hiding
kernel.pid_max = 2097152
kernel.perf_event_paranoid = 3

# Restrict access to kernel logs
kernel.sysrq = 0

# Panic configuration
kernel.panic = 60
kernel.panic_on_oops = 0

# Network security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.all.forwarding = 0

# TCP hardening
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# File system
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_fifos = 2
EOF

sysctl -p /etc/sysctl.d/99-sae501-hardening.conf > /dev/null 2>&1
log_success "Kernel security parameters applied"

# ============================================================================
# 4. MYSQL SECURITY
# ============================================================================
log_info "Hardening MySQL security..."

if command -v mysql &> /dev/null; then
    # Remove anonymous users
    mysql -u root << 'EOF' 2>/dev/null || true
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF
    log_success "MySQL anonymous users removed and test database dropped"

    # Enable MySQL slow query log and audit
    if [ ! -f /etc/mysql/mysql.conf.d/sae501-hardening.cnf ]; then
        cat > /etc/mysql/mysql.conf.d/sae501-hardening.cnf << 'EOF'
[mysqld]
# Security settings
symbolic-links = 0
local-infile = 0
skip-external-locking = 1
skip-name-resolve = 1

# Audit and logging
log_error = /var/log/mysql/error.log
log_error_verbosity = 3
general_log = 0
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2

# Binary logging for backups
log_bin = /var/log/mysql/mysql-bin.log
expire_logs_days = 14

# InnoDB hardening
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_autoinc_lock_mode = 2
EOF
        systemctl restart mysql > /dev/null 2>&1 || true
        log_success "MySQL hardening configuration applied"
    fi
else
    log_warning "MySQL not found, skipping MySQL hardening"
fi

# ============================================================================
# 5. FAIL2BAN INSTALLATION AND CONFIGURATION
# ============================================================================
log_info "Setting up Fail2Ban..."

if ! command -v fail2ban-client &> /dev/null; then
    apt-get update && apt-get install -y fail2ban > /dev/null
    log_success "Fail2Ban installed"
fi

# Create local jail configuration
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sender = root@localhost
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 1800

[sshd-ddos]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 10
findtime = 600
bantime = 1800

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
action = %(action_mwl)s
bantime = 604800
findtime = 86400
maxretry = 5
EOF

systemctl enable fail2ban > /dev/null
systemctl restart fail2ban > /dev/null
log_success "Fail2Ban configured and enabled"

# ============================================================================
# 6. AUDIT DAEMON CONFIGURATION
# ============================================================================
log_info "Configuring audit logging..."

if ! command -v auditctl &> /dev/null; then
    apt-get install -y auditd > /dev/null
    log_success "auditd installed"
fi

# Create audit rules
cat > /etc/audit/rules.d/sae501.rules << 'EOF'
# Remove any existing rules
-D

# Buffer Size
-b 8192

# Failure handling
-f 1

# Audit system calls
-a always,exit -F arch=b64 -S execve -k exec
-a always,exit -F arch=b32 -S execve -k exec

# Audit file modifications
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
-w /var/log/auth.log -p wa -k auth
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/mysql/ -p wa -k mysql_config
-w /etc/freeradius/ -p wa -k radius_config

# Audit user/group modifications
-w /etc/group -p wa -k group_modifications
-w /etc/passwd -p wa -k passwd_modifications
-w /etc/gshadow -p wa -k gshadow_modifications
-w /etc/shadow -p wa -k shadow_modifications

# Make configuration immutable
-e 2
EOF

systemctl enable auditd > /dev/null
systemctl restart auditd > /dev/null
augenrules --load > /dev/null 2>&1 || true
log_success "Audit rules configured and enabled"

# ============================================================================
# 7. FILE PERMISSIONS HARDENING
# ============================================================================
log_info "Hardening file permissions..."

# Sensitive files permissions
chmod 644 /etc/passwd
chmod 640 /etc/shadow
chmod 644 /etc/group
chmod 640 /etc/gshadow
chmod 644 /etc/ssh/sshd_config
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub

# Ensure cron and at are restricted
chmod 700 /var/spool/cron/crontabs 2>/dev/null || true
chmod 700 /var/spool/at 2>/dev/null || true

log_success "File permissions hardened"

# ============================================================================
# 8. SYSTEM UPDATES AND CLEANUP
# ============================================================================
log_info "Updating system packages..."

apt-get update > /dev/null
apt-get upgrade -y > /dev/null
log_success "System packages updated"

# ============================================================================
# FINAL SUMMARY
# ============================================================================
log_info "=========================================="
log_success "System hardening completed successfully!"
log_info "=========================================="
log_info ""
log_info "Hardening applied:"
log_info "  ✓ UFW Firewall configured"
log_info "  ✓ SSH security hardened"
log_info "  ✓ Kernel security parameters applied"
log_info "  ✓ MySQL security enhanced"
log_info "  ✓ Fail2Ban configured"
log_info "  ✓ Audit logging enabled"
log_info "  ✓ File permissions hardened"
log_info ""
log_info "Firewall status:"
log_info "  ufw status verbose"
log_info ""
log_info "SSH is active on port 22 (password auth temporarily enabled)"
log_info ""

exit 0

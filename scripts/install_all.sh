#!/bin/bash

#############################################################################
#                   SAE501 - MASTER INSTALLATION SCRIPT                    #
#        Orchestrates complete installation of all SAE501 components       #
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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="/var/log/sae501"
MASTER_LOG="$LOG_DIR/install_all.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"
touch "$MASTER_LOG"

# Logging functions
log_info() {
    local msg="[INFO] $1"
    echo -e "${BLUE}${msg}${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${msg}" >> "$MASTER_LOG"
}

log_success() {
    local msg="[✓] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${msg}" >> "$MASTER_LOG"
}

log_warning() {
    local msg="[⚠] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${msg}" >> "$MASTER_LOG"
}

log_error() {
    local msg="[✗] $1"
    echo -e "${RED}${msg}${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${msg}" >> "$MASTER_LOG"
}

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use: sudo bash $0)"
    exit 1
fi

# Track failed steps
FAILED_STEPS=()

# Function to run an installation script
run_install_script() {
    local script_name=$1
    local script_path="$SCRIPT_DIR/$script_name"
    local step_name=${script_name%.sh}
    
    log_info "Running $step_name..."
    
    if [ ! -f "$script_path" ]; then
        log_error "Script not found: $script_path"
        FAILED_STEPS+=("$step_name")
        return 1
    fi
    
    if ! bash "$script_path" >> "$MASTER_LOG" 2>&1; then
        log_warning "$step_name completed with warnings/errors (check logs)"
        FAILED_STEPS+=("$step_name")
        # Continue anyway - some services may fail in isolated environments
    else
        log_success "$step_name completed successfully"
    fi
}

# ============================================================================
# MAIN INSTALLATION SEQUENCE
# ============================================================================

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  SAE501 - MASTER INSTALLER                 ║${NC}"
echo -e "${BLUE}║    Complete installation of Wi-Fi Security Architecture     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "Installation started at $(date '+%Y-%m-%d %H:%M:%S')"
log_info "Log file: $MASTER_LOG"
log_info "Script directory: $SCRIPT_DIR"
echo ""

# Step 1: Prepare environment
log_info "Step 1: Preparing system environment..."
echo "  • Updating package manager"
apt-get update > /dev/null 2>&1 || log_warning "apt-get update encountered issues"
echo "  • Installing core dependencies (curl, wget, gnupg)"
apt-get install -y curl wget gnupg > /dev/null 2>&1 || true
echo "  • Creating SAE501 directories"
mkdir -p /opt/sae501/secrets
mkdir -p /var/log/sae501
chmod 700 /opt/sae501/secrets
log_success "System environment prepared"
echo ""

# Step 2: Database installation
log_info "Step 2: Database Installation"
log_info "================================"
run_install_script "install_mysql.sh"
echo ""

# Step 3: Wait for MySQL to be fully ready
log_info "Waiting for MySQL to be fully ready (5 seconds)..."
sleep 5

# Verify MySQL is actually running before continuing
log_info "Verifying MySQL is running..."
for i in {1..10}; do
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
        log_success "MySQL verified running"
        break
    elif [ $i -lt 10 ]; then
        log_warning "MySQL startup attempt $i/10..."
        sleep 2
    else
        log_error "MySQL failed to start after multiple attempts"
        FAILED_STEPS+=("mysql-verification")
    fi
done
echo ""

# Step 4: FreeRADIUS
log_info "Step 3: FreeRADIUS Installation"
log_info "================================"
run_install_script "install_radius.sh"
echo ""

# Step 5: Web Admin Interface
log_info "Step 4: PHP-Admin Web Interface Installation"
log_info "========================================"
run_install_script "install_php_admin.sh"
echo ""

# Step 6: System Hardening
log_info "Step 5: System Hardening"
log_info "========================"
run_install_script "install_hardening.sh"
echo ""

# Step 7: SSL/TLS Certificates
log_info "Step 6: SSL/TLS Certificate Generation"
log_info "======================================"
run_install_script "generate_certificates.sh"
echo ""

# Step 8: Monitoring (optional - may fail in isolated environment)
log_info "Step 7: Monitoring Setup (Optional)"
log_info "==================================="
run_install_script "install_wazuh.sh" || log_warning "Wazuh setup skipped or failed (this is optional)"
echo ""

# ============================================================================
# POST-INSTALLATION VERIFICATION
# ============================================================================

log_info "Step 8: Post-Installation Verification"
log_info "======================================"
echo ""

# Check MySQL
if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
    log_success "✓ MySQL/MariaDB is running"
else
    log_warning "⚠ MySQL/MariaDB not running (will try to start)"
    systemctl start mysql 2>/dev/null || systemctl start mariadb 2>/dev/null || true
    sleep 2
fi

# Check FreeRADIUS
if systemctl is-active --quiet freeradius 2>/dev/null; then
    log_success "✓ FreeRADIUS is running"
else
    log_warning "⚠ FreeRADIUS not running - attempting restart"
    systemctl restart freeradius 2>/dev/null || true
    sleep 2
    if systemctl is-active --quiet freeradius 2>/dev/null; then
        log_success "✓ FreeRADIUS is now running"
    else
        log_error "✗ FreeRADIUS failed to start"
        FAILED_STEPS+=("freeradius")
    fi
fi

# Check Apache
if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
    log_success "✓ Apache Web Server is running"
else
    log_warning "⚠ Apache Web Server not running"
fi

# Check PHP-Admin
if [ -f /var/www/html/php-admin/index.php ]; then
    log_success "✓ PHP-Admin interface installed"
else
    log_warning "⚠ PHP-Admin interface not found"
fi

echo ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ INSTALLATION COMPLETED SUCCESSFULLY!${NC}"
else
    echo -e "${YELLOW}⚠ INSTALLATION COMPLETED WITH WARNINGS:${NC}"
    for step in "${FAILED_STEPS[@]}"; do
        echo -e "  ${YELLOW}• $step${NC}"
    done
fi

echo ""
echo -e "${BLUE}NEXT STEPS:${NC}"
echo "  1. View system credentials:        bash $SCRIPT_DIR/show_credentials.sh"
echo "  2. Run diagnostics:                bash $SCRIPT_DIR/diagnostics.sh"
echo "  3. Access PHP-Admin:               http://localhost/php-admin/"
echo "  4. Default credentials:            admin / Admin@Secure123!"
echo "  5. Complete installation log:      cat $MASTER_LOG"
echo ""
echo -e "${BLUE}SECURITY REMINDER:${NC}"
echo "  • Change all default passwords immediately"
echo "  • Review firewall rules (ufw status verbose)"
echo "  • Configure SSL/TLS for production"
echo "  • Set up regular backups"
echo "  • Review audit logs (auditctl -l)"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

log_success "Installation process completed at $(date '+%Y-%m-%d %H:%M:%S')"

exit 0

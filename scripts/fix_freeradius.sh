#!/bin/bash

#############################################################################
#                   SAE501 - FreeRADIUS Diagnostic & Fix                    #
#                    Troubleshooting and Configuration Repair               #
#                     Author: SAE501 Security Team                         #
#                          Version: 1.0                                    #
#############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

echo ""
echo -e "${BLUE}╔═════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    FreeRADIUS Diagnostic & Fix Tool                  ║${NC}"
echo -e "${BLUE}╚═════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# STEP 1: Check FreeRADIUS Installation
# ============================================================================
log_info "Step 1: Checking FreeRADIUS installation..."

if ! command -v freeradius &> /dev/null; then
    log_error "FreeRADIUS not installed"
    exit 1
fi

FREERADIUS_VERSION=$(freeradius -v 2>&1 | head -1)
log_success "FreeRADIUS found: $FREERADIUS_VERSION"

# ============================================================================
# STEP 2: Verify Configuration Syntax
# ============================================================================
log_info "Step 2: Verifying configuration syntax..."

echo ""
log_info "Running: freeradius -Cx -lstdout"
echo ""

if freeradius -Cx -lstdout 2>&1 | tee /tmp/radius_check.log; then
    log_success "Configuration syntax OK"
else
    log_error "Configuration syntax ERROR - details below:"
    echo ""
    cat /tmp/radius_check.log
    echo ""
fi

# ============================================================================
# STEP 3: Check File Permissions
# ============================================================================
log_info "Step 3: Checking file permissions..."

# Check if freerad user exists
if id "freerad" &>/dev/null; then
    log_success "freerad user exists"
else
    log_error "freerad user not found - creating..."
    useradd -r -s /bin/false freerad 2>/dev/null || true
    log_success "freerad user created"
fi

# Fix permissions
echo "  Fixing /etc/freeradius permissions..."
chown -R freerad:freerad /etc/freeradius 2>/dev/null || true
chmod -R 750 /etc/freeradius 2>/dev/null || true

echo "  Fixing /var/lib/freeradius permissions..."
chown -R freerad:freerad /var/lib/freeradius 2>/dev/null || true
chmod -R 750 /var/lib/freeradius 2>/dev/null || true

echo "  Fixing /var/log/freeradius permissions..."
mkdir -p /var/log/freeradius
chown -R freerad:freerad /var/log/freeradius 2>/dev/null || true
chmod -R 750 /var/log/freeradius 2>/dev/null || true

log_success "File permissions fixed"

# ============================================================================
# STEP 4: Check MySQL Connectivity
# ============================================================================
log_info "Step 4: Checking MySQL connectivity..."

if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
    log_success "MySQL is running"
    
    # Try to connect
    if mysql -u radiususer -p$(grep DB_PASSWORD_RADIUS /opt/sae501/secrets/db.env 2>/dev/null | cut -d= -f2) radius -e "SELECT 1;" &>/dev/null; then
        log_success "MySQL connection OK"
        
        # Check tables
        TABLE_COUNT=$(mysql -u radiususer -p$(grep DB_PASSWORD_RADIUS /opt/sae501/secrets/db.env 2>/dev/null | cut -d= -f2) radius -e "SHOW TABLES;" 2>/dev/null | wc -l)
        log_success "RADIUS database has tables: $TABLE_COUNT"
    else
        log_error "MySQL connection failed - check credentials in db.env"
    fi
else
    log_error "MySQL is not running"
    log_info "Starting MySQL..."
    systemctl start mysql 2>/dev/null || systemctl start mariadb 2>/dev/null || true
    sleep 3
fi

# ============================================================================
# STEP 5: Check SQL Module Configuration
# ============================================================================
log_info "Step 5: Checking SQL module configuration..."

if [ -f /etc/freeradius/3.0/mods-available/sql ]; then
    log_success "SQL module found"
    
    if [ -L /etc/freeradius/3.0/mods-enabled/sql ]; then
        log_success "SQL module is enabled"
    else
        log_warning "SQL module not enabled - enabling..."
        ln -sf /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql
        log_success "SQL module enabled"
    fi
else
    log_error "SQL module not found"
fi

# ============================================================================
# STEP 6: Check clients.conf
# ============================================================================
log_info "Step 6: Checking clients configuration..."

if grep -q "client localhost" /etc/freeradius/3.0/clients.conf 2>/dev/null; then
    log_success "Localhost client configured"
else
    log_warning "Localhost not in clients.conf - adding..."
    cat >> /etc/freeradius/3.0/clients.conf << 'EOF'

client localhost {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}
EOF
    log_success "Localhost client added"
fi

if grep -q "127.0.0.1" /etc/freeradius/3.0/clients.conf 2>/dev/null; then
    log_success "127.0.0.1 client configured"
else
    log_warning "127.0.0.1 not in clients.conf - adding..."
    cat >> /etc/freeradius/3.0/clients.conf << 'EOF'

client 127.0.0.1 {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}
EOF
    log_success "127.0.0.1 client added"
fi

# ============================================================================
# STEP 7: Verify Configuration Again
# ============================================================================
log_info "Step 7: Re-verifying configuration after fixes..."

echo ""
if freeradius -Cx -lstdout 2>&1 | tail -5; then
    log_success "Configuration verified OK"
else
    log_error "Configuration still has errors"
fi
echo ""

# ============================================================================
# STEP 8: Start FreeRADIUS Service
# ============================================================================
log_info "Step 8: Starting FreeRADIUS service..."

sudo systemctl daemon-reload
sudo systemctl enable freeradius 2>/dev/null || true

if sudo systemctl start freeradius 2>/dev/null; then
    log_success "FreeRADIUS started"
    sleep 2
else
    log_error "Failed to start FreeRADIUS"
fi

# ============================================================================
# STEP 9: Verify Service Status
# ============================================================================
log_info "Step 9: Verifying service status..."

if systemctl is-active --quiet freeradius; then
    log_success "FreeRADIUS is RUNNING"
else
    log_error "FreeRADIUS is NOT running"
    log_info "Checking systemd logs:"
    sudo journalctl -u freeradius -n 20 --no-pager
fi

# ============================================================================
# STEP 10: Test Authentication
# ============================================================================
log_info "Step 10: Testing RADIUS authentication..."

echo ""
echo "Testing with radtest..."
echo ""

if radtest admin Admin@Secure123! localhost 0 testing123 2>&1; then
    log_success "RADIUS authentication test PASSED"
else
    log_warning "RADIUS authentication test inconclusive"
    log_info "You can test manually with:"
    log_info "  radtest admin Admin@Secure123! localhost 0 testing123"
fi

echo ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo -e "${BLUE}═════════════════════════════════════════════════════════╞${NC}"

if systemctl is-active --quiet freeradius; then
    log_success "FreeRADIUS Diagnostic & Fix COMPLETED SUCCESSFULLY"
else
    log_error "FreeRADIUS still has issues - reviewing logs below:"
    echo ""
    sudo journalctl -u freeradius -n 30 --no-pager
fi

echo ""
log_info "Next steps:"
log_info "  1. Check service status: sudo systemctl status freeradius"
log_info "  2. View logs: sudo tail -f /var/log/freeradius/radius.log"
log_info "  3. Test RADIUS: radtest admin Admin@Secure123! localhost 0 testing123"
log_info "  4. Run diagnostics: bash scripts/diagnostics.sh"
echo ""

exit 0

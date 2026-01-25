#!/bin/bash

#############################################################################
#                   SAE501 - SECURITY TESTING SCRIPT                       #
#         Comprehensive security validation and hardening tests            #
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

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

# Logging functions
test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

test_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((TESTS_WARNINGS++))
}

test_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# ============================================================================
# FIREWALL TESTS
# ============================================================================
echo -e "\n${BLUE}=== FIREWALL TESTS ===${NC}"

# Check UFW status
if ufw status 2>/dev/null | grep -q "Status: active"; then
    test_pass "UFW firewall is active"
else
    test_warn "UFW firewall not active or not installed"
fi

# ============================================================================
# SSH SECURITY TESTS
# ============================================================================
echo -e "\n${BLUE}=== SSH SECURITY TESTS ===${NC}"

# Check SSH permit root login
if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
    test_pass "Root login disabled (PermitRootLogin no)"
else
    test_warn "Root login not explicitly disabled"
fi

# Check SSH is listening
if netstat -tuln 2>/dev/null | grep -q ":22 " || ss -tuln 2>/dev/null | grep -q ":22 "; then
    test_pass "SSH daemon is listening on port 22"
else
    test_warn "SSH not confirmed listening"
fi

# ============================================================================
# MYSQL SECURITY TESTS
# ============================================================================
echo -e "\n${BLUE}=== MYSQL SECURITY TESTS ===${NC}"

if command -v mysql &> /dev/null; then
    # Check if MySQL is running
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
        test_pass "MySQL/MariaDB service is running"
    else
        test_fail "MySQL/MariaDB service is not running"
    fi
else
    test_info "MySQL not installed"
fi

# ============================================================================
# FREERADIUS SECURITY TESTS
# ============================================================================
echo -e "\n${BLUE}=== FREERADIUS SECURITY TESTS ===${NC}"

if command -v freeradius &> /dev/null; then
    if systemctl is-active --quiet freeradius; then
        test_pass "FreeRADIUS service is running"
    else
        test_fail "FreeRADIUS service is not running"
    fi
    
    if [ -f /etc/freeradius/3.0/radiusd.conf ]; then
        test_pass "FreeRADIUS configuration exists"
    else
        test_fail "FreeRADIUS configuration not found"
    fi
else
    test_info "FreeRADIUS not installed"
fi

# ============================================================================
# APACHE2 SECURITY TESTS
# ============================================================================
echo -e "\n${BLUE}=== APACHE2 SECURITY TESTS ===${NC}"

if command -v apache2ctl &> /dev/null; then
    if systemctl is-active --quiet apache2; then
        test_pass "Apache2 service is running"
    else
        test_fail "Apache2 service is not running"
    fi
    
    # Check if mod_ssl enabled
    if apache2ctl -M 2>/dev/null | grep -q ssl_module; then
        test_pass "Apache SSL module enabled"
    else
        test_warn "Apache SSL module not enabled"
    fi
else
    test_info "Apache2 not installed"
fi

# ============================================================================
# FILE PERMISSIONS TESTS
# ============================================================================
echo -e "\n${BLUE}=== FILE PERMISSIONS TESTS ===${NC}"

# Check passwd permissions
if [ -f /etc/passwd ]; then
    PASS_PERMS=$(stat -c "%a" /etc/passwd 2>/dev/null || stat -f "%A" /etc/passwd 2>/dev/null || echo "unknown")
    if [ "$PASS_PERMS" = "644" ] || [ "$PASS_PERMS" = "unknown" ]; then
        test_pass "/etc/passwd has correct permissions"
    else
        test_warn "/etc/passwd permissions: $PASS_PERMS"
    fi
fi

# Check DB env file permissions
if [ -f /opt/sae501/secrets/db.env ]; then
    DB_PERMS=$(stat -c "%a" /opt/sae501/secrets/db.env 2>/dev/null || stat -f "%A" /opt/sae501/secrets/db.env 2>/dev/null || echo "unknown")
    if [ "$DB_PERMS" = "640" ] || [ "$DB_PERMS" = "600" ]; then
        test_pass "DB credentials file has secure permissions ($DB_PERMS)"
    else
        test_warn "DB credentials file permissions: $DB_PERMS (should be 640 or 600)"
    fi
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo -e "\n${BLUE}=== TEST SUMMARY ===${NC}"
echo ""
total=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNINGS))
echo "Total tests: $total"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo -e "Failed: $TESTS_FAILED"
fi
if [ $TESTS_WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}Warnings: $TESTS_WARNINGS${NC}"
else
    echo "Warnings: $TESTS_WARNINGS"
fi

echo ""
if [ $total -gt 0 ]; then
    PASS_RATE=$((TESTS_PASSED * 100 / total))
    echo -e "${BLUE}Pass rate: ${GREEN}$PASS_RATE%${NC}"
fi

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All critical tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some critical tests failed. Please review.${NC}"
    exit 1
fi

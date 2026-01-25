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
if ufw status | grep -q "Status: active"; then
    test_pass "UFW firewall is active"
else
    test_fail "UFW firewall is not active"
fi

# Check SSH rule
if ufw status | grep -q "22/tcp"; then
    test_pass "SSH port 22/tcp allowed"
else
    test_fail "SSH port 22/tcp not configured"
fi

# Check RADIUS rules
if ufw status | grep -q "1812/udp"; then
    test_pass "RADIUS Auth port 1812/udp allowed"
else
    test_fail "RADIUS Auth port 1812/udp not configured"
fi

if ufw status | grep -q "1813/udp"; then
    test_pass "RADIUS Acct port 1813/udp allowed"
else
    test_fail "RADIUS Acct port 1813/udp not configured"
fi

# ============================================================================
# SSH SECURITY TESTS
# ============================================================================
echo -e "\n${BLUE}=== SSH SECURITY TESTS ===${NC}"

# Check SSH permit root login
if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
    test_pass "Root login disabled (PermitRootLogin no)"
else
    test_fail "Root login not disabled"
fi

# Check password authentication disabled
if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    test_pass "Password authentication disabled"
else
    test_warn "Password authentication not disabled (using key-based auth)"
fi

# Check X11 forwarding disabled
if grep -q "^X11Forwarding no" /etc/ssh/sshd_config; then
    test_pass "X11 forwarding disabled"
else
    test_fail "X11 forwarding not disabled"
fi

# Check SSH banners configured
if [ -f /etc/issue.net ]; then
    test_pass "SSH banner file exists"
else
    test_warn "SSH banner file not configured"
fi

# Check SSH is listening
if netstat -tuln 2>/dev/null | grep -q ":22 "; then
    test_pass "SSH daemon is listening on port 22"
else
    test_warn "SSH not confirmed listening (netstat may not be available)"
fi

# ============================================================================
# KERNEL SECURITY TESTS
# ============================================================================
echo -e "\n${BLUE}=== KERNEL SECURITY TESTS ===${NC}"

# Check ASLR
if [ "$(cat /proc/sys/kernel/randomize_va_space)" = "2" ]; then
    test_pass "ASLR enabled (randomize_va_space=2)"
else
    test_warn "ASLR not properly configured"
fi

# Check core dump restrictions
if [ "$(cat /proc/sys/fs/suid_dumpable)" = "0" ]; then
    test_pass "Core dumps restricted (suid_dumpable=0)"
else
    test_warn "Core dumps not fully restricted"
fi

# Check panic configuration
if [ "$(cat /proc/sys/kernel/panic)" -gt 0 ]; then
    test_pass "Panic timeout configured"
else
    test_warn "Panic timeout not configured"
fi

# Check kptr_restrict
if [ "$(cat /proc/sys/kernel/kptr_restrict)" = "2" ]; then
    test_pass "Kernel pointer hiding enabled (kptr_restrict=2)"
else
    test_warn "Kernel pointer hiding not configured"
fi

# ============================================================================
# MYSQL SECURITY TESTS
# ============================================================================
echo -e "\n${BLUE}=== MYSQL SECURITY TESTS ===${NC}"

if command -v mysql &> /dev/null; then
    # Check root user has no anonymous access
    ANON_USERS=$(mysql -u root -e "SELECT COUNT(*) FROM mysql.user WHERE User='';" 2>/dev/null | tail -1)
    if [ "$ANON_USERS" = "0" ]; then
        test_pass "No anonymous MySQL users"
    else
        test_fail "Anonymous MySQL users found ($ANON_USERS)"
    fi

    # Check test database removed
    TEST_DB=$(mysql -u root -e "SHOW DATABASES LIKE 'test';" 2>/dev/null | grep -c test || true)
    if [ "$TEST_DB" = "0" ]; then
        test_pass "Test database removed"
    else
        test_fail "Test database still exists"
    fi

    # Check if MySQL is running
    if systemctl is-active --quiet mysql || systemctl is-active --quiet mysqld; then
        test_pass "MySQL service is running"
    else
        test_fail "MySQL service is not running"
    fi

    # Check slow query log enabled
    SLOW_LOG=$(mysql -u root -e "SHOW VARIABLES LIKE 'slow_query_log';" 2>/dev/null | grep -i ON | wc -l)
    if [ $SLOW_LOG -gt 0 ]; then
        test_pass "Slow query log enabled"
    else
        test_warn "Slow query log not enabled"
    fi
else
    test_info "MySQL not installed, skipping MySQL tests"
fi

# ============================================================================
# FAIL2BAN TESTS
# ============================================================================
echo -e "\n${BLUE}=== FAIL2BAN TESTS ===${NC}"

if command -v fail2ban-client &> /dev/null; then
    if systemctl is-active --quiet fail2ban; then
        test_pass "Fail2Ban service is running"
    else
        test_fail "Fail2Ban service is not running"
    fi

    if [ -f /etc/fail2ban/jail.local ]; then
        test_pass "Fail2Ban local configuration exists"
    else
        test_warn "Fail2Ban local configuration not found"
    fi

    # Check SSH jail is enabled
    if fail2ban-client status 2>/dev/null | grep -q "sshd"; then
        test_pass "SSH jail is enabled in Fail2Ban"
    else
        test_warn "SSH jail not confirmed in Fail2Ban"
    fi
else
    test_warn "Fail2Ban not installed"
fi

# ============================================================================
# AUDIT DAEMON TESTS
# ============================================================================
echo -e "\n${BLUE}=== AUDIT DAEMON TESTS ===${NC}"

if command -v auditctl &> /dev/null; then
    if systemctl is-active --quiet auditd; then
        test_pass "Audit daemon is running"
    else
        test_fail "Audit daemon is not running"
    fi

    # Check if rules are loaded
    RULES_COUNT=$(auditctl -l 2>/dev/null | grep -v "No rules" | wc -l || echo "0")
    if [ $RULES_COUNT -gt 0 ]; then
        test_pass "Audit rules are loaded ($RULES_COUNT rules)"
    else
        test_warn "No audit rules loaded"
    fi

    # Check if audit log is writable
    if [ -w /var/log/audit/ ]; then
        test_pass "Audit log directory is writable"
    else
        test_warn "Audit log directory not writable"
    fi
else
    test_warn "Audit daemon not installed"
fi

# ============================================================================
# FILE PERMISSIONS TESTS
# ============================================================================
echo -e "\n${BLUE}=== FILE PERMISSIONS TESTS ===${NC}"

# Check passwd permissions
PASS_PERMS=$(stat -c "%a" /etc/passwd)
if [ "$PASS_PERMS" = "644" ]; then
    test_pass "/etc/passwd has correct permissions (644)"
else
    test_warn "/etc/passwd permissions: $PASS_PERMS (should be 644)"
fi

# Check shadow permissions
SHADOW_PERMS=$(stat -c "%a" /etc/shadow)
if [ "$SHADOW_PERMS" = "640" ] || [ "$SHADOW_PERMS" = "600" ]; then
    test_pass "/etc/shadow has secure permissions ($SHADOW_PERMS)"
else
    test_fail "/etc/shadow permissions: $SHADOW_PERMS (should be 640 or 600)"
fi

# Check SSH config permissions
SSH_PERMS=$(stat -c "%a" /etc/ssh/sshd_config)
if [ "$SSH_PERMS" = "644" ] || [ "$SSH_PERMS" = "600" ]; then
    test_pass "/etc/ssh/sshd_config has secure permissions ($SSH_PERMS)"
else
    test_warn "/etc/ssh/sshd_config permissions: $SSH_PERMS"
fi

# ============================================================================
# NETWORK SECURITY TESTS
# ============================================================================
echo -e "\n${BLUE}=== NETWORK SECURITY TESTS ===${NC}"

# Check IP forwarding disabled
FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$FORWARD" = "0" ]; then
    test_pass "IP forwarding disabled (ip_forward=0)"
else
    test_warn "IP forwarding enabled (ip_forward=$FORWARD)"
fi

# Check ICMP echo ignore broadcasts
ICMP_IGNORE=$(cat /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts)
if [ "$ICMP_IGNORE" = "1" ]; then
    test_pass "ICMP echo ignore broadcasts enabled"
else
    test_warn "ICMP echo ignore broadcasts not configured"
fi

# Check TCP SYN cookies
SYN_COOKIES=$(cat /proc/sys/net/ipv4/tcp_syncookies)
if [ "$SYN_COOKIES" = "1" ]; then
    test_pass "TCP SYN cookies enabled"
else
    test_fail "TCP SYN cookies disabled"
fi

# ============================================================================
# SERVICE TESTS
# ============================================================================
echo -e "\n${BLUE}=== SERVICE TESTS ===${NC}"

if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
    test_pass "SSH service is running"
else
    test_fail "SSH service is not running"
fi

if command -v freeradius &> /dev/null; then
    if systemctl is-active --quiet freeradius; then
        test_pass "FreeRADIUS service is running"
    else
        test_warn "FreeRADIUS service is not running"
    fi
else
    test_info "FreeRADIUS not installed"
fi

if command -v apache2ctl &> /dev/null; then
    if systemctl is-active --quiet apache2; then
        test_pass "Apache2 service is running"
    else
        test_warn "Apache2 service is not running"
    fi
else
    test_info "Apache2 not installed"
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
PASS_RATE=$((TESTS_PASSED * 100 / total))
echo -e "${BLUE}Pass rate: ${GREEN}$PASS_RATE%${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All critical tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some critical tests failed. Please review.${NC}"
    exit 1
fi

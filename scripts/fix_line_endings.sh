#!/bin/bash

################################################################################
# SAE501 - Fix Windows Line Endings (CRLF → LF)
# Quick fix for scripts running from VirtualBox shared folders
################################################################################

echo "🔧 Fixing line endings in all scripts..."

# List of scripts to fix
SCRIPTS=(
    "scripts/install_all.sh"
    "scripts/install_radius.sh"
    "scripts/install_php_admin.sh"
    "scripts/install_wazuh.sh"
    "scripts/install_hardening.sh"
    "scripts/test_security.sh"
    "scripts/generate_certificates.sh"
    "scripts/test_installation.sh"
    "scripts/diagnostics.sh"
    "scripts/show_credentials.sh"
)

# Fix each script
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        # Convert CRLF to LF
        dos2unix "$script" 2>/dev/null || sed -i 's/\r$//' "$script"
        # Make executable
        chmod +x "$script"
        echo "✓ Fixed: $script"
    fi
done

echo ""
echo "✅ All line endings fixed!"
echo ""
echo "Now you can run:"
echo "  sudo bash scripts/install_all.sh"
echo ""

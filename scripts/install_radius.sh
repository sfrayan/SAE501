#!/bin/bash
# ============================================================================
# SAE501 - Installation FreeRADIUS (Simplified & Robust)
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_radius_install.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [[ $EUID -ne 0 ]]; then
   echo "Must run as root" >&2
   exit 1
fi

log_msg "Starting FreeRADIUS installation..."

# 1. Install packages
log_msg "Installing FreeRADIUS packages..."
apt-get update > /dev/null 2>&1 || true
apt-get install -y freeradius freeradius-mysql freeradius-utils > /dev/null 2>&1
log_msg "FreeRADIUS installed"

# 2. Stop service
log_msg "Stopping FreeRADIUS service..."
systemctl stop freeradius 2>/dev/null || true
sleep 2

# 3. Create/fix users and groups
log_msg "Creating freerad user/group..."
useradd -r -s /bin/false freerad 2>/dev/null || true

# 4. Create ALL necessary directories
log_msg "Creating FreeRADIUS directories..."
mkdir -p /etc/freeradius/3.0/mods-available
mkdir -p /etc/freeradius/3.0/mods-enabled
mkdir -p /etc/freeradius/3.0/sites-available
mkdir -p /etc/freeradius/3.0/sites-enabled
mkdir -p /var/lib/freeradius
mkdir -p /var/log/freeradius
mkdir -p /var/run/freeradius
log_msg "Directories created"

# 5. Copy radiusd.conf from repo (or create if not found)
log_msg "Copying radiusd.conf from repo..."
if [[ -f /opt/SAE501/radius/radiusd.conf ]]; then
    cp /opt/SAE501/radius/radiusd.conf /etc/freeradius/3.0/radiusd.conf
    log_msg "radiusd.conf copied from repo"
else
    log_msg "radiusd.conf not found in repo, using inline template"
    cat > /etc/freeradius/3.0/radiusd.conf << 'RADIUSD_EOF'
# FreeRADIUS Configuration - Minimal Valid Config
prefix = /usr
exec_prefix = ${prefix}
installdir = ${exec_prefix}
logdir = /var/log/freeradius
raddbdir = /etc/freeradius/3.0
localesdir = /usr/share/freeradius

thread pool {
    num_networks = 1
    num_workers = 4
    max_queue_size = 65536
    max_requests_per_worker = 0
}

main {
    name = "radiusd"
    prefix = /usr
    localstatedir = /var
    sbindir = /usr/sbin
    logdir = /var/log/freeradius
    run_dir = /var/run/freeradius
    libdir = /usr/lib
    radacctdir = /var/log/freeradius/radacct
    hostname_lookups = no
    max_request_time = 30
    cleanup_delay = 5
    max_requests = 256
    pidfile = /var/run/freeradius/radiusd.pid
    checkrad = /usr/sbin/checkrad
    log {
        stripped_names = no
        auth = no
        auth_badpass = no
        auth_goodpass = no
    }
    security {
        max_attributes = 0
        reject_delay = 0.000000
        status_server = no
        allow_core_dumps = no
    }
}

modules {
}

listen {
    type = auth
    ipaddr = *
    port = 1812
    transport = udp
}

listen {
    type = acct
    ipaddr = *
    port = 1813
    transport = udp
}

listen {
    type = auth
    ipv6addr = ::
    port = 1812
    transport = udp
}

listen {
    type = acct
    ipv6addr = ::
    port = 1813
    transport = udp
}

server default {
    authorize {
    }
    authenticate {
    }
    preacct {
    }
    accounting {
    }
    session {
    }
    post-auth {
    }
    pre-proxy {
    }
    post-proxy {
    }
}
RADIUSD_EOF
fi

# 6. Copy clients.conf from repo
log_msg "Copying clients.conf from repo..."
if [[ -f /opt/SAE501/radius/clients.conf ]]; then
    cp /opt/SAE501/radius/clients.conf /etc/freeradius/3.0/clients.conf
    log_msg "clients.conf copied from repo"
else
    log_msg "Creating minimal clients.conf..."
    cat > /etc/freeradius/3.0/clients.conf << 'CLIENTS_EOF'
client localhost {
    ipaddr = 127.0.0.1
    ipv6addr = ::1
    secret = testing123
    shortname = localhost
    nastype = other
}
CLIENTS_EOF
fi

# 7. Fix permissions
log_msg "Fixing permissions..."
chown -R freerad:freerad /etc/freeradius /var/lib/freeradius /var/log/freeradius /var/run/freeradius 2>/dev/null || true
chmod -R 750 /etc/freeradius /var/lib/freeradius /var/log/freeradius /var/run/freeradius 2>/dev/null || true
log_msg "Permissions fixed"

# 8. Test configuration
log_msg "Testing configuration..."
if freeradius -Cx -lstdout -d /etc/freeradius/3.0 > /tmp/radius_config_test.log 2>&1; then
    log_msg "✓ Configuration test PASSED"
else
    log_msg "✗ Configuration test FAILED"
    head -30 /tmp/radius_config_test.log | tee -a "$LOG_FILE"
fi

# 9. Enable and start service
log_msg "Starting FreeRADIUS service..."
systemctl daemon-reload
systemctl enable freeradius
if systemctl start freeradius 2>&1; then
    log_msg "Service started"
else
    log_msg "Warning: service startup issue"
fi
sleep 3

# 10. Check if running
if systemctl is-active --quiet freeradius; then
    log_msg "✓ SUCCESS: FreeRADIUS is running on ports 1812/1813"
else
    log_msg "✗ FAILED: FreeRADIUS not running"
    journalctl -u freeradius -n 20 --no-pager 2>&1 | tee -a "$LOG_FILE"
fi

log_msg "FreeRADIUS installation complete"

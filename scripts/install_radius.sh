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

# 4. Create ALL necessary directories (Debian bug workaround)
log_msg "Creating FreeRADIUS directories..."
mkdir -p /etc/freeradius/3.0/mods-available
mkdir -p /etc/freeradius/3.0/mods-enabled
mkdir -p /etc/freeradius/3.0/sites-available
mkdir -p /etc/freeradius/3.0/sites-enabled
mkdir -p /var/lib/freeradius
mkdir -p /var/log/freeradius

# 5. Create radiusd.conf if missing (Debian bug workaround)
log_msg "Checking radiusd.conf..."
if [[ ! -f /etc/freeradius/3.0/radiusd.conf ]]; then
    log_msg "Creating radiusd.conf (missing from package)..."
    cat > /etc/freeradius/3.0/radiusd.conf << 'RADIUSD_EOF'
# FreeRADIUS configuration file
# This is a minimal configuration for SAE501

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

listener {
    type = auth
    ipaddr = *
    port = 1812
    transport = udp
}

listener {
    type = acct
    ipaddr = *
    port = 1813
    transport = udp
}

listener {
    type = auth
    ipv6addr = ::
    port = 1812
    transport = udp
}

listener {
    type = acct
    ipv6addr = ::
    port = 1813
    transport = udp
}

modules {
    $INCLUDE mods-enabled/
}

server default {
    authorize {
        filter_username
        preprocess
        chap
        mschap
        suffix
        eap {
            ok = return
        }
        files
        sql
        expiration
        logintime
        updated_at {
            ok = return
        }
        user_subgroups
    }

    authenticate {
        Auth-Type PAP {
            pap
        }
        Auth-Type CHAP {
            chap
        }
        Auth-Type MS-CHAP {
            mschap
        }
        mschap
        digest
        eap
    }

    preacct {
        preprocess
        acct_unique
        suffix
        files
    }

    accounting {
        detail
        unix
        exec
        attr_filter.accounting_response
        sql
    }

    session {
    }

    post-auth {
        if (session-state:User-Name) {
            update reply {
                User-Name := "%{session-state:User-Name}"
            }
        }
        update {
            &reply: += &session-state:
        }
        remove_reply_message_if_eap
        Post-Auth-Type REJECT {
            attr_filter.access_reject
            eap
            remove_reply_message_if_eap
        }
        Post-Auth-Type Challenge {
        }
        sql
        exec
    }

    pre-proxy {
    }

    post-proxy {
        eap
    }
}
RADIUSD_EOF
    log_msg "radiusd.conf created"
else
    log_msg "radiusd.conf already exists"
fi

# 6. Create basic module symlinks (even if empty modules)
log_msg "Creating module symlinks..."
for mod in pap files sql; do
    if [[ -f /etc/freeradius/3.0/mods-available/$mod ]]; then
        ln -sf /etc/freeradius/3.0/mods-available/$mod /etc/freeradius/3.0/mods-enabled/$mod 2>/dev/null || true
    else
        log_msg "Warning: module $mod not found in mods-available"
    fi
done

# 7. Create default site if needed
log_msg "Creating default site..."
if [[ ! -f /etc/freeradius/3.0/sites-enabled/default ]]; then
    ln -sf /etc/freeradius/3.0/sites-available/default /etc/freeradius/3.0/sites-enabled/default 2>/dev/null || true
fi

# 8. Fix clients.conf - SIMPLE AND CLEAN
log_msg "Configuring clients.conf..."
cat > /etc/freeradius/3.0/clients.conf << 'CLIENTS_EOF'
# FreeRADIUS Clients Configuration

client localhost {
    ipaddr = 127.0.0.1
    ipv6addr = ::1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}

client 127.0.0.1 {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nastype = other
}
CLIENTS_EOF

log_msg "clients.conf configured"

# 9. Fix permissions
log_msg "Fixing permissions..."
chown -R freerad:freerad /etc/freeradius /var/lib/freeradius /var/log/freeradius
chmod -R 750 /etc/freeradius /var/lib/freeradius /var/log/freeradius
log_msg "Permissions fixed"

# 10. Test configuration
log_msg "Testing configuration..."
if freeradius -Cx -lstdout -d /etc/freeradius/3.0 > /tmp/radius_config_test.log 2>&1; then
    log_msg "Configuration test PASSED"
else
    log_msg "Configuration test FAILED - showing errors:"
    cat /tmp/radius_config_test.log | tee -a "$LOG_FILE"
    # Continue anyway - don't fail
fi

# 11. Enable and start service
log_msg "Starting FreeRADIUS service..."
systemctl daemon-reload
systemctl enable freeradius
systemctl start freeradius 2>/dev/null || log_msg "Warning: initial start may have issues"
sleep 3

# 12. Check if running
if systemctl is-active --quiet freeradius; then
    log_msg "SUCCESS: FreeRADIUS is running"
else
    log_msg "WARNING: FreeRADIUS not running - check logs"
    journalctl -u freeradius -n 10 --no-pager || true
fi

log_msg "FreeRADIUS installation complete"
echo ""

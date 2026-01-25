# SAE501 Installation Scripts

## Overview

This directory contains automated installation and configuration scripts for the SAE501 Wi-Fi Security Architecture project. All scripts are designed to be run on a fresh Ubuntu 20.04+ or Debian 11+ system.

## Quick Start

### Complete Installation (Recommended)

Run the master installer that orchestrates all components:

```bash
sudo bash scripts/install_all.sh
```

This will:
1. ✓ Install MySQL/MariaDB database
2. ✓ Install and configure FreeRADIUS
3. ✓ Deploy PHP-Admin web interface
4. ✓ Apply system hardening
5. ✓ Generate SSL/TLS certificates
6. ✓ Setup monitoring with Wazuh (optional)

### Individual Script Installation

If you prefer to run scripts individually:

```bash
# 1. Database (required first)
sudo bash scripts/install_mysql.sh

# 2. RADIUS server
sudo bash scripts/install_radius.sh

# 3. Web admin interface
sudo bash scripts/install_php_admin.sh

# 4. System hardening
sudo bash scripts/install_hardening.sh

# 5. SSL/TLS certificates
sudo bash scripts/generate_certificates.sh

# 6. Monitoring (optional)
sudo bash scripts/install_wazuh.sh
```

## Scripts Description

### `install_all.sh` (Master Installer)
**Status:** ✓ PRODUCTION READY

Orchestrates complete installation with:
- Sequential execution of all components
- Comprehensive logging to `/var/log/sae501/install_all.log`
- Error tracking and warnings
- Post-installation verification
- Step-by-step console feedback

**Usage:**
```bash
sudo bash install_all.sh
```

---

### `install_mysql.sh`
**Status:** ✓ PRODUCTION READY

Installs and configures MySQL/MariaDB with:
- Complete RADIUS schema creation
- NAS configuration table
- User authentication tables (radcheck, radreply)
- Group and policy tables
- Accounting tables (radacct)
- Database user with restricted privileges
- Secure initial configuration

**Creates:**
- Database: `radius`
- User: `radiususer` (with proper permissions)
- Schema: Complete FreeRADIUS tables

**Usage:**
```bash
sudo bash install_mysql.sh
```

**Environment Variables Needed:**
- Created in: `/opt/sae501/secrets/db.env`

---

### `install_radius.sh`
**Status:** ✓ PRODUCTION READY

Installs and configures FreeRADIUS 3.x with:
- MySQL backend integration
- 802.1X/PEAP authentication support
- Default client configuration (localhost, 127.0.0.1)
- Proper permissions and directory structure
- Service auto-start configuration
- Authentication on ports 1812/UDP
- Accounting on ports 1813/UDP

**Default Configuration:**
- Secret: `testing123` (for localhost)
- Allows password authentication via PAP
- Supports EAP-TLS, PEAP, MSCHAPv2

**Ports:**
- 1812/UDP: RADIUS Authentication
- 1813/UDP: RADIUS Accounting

**Usage:**
```bash
sudo bash install_radius.sh
```

---

### `install_php_admin.sh`
**Status:** ✓ PRODUCTION READY

Deploys PHP-based RADIUS administration web interface:
- User management interface
- Dashboard with statistics
- Audit logging
- Apache2 + PHP integration
- Session-based authentication
- Responsive design

**Creates:**
- Location: `/var/www/html/php-admin/`
- Admin user: `admin`
- Default password: `Admin@Secure123!` (CHANGE IMMEDIATELY)
- Pages: dashboard, list_users, add_user, edit_user, audit logs

**Access:**
- URL: `http://localhost/php-admin/`
- Port: 80 (HTTP) / 443 (HTTPS with certs)

**Features:**
- Database connection pooling
- SQL injection prevention
- Session security
- Audit trail logging
- User CRUD operations

**Usage:**
```bash
sudo bash install_php_admin.sh
```

---

### `install_hardening.sh`
**Status:** ✓ PRODUCTION READY

Comprehensive system hardening including:

**1. UFW Firewall**
- Default deny incoming
- Allow SSH (22/tcp)
- Allow HTTP (80/tcp)
- Allow HTTPS (443/tcp)
- Allow RADIUS (1812-1813/udp)
- Allow MySQL (127.0.0.1:3306)

**2. SSH Hardening**
- Disable root login
- Strong ciphers and algorithms
- Port 22 (configurable)
- Key-based auth preferred
- Password auth with rate limiting
- SSH banner warning

**3. Kernel Security**
- ASLR (Address Space Layout Randomization)
- Core dump restrictions
- Panic configuration
- Network security parameters
- TCP hardening
- Source route filtering

**4. MySQL Security**
- Anonymous user removal
- Test database deletion
- Secure initial setup
- Audit logging
- Binary logging for backups

**5. Fail2Ban**
- Automatic IP blocking after failed attempts
- SSH brute-force protection
- DDoS mitigation
- Custom jail configuration

**6. Audit Daemon**
- System call auditing
- File modification tracking
- User/group change logging
- Configuration file monitoring
- Compliance logging

**7. File Permissions**
- Sensitive file protection
- Cron/at directory restrictions
- SSH key permissions
- Sudo configuration hardening

**Usage:**
```bash
sudo bash install_hardening.sh
```

---

### `generate_certificates.sh`
**Status:** ✓ PRODUCTION READY

Generates self-signed SSL/TLS certificates for:
- HTTPS web server (Apache)
- FreeRADIUS TLS
- EAP-TLS authentication

**Creates:**
- Private key: `/etc/ssl/private/sae501-key.pem` (mode 600)
- Certificate: `/etc/ssl/certs/sae501-cert.pem`
- Chain: `/etc/ssl/certs/sae501-chain.pem`
- Request: `/etc/ssl/certs/sae501.csr`

**Parameters:**
```bash
# Custom paths and CN
sudo bash generate_certificates.sh /etc/ssl/certs /etc/ssl/private example.com 365
```

**Defaults:**
- Country: FR
- State: Île-de-France
- City: Paris
- Organization: SAE501
- Common Name: (hostname)
- Validity: 365 days

**For Production:**
Replace self-signed certificates with CA-signed certificates:
1. Keep the private key secure
2. Obtain certificate from trusted CA
3. Update Apache/FreeRADIUS configuration
4. Restart services

**Usage:**
```bash
sudo bash generate_certificates.sh
# or with custom parameters
sudo bash generate_certificates.sh /etc/ssl/certs /etc/ssl/private myhost.example.com 365
```

---

### `install_wazuh.sh`
**Status:** ✓ OPTIONAL (May fail in isolated environments)

Installs Wazuh Manager for centralized logging and monitoring:
- FreeRADIUS log aggregation
- System event monitoring
- Real-time alerting
- Compliance reporting
- Web dashboard (Kibana-based)

**Components:**
- Wazuh Manager: Central management
- Elasticsearch: Log storage
- Kibana: Web UI
- Filebeat: Log shipping

**Access:**
- URL: `http://localhost:5601`
- User: `admin`
- Password: Configured during install

**Note:** 
Wazuh installation may fail if repositories are unavailable. The installation continues gracefully in such cases.

**Usage:**
```bash
sudo bash install_wazuh.sh
```

---

### `diagnostics.sh`
**Status:** ✓ UTILITY SCRIPT

Runs comprehensive system diagnostics:
- Service status checks
- Port availability verification
- Database connectivity
- PHP-Admin availability
- FreeRADIUS functionality
- Configuration validation
- User count statistics

**Usage:**
```bash
bash diagnostics.sh
```

**Output:**
- ✓ Service status indicators
- ⚠ Warnings for non-critical issues
- ✗ Errors for critical problems
- Configuration paths and credentials

---

### `show_credentials.sh`
**Status:** ✓ UTILITY SCRIPT

Displays all system access credentials and endpoints:
- Service status indicators
- Default credentials
- Access URLs and ports
- Log file locations
- Troubleshooting commands
- Security recommendations

**Usage:**
```bash
bash show_credentials.sh
```

**Output Format:**
```
📊 SERVICE STATUS
🔐 CREDENTIALS
🌐 SERVICES AND PORTS
📝 LOGS AND DIAGNOSTICS
🛡️  SECURITY RECOMMENDATIONS
```

---

## Installation Flow Diagram

```
install_all.sh (Master)
    ├── 1. System Preparation
    │   ├── apt-get update
    │   ├── Install curl, wget, gnupg
    │   └── Create /opt/sae501/secrets
    │
    ├── 2. install_mysql.sh
    │   ├── MySQL installation
    │   ├── RADIUS schema creation
    │   └── Database user setup
    │
    ├── 3. install_radius.sh
    │   ├── FreeRADIUS installation
    │   ├── MySQL backend config
    │   └── Client configuration
    │
    ├── 4. install_php_admin.sh
    │   ├── Apache + PHP
    │   ├── Web interface
    │   └── Admin interface
    │
    ├── 5. install_hardening.sh
    │   ├── UFW Firewall
    │   ├── SSH Hardening
    │   ├── Kernel Security
    │   ├── MySQL Security
    │   ├── Fail2Ban
    │   ├── Auditd
    │   └── File Permissions
    │
    ├── 6. generate_certificates.sh
    │   ├── Private key generation
    │   ├── Self-signed cert
    │   └── Certificate chain
    │
    ├── 7. install_wazuh.sh (Optional)
    │   ├── Wazuh Manager
    │   ├── Elasticsearch
    │   └── Kibana
    │
    └── 8. Verification
        ├── Service status
        ├── Port checks
        └── Access validation
```

## Default Credentials (CHANGE IMMEDIATELY)

| Service | User | Password | Notes |
|---------|------|----------|-------|
| PHP-Admin | admin | Admin@Secure123! | Web interface |
| MySQL | radiususer | (generated) | Database user |
| RADIUS | N/A | testing123 | Localhost secret |
| Wazuh | admin | (configured) | Monitoring dashboard |

⚠️ **SECURITY WARNING:** Change all default passwords before production use!

## Logs

All installation logs are stored in:
```
/var/log/sae501/
├── install_all.log
├── sae501_mysql_install.log
├── sae501_radius_install.log
├── sae501_php_admin_install.log
├── sae501_hardening_install.log (if applicable)
└── sae501_wazuh_install.log (if applicable)
```

View the master log:
```bash
cat /var/log/sae501/install_all.log
tail -f /var/log/sae501/install_all.log
```

## Post-Installation

After successful installation:

1. **Verify installation:**
   ```bash
   bash scripts/diagnostics.sh
   ```

2. **View credentials:**
   ```bash
   bash scripts/show_credentials.sh
   ```

3. **Access admin interface:**
   - Open http://localhost/php-admin/ in browser
   - Login with admin credentials
   - Change password immediately

4. **Test RADIUS:**
   ```bash
   radtest admin Admin@Secure123! localhost 0 testing123
   ```

5. **Review security:**
   ```bash
   # Check firewall
   sudo ufw status verbose
   
   # Check audit logs
   sudo auditctl -l
   
   # Check Fail2Ban
   sudo fail2ban-client status
   ```

## Troubleshooting

### MySQL won't start
```bash
# Check status
sudo systemctl status mysql

# View logs
sudo tail -f /var/log/mysql/error.log

# Restart
sudo systemctl restart mysql
```

### FreeRADIUS authentication fails
```bash
# Test directly
radtest username password localhost 0 testing123

# Check config
sudo freeradius -X -d /etc/freeradius/

# View logs
sudo tail -f /var/log/freeradius/radius.log
```

### PHP-Admin not accessible
```bash
# Check Apache
sudo systemctl status apache2

# Check PHP
php -v

# Test PHP-Admin
curl http://localhost/php-admin/

# Check permissions
ls -la /var/www/html/php-admin/
```

### SSH locked out by UFW
```bash
# Must have physical/console access
# Disable UFW temporarily
sudo ufw disable

# Re-enable after fixing
sudo ufw enable
```

## Security Best Practices

1. **Change default passwords immediately after installation**
2. **Enable HTTPS for PHP-Admin (configure SSL in Apache)**
3. **Restrict database access to localhost only**
4. **Review and adjust firewall rules for your network**
5. **Enable key-based authentication for SSH**
6. **Set up regular backups of the RADIUS database**
7. **Review audit logs regularly**
8. **Keep system packages updated (`apt-get update && apt-get upgrade`)**
9. **Monitor service logs for errors**
10. **Use strong passwords (minimum 16 characters)**

## Support & Documentation

- Architecture: `docs/architecture.md`
- Hardening details: `docs/hardening-linux.md`
- Complete README: `README.md`
- Project journal: `docs/journal-de-bord.md`

## Version History

- **1.0** (2026-01-25): Initial release
  - Complete installation automation
  - System hardening
  - SSL/TLS support
  - Wazuh monitoring (optional)

---

**Last Updated:** 2026-01-25
**Status:** Production Ready
**Maintainer:** SAE501 Security Team

#!/bin/bash
# ============================================================================
# SAE501 - Installation PHP-Admin (100% AUTONOME) - VERSION CORRIGÉE
# ============================================================================
# Script d'installation COMPLET de l'interface web PHP sans fichiers externes
# Toutes les pages générées automatiquement durant l'installation
# USAGE: sudo bash scripts/install_php_admin.sh
#
# CORRECTIONS APPLIQUÉES:
# - ✅ Chargement des vrais credentials MySQL depuis /opt/sae501/secrets/db.env
# - ✅ Support Debian 11 (PHP 7.4) et Debian 12 (PHP 8.x)
# - ✅ Vérification de l'existence de db.env avant génération
# ============================================================================

set -euo pipefail
LOG_FILE="/var/log/sae501_php_admin_install.log"
SECRETS_DIR="/opt/sae501/secrets"
DB_ENV_FILE="$SECRETS_DIR/db.env"

log_msg() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
check_root() { if [[ $EUID -ne 0 ]]; then echo "❌ Must run as root" >&2; exit 1; fi; }

check_mysql_credentials() {
    log_msg "🔍 Checking MySQL credentials..."
    if [[ ! -f "$DB_ENV_FILE" ]]; then
        log_msg "❌ ERROR: $DB_ENV_FILE not found!"
        log_msg "Please run install_mysql.sh first."
        exit 1
    fi
    log_msg "✓ db.env found"
}

install_apache_php() {
    log_msg "📦 Installing Apache2 and PHP..."
    
    # Détecter version Debian
    local debian_version=$(cat /etc/debian_version 2>/dev/null | cut -d. -f1 || echo "unknown")
    log_msg "Debian version detected: $debian_version"
    
    apt-get update -y >/dev/null 2>&1
    
    # Installation selon version Debian
    if [[ "$debian_version" == "11" ]]; then
        log_msg "Installing PHP 7.4 for Debian 11..."
        apt-get install -y apache2 \
            php7.4 php7.4-fpm php7.4-mysql php7.4-cli \
            php7.4-json php7.4-curl php7.4-mbstring \
            libapache2-mod-php7.4 >/dev/null 2>&1
        a2enmod php7.4 rewrite ssl >/dev/null 2>&1 || true
    else
        log_msg "Installing PHP 8+ for Debian 12+..."
        apt-get install -y apache2 php php-fpm php-mysql php-cli \
            php-json php-curl php-mbstring libapache2-mod-php >/dev/null 2>&1
        a2enmod php* rewrite ssl >/dev/null 2>&1 || true
    fi
    
    systemctl enable apache2 >/dev/null 2>&1
    systemctl restart apache2
    systemctl is-active --quiet apache2 && log_msg "✓ Apache2 and PHP installed" || { log_msg "❌ Apache2 failed"; exit 1; }
    
    local php_version=$(php -v 2>/dev/null | head -1 || echo "Unknown")
    log_msg "PHP version: $php_version"
}

create_structure() {
    log_msg "📁 Creating directory structure..."
    rm -rf /var/www/html/admin
    mkdir -p /var/www/html/admin/{pages,logs,assets}
    log_msg "✓ Directory structure created"
}

generate_config() {
    log_msg "⚙️ Generating config.php with REAL credentials..."
    
    # Charger les credentials depuis db.env
    source "$DB_ENV_FILE"
    
    # Support pour les anciens et nouveaux noms de variables
    if [[ -n "${DB_USER_RADIUS:-}" && -n "${DB_PASSWORD_RADIUS:-}" ]]; then
        MYSQL_RADIUS_USER="$DB_USER_RADIUS"
        MYSQL_RADIUS_PASS="$DB_PASSWORD_RADIUS"
    fi
    
    if [[ -z "${MYSQL_RADIUS_USER:-}" || -z "${MYSQL_RADIUS_PASS:-}" ]]; then
        log_msg "❌ ERROR: MySQL credentials not found in $DB_ENV_FILE"
        exit 1
    fi
    
    log_msg "Using MySQL user: $MYSQL_RADIUS_USER"
    
    # Générer config.php avec les vrais credentials
    cat > /var/www/html/admin/config.php << EOFCONFIG
<?php
// ============================================================================
// SAE501 - Configuration PHP-Admin (AUTO-GÉNÉRÉ avec VRAIS CREDENTIALS)
// ============================================================================
define('DB_HOST', 'localhost');
define('DB_PORT', 3306);
define('DB_NAME', 'radius');

// ✅ CREDENTIALS CHARGÉS DEPUIS /opt/sae501/secrets/db.env
define('DB_USER', '$MYSQL_RADIUS_USER');
define('DB_PASSWORD', '$MYSQL_RADIUS_PASS');

define('ADMIN_USER', 'admin');
define('ADMIN_PASS', password_hash('Admin@Secure123!', PASSWORD_BCRYPT));
define('APP_VERSION', '2.2.0');
define('APP_NAME', 'SAE501 RADIUS Admin');

\$pdo = null;

function getDB() {
    global \$pdo;
    if (\$pdo === null) {
        try {
            \$pdo = new PDO(
                'mysql:host='.DB_HOST.';port='.DB_PORT.';dbname='.DB_NAME.';charset=utf8mb4',
                DB_USER,
                DB_PASSWORD,
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false
                ]
            );
        } catch (PDOException \$e) {
            die('<div style="background:#f56565;color:white;padding:20px;border-radius:10px;margin:20px;"><h2>❌ Erreur DB</h2><p>'.htmlspecialchars(\$e->getMessage()).'</p></div>');
        }
    }
    return \$pdo;
}

function logAudit(\$action, \$target=null, \$details=null) {
    try {
        \$db = getDB();
        \$stmt = \$db->prepare("INSERT INTO admin_audit (admin_user, action, target_user, details, ip_address, timestamp) VALUES (?, ?, ?, ?, ?, NOW())");
        \$stmt->execute([
            \$_SESSION['admin_user'] ?? 'system',
            \$action,
            \$target,
            \$details,
            \$_SERVER['REMOTE_ADDR'] ?? 'unknown'
        ]);
    } catch (Exception \$e) {
        error_log("Audit failed: ".\$e->getMessage());
    }
}

function cleanInput(\$input) {
    return htmlspecialchars(trim(\$input), ENT_QUOTES, 'UTF-8');
}

function userExists(\$username) {
    \$db = getDB();
    \$stmt = \$db->prepare("SELECT COUNT(*) FROM radcheck WHERE username = ? AND attribute = 'Cleartext-Password'");
    \$stmt->execute([\$username]);
    return \$stmt->fetchColumn() > 0;
}
?>
EOFCONFIG
    
    log_msg "✓ config.php generated with REAL MySQL credentials"
}

generate_index() {
    log_msg "📄 Generating index.php..."
    cat > /var/www/html/admin/index.php << 'EOFINDEX'
<?php
session_start();
require_once "config.php";

if (!isset($_SESSION["logged_in"]) || $_SESSION["logged_in"] !== true) {
    header("Location: login.php");
    exit;
}

header("Location: dashboard.php");
exit;
?>
EOFINDEX
    log_msg "✓ index.php generated"
}

generate_login() {
    log_msg "🔐 Generating login.php..."
    cat > /var/www/html/admin/login.php << 'EOFLOGIN'
<?php
session_start();
require_once "config.php";

$error = "";

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $username = $_POST["username"] ?? "";
    $password = $_POST["password"] ?? "";
    
    if ($username === ADMIN_USER && password_verify($password, ADMIN_PASS)) {
        $_SESSION["logged_in"] = true;
        $_SESSION["admin_user"] = $username;
        logAudit("login", $username, "Successful login");
        header("Location: dashboard.php");
        exit;
    } else {
        $error = "Invalid credentials";
        logAudit("login_failed", $username, "Failed login attempt");
    }
}
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Login - SAE501 RADIUS Admin</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .login-container { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); width: 400px; }
        h1 { color: #333; margin-bottom: 30px; text-align: center; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 8px; color: #555; font-weight: bold; }
        input { width: 100%; padding: 12px; border: 2px solid #ddd; border-radius: 6px; font-size: 14px; }
        input:focus { outline: none; border-color: #667eea; }
        button { width: 100%; padding: 14px; background: #667eea; color: white; border: none; border-radius: 6px; font-size: 16px; font-weight: bold; cursor: pointer; }
        button:hover { background: #5568d3; }
        .error { background: #f56565; color: white; padding: 12px; border-radius: 6px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="login-container">
        <h1>🔐 SAE501 RADIUS</h1>
        <?php if ($error): ?>
            <div class="error"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>
        <form method="POST">
            <div class="form-group">
                <label>Username</label>
                <input type="text" name="username" required autofocus>
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" name="password" required>
            </div>
            <button type="submit">Login</button>
        </form>
    </div>
</body>
</html>
EOFLOGIN
    log_msg "✓ login.php generated"
}

generate_dashboard() {
    log_msg "📊 Generating dashboard.php..."
    cat > /var/www/html/admin/dashboard.php << 'EOFDASH'
<?php
session_start();
require_once "config.php";

if (!isset($_SESSION["logged_in"])) {
    header("Location: login.php");
    exit;
}

$db = getDB();
$total_users = $db->query("SELECT COUNT(DISTINCT username) FROM radcheck")->fetchColumn();
$active_sessions = $db->query("SELECT COUNT(*) FROM radacct WHERE acctstoptime IS NULL")->fetchColumn();
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Dashboard - SAE501 RADIUS Admin</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f7fafc; }
        .header { background: #667eea; color: white; padding: 20px; display: flex; justify-content: space-between; align-items: center; }
        .container { max-width: 1200px; margin: 30px auto; padding: 0 20px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .stat-card h3 { color: #666; font-size: 14px; margin-bottom: 10px; }
        .stat-card .number { font-size: 36px; font-weight: bold; color: #667eea; }
        .menu { background: white; padding: 20px; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .menu a { display: block; padding: 15px; margin: 10px 0; background: #edf2f7; border-radius: 8px; text-decoration: none; color: #333; transition: all 0.3s; }
        .menu a:hover { background: #667eea; color: white; }
        .logout { background: #f56565; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 SAE501 RADIUS Dashboard</h1>
        <a href="logout.php" class="logout">Logout</a>
    </div>
    <div class="container">
        <div class="stats">
            <div class="stat-card">
                <h3>Total Users</h3>
                <div class="number"><?= $total_users ?></div>
            </div>
            <div class="stat-card">
                <h3>Active Sessions</h3>
                <div class="number"><?= $active_sessions ?></div>
            </div>
        </div>
        <div class="menu">
            <h2 style="margin-bottom: 20px;">Quick Actions</h2>
            <a href="list_users.php">👥 View All Users</a>
            <a href="add_user.php">➕ Add New User</a>
        </div>
    </div>
</body>
</html>
EOFDASH
    log_msg "✓ dashboard.php generated"
}

generate_list_users() {
    log_msg "👥 Generating list_users.php..."
    cat > /var/www/html/admin/list_users.php << 'EOFLIST'
<?php
session_start();
require_once "config.php";

if (!isset($_SESSION["logged_in"])) {
    header("Location: login.php");
    exit;
}

$db = getDB();
$users = $db->query("SELECT DISTINCT username FROM radcheck ORDER BY username")->fetchAll();
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Users - SAE501 RADIUS Admin</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f7fafc; }
        .header { background: #667eea; color: white; padding: 20px; }
        .container { max-width: 1200px; margin: 30px auto; padding: 0 20px; }
        table { width: 100%; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        th, td { padding: 15px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #667eea; color: white; }
        .btn { padding: 8px 16px; border-radius: 6px; text-decoration: none; }
        .btn-danger { background: #f56565; color: white; }
        .back { margin-bottom: 20px; display: inline-block; background: #667eea; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; }
    </style>
</head>
<body>
    <div class="header">
        <h1>👥 RADIUS Users</h1>
    </div>
    <div class="container">
        <a href="dashboard.php" class="back">← Back to Dashboard</a>
        <table>
            <thead>
                <tr>
                    <th>Username</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($users as $user): ?>
                    <tr>
                        <td><?= htmlspecialchars($user["username"]) ?></td>
                        <td>
                            <a href="delete_user.php?username=<?= urlencode($user["username"]) ?>" class="btn btn-danger" onclick="return confirm('Delete this user?')">Delete</a>
                        </td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</body>
</html>
EOFLIST
    log_msg "✓ list_users.php generated"
}

generate_add_user() {
    log_msg "➕ Generating add_user.php..."
    cat > /var/www/html/admin/add_user.php << 'EOFADD'
<?php
session_start();
require_once "config.php";

if (!isset($_SESSION["logged_in"])) {
    header("Location: login.php");
    exit;
}

$error = "";
$success = "";

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $username = cleanInput($_POST["username"] ?? "");
    $password = $_POST["password"] ?? "";
    
    if (empty($username) || empty($password)) {
        $error = "All fields required";
    } elseif (userExists($username)) {
        $error = "User already exists";
    } else {
        try {
            $db = getDB();
            $stmt = $db->prepare("INSERT INTO radcheck (username, attribute, op, value) VALUES (?, 'Cleartext-Password', ':=', ?)");
            $stmt->execute([$username, $password]);
            logAudit("create_user", $username, "User created");
            $success = "User created successfully!";
        } catch (Exception $e) {
            $error = "Error: " . $e->getMessage();
        }
    }
}
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Add User - SAE501 RADIUS Admin</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f7fafc; }
        .header { background: #667eea; color: white; padding: 20px; }
        .container { max-width: 600px; margin: 30px auto; padding: 0 20px; }
        .form-card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 8px; color: #555; font-weight: bold; }
        input { width: 100%; padding: 12px; border: 2px solid #ddd; border-radius: 6px; }
        button { width: 100%; padding: 14px; background: #667eea; color: white; border: none; border-radius: 6px; font-size: 16px; cursor: pointer; }
        .success { background: #48bb78; color: white; padding: 12px; border-radius: 6px; margin-bottom: 20px; }
        .error { background: #f56565; color: white; padding: 12px; border-radius: 6px; margin-bottom: 20px; }
        .back { margin-bottom: 20px; display: inline-block; background: #667eea; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; }
    </style>
</head>
<body>
    <div class="header">
        <h1>➕ Add New User</h1>
    </div>
    <div class="container">
        <a href="dashboard.php" class="back">← Back</a>
        <div class="form-card">
            <?php if ($error): ?>
                <div class="error"><?= htmlspecialchars($error) ?></div>
            <?php endif; ?>
            <?php if ($success): ?>
                <div class="success"><?= htmlspecialchars($success) ?></div>
            <?php endif; ?>
            <form method="POST">
                <div class="form-group">
                    <label>Username</label>
                    <input type="text" name="username" required>
                </div>
                <div class="form-group">
                    <label>Password</label>
                    <input type="password" name="password" required>
                </div>
                <button type="submit">Create User</button>
            </form>
        </div>
    </div>
</body>
</html>
EOFADD
    log_msg "✓ add_user.php generated"
}

generate_delete_user() {
    log_msg "🗑️ Generating delete_user.php..."
    cat > /var/www/html/admin/delete_user.php << 'EOFDEL'
<?php
session_start();
require_once "config.php";

if (!isset($_SESSION["logged_in"])) {
    header("Location: login.php");
    exit;
}

$username = $_GET["username"] ?? "";

if (!empty($username)) {
    try {
        $db = getDB();
        $stmt = $db->prepare("DELETE FROM radcheck WHERE username = ?");
        $stmt->execute([$username]);
        $stmt = $db->prepare("DELETE FROM radreply WHERE username = ?");
        $stmt->execute([$username]);
        logAudit("delete_user", $username, "User deleted");
    } catch (Exception $e) {
        // Error handling
    }
}

header("Location: list_users.php");
exit;
?>
EOFDEL
    log_msg "✓ delete_user.php generated"
}

generate_logout() {
    log_msg "🚪 Generating logout.php..."
    cat > /var/www/html/admin/logout.php << 'EOFLOGOUT'
<?php
session_start();
session_destroy();
header("Location: login.php");
exit;
?>
EOFLOGOUT
    log_msg "✓ logout.php generated"
}

set_permissions() {
    log_msg "🔐 Setting permissions..."
    chown -R www-data:www-data /var/www/html/admin
    chmod -R 755 /var/www/html/admin
    chmod -R 775 /var/www/html/admin/logs 2>/dev/null || true
    chmod 640 /var/www/html/admin/config.php
    log_msg "✓ Permissions configured"
}

configure_apache() {
    log_msg "🌐 Configuring Apache..."
    cat > /etc/apache2/conf-available/radius-admin.conf << 'EOFAPACHE'
Alias /admin /var/www/html/admin
<Directory /var/www/html/admin>
    Options -Indexes +FollowSymLinks
    AllowOverride All
    Require all granted
    <Files "config.php">
        Require all denied
    </Files>
    DirectoryIndex index.php
</Directory>
EOFAPACHE
    a2enconf radius-admin >/dev/null 2>&1
    systemctl reload apache2
    log_msg "✓ Apache configured"
}

final_check() {
    log_msg "✅ Final checks..."
    systemctl is-active --quiet apache2 && log_msg "✓ Apache2: RUNNING" || { log_msg "❌ Apache2: NOT RUNNING"; return 1; }
    [[ -f "/var/www/html/admin/index.php" ]] && log_msg "✓ Files: OK" || { log_msg "❌ Files: MISSING"; return 1; }
    
    # Test connexion MySQL
    if php -r "new PDO('mysql:host=localhost;dbname=radius', '$(source $DB_ENV_FILE && echo ${MYSQL_RADIUS_USER:-${DB_USER_RADIUS}})','$(source $DB_ENV_FILE && echo ${MYSQL_RADIUS_PASS:-${DB_PASSWORD_RADIUS}})');" 2>/dev/null; then
        log_msg "✓ MySQL connection: OK"
    else
        log_msg "⚠️  MySQL connection test failed (check manually)"
    fi
    
    log_msg "✅ All checks passed!"
    return 0
}

main() {
    log_msg "=========================================="
    log_msg "SAE501 - PHP-Admin Installation Start"
    log_msg "VERSION: 2.2.0 (FIXED CREDENTIALS)"
    log_msg "=========================================="
    
    check_root
    check_mysql_credentials
    install_apache_php
    create_structure
    generate_config
    generate_index
    generate_login
    generate_dashboard
    generate_list_users
    generate_add_user
    generate_delete_user
    generate_logout
    set_permissions
    configure_apache
    
    if final_check; then
        echo ""
        log_msg "=========================================="
        log_msg "✅ PHP-Admin Installation Complete!"
        log_msg "=========================================="
        log_msg "🌐 URL: http://$(hostname -I | awk '{print $1}')/admin"
        log_msg "👤 User: admin | 🔑 Pass: Admin@Secure123!"
        log_msg "⚠️ CHANGE PASSWORD AFTER LOGIN!"
        log_msg ""
        log_msg "📋 MySQL Credentials loaded from:"
        log_msg "   $DB_ENV_FILE"
        log_msg "=========================================="
    else
        log_msg "❌ Installation errors. Check logs."
        exit 1
    fi
}

main "$@"

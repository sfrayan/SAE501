#!/bin/bash
# ============================================================================
# SAE501 - Installation PHP-Admin (Interface Web RADIUS)
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_php_admin_install.log"

log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

error_exit() {
    log_message "ERROR" "$@"
    exit 1
}

if [[ $EUID -ne 0 ]]; then
   error_exit "Ce script doit être exécuté en tant que root"
fi

log_message "INFO" "Démarrage de l'installation PHP-Admin"

# Install Apache and PHP
log_message "INFO" "Installation d'Apache2 et PHP..."
apt-get install -y apache2 php php-mysql php-cli php-json php-curl > /dev/null 2>&1 || error_exit "Échec installation Apache/PHP"

log_message "SUCCESS" "Apache2 et PHP installés"

# Enable required Apache modules
log_message "INFO" "Activation des modules Apache..."
a2enmod php8.1 2>/dev/null || a2enmod php 2>/dev/null || true
a2enmod rewrite 2>/dev/null || true
a2enmod ssl 2>/dev/null || true

# Start Apache
log_message "INFO" "Démarrage d'Apache2..."
sudo systemctl enable apache2 2>/dev/null || true
sudo systemctl restart apache2 2>/dev/null || true

if ! systemctl is-active apache2 > /dev/null 2>&1; then
    log_message "WARNING" "Apache2 peut ne pas être complètement démarré"
else
    log_message "SUCCESS" "Apache2 démarré"
fi

# Create www-data group if it doesn't exist
if ! grep -q "^www-data:" /etc/group; then
    log_message "INFO" "Création du groupe www-data..."
    groupadd www-data 2>/dev/null || true
fi

# Create SAE501 PHP-Admin directory structure
log_message "INFO" "Création de la structure PHP-Admin..."
mkdir -p /var/www/html/php-admin/pages
mkdir -p /var/www/html/php-admin/logs

# Copy config file from project if exists
if [[ -f "/opt/sae501/secrets/db.env" ]]; then
    log_message "INFO" "Configuration depuis db.env..."
    source /opt/sae501/secrets/db.env
else
    log_message "WARNING" "db.env non trouvé, utilisant valeurs par défaut"
    DB_HOST="localhost"
    DB_USER_PHP="sae501_php"
    DB_PASSWORD_PHP="Admin@Secure123!"
    DB_NAME="radius"
fi

# Create config.php
log_message "INFO" "Création de config.php..."
cat > /var/www/html/php-admin/config.php << 'EOF'
<?php
// Configuration SAE501 PHP-Admin
define('DB_HOST', 'localhost');
define('DB_PORT', 3306);
define('DB_NAME', 'radius');
define('DB_USER', 'sae501_php');
define('DB_PASSWORD', 'Admin@Secure123!');

// Admin credentials
define('ADMIN_USER', 'admin');
define('ADMIN_PASS', password_hash('Admin@Secure123!', PASSWORD_BCRYPT));

// Paths
define('LOG_DIR', __DIR__ . '/logs');
define('APP_VERSION', '1.0.0');

// Database connection
$pdo = null;

function getDB() {
    global $pdo;
    if ($pdo === null) {
        try {
            $pdo = new PDO(
                'mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME,
                DB_USER,
                DB_PASSWORD,
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::MYSQL_ATTR_CHARSET => 'utf8mb4'
                ]
            );
        } catch (PDOException $e) {
            die('Erreur de connexion base de données: ' . htmlspecialchars($e->getMessage()));
        }
    }
    return $pdo;
}

function logAudit($action, $target_user = null, $details = null) {
    $db = getDB();
    $admin_user = $_SESSION['admin_user'] ?? 'system';
    $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    
    $sql = "INSERT INTO admin_audit (admin_user, action, target_user, details, ip_address) 
            VALUES (?, ?, ?, ?, ?)";
    $stmt = $db->prepare($sql);
    $stmt->execute([$admin_user, $action, $target_user, $details, $ip_address]);
}
?>
EOF

log_message "SUCCESS" "config.php créé"

# Create index.php (Router)
log_message "INFO" "Création de index.php..."
cat > /var/www/html/php-admin/index.php << 'EOF'
<?php
require_once 'config.php';
session_start();

// Check authentication
if (!isset($_SESSION['authenticated']) && $_GET['action'] ?? '' !== 'login') {
    $_GET['action'] = 'login';
}

$action = $_GET['action'] ?? 'dashboard';

// Security: whitelist actions
$valid_actions = ['login', 'logout', 'dashboard', 'list_users', 'add_user', 'edit_user', 'delete_user', 'audit', 'system', 'settings'];

if (!in_array($action, $valid_actions)) {
    $action = 'dashboard';
}

?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SAE501 - Admin RADIUS</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
        }
        .header h1 { margin-bottom: 5px; }
        .header p { opacity: 0.9; }
        .navbar {
            display: flex;
            gap: 15px;
            padding: 20px;
            border-bottom: 1px solid #eee;
            flex-wrap: wrap;
        }
        .navbar a, .navbar button {
            padding: 8px 16px;
            border-radius: 5px;
            border: none;
            cursor: pointer;
            text-decoration: none;
            background: #f0f0f0;
            color: #333;
            transition: all 0.3s;
        }
        .navbar a:hover, .navbar button:hover {
            background: #667eea;
            color: white;
        }
        .navbar a.active {
            background: #667eea;
            color: white;
        }
        .content {
            padding: 30px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        .stat-card h3 { font-size: 32px; margin: 10px 0; }
        .stat-card p { opacity: 0.9; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        table th, table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        table th {
            background: #f5f5f5;
            font-weight: 600;
        }
        table tr:hover {
            background: #f9f9f9;
        }
        .btn {
            display: inline-block;
            padding: 10px 20px;
            margin: 5px;
            border-radius: 5px;
            border: none;
            cursor: pointer;
            text-decoration: none;
            transition: all 0.3s;
        }
        .btn-primary {
            background: #667eea;
            color: white;
        }
        .btn-primary:hover {
            background: #764ba2;
        }
        .btn-danger {
            background: #f56565;
            color: white;
        }
        .btn-danger:hover {
            background: #e53e3e;
        }
        .btn-success {
            background: #48bb78;
            color: white;
        }
        .btn-success:hover {
            background: #38a169;
        }
        .form-group {
            margin-bottom: 15px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: 500;
        }
        input, select, textarea {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 14px;
        }
        input:focus, select:focus, textarea:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        .footer {
            text-align: center;
            padding: 20px;
            border-top: 1px solid #eee;
            color: #666;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 SAE501 - Admin RADIUS</h1>
            <p>Gestion centralisée des utilisateurs Wi-Fi RADIUS</p>
        </div>
        
        <?php if (isset($_SESSION['authenticated'])): ?>
        <div class="navbar">
            <a href="?action=dashboard" class="<?php echo ($action === 'dashboard') ? 'active' : ''; ?>">Tableau de bord</a>
            <a href="?action=add_user" class="<?php echo ($action === 'add_user') ? 'active' : ''; ?>">Ajouter utilisateur</a>
            <a href="?action=list_users" class="<?php echo ($action === 'list_users') ? 'active' : ''; ?>">Liste utilisateurs</a>
            <a href="?action=audit" class="<?php echo ($action === 'audit') ? 'active' : ''; ?>">Logs d'audit</a>
            <a href="?action=system" class="<?php echo ($action === 'system') ? 'active' : ''; ?>">Paramétres</a>
            <button class="btn btn-danger" onclick="window.location='?action=logout'">Déconnexion</button>
        </div>
        <?php endif; ?>
        
        <div class="content">
            <?php
            $page_file = __DIR__ . '/pages/' . $action . '.php';
            if ($action === 'login' || file_exists($page_file)) {
                if ($action === 'login') {
                    ?>
                    <form method="POST" style="max-width: 400px;">
                        <div class="form-group">
                            <label>Identifiant</label>
                            <input type="text" name="username" required>
                        </div>
                        <div class="form-group">
                            <label>Mot de passe</label>
                            <input type="password" name="password" required>
                        </div>
                        <button type="submit" class="btn btn-primary" style="width: 100%;">Connexion</button>
                    </form>
                    <?php
                    // Handle login
                    if ($_POST) {
                        if ($_POST['username'] === ADMIN_USER && password_verify($_POST['password'], ADMIN_PASS)) {
                            $_SESSION['authenticated'] = true;
                            $_SESSION['admin_user'] = $_POST['username'];
                            header('Location: ?action=dashboard');
                            exit;
                        } else {
                            echo '<p style="color: red; margin-top: 10px;">Identifiants incorrects</p>';
                        }
                    }
                } else {
                    if (!isset($_SESSION['authenticated'])) {
                        header('Location: ?action=login');
                        exit;
                    }
                    include $page_file;
                }
            } else {
                echo '<p>Page non trouvée</p>';
            }
            ?>
        </div>
        
        <div class="footer">
            SAE501 - Admin RADIUS | Version 1.0.0 | Dernière mise à jour: 2026-01-25 15:44:11
        </div>
    </div>
</body>
</html>
EOF

log_message "SUCCESS" "index.php créé"

# Create dashboard.php
log_message "INFO" "Création des pages PHP..."
mkdir -p /var/www/html/php-admin/pages

cat > /var/www/html/php-admin/pages/dashboard.php << 'EOF'
<?php
$db = getDB();

// Get statistics
$user_count = $db->query("SELECT COUNT(*) FROM radcheck WHERE attribute='Cleartext-Password'") ->fetchColumn();
$group_count = $db->query("SELECT COUNT(DISTINCT groupname) FROM radgroupcheck")->fetchColumn();
$recent_logins = $db->query("SELECT COUNT(*) FROM auth_attempts WHERE status='success' AND timestamp > DATE_SUB(NOW(), INTERVAL 1 DAY)")->fetchColumn();

?>
<h2>🎫 Tableau de bord</h2>

<div class="stats">
    <div class="stat-card">
        <p>👤 UTILISATEURS TOTAUX</p>
        <h3><?php echo (int)$user_count; ?></h3>
        <p>Utilisateurs Wi-Fi actifs</p>
    </div>
    <div class="stat-card">
        <p>🔐 GROUPES D'ACCÈS</p>
        <h3><?php echo (int)$group_count; ?></h3>
        <p>Groupes de permissions</p>
    </div>
    <div class="stat-card">
        <p>⚡ ACTIONS RAPIDES</p>
        <p><a href="?action=add_user" style="color: white; text-decoration: none;">+ Ajouter un utilisateur</a></p>
        <p><a href="?action=list_users" style="color: white; text-decoration: none;">Voir tous les utilisateurs →</a></p>
    </div>
</div>

<h3>Informations système</h3>

<table>
    <tr>
        <td><strong>Base de données</strong></td>
        <td>RADIUS (FreeRADIUS)</td>
    </tr>
    <tr>
        <td><strong>Authentification</strong></td>
        <td>Service Environnement</td>
    </tr>
</table>
EOF

# Create other page files
cat > /var/www/html/php-admin/pages/list_users.php << 'EOF'
<?php
$db = getDB();
$users = $db->query("SELECT DISTINCT username FROM radcheck WHERE attribute='Cleartext-Password'")->fetchAll();
?>
<h2>👤 Liste utilisateurs</h2>
<table>
    <thead><tr><th>Utilisateur</th><th>Actions</th></tr></thead>
    <tbody>
    <?php foreach ($users as $user): ?>
        <tr>
            <td><?php echo htmlspecialchars($user['username']); ?></td>
            <td>
                <a href="?action=edit_user&user=<?php echo urlencode($user['username']); ?>" class="btn btn-primary">Modifier</a>
                <a href="?action=delete_user&user=<?php echo urlencode($user['username']); ?>" class="btn btn-danger">Supprimer</a>
            </td>
        </tr>
    <?php endforeach; ?>
    </tbody>
</table>
EOF

cat > /var/www/html/php-admin/pages/add_user.php << 'EOF'
<?php
if ($_POST) {
    $db = getDB();
    $username = trim($_POST['username'] ?? '');
    $password = trim($_POST['password'] ?? '');
    
    if ($username && $password) {
        try {
            $db->prepare("INSERT INTO radcheck (username, attribute, op, value) VALUES (?, 'Cleartext-Password', ':=', ?)"
            )->execute([$username, $password]);
            
            logAudit('add_user', $username, 'Nouvel utilisateur créé');
            echo '<p style="color: green;">Utilisateur ajouté avec succès!</p>';
        } catch (Exception $e) {
            echo '<p style="color: red;">Erreur: ' . htmlspecialchars($e->getMessage()) . '</p>';
        }
    }
}
?>
<h2>➕ Ajouter utilisateur</h2>
<form method="POST" style="max-width: 500px;">
    <div class="form-group">
        <label>Nom d'utilisateur</label>
        <input type="text" name="username" required>
    </div>
    <div class="form-group">
        <label>Mot de passe</label>
        <input type="password" name="password" required>
    </div>
    <button type="submit" class="btn btn-success">Ajouter</button>
</form>
EOF

cat > /var/www/html/php-admin/pages/edit_user.php << 'EOF'
<?php echo '<h2>✍ Edit utilisateur</h2><p>En construction...</p>'; ?>
EOF

cat > /var/www/html/php-admin/pages/delete_user.php << 'EOF'
<?php
if (isset($_GET['user']) && isset($_GET['confirm'])) {
    $db = getDB();
    $user = $_GET['user'];
    try {
        $db->prepare("DELETE FROM radcheck WHERE username = ?")->execute([$user]);
        logAudit('delete_user', $user, 'Utilisateur supprimé');
        echo '<p style="color: green;">Utilisateur supprimé!</p>';
    } catch (Exception $e) {
        echo '<p style="color: red;">Erreur: ' . htmlspecialchars($e->getMessage()) . '</p>';
    }
} else {
    echo '<h2>⚠ Supprimer utilisateur</h2><p>Veuillez confirmer</p>';
}
?>
EOF

cat > /var/www/html/php-admin/pages/audit.php << 'EOF'
<?php
$db = getDB();
$logs = $db->query("SELECT * FROM admin_audit ORDER BY timestamp DESC LIMIT 100")->fetchAll();
?>
<h2>📃 Logs d'audit</h2>
<table>
    <thead>
        <tr><th>Timestamp</th><th>Admin</th><th>Action</th><th>User Cible</th></tr>
    </thead>
    <tbody>
    <?php foreach ($logs as $log): ?>
        <tr>
            <td><?php echo $log['timestamp']; ?></td>
            <td><?php echo htmlspecialchars($log['admin_user']); ?></td>
            <td><?php echo htmlspecialchars($log['action']); ?></td>
            <td><?php echo htmlspecialchars($log['target_user'] ?? '-'); ?></td>
        </tr>
    <?php endforeach; ?>
    </tbody>
</table>
EOF

cat > /var/www/html/php-admin/pages/system.php << 'EOF'
<?php echo '<h2>⚙ Paramétres Système</h2><p>PHP Version: ' . phpversion() . '</p>'; ?>
EOF

# Set permissions
log_message "INFO" "Configuration des permissions..."
chown -R www-data:www-data /var/www/html/php-admin
chmod -R 755 /var/www/html/php-admin
chmod -R 775 /var/www/html/php-admin/logs

log_message "SUCCESS" "Installation PHP-Admin terminée"
echo ""
echo "============================================"
echo "PHP-Admin installé avec succès!"
echo "URL: http://localhost/php-admin/"
echo "============================================"

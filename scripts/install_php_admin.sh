#!/bin/bash
# ============================================================================
# SAE501 - Installation PHP-Admin (100% AUTONOME)
# ============================================================================
#
# Ce script réalise une installation COMPLÈTE de l'interface web PHP
# sans dépendre d'aucun fichier externe. Toutes les pages sont générées
# automatiquement durant l'installation.
#
# FONCTIONNALITÉS:
# - Installation Apache2 + PHP 8.x
# - Interface web responsive moderne
# - Gestion complète des utilisateurs RADIUS
# - Logs d'audit détaillés
# - Dashboard avec statistiques
# - Paramètres système
# - Authentification sécurisée (bcrypt)
# - Design moderne avec dégradés
#
# USAGE:
#   sudo bash scripts/install_php_admin.sh
#
# PRÉ-REQUIS:
#   - MySQL déjà installé avec la base RADIUS
#   - FreeRADIUS installé
#
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/sae501_php_admin_install.log"

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
       echo "❌ Must run as root" >&2
       exit 1
    fi
}

# ============================================================================
# INSTALLATION APACHE ET PHP
# ============================================================================

install_apache_php() {
    log_msg "📦 Installing Apache2 and PHP..."
    
    apt-get update -y >/dev/null 2>&1
    apt-get install -y \
        apache2 \
        php \
        php-mysql \
        php-cli \
        php-json \
        php-curl \
        php-mbstring \
        libapache2-mod-php \
        >/dev/null 2>&1
    
    # Activer modules Apache
    a2enmod php* >/dev/null 2>&1 || true
    a2enmod rewrite >/dev/null 2>&1
    a2enmod ssl >/dev/null 2>&1
    
    systemctl enable apache2 >/dev/null 2>&1
    systemctl restart apache2
    
    if systemctl is-active --quiet apache2; then
        log_msg "✓ Apache2 and PHP installed"
    else
        log_msg "❌ Apache2 failed to start"
        exit 1
    fi
}

# ============================================================================
# CRÉATION DE LA STRUCTURE
# ============================================================================

create_structure() {
    log_msg "📁 Creating directory structure..."
    
    rm -rf /var/www/html/admin
    mkdir -p /var/www/html/admin/pages
    mkdir -p /var/www/html/admin/logs
    mkdir -p /var/www/html/admin/assets
    
    log_msg "✓ Directory structure created"
}

# ============================================================================
# GÉNÉRATION CONFIG.PHP
# ============================================================================

generate_config() {
    log_msg "⚙️  Generating config.php..."
    
    cat > /var/www/html/admin/config.php << 'CONFIGPHP_EOF'
<?php
// ============================================================================
// SAE501 - Configuration PHP-Admin
// Généré automatiquement - NE PAS MODIFIER MANUELLEMENT
// ============================================================================

// Configuration base de données
define('DB_HOST', 'localhost');
define('DB_PORT', 3306);
define('DB_NAME', 'radius');
define('DB_USER', 'radiusapp');
define('DB_PASSWORD', 'RadiusApp@Secure123!');

// Authentification admin
define('ADMIN_USER', 'admin');
define('ADMIN_PASS', password_hash('Admin@Secure123!', PASSWORD_BCRYPT));

// Paramètres application
define('LOG_DIR', __DIR__ . '/logs');
define('APP_VERSION', '2.0.0');
define('APP_NAME', 'SAE501 RADIUS Admin');

// Sécurité
ini_set('session.cookie_httponly', 1);
ini_set('session.use_strict_mode', 1);
ini_set('session.cookie_secure', 0); // Mettre à 1 en HTTPS

// Connexion base de données globale
$pdo = null;

/**
 * Récupérer la connexion PDO
 */
function getDB() {
    global $pdo;
    if ($pdo === null) {
        try {
            $pdo = new PDO(
                'mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME . ';charset=utf8mb4',
                DB_USER,
                DB_PASSWORD,
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false
                ]
            );
        } catch (PDOException $e) {
            die('<div style="background: #f56565; color: white; padding: 20px; border-radius: 10px; margin: 20px;"><h2>❌ Erreur de connexion base de données</h2><p>' . htmlspecialchars($e->getMessage()) . '</p></div>');
        }
    }
    return $pdo;
}

/**
 * Logger une action d'audit
 */
function logAudit($action, $target_user = null, $details = null) {
    try {
        $db = getDB();
        $admin_user = $_SESSION['admin_user'] ?? 'system';
        $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        
        $sql = "INSERT INTO admin_audit (admin_user, action, target_user, details, ip_address, timestamp) 
                VALUES (?, ?, ?, ?, ?, NOW())";
        $stmt = $db->prepare($sql);
        $stmt->execute([$admin_user, $action, $target_user, $details, $ip_address]);
    } catch (Exception $e) {
        error_log("Audit log failed: " . $e->getMessage());
    }
}

/**
 * Afficher un message flash
 */
function flashMessage($message, $type = 'success') {
    $_SESSION['flash_message'] = $message;
    $_SESSION['flash_type'] = $type;
}

/**
 * Récupérer et effacer le message flash
 */
function getFlash() {
    if (isset($_SESSION['flash_message'])) {
        $message = $_SESSION['flash_message'];
        $type = $_SESSION['flash_type'] ?? 'success';
        unset($_SESSION['flash_message'], $_SESSION['flash_type']);
        
        $colors = [
            'success' => '#48bb78',
            'error' => '#f56565',
            'warning' => '#ed8936',
            'info' => '#4299e1'
        ];
        
        $color = $colors[$type] ?? $colors['info'];
        echo '<div style="background: ' . $color . '; color: white; padding: 15px; border-radius: 8px; margin-bottom: 20px;">' . htmlspecialchars($message) . '</div>';
    }
}

/**
 * Nettoyer input utilisateur
 */
function cleanInput($input) {
    return htmlspecialchars(trim($input), ENT_QUOTES, 'UTF-8');
}

/**
 * Vérifier si utilisateur existe
 */
function userExists($username) {
    $db = getDB();
    $stmt = $db->prepare("SELECT COUNT(*) FROM radcheck WHERE username = ? AND attribute = 'Cleartext-Password'");
    $stmt->execute([$username]);
    return $stmt->fetchColumn() > 0;
}
?>
CONFIGPHP_EOF
    
    log_msg "✓ config.php generated"
}

# ============================================================================
# GÉNÉRATION INDEX.PHP (ROUTER)
# ============================================================================

generate_index() {
    log_msg "🏠 Generating index.php..."
    
    cat > /var/www/html/admin/index.php << 'INDEXPHP_EOF'
<?php
// ============================================================================
// SAE501 - Router principal
// ============================================================================

require_once 'config.php';
session_start();

// Gérer la déconnexion
if (isset($_GET['action']) && $_GET['action'] === 'logout') {
    session_destroy();
    header('Location: ?action=login');
    exit;
}

// Vérifier authentification
if (!isset($_SESSION['authenticated']) && ($_GET['action'] ?? '') !== 'login') {
    header('Location: ?action=login');
    exit;
}

$action = $_GET['action'] ?? 'dashboard';

// Sécurité: whitelist actions
$valid_actions = [
    'login', 'logout', 'dashboard', 'list_users', 'add_user', 
    'edit_user', 'delete_user', 'audit', 'system', 'settings'
];

if (!in_array($action, $valid_actions)) {
    $action = 'dashboard';
}

?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo APP_NAME; ?></title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.15);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .header-left h1 {
            font-size: 28px;
            margin-bottom: 8px;
        }
        
        .header-left p {
            opacity: 0.95;
            font-size: 14px;
        }
        
        .header-right {
            text-align: right;
            font-size: 13px;
            opacity: 0.9;
        }
        
        .navbar {
            display: flex;
            gap: 10px;
            padding: 25px;
            border-bottom: 2px solid #f0f0f0;
            flex-wrap: wrap;
            background: #fafafa;
        }
        
        .navbar a, .navbar button {
            padding: 10px 18px;
            border-radius: 8px;
            border: none;
            cursor: pointer;
            text-decoration: none;
            background: white;
            color: #333;
            transition: all 0.3s;
            font-size: 14px;
            font-weight: 500;
            border: 1px solid #e0e0e0;
        }
        
        .navbar a:hover, .navbar button:hover {
            background: #667eea;
            color: white;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
        }
        
        .navbar a.active {
            background: #667eea;
            color: white;
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
        }
        
        .navbar .logout-btn {
            margin-left: auto;
            background: #f56565;
            color: white;
            border-color: #f56565;
        }
        
        .navbar .logout-btn:hover {
            background: #e53e3e;
        }
        
        .content {
            padding: 40px;
            min-height: 500px;
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            margin-bottom: 40px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 10px 25px rgba(102, 126, 234, 0.3);
            transition: transform 0.3s;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
        }
        
        .stat-card .icon {
            font-size: 40px;
            margin-bottom: 15px;
        }
        
        .stat-card h3 {
            font-size: 42px;
            margin: 15px 0;
            font-weight: 700;
        }
        
        .stat-card p {
            opacity: 0.95;
            font-size: 14px;
        }
        
        .stat-card a {
            color: white;
            text-decoration: underline;
            opacity: 0.95;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 25px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            border-radius: 10px;
            overflow: hidden;
        }
        
        table th, table td {
            padding: 15px;
            text-align: left;
            border-bottom: 1px solid #f0f0f0;
        }
        
        table th {
            background: #667eea;
            color: white;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 12px;
            letter-spacing: 0.5px;
        }
        
        table tr:hover {
            background: #f9f9f9;
        }
        
        table tr:last-child td {
            border-bottom: none;
        }
        
        .btn {
            display: inline-block;
            padding: 10px 22px;
            margin: 5px;
            border-radius: 8px;
            border: none;
            cursor: pointer;
            text-decoration: none;
            transition: all 0.3s;
            font-size: 14px;
            font-weight: 500;
        }
        
        .btn-primary {
            background: #667eea;
            color: white;
        }
        
        .btn-primary:hover {
            background: #5568d3;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }
        
        .btn-danger {
            background: #f56565;
            color: white;
        }
        
        .btn-danger:hover {
            background: #e53e3e;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(245, 101, 101, 0.4);
        }
        
        .btn-success {
            background: #48bb78;
            color: white;
        }
        
        .btn-success:hover {
            background: #38a169;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(72, 187, 120, 0.4);
        }
        
        .btn-warning {
            background: #ed8936;
            color: white;
        }
        
        .btn-warning:hover {
            background: #dd6b20;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #333;
            font-size: 14px;
        }
        
        input, select, textarea {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 14px;
            transition: all 0.3s;
        }
        
        input:focus, select:focus, textarea:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        .login-form {
            max-width: 450px;
            margin: 50px auto;
            padding: 40px;
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }
        
        .login-form h2 {
            margin-bottom: 30px;
            text-align: center;
            color: #667eea;
        }
        
        .footer {
            text-align: center;
            padding: 25px;
            border-top: 2px solid #f0f0f0;
            color: #999;
            font-size: 13px;
            background: #fafafa;
        }
        
        h2 {
            color: #333;
            margin-bottom: 25px;
            font-size: 24px;
        }
        
        h3 {
            color: #555;
            margin: 30px 0 20px 0;
            font-size: 18px;
        }
        
        .card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            margin-bottom: 25px;
        }
        
        .badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .badge-success {
            background: #c6f6d5;
            color: #22543d;
        }
        
        .badge-danger {
            background: #fed7d7;
            color: #742a2a;
        }
        
        .badge-warning {
            background: #feebc8;
            color: #7c2d12;
        }
        
        .badge-info {
            background: #bee3f8;
            color: #2c5282;
        }
        
        @media (max-width: 768px) {
            .header {
                padding: 25px;
            }
            
            .content {
                padding: 20px;
            }
            
            .stats {
                grid-template-columns: 1fr;
            }
            
            table {
                font-size: 12px;
            }
            
            table th, table td {
                padding: 10px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <?php if (isset($_SESSION['authenticated'])): ?>
        <!-- Header -->
        <div class="header">
            <div class="header-left">
                <h1>🌐 <?php echo APP_NAME; ?></h1>
                <p>Gestion centralisée des utilisateurs Wi-Fi RADIUS</p>
            </div>
            <div class="header-right">
                <div>👤 Utilisateur: <strong><?php echo htmlspecialchars($_SESSION['admin_user']); ?></strong></div>
                <div>📅 <?php echo date('d/m/Y H:i'); ?></div>
            </div>
        </div>
        
        <!-- Navigation -->
        <div class="navbar">
            <a href="?action=dashboard" class="<?php echo ($action === 'dashboard') ? 'active' : ''; ?>">🏠 Tableau de bord</a>
            <a href="?action=list_users" class="<?php echo ($action === 'list_users') ? 'active' : ''; ?>">👥 Utilisateurs</a>
            <a href="?action=add_user" class="<?php echo ($action === 'add_user') ? 'active' : ''; ?>">➕ Ajouter</a>
            <a href="?action=audit" class="<?php echo ($action === 'audit') ? 'active' : ''; ?>">📄 Logs</a>
            <a href="?action=system" class="<?php echo ($action === 'system') ? 'active' : ''; ?>">⚙️ Système</a>
            <button class="logout-btn" onclick="if(confirm('Se déconnecter?')) window.location='?action=logout'">🚪 Déconnexion</button>
        </div>
        <?php endif; ?>
        
        <!-- Contenu -->
        <div class="content">
            <?php
            // Afficher message flash
            getFlash();
            
            // Charger la page appropriée
            $page_file = __DIR__ . '/pages/' . $action . '.php';
            
            if ($action === 'login') {
                include 'pages/login.php';
            } elseif (file_exists($page_file)) {
                if (!isset($_SESSION['authenticated'])) {
                    header('Location: ?action=login');
                    exit;
                }
                include $page_file;
            } else {
                echo '<div class="card"><h2>❌ Page non trouvée</h2><p>La page demandée n\'existe pas.</p></div>';
            }
            ?>
        </div>
        
        <?php if (isset($_SESSION['authenticated'])): ?>
        <!-- Footer -->
        <div class="footer">
            <strong><?php echo APP_NAME; ?></strong> | Version <?php echo APP_VERSION; ?> | © 2026 SAE501 - Sorbonne Paris Nord<br>
            Dernière connexion: <?php echo date('d/m/Y H:i:s'); ?>
        </div>
        <?php endif; ?>
    </div>
</body>
</html>
INDEXPHP_EOF
    
    log_msg "✓ index.php generated"
}

# ============================================================================
# GÉNÉRATION DES PAGES
# ============================================================================

generate_pages() {
    log_msg "📄 Generating all pages..."
    
    # Page: login.php
    cat > /var/www/html/admin/pages/login.php << 'LOGINPHP_EOF'
<?php
// Traitement du formulaire de connexion
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    
    if ($username === ADMIN_USER && password_verify($password, ADMIN_PASS)) {
        $_SESSION['authenticated'] = true;
        $_SESSION['admin_user'] = $username;
        $_SESSION['login_time'] = time();
        
        logAudit('login', null, 'Connexion réussie');
        
        header('Location: ?action=dashboard');
        exit;
    } else {
        $error = 'Identifiants incorrects';
        logAudit('login_failed', $username, 'Tentative de connexion échouée');
    }
}
?>

<div class="login-form">
    <h2>🔐 Connexion Admin</h2>
    
    <?php if (isset($error)): ?>
        <div style="background: #fed7d7; color: #742a2a; padding: 15px; border-radius: 8px; margin-bottom: 20px; text-align: center;">
            ❌ <?php echo htmlspecialchars($error); ?>
        </div>
    <?php endif; ?>
    
    <form method="POST">
        <div class="form-group">
            <label>👤 Identifiant</label>
            <input type="text" name="username" required autofocus placeholder="admin">
        </div>
        <div class="form-group">
            <label>🔑 Mot de passe</label>
            <input type="password" name="password" required placeholder="••••••••">
        </div>
        <button type="submit" class="btn btn-primary" style="width: 100%; padding: 14px; font-size: 16px;">
            → Se connecter
        </button>
    </form>
    
    <div style="margin-top: 25px; padding-top: 20px; border-top: 1px solid #eee; text-align: center; color: #999; font-size: 12px;">
        <p>Par défaut: <strong>admin</strong> / <strong>Admin@Secure123!</strong></p>
        <p style="margin-top: 10px;">⚠️ Changez le mot de passe après la première connexion</p>
    </div>
</div>
LOGINPHP_EOF

    # Page: dashboard.php
    cat > /var/www/html/admin/pages/dashboard.php << 'DASHBOARDPHP_EOF'
<?php
$db = getDB();

// Statistiques
try {
    $user_count = $db->query("SELECT COUNT(DISTINCT username) FROM radcheck WHERE attribute='Cleartext-Password'")->fetchColumn();
    $group_count = $db->query("SELECT COUNT(DISTINCT groupname) FROM radgroupcheck")->fetchColumn();
    $auth_success_today = $db->query("SELECT COUNT(*) FROM radpostauth WHERE authdate > CURDATE() AND reply='Access-Accept'")->fetchColumn();
    $auth_failed_today = $db->query("SELECT COUNT(*) FROM radpostauth WHERE authdate > CURDATE() AND reply='Access-Reject'")->fetchColumn();
} catch (Exception $e) {
    $user_count = 0;
    $group_count = 0;
    $auth_success_today = 0;
    $auth_failed_today = 0;
}

// Dernières authentifications
try {
    $recent_auths = $db->query("
        SELECT username, reply, authdate, nasipaddress 
        FROM radpostauth 
        ORDER BY authdate DESC 
        LIMIT 10
    ")->fetchAll();
} catch (Exception $e) {
    $recent_auths = [];
}
?>

<h2>🏠 Tableau de bord</h2>

<div class="stats">
    <div class="stat-card">
        <div class="icon">👥</div>
        <h3><?php echo number_format($user_count); ?></h3>
        <p>Utilisateurs RADIUS</p>
        <p style="margin-top: 10px;"><a href="?action=list_users" style="color: white; text-decoration: underline;">Voir tous →</a></p>
    </div>
    
    <div class="stat-card">
        <div class="icon">✅</div>
        <h3><?php echo number_format($auth_success_today); ?></h3>
        <p>Authentifications réussies aujourd'hui</p>
        <p style="margin-top: 10px; opacity: 0.9; font-size: 12px;">Connexions Wi-Fi valides</p>
    </div>
    
    <div class="stat-card">
        <div class="icon">❌</div>
        <h3><?php echo number_format($auth_failed_today); ?></h3>
        <p>Authentifications échouées aujourd'hui</p>
        <p style="margin-top: 10px; opacity: 0.9; font-size: 12px;">Tentatives invalid es</p>
    </div>
    
    <div class="stat-card">
        <div class="icon">🛡️</div>
        <h3><?php echo number_format($group_count); ?></h3>
        <p>Groupes d'accès</p>
        <p style="margin-top: 10px;"><a href="?action=add_user" style="color: white; text-decoration: underline;">➕ Ajouter utilisateur</a></p>
    </div>
</div>

<div class="card">
    <h3>🕒 Dernières authentifications</h3>
    
    <?php if (count($recent_auths) > 0): ?>
        <table>
            <thead>
                <tr>
                    <th>Utilisateur</th>
                    <th>Résultat</th>
                    <th>Date/Heure</th>
                    <th>NAS IP</th>
                </tr>
            </thead>
            <tbody>
            <?php foreach ($recent_auths as $auth): ?>
                <tr>
                    <td><strong><?php echo htmlspecialchars($auth['username']); ?></strong></td>
                    <td>
                        <?php if ($auth['reply'] === 'Access-Accept'): ?>
                            <span class="badge badge-success">✅ Réussie</span>
                        <?php else: ?>
                            <span class="badge badge-danger">❌ Échouée</span>
                        <?php endif; ?>
                    </td>
                    <td><?php echo $auth['authdate']; ?></td>
                    <td><?php echo htmlspecialchars($auth['nasipaddress'] ?? 'N/A'); ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    <?php else: ?>
        <p style="color: #999; text-align: center; padding: 40px;">📄 Aucune authentification enregistrée</p>
    <?php endif; ?>
</div>

<div class="card">
    <h3>📊 Informations système</h3>
    <table>
        <tr>
            <td><strong>💾 Base de données</strong></td>
            <td><?php echo DB_NAME; ?> @ <?php echo DB_HOST; ?></td>
        </tr>
        <tr>
            <td><strong>🔧 PHP Version</strong></td>
            <td><?php echo phpversion(); ?></td>
        </tr>
        <tr>
            <td><strong>📦 Application</strong></td>
            <td><?php echo APP_NAME; ?> v<?php echo APP_VERSION; ?></td>
        </tr>
        <tr>
            <td><strong>🕐 Heure serveur</strong></td>
            <td><?php echo date('d/m/Y H:i:s'); ?></td>
        </tr>
    </table>
</div>
DASHBOARDPHP_EOF

    # Page: list_users.php
    cat > /var/www/html/admin/pages/list_users.php << 'LISTUSERSPHP_EOF'
<?php
$db = getDB();

// Récupérer tous les utilisateurs
try {
    $users = $db->query("
        SELECT DISTINCT username 
        FROM radcheck 
        WHERE attribute='Cleartext-Password' 
        ORDER BY username ASC
    ")->fetchAll();
} catch (Exception $e) {
    $users = [];
    flashMessage('Erreur lors de la récupération des utilisateurs: ' . $e->getMessage(), 'error');
}
?>

<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 25px;">
    <h2>👥 Liste des utilisateurs (<?php echo count($users); ?>)</h2>
    <a href="?action=add_user" class="btn btn-success">➕ Ajouter un utilisateur</a>
</div>

<?php if (count($users) > 0): ?>
    <div class="card">
        <table>
            <thead>
                <tr>
                    <th>#</th>
                    <th>Nom d'utilisateur</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
            <?php $i = 1; foreach ($users as $user): ?>
                <tr>
                    <td><?php echo $i++; ?></td>
                    <td><strong><?php echo htmlspecialchars($user['username']); ?></strong></td>
                    <td>
                        <a href="?action=edit_user&user=<?php echo urlencode($user['username']); ?>" class="btn btn-primary">✏️ Modifier</a>
                        <a href="?action=delete_user&user=<?php echo urlencode($user['username']); ?>" 
                           onclick="return confirm('Supprimer l\'utilisateur <?php echo htmlspecialchars($user['username']); ?>?');" 
                           class="btn btn-danger">🗑️ Supprimer</a>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
<?php else: ?>
    <div class="card" style="text-align: center; padding: 60px;">
        <p style="font-size: 48px; margin-bottom: 20px;">👥</p>
        <h3>Aucun utilisateur</h3>
        <p style="color: #999; margin: 20px 0;">Commencez par ajouter votre premier utilisateur RADIUS</p>
        <a href="?action=add_user" class="btn btn-success">➕ Ajouter un utilisateur</a>
    </div>
<?php endif; ?>
LISTUSERSPHP_EOF

    # Page: add_user.php
    cat > /var/www/html/admin/pages/add_user.php << 'ADDUSERPHP_EOF'
<?php
// Traitement du formulaire
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = cleanInput($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    
    if (empty($username) || empty($password)) {
        flashMessage('Le nom d\'utilisateur et le mot de passe sont obligatoires', 'error');
    } elseif (userExists($username)) {
        flashMessage('Cet utilisateur existe déjà', 'warning');
    } else {
        try {
            $db = getDB();
            $stmt = $db->prepare("
                INSERT INTO radcheck (username, attribute, op, value) 
                VALUES (?, 'Cleartext-Password', ':=', ?)
            ");
            $stmt->execute([$username, $password]);
            
            logAudit('add_user', $username, 'Utilisateur créé');
            flashMessage('Utilisateur ajouté avec succès!', 'success');
            
            // Redirection
            header('Location: ?action=list_users');
            exit;
        } catch (Exception $e) {
            flashMessage('Erreur lors de l\'ajout: ' . $e->getMessage(), 'error');
        }
    }
}
?>

<h2>➕ Ajouter un utilisateur</h2>

<div class="card" style="max-width: 600px;">
    <form method="POST">
        <div class="form-group">
            <label>👤 Nom d'utilisateur *</label>
            <input type="text" name="username" required placeholder="exemple: jean.dupont" 
                   pattern="[a-zA-Z0-9._-]+" 
                   title="Lettres, chiffres, points, tirets et underscores uniquement">
            <small style="color: #999; font-size: 12px; display: block; margin-top: 5px;">
                Lettres, chiffres, points, tirets et underscores uniquement
            </small>
        </div>
        
        <div class="form-group">
            <label>🔑 Mot de passe *</label>
            <input type="password" name="password" required placeholder="Mot de passe sécurisé" 
                   minlength="8">
            <small style="color: #999; font-size: 12px; display: block; margin-top: 5px;">
                Minimum 8 caractères recommandés
            </small>
        </div>
        
        <div style="display: flex; gap: 10px; margin-top: 25px;">
            <button type="submit" class="btn btn-success">✅ Ajouter l'utilisateur</button>
            <a href="?action=list_users" class="btn btn-primary">← Retour à la liste</a>
        </div>
    </form>
</div>

<div class="card" style="max-width: 600px; margin-top: 20px; background: #f7fafc;">
    <h3>💡 Conseils</h3>
    <ul style="line-height: 2; color: #555;">
        <li>Utilisez un nom d'utilisateur unique</li>
        <li>Choisissez un mot de passe fort (8+ caractères)</li>
        <li>Les utilisateurs pourront se connecter au Wi-Fi avec ces identifiants</li>
        <li>Le mot de passe est stocké en clair dans RADIUS (nécessaire pour PEAP)</li>
    </ul>
</div>
ADDUSERPHP_EOF

    # Page: edit_user.php
    cat > /var/www/html/admin/pages/edit_user.php << 'EDITUSERPHP_EOF'
<?php
$username = $_GET['user'] ?? '';

if (empty($username) || !userExists($username)) {
    flashMessage('Utilisateur introuvable', 'error');
    header('Location: ?action=list_users');
    exit;
}

// Traitement du formulaire
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $new_password = $_POST['password'] ?? '';
    
    if (empty($new_password)) {
        flashMessage('Le mot de passe ne peut pas être vide', 'error');
    } else {
        try {
            $db = getDB();
            $stmt = $db->prepare("
                UPDATE radcheck 
                SET value = ? 
                WHERE username = ? AND attribute = 'Cleartext-Password'
            ");
            $stmt->execute([$new_password, $username]);
            
            logAudit('edit_user', $username, 'Mot de passe modifié');
            flashMessage('Mot de passe mis à jour avec succès!', 'success');
            
            header('Location: ?action=list_users');
            exit;
        } catch (Exception $e) {
            flashMessage('Erreur lors de la modification: ' . $e->getMessage(), 'error');
        }
    }
}
?>

<h2>✏️ Modifier l'utilisateur</h2>

<div class="card" style="max-width: 600px;">
    <h3>Utilisateur: <strong><?php echo htmlspecialchars($username); ?></strong></h3>
    
    <form method="POST" style="margin-top: 25px;">
        <div class="form-group">
            <label>🔑 Nouveau mot de passe *</label>
            <input type="password" name="password" required placeholder="Nouveau mot de passe" 
                   minlength="8">
            <small style="color: #999; font-size: 12px; display: block; margin-top: 5px;">
                Entrez un nouveau mot de passe pour cet utilisateur
            </small>
        </div>
        
        <div style="display: flex; gap: 10px; margin-top: 25px;">
            <button type="submit" class="btn btn-success">✅ Enregistrer</button>
            <a href="?action=list_users" class="btn btn-primary">← Annuler</a>
        </div>
    </form>
</div>
EDITUSERPHP_EOF

    # Page: delete_user.php
    cat > /var/www/html/admin/pages/delete_user.php << 'DELETEUSERPHP_EOF'
<?php
$username = $_GET['user'] ?? '';

if (empty($username)) {
    flashMessage('Utilisateur non spécifié', 'error');
    header('Location: ?action=list_users');
    exit;
}

if (!userExists($username)) {
    flashMessage('Utilisateur introuvable', 'error');
    header('Location: ?action=list_users');
    exit;
}

try {
    $db = getDB();
    
    // Supprimer de radcheck
    $stmt = $db->prepare("DELETE FROM radcheck WHERE username = ?");
    $stmt->execute([$username]);
    
    // Supprimer de radreply
    $stmt = $db->prepare("DELETE FROM radreply WHERE username = ?");
    $stmt->execute([$username]);
    
    // Supprimer de radusergroup
    $stmt = $db->prepare("DELETE FROM radusergroup WHERE username = ?");
    $stmt->execute([$username]);
    
    logAudit('delete_user', $username, 'Utilisateur supprimé');
    flashMessage('Utilisateur supprimé avec succès!', 'success');
} catch (Exception $e) {
    flashMessage('Erreur lors de la suppression: ' . $e->getMessage(), 'error');
}

header('Location: ?action=list_users');
exit;
DELETEUSERPHP_EOF

    # Page: audit.php
    cat > /var/www/html/admin/pages/audit.php << 'AUDITPHP_EOF'
<?php
$db = getDB();

try {
    $logs = $db->query("
        SELECT * FROM admin_audit 
        ORDER BY timestamp DESC 
        LIMIT 200
    ")->fetchAll();
} catch (Exception $e) {
    $logs = [];
    flashMessage('Erreur lors de la récupération des logs: ' . $e->getMessage(), 'error');
}
?>

<h2>📄 Logs d'audit (<?php echo count($logs); ?> dernières actions)</h2>

<?php if (count($logs) > 0): ?>
    <div class="card">
        <table>
            <thead>
                <tr>
                    <th>Date/Heure</th>
                    <th>Admin</th>
                    <th>Action</th>
                    <th>Utilisateur cible</th>
                    <th>Détails</th>
                    <th>IP</th>
                </tr>
            </thead>
            <tbody>
            <?php foreach ($logs as $log): ?>
                <tr>
                    <td><small><?php echo $log['timestamp']; ?></small></td>
                    <td><strong><?php echo htmlspecialchars($log['admin_user']); ?></strong></td>
                    <td>
                        <?php 
                        $action_badges = [
                            'login' => 'success',
                            'login_failed' => 'danger',
                            'add_user' => 'success',
                            'edit_user' => 'warning',
                            'delete_user' => 'danger',
                            'logout' => 'info'
                        ];
                        $badge_class = 'badge-' . ($action_badges[$log['action']] ?? 'info');
                        ?>
                        <span class="badge <?php echo $badge_class; ?>"><?php echo htmlspecialchars($log['action']); ?></span>
                    </td>
                    <td><?php echo htmlspecialchars($log['target_user'] ?? '-'); ?></td>
                    <td><small><?php echo htmlspecialchars($log['details'] ?? '-'); ?></small></td>
                    <td><small><?php echo htmlspecialchars($log['ip_address'] ?? '-'); ?></small></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
<?php else: ?>
    <div class="card" style="text-align: center; padding: 60px;">
        <p style="font-size: 48px; margin-bottom: 20px;">📄</p>
        <h3>Aucun log d'audit</h3>
        <p style="color: #999;">Les actions administratives seront enregistrées ici</p>
    </div>
<?php endif; ?>
AUDITPHP_EOF

    # Page: system.php
    cat > /var/www/html/admin/pages/system.php << 'SYSTEMPHP_EOF'
<?php
$db = getDB();

// Vérifier l'état des services
$services = [
    ['name' => 'FreeRADIUS', 'command' => 'systemctl is-active freeradius'],
    ['name' => 'MySQL', 'command' => 'systemctl is-active mysql'],
    ['name' => 'Apache2', 'command' => 'systemctl is-active apache2'],
];

$service_status = [];
foreach ($services as $service) {
    exec($service['command'] . ' 2>&1', $output, $return_code);
    $service_status[$service['name']] = ($return_code === 0) ? 'actif' : 'inactif';
}

// Informations base de données
try {
    $db_info = $db->query("SELECT VERSION() as version")->fetch();
    $db_version = $db_info['version'];
} catch (Exception $e) {
    $db_version = 'Erreur';
}

try {
    $db_size = $db->query("
        SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb 
        FROM information_schema.tables 
        WHERE table_schema = '" . DB_NAME . "'
    ")->fetch();
    $db_size_mb = $db_size['size_mb'] ?? '0';
} catch (Exception $e) {
    $db_size_mb = 'N/A';
}
?>

<h2>⚙️ Paramètres système</h2>

<div class="card">
    <h3>📦 Informations application</h3>
    <table>
        <tr>
            <td><strong>Nom</strong></td>
            <td><?php echo APP_NAME; ?></td>
        </tr>
        <tr>
            <td><strong>Version</strong></td>
            <td><?php echo APP_VERSION; ?></td>
        </tr>
        <tr>
            <td><strong>PHP Version</strong></td>
            <td><?php echo phpversion(); ?></td>
        </tr>
        <tr>
            <td><strong>Serveur Web</strong></td>
            <td><?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'Apache2'; ?></td>
        </tr>
    </table>
</div>

<div class="card">
    <h3>🛡️ État des services</h3>
    <table>
        <?php foreach ($service_status as $name => $status): ?>
        <tr>
            <td><strong><?php echo $name; ?></strong></td>
            <td>
                <?php if ($status === 'actif'): ?>
                    <span class="badge badge-success">✅ Actif</span>
                <?php else: ?>
                    <span class="badge badge-danger">❌ Inactif</span>
                <?php endif; ?>
            </td>
        </tr>
        <?php endforeach; ?>
    </table>
</div>

<div class="card">
    <h3>💾 Base de données</h3>
    <table>
        <tr>
            <td><strong>Hôte</strong></td>
            <td><?php echo DB_HOST; ?>:<?php echo DB_PORT; ?></td>
        </tr>
        <tr>
            <td><strong>Nom BDD</strong></td>
            <td><?php echo DB_NAME; ?></td>
        </tr>
        <tr>
            <td><strong>Version MySQL</strong></td>
            <td><?php echo $db_version; ?></td>
        </tr>
        <tr>
            <td><strong>Taille BDD</strong></td>
            <td><?php echo $db_size_mb; ?> MB</td>
        </tr>
    </table>
</div>

<div class="card">
    <h3>🔑 Sécurité</h3>
    <div style="background: #fef5e7; border-left: 4px solid #f39c12; padding: 20px; border-radius: 5px;">
        <p style="margin-bottom: 15px;"><strong>⚠️ Important:</strong></p>
        <ul style="line-height: 2; color: #555;">
            <li>Changez le mot de passe par défaut: <code>Admin@Secure123!</code></li>
            <li>Activez HTTPS pour sécuriser la connexion</li>
            <li>Limitez l'accès à cette interface (firewall, VPN)</li>
            <li>Consultez régulièrement les logs d'audit</li>
            <li>Effectuez des sauvegardes régulières de la base de données</li>
        </ul>
    </div>
</div>

<div class="card">
    <h3>🔧 Actions rapides</h3>
    <div style="display: flex; gap: 10px; flex-wrap: wrap;">
        <button onclick="if(confirm('Tester la connexion RADIUS?')) alert('Utilisez: radtest testuser testpass localhost 0 testing123');" 
                class="btn btn-primary">📡 Tester RADIUS</button>
        <button onclick="window.location.reload();" class="btn btn-primary">🔄 Rafraîchir</button>
    </div>
</div>
SYSTEMPHP_EOF

    log_msg "✓ All pages generated"
}

# ============================================================================
# CONFIGURATION DES PERMISSIONS
# ============================================================================

set_permissions() {
    log_msg "🔐 Setting permissions..."
    
    chown -R www-data:www-data /var/www/html/admin
    chmod -R 755 /var/www/html/admin
    chmod -R 775 /var/www/html/admin/logs
    
    # Sécuriser config.php
    chmod 640 /var/www/html/admin/config.php
    
    log_msg "✓ Permissions configured"
}

# ============================================================================
# CONFIGURATION APACHE VIRTUALHOST
# ============================================================================

configure_apache() {
    log_msg "🌐 Configuring Apache VirtualHost..."
    
    # Créer un alias pour /admin
    cat > /etc/apache2/conf-available/radius-admin.conf << 'APACHECONF_EOF'
Alias /admin /var/www/html/admin

<Directory /var/www/html/admin>
    Options -Indexes +FollowSymLinks
    AllowOverride All
    Require all granted
    
    # Protection supplémentaire
    <Files "config.php">
        Require all denied
    </Files>
    
    # Redirection automatique vers index.php
    DirectoryIndex index.php
</Directory>
APACHECONF_EOF
    
    # Activer la configuration
    a2enconf radius-admin >/dev/null 2>&1
    systemctl reload apache2
    
    log_msg "✓ Apache configured"
}

# ============================================================================
# VÉRIFICATION FINALE
# ============================================================================

final_check() {
    log_msg "✅ Performing final checks..."
    
    local all_ok=true
    
    # Vérifier Apache
    if systemctl is-active --quiet apache2; then
        log_msg "✓ Apache2: RUNNING"
    else
        log_msg "❌ Apache2: NOT RUNNING"
        all_ok=false
    fi
    
    # Vérifier fichiers
    if [[ -f "/var/www/html/admin/index.php" ]]; then
        log_msg "✓ Files: OK"
    else
        log_msg "❌ Files: MISSING"
        all_ok=false
    fi
    
    if $all_ok; then
        log_msg "✅ All checks passed!"
        return 0
    else
        log_msg "❌ Some checks failed"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_msg "=========================================="
    log_msg "SAE501 - PHP-Admin Installation Start"
    log_msg "=========================================="
    
    check_root
    
    install_apache_php
    create_structure
    generate_config
    generate_index
    generate_pages
    set_permissions
    configure_apache
    
    if final_check; then
        echo ""
        log_msg "=========================================="
        log_msg "✅ PHP-Admin Installation Complete!"
        log_msg "=========================================="
        log_msg ""
        log_msg "🌐 Access Information:"
        log_msg "  - URL: http://$(hostname -I | awk '{print $1}')/admin"
        log_msg "  - Username: admin"
        log_msg "  - Password: Admin@Secure123!"
        log_msg ""
        log_msg "⚠️  IMPORTANT: Change default password after first login!"
        log_msg ""
    else
        log_msg "❌ Installation completed with errors. Check logs above."
        exit 1
    fi
}

main "$@"

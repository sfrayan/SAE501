<?php
/**
 * SAE501 - Interface d'administration RADIUS
 * Page principale
 */

require_once 'config.php';

// Vérifier l'authentification
$is_authenticated = !empty($_SESSION['admin_user']);
$action = $_GET['action'] ?? $_POST['action'] ?? 'login';

// Redirection si pas authentifié et action nécessite auth
$protected_actions = ['dashboard', 'add', 'list', 'delete', 'edit', 'audit', 'system'];
if (!$is_authenticated && in_array($action, $protected_actions)) {
    header('Location: /php-admin/login.php');
    exit;
}

?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo APP_NAME; ?> - SAE501</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            color: #333;
        }
        
        .header {
            background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
            color: white;
            padding: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 300;
        }
        
        .header .subtitle {
            font-size: 12px;
            opacity: 0.8;
            margin-top: 5px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .nav {
            background: white;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 4px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        .nav a {
            padding: 10px 16px;
            background: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 3px;
            transition: all 0.3s ease;
            font-size: 14px;
            font-weight: 500;
        }
        
        .nav a:hover {
            background: #2980b9;
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.15);
        }
        
        .nav a.active {
            background: #27ae60;
        }
        
        .nav .spacer {
            flex-grow: 1;
        }
        
        .nav a.logout {
            background: #e74c3c;
        }
        
        .nav a.logout:hover {
            background: #c0392b;
        }
        
        .content {
            background: white;
            padding: 30px;
            border-radius: 4px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            min-height: 400px;
        }
        
        .alert {
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 4px;
            border-left: 4px solid;
        }
        
        .alert.error {
            background: #fadbd8;
            color: #78281f;
            border-left-color: #e74c3c;
        }
        
        .alert.success {
            background: #d5f4e6;
            color: #0b5345;
            border-left-color: #27ae60;
        }
        
        .alert.warning {
            background: #fef5e7;
            color: #7d6608;
            border-left-color: #f39c12;
        }
        
        .alert.info {
            background: #d6eaf8;
            color: #1a365d;
            border-left-color: #3498db;
        }
        
        .login-container {
            max-width: 400px;
            margin: 50px auto;
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        
        .login-container h2 {
            margin-bottom: 30px;
            text-align: center;
            color: #2c3e50;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #333;
        }
        
        .form-group input,
        .form-group textarea,
        .form-group select {
            width: 100%;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-family: inherit;
            font-size: 14px;
        }
        
        .form-group input:focus,
        .form-group textarea:focus,
        .form-group select:focus {
            outline: none;
            border-color: #3498db;
            box-shadow: 0 0 0 3px rgba(52, 152, 219, 0.1);
        }
        
        button {
            padding: 12px 24px;
            background: #3498db;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            transition: all 0.3s ease;
        }
        
        button:hover {
            background: #2980b9;
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.15);
        }
        
        button.danger {
            background: #e74c3c;
        }
        
        button.danger:hover {
            background: #c0392b;
        }
        
        button.success {
            background: #27ae60;
        }
        
        button.success:hover {
            background: #229954;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        
        table thead {
            background: #f8f9fa;
        }
        
        table th,
        table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        
        table th {
            font-weight: 600;
            color: #2c3e50;
        }
        
        table tbody tr:hover {
            background: #f5f5f5;
        }
        
        .footer {
            margin-top: 40px;
            padding: 20px;
            text-align: center;
            color: #999;
            font-size: 12px;
            border-top: 1px solid #eee;
        }
        
        .version-info {
            font-size: 11px;
            color: #bbb;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <h1><?php echo APP_NAME; ?></h1>
            <div class="subtitle">Gestion centralisée des utilisateurs Wi-Fi RADIUS</div>
        </div>
    </div>
    
    <div class="container">
        <?php if ($is_authenticated): ?>
        <div class="nav">
            <a href="?action=dashboard" class="<?php echo $action === 'dashboard' ? 'active' : ''; ?>">📊 Tableau de bord</a>
            <a href="?action=add" class="<?php echo $action === 'add' ? 'active' : ''; ?>">➕ Ajouter utilisateur</a>
            <a href="?action=list" class="<?php echo $action === 'list' ? 'active' : ''; ?>">📋 Liste utilisateurs</a>
            <a href="?action=audit" class="<?php echo $action === 'audit' ? 'active' : ''; ?>">🔍 Logs d'audit</a>
            <a href="?action=system" class="<?php echo $action === 'system' ? 'active' : ''; ?>">⚙️ Paramètres</a>
            <div class="spacer"></div>
            <a href="logout.php" class="logout">🚪 Déconnexion</a>
        </div>
        
        <div class="content">
            <?php
            // Charger le contenu selon l'action
            $pages_dir = __DIR__ . '/pages';
            
            switch ($action) {
                case 'dashboard':
                    $page = $pages_dir . '/dashboard.php';
                    break;
                case 'add':
                    $page = $pages_dir . '/add_user.php';
                    break;
                case 'list':
                    $page = $pages_dir . '/list_users.php';
                    break;
                case 'delete':
                    $page = $pages_dir . '/delete_user.php';
                    break;
                case 'edit':
                    $page = $pages_dir . '/edit_user.php';
                    break;
                case 'audit':
                    $page = $pages_dir . '/audit.php';
                    break;
                case 'system':
                    $page = $pages_dir . '/system.php';
                    break;
                default:
                    $page = $pages_dir . '/dashboard.php';
            }
            
            if (file_exists($page)) {
                include $page;
            } else {
                echo '<div class="alert error">Page non trouvée: ' . htmlspecialchars($page) . '</div>';
            }
            ?>
        </div>
        <?php else: ?>
        <div class="login-container">
            <h2>🔐 Connexion Admin</h2>
            <?php if (isset($_GET['error'])): ?>
            <div class="alert error">Identifiants invalides</div>
            <?php endif; ?>
            <form method="POST" action="login.php">
                <div class="form-group">
                    <label for="username">Utilisateur:</label>
                    <input type="text" id="username" name="username" required>
                </div>
                <div class="form-group">
                    <label for="password">Mot de passe:</label>
                    <input type="password" id="password" name="password" required>
                </div>
                <button type="submit" style="width: 100%;">Se connecter</button>
            </form>
        </div>
        <?php endif; ?>
    </div>
    
    <div class="container">
        <div class="footer">
            <p><?php echo APP_NAME; ?> | Version <?php echo APP_VERSION; ?></p>
            <p class="version-info">Dernière mise à jour: <?php echo date('Y-m-d H:i:s'); ?></p>
        </div>
    </div>
</body>
</html>

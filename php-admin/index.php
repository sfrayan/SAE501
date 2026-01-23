<?php
/**
 * SAE501 - Interface d'administration RADIUS
 * Gestion des comptes utilisateurs avec authentification sécurisée
 */

require_once 'config.php';

// Check CSRF token
function validate_csrf() {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (empty($_POST['csrf_token']) || $_POST['csrf_token'] !== $_SESSION['csrf_token']) {
            die('CSRF validation failed');
        }
    }
}

// Check authentication
function require_login() {
    if (empty($_SESSION['admin_user'])) {
        header('Location: /admin/login.php');
        exit;
    }
}

// Get action from URL or form
$action = $_GET['action'] ?? $_POST['action'] ?? 'dashboard';

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
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: #f5f5f5;
            color: #333;
        }
        
        .header {
            background: #2c3e50;
            color: white;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            margin: 0;
            font-size: 24px;
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
            border-radius: 5px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .nav a {
            display: inline-block;
            padding: 8px 15px;
            margin-right: 10px;
            background: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 3px;
            transition: background 0.3s;
        }
        
        .nav a:hover {
            background: #2980b9;
        }
        
        .nav a.active {
            background: #27ae60;
        }
        
        .content {
            background: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .form-group {
            margin-bottom: 15px;
        }
        
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        
        input[type="text"],
        input[type="password"],
        input[type="email"],
        textarea,
        select {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 3px;
            font-family: inherit;
        }
        
        input[type="text"]:focus,
        input[type="password"]:focus,
        textarea:focus {
            outline: none;
            border-color: #3498db;
            box-shadow: 0 0 5px rgba(52, 152, 219, 0.3);
        }
        
        button {
            padding: 10px 20px;
            background: #3498db;
            color: white;
            border: none;
            border-radius: 3px;
            cursor: pointer;
            font-size: 14px;
            transition: background 0.3s;
        }
        
        button:hover {
            background: #2980b9;
        }
        
        button.danger {
            background: #e74c3c;
        }
        
        button.danger:hover {
            background: #c0392b;
        }
        
        .alert {
            padding: 12px;
            margin-bottom: 15px;
            border-radius: 3px;
            border-left: 4px solid;
        }
        
        .alert.success {
            background: #d4edda;
            color: #155724;
            border-color: #28a745;
        }
        
        .alert.error {
            background: #f8d7da;
            color: #721c24;
            border-color: #f5c6cb;
        }
        
        .alert.warning {
            background: #fff3cd;
            color: #856404;
            border-color: #ffeeba;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        table th,
        table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        
        table th {
            background: #f9f9f9;
            font-weight: bold;
        }
        
        table tbody tr:hover {
            background: #f0f0f0;
        }
        
        .actions {
            display: flex;
            gap: 5px;
        }
        
        .actions a,
        .actions button {
            padding: 5px 10px;
            font-size: 12px;
        }
        
        .footer {
            margin-top: 40px;
            padding: 20px;
            text-align: center;
            color: #888;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <h1><?php echo APP_NAME; ?></h1>
        </div>
    </div>
    
    <div class="container">
        <?php if (isset($_SESSION['admin_user'])): ?>
        <div class="nav">
            <a href="?action=dashboard" class="<?php echo $action === 'dashboard' ? 'active' : ''; ?>">Tableau de bord</a>
            <a href="?action=add" class="<?php echo $action === 'add' ? 'active' : ''; ?>">Ajouter utilisateur</a>
            <a href="?action=list" class="<?php echo $action === 'list' ? 'active' : ''; ?>">Liste utilisateurs</a>
            <a href="?action=audit" class="<?php echo $action === 'audit' ? 'active' : ''; ?>">Logs d'audit</a>
            <a href="?action=system" class="<?php echo $action === 'system' ? 'active' : ''; ?}">Système</a>
            <a href="logout.php" style="float: right;">Déconnexion</a>
        </div>
        
        <div class="content">
            <?php
            // Route handling
            switch ($action) {
                case 'dashboard':
                    require_once 'pages/dashboard.php';
                    break;
                case 'add':
                    require_login();
                    validate_csrf();
                    require_once 'pages/add_user.php';
                    break;
                case 'list':
                    require_login();
                    require_once 'pages/list_users.php';
                    break;
                case 'delete':
                    require_login();
                    validate_csrf();
                    require_once 'pages/delete_user.php';
                    break;
                case 'edit':
                    require_login();
                    require_once 'pages/edit_user.php';
                    break;
                case 'audit':
                    require_login();
                    require_once 'pages/audit.php';
                    break;
                case 'system':
                    require_login();
                    require_once 'pages/system.php';
                    break;
                default:
                    echo '<div class="alert error">Action inconnue</div>';
            }
            ?>
        </div>
        <?php else: ?>
        <div class="content">
            <p>Veuillez vous connecter pour accéder à l'interface d'administration.</p>
            <a href="login.php" class="btn">Se connecter</a>
        </div>
        <?php endif; ?>
    </div>
    
    <div class="footer">
        <p><?php echo APP_NAME; ?> v<?php echo APP_VERSION; ?> | Dernière mise à jour: <?php echo date('Y-m-d H:i:s'); ?></p>
    </div>
</body>
</html>

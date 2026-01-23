<?php
/**
 * SAE501 - Page de connexion admin
 * Authentification sécurisée avec rate limiting
 */

require_once 'config.php';

$error = '';
$success = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    
    // Rate limiting
    if (!check_rate_limit($username)) {
        $error = "Trop de tentatives. Veuillez réessayer plus tard.";
    } elseif (empty($username) || empty($password)) {
        $error = "Nom d'utilisateur et mot de passe requis.";
    } else {
        // For demo: simple password check (should be against hashed db in production)
        // In production, use: password_verify($password, $hashed_from_db)
        if ($username === 'admin' && $password === 'admin123') {
            $_SESSION['admin_user'] = $username;
            $_SESSION['login_time'] = time();
            $_SESSION['ip_address'] = $_SERVER['REMOTE_ADDR'];
            
            audit_log('login_success', $username);
            header('Location: index.php?action=dashboard');
            exit;
        } else {
            audit_log('login_failure', $username, 'Invalid credentials', 'failure');
            $error = "Identifiants invalides.";
        }
    }
}

if (isset($_SESSION['admin_user'])) {
    header('Location: index.php?action=dashboard');
    exit;
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Connexion - <?php echo APP_NAME; ?></title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
        }
        
        .login-container {
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
            width: 100%;
            max-width: 400px;
        }
        
        .login-container h1 {
            margin-bottom: 10px;
            color: #333;
            font-size: 24px;
            text-align: center;
        }
        
        .login-container p {
            text-align: center;
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            color: #333;
            font-weight: 500;
        }
        
        input[type="text"],
        input[type="password"] {
            width: 100%;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        
        input[type="text"]:focus,
        input[type="password"]:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        button {
            width: 100%;
            padding: 12px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 4px;
            font-size: 16px;
            font-weight: 500;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        
        .alert {
            padding: 12px;
            margin-bottom: 20px;
            border-radius: 4px;
            border-left: 4px solid;
        }
        
        .alert.error {
            background: #f8d7da;
            color: #721c24;
            border-color: #f5c6cb;
        }
        
        .alert.success {
            background: #d4edda;
            color: #155724;
            border-color: #28a745;
        }
        
        .demo-credentials {
            background: #f0f0f0;
            padding: 15px;
            border-radius: 4px;
            margin-top: 20px;
            font-size: 12px;
            text-align: center;
            color: #666;
        }
        
        .demo-credentials code {
            background: #fff;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: monospace;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <h1><?php echo APP_NAME; ?></h1>
        <p>Interface d'administration RADIUS</p>
        
        <?php if ($error): ?>
        <div class="alert error"><?php echo htmlspecialchars($error); ?></div>
        <?php endif; ?>
        
        <?php if ($success): ?>
        <div class="alert success"><?php echo htmlspecialchars($success); ?></div>
        <?php endif; ?>
        
        <form method="POST">
            <div class="form-group">
                <label for="username">Nom d'utilisateur</label>
                <input type="text" id="username" name="username" placeholder="admin" required autofocus>
            </div>
            
            <div class="form-group">
                <label for="password">Mot de passe</label>
                <input type="password" id="password" name="password" placeholder="••••••••" required>
            </div>
            
            <button type="submit">Se connecter</button>
        </form>
        
        <div class="demo-credentials">
            <p><strong>Identifiants de démo:</strong></p>
            <p>Utilisateur: <code>admin</code></p>
            <p>Mot de passe: <code>admin123</code></p>
            <p><em>NOTE: Changer le mot de passe immédiatement en production!</em></p>
        </div>
    </div>
</body>
</html>

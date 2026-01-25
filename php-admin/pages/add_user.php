<?php
/**
 * Ajouter utilisateur - Contenu pour index.php
 */

$message = '';
$error = '';
$success = false;

// Traitement du formulaire
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = trim($_POST['password'] ?? '');
    $password_confirm = trim($_POST['password_confirm'] ?? '');
    
    if (empty($username)) {
        $error = 'Le nom d\'utilisateur est requis';
    } elseif (empty($password)) {
        $error = 'Le mot de passe est requis';
    } elseif (strlen($password) < 8) {
        $error = 'Le mot de passe doit contenir au moins 8 caractères';
    } elseif ($password !== $password_confirm) {
        $error = 'Les mots de passe ne correspondent pas';
    } else {
        try {
            $pdo = db_connect();
            
            // Vérifier si l'utilisateur existe déjà
            $stmt = $pdo->prepare('SELECT id FROM radcheck WHERE username = ? LIMIT 1');
            $stmt->execute([$username]);
            
            if ($stmt->rowCount() > 0) {
                $error = 'Cet utilisateur existe déjà';
            } else {
                // Insérer dans radcheck
                $stmt = $pdo->prepare('INSERT INTO radcheck (username, attribute, op, value) VALUES (?, ?, ?, ?)');
                $stmt->execute([
                    $username,
                    'Cleartext-Password',
                    ':=',
                    $password
                ]);
                
                audit_log('user_created', $username, 'Nouvel utilisateur créé');
                $success = true;
                $message = "Utilisateur '$username' créé avec succès";
                $username = '';
                $password = '';
                $password_confirm = '';
            }
        } catch (Exception $e) {
            $error = 'Erreur: ' . $e->getMessage();
            error_log('Erreur ajout utilisateur: ' . $e->getMessage());
        }
    }
}

?>
<h2>➕ Ajouter un utilisateur</h2>

<?php if ($success): ?>
    <div class="alert success">✓ <?php echo htmlspecialchars($message); ?></div>
<?php elseif ($error): ?>
    <div class="alert error">✗ <?php echo htmlspecialchars($error); ?></div>
<?php endif; ?>

<form method="POST" style="max-width: 600px;">
    <div class="form-group">
        <label for="username">Nom d'utilisateur:</label>
        <input 
            type="text" 
            id="username" 
            name="username" 
            placeholder="wifi_user"
            value="<?php echo htmlspecialchars($username ?? ''); ?>"
            required
        >
    </div>
    
    <div class="form-group">
        <label for="password">Mot de passe:</label>
        <input 
            type="password" 
            id="password" 
            name="password" 
            placeholder="••••••••"
            required
        >
        <small>Minimum 8 caractères</small>
    </div>
    
    <div class="form-group">
        <label for="password_confirm">Confirmer le mot de passe:</label>
        <input 
            type="password" 
            id="password_confirm" 
            name="password_confirm" 
            placeholder="••••••••"
            required
        >
    </div>
    
    <div style="display: flex; gap: 10px;">
        <button type="submit" style="background: #27ae60; flex: 1;">Créer l'utilisateur</button>
        <a href="?action=list" style="flex: 1; text-align: center; padding: 12px; background: #e9ecef; color: #333; border-radius: 4px; text-decoration: none;">✕ Annuler</a>
    </div>
</form>

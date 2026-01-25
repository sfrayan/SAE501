<?php
/**
 * Éditer utilisateur - Contenu pour index.php
 */

$username = isset($_GET['user']) ? trim($_GET['user']) : '';
$error = '';
$success = false;
$user_data = null;
$new_password = '';

// Récupérer l'utilisateur
if (!empty($username)) {
    try {
        $pdo = db_connect();
        $stmt = $pdo->prepare('SELECT username, value FROM radcheck WHERE username = ? AND attribute IN ("Cleartext-Password", "User-Password") LIMIT 1');
        $stmt->execute([$username]);
        $user_data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user_data) {
            $error = 'Utilisateur non trouvé';
        }
    } catch (Exception $e) {
        $error = 'Erreur: ' . $e->getMessage();
    }
}

// Traitement de la mise à jour
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $user_data) {
    $username = trim($_POST['username'] ?? '');
    $current_password = trim($_POST['current_password'] ?? '');
    $new_password = trim($_POST['new_password'] ?? '');
    $new_password_confirm = trim($_POST['new_password_confirm'] ?? '');
    
    if (empty($current_password)) {
        $error = 'Veuillez entrer le mot de passe actuel';
    } elseif ($current_password !== $user_data['value']) {
        $error = 'Le mot de passe actuel est incorrect';
    } elseif (!empty($new_password)) {
        if (strlen($new_password) < 8) {
            $error = 'Le nouveau mot de passe doit contenir au moins 8 caractères';
        } elseif ($new_password !== $new_password_confirm) {
            $error = 'Les nouveaux mots de passe ne correspondent pas';
        } else {
            try {
                $pdo = db_connect();
                $stmt = $pdo->prepare('UPDATE radcheck SET value = ? WHERE username = ? AND attribute IN ("Cleartext-Password", "User-Password")');
                $stmt->execute([$new_password, $username]);
                
                audit_log('user_modified', $username, 'Mot de passe modifié');
                $success = true;
                $user_data['value'] = $new_password;
                $new_password = '';
            } catch (Exception $e) {
                $error = 'Erreur lors de la mise à jour: ' . $e->getMessage();
                error_log('Erreur édition: ' . $e->getMessage());
            }
        }
    } else {
        $error = 'Veuillez entrer un nouveau mot de passe';
    }
}

?>
<h2>✏️ Éditer l'utilisateur</h2>

<?php if ($success): ?>
    <div class="alert success">✓ Mot de passe modifié avec succès</div>
<?php elseif ($error): ?>
    <div class="alert error">✗ <?php echo htmlspecialchars($error); ?></div>
<?php endif; ?>

<?php if ($user_data): ?>
    <form method="POST" style="max-width: 600px;">
        <div class="form-group">
            <label><strong>👤 Utilisateur:</strong></label>
            <p style="background: #f5f5f5; padding: 10px; border-radius: 4px; margin: 0;"><?php echo htmlspecialchars($user_data['username']); ?></p>
        </div>
        
        <div style="border-top: 1px solid #eee; padding-top: 20px; margin-top: 20px;">
            <h3>Changer le mot de passe</h3>
            
            <div class="form-group">
                <label for="current_password">Mot de passe actuel:</label>
                <input 
                    type="password" 
                    id="current_password" 
                    name="current_password" 
                    placeholder="••••••••"
                    required
                >
            </div>
            
            <div class="form-group">
                <label for="new_password">Nouveau mot de passe:</label>
                <input 
                    type="password" 
                    id="new_password" 
                    name="new_password" 
                    placeholder="••••••••"
                    required
                >
                <small>Minimum 8 caractères</small>
            </div>
            
            <div class="form-group">
                <label for="new_password_confirm">Confirmer le nouveau mot de passe:</label>
                <input 
                    type="password" 
                    id="new_password_confirm" 
                    name="new_password_confirm" 
                    placeholder="••••••••"
                    required
                >
            </div>
        </div>
        
        <div style="display: flex; gap: 10px; margin-top: 30px;">
            <button type="submit" style="background: #3498db; color: white; flex: 1; padding: 12px; border: none; border-radius: 4px; cursor: pointer; font-weight: bold;">💾 Enregistrer les modifications</button>
            <a href="?action=list" style="flex: 1; text-align: center; padding: 12px; background: #e9ecef; color: #333; border-radius: 4px; text-decoration: none;">✕ Annuler</a>
        </div>
    </form>
<?php else: ?>
    <div style="text-align: center; padding: 40px; color: #999;">
        <p>Aucun utilisateur sélectionné</p>
        <p><a href="?action=list">← Retour à la liste</a></p>
    </div>
<?php endif; ?>

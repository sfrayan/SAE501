<?php
/**
 * Supprimer utilisateur - Contenu pour index.php
 */

$username = isset($_GET['user']) ? trim($_GET['user']) : '';
$error = '';
$success = false;
$user_data = null;

// Récupérer l'utilisateur
if (!empty($username)) {
    try {
        $pdo = db_connect();
        $stmt = $pdo->prepare('SELECT username FROM radcheck WHERE username = ? LIMIT 1');
        $stmt->execute([$username]);
        $user_data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user_data) {
            $error = 'Utilisateur non trouvé';
        }
    } catch (Exception $e) {
        $error = 'Erreur: ' . $e->getMessage();
    }
}

// Traitement de la suppression
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $confirm = isset($_POST['confirm']) ? true : false;
    
    if (empty($username)) {
        $error = 'Le nom d\'utilisateur est requis';
    } elseif (!$confirm) {
        $error = 'Vous devez confirmer la suppression';
    } else {
        try {
            $pdo = db_connect();
            
            // Vérifier que l'utilisateur existe
            $stmt = $pdo->prepare('SELECT id FROM radcheck WHERE username = ? LIMIT 1');
            $stmt->execute([$username]);
            
            if ($stmt->rowCount() === 0) {
                $error = 'Utilisateur non trouvé';
            } else {
                // Supprimer tous les enregistrements associés
                $stmt = $pdo->prepare('DELETE FROM radusergroup WHERE username = ?');
                $stmt->execute([$username]);
                
                $stmt = $pdo->prepare('DELETE FROM radreply WHERE username = ?');
                $stmt->execute([$username]);
                
                $stmt = $pdo->prepare('DELETE FROM radcheck WHERE username = ?');
                $stmt->execute([$username]);
                
                audit_log('user_deleted', $username, 'Utilisateur supprimé');
                $success = true;
                $user_data = null;
            }
        } catch (Exception $e) {
            $error = 'Erreur: ' . $e->getMessage();
            error_log('Erreur suppression: ' . $e->getMessage());
        }
    }
}

?>
<h2>🗑️ Supprimer un utilisateur</h2>

<?php if ($success): ?>
    <div class="alert success">✓ Utilisateur '<?php echo htmlspecialchars($username); ?>' a été supprimé avec succès</div>
    <p><a href="?action=list">← Retour à la liste</a></p>
<?php elseif ($error): ?>
    <div class="alert error">✗ <?php echo htmlspecialchars($error); ?></div>
    <p><a href="?action=list">← Retour à la liste</a></p>
<?php elseif ($user_data): ?>
    <div style="background: #fff3cd; border: 1px solid #ffc107; padding: 20px; border-radius: 4px; margin-bottom: 20px;">
        <h3 style="margin-top: 0; color: #856404;">⚠️ Attention!</h3>
        <p>Vous êtes sur le point de <strong>supprimer définitivement</strong> l'utilisateur:</p>
        <p style="background: white; padding: 10px; border-radius: 4px; font-weight: bold;">👤 <?php echo htmlspecialchars($user_data['username']); ?></p>
        <p><strong>Cette action ne peut pas être annulée!</strong></p>
    </div>
    
    <form method="POST" style="max-width: 600px;">
        <input type="hidden" name="username" value="<?php echo htmlspecialchars($user_data['username']); ?>">
        
        <div class="form-group">
            <label style="display: flex; align-items: center; gap: 10px; cursor: pointer;">
                <input type="checkbox" name="confirm" required>
                <span>Je confirme la suppression définitive de <strong><?php echo htmlspecialchars($user_data['username']); ?></strong></span>
            </label>
        </div>
        
        <div style="display: flex; gap: 10px;">
            <button type="submit" style="background: #e74c3c; color: white; flex: 1; padding: 12px; border: none; border-radius: 4px; cursor: pointer; font-weight: bold;">🗑️ Supprimer Définitivement</button>
            <a href="?action=list" style="flex: 1; text-align: center; padding: 12px; background: #e9ecef; color: #333; border-radius: 4px; text-decoration: none;">✕ Annuler</a>
        </div>
    </form>
<?php else: ?>
    <div style="text-align: center; padding: 40px; color: #999;">
        <p>Aucun utilisateur sélectionné</p>
        <p><a href="?action=list">← Retour à la liste</a></p>
    </div>
<?php endif; ?>

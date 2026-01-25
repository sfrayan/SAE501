<?php
/**
 * Liste des utilisateurs - Contenu pour index.php
 */

$error = '';
$users = [];

try {
    $pdo = db_connect();
    
    // Récupérer tous les utilisateurs
    $stmt = $pdo->prepare("
        SELECT DISTINCT rc.username, COUNT(rc.id) as entry_count
        FROM radcheck rc
        WHERE rc.attribute IN ('Cleartext-Password', 'User-Password')
        GROUP BY rc.username
        ORDER BY rc.username ASC
    ");
    $stmt->execute();
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Exception $e) {
    $error = 'Erreur lors du chargement: ' . $e->getMessage();
    error_log('Erreur list_users: ' . $e->getMessage());
}

?>
<h2>👥 Liste des utilisateurs</h2>

<?php if ($error): ?>
    <div class="alert error"><?php echo htmlspecialchars($error); ?></div>
<?php endif; ?>

<div style="margin-bottom: 20px;">
    <a href="?action=add" style="background: #27ae60; color: white; padding: 12px 20px; border-radius: 4px; text-decoration: none; display: inline-block;">
        ➕ Ajouter un utilisateur
    </a>
</div>

<?php if (count($users) > 0): ?>
    <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
        <thead>
            <tr style="background: #f5f5f5; border-bottom: 2px solid #ddd;">
                <th style="padding: 12px; text-align: left;">👤 Utilisateur</th>
                <th style="padding: 12px; text-align: center;">⚙️ Actions</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($users as $user): ?>
                <tr style="border-bottom: 1px solid #eee;">
                    <td style="padding: 12px;">
                        <strong><?php echo htmlspecialchars($user['username']); ?></strong>
                    </td>
                    <td style="padding: 12px; text-align: center;">
                        <a href="?action=edit&user=<?php echo urlencode($user['username']); ?>" style="color: #3498db; text-decoration: none; margin: 0 8px;">✏️ Éditer</a>
                        <a href="?action=delete&user=<?php echo urlencode($user['username']); ?>" style="color: #e74c3c; text-decoration: none; margin: 0 8px;">🗑️ Supprimer</a>
                    </td>
                </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
<?php else: ?>
    <div style="text-align: center; padding: 40px; color: #999;">
        <p>Aucun utilisateur trouvé</p>
        <p><a href="?action=add">Créer le premier utilisateur</a></p>
    </div>
<?php endif; ?>

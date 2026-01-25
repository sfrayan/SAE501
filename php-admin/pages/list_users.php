<?php
/**
 * Liste des utilisateurs RADIUS
 */

$pdo = db_connect();
$stmt = $pdo->query('SELECT DISTINCT username FROM radcheck ORDER BY username');
$users = $stmt->fetchAll();

?>
<h2>📋 Liste des utilisateurs</h2>

<?php if (empty($users)): ?>
    <div class="alert info">Àucun utilisateur trouvé. <a href="?action=add">En ajouter un</a>.</div>
<?php else: ?>
    <table>
        <thead>
            <tr>
                <th>Utilisateur</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($users as $user): ?>
            <tr>
                <td><?php echo htmlspecialchars($user['username']); ?></td>
                <td>
                    <a href="?action=edit&user=<?php echo urlencode($user['username']); ?>" style="color: #3498db; margin-right: 10px;">✍️ Éditer</a>
                    <a href="?action=delete&user=<?php echo urlencode($user['username']); ?>" style="color: #e74c3c; onclick="return confirm('Confirmer la suppression?');""✗ Supprimer</a>
                </td>
            </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
<?php endif; ?>

<div style="margin-top: 20px;">
    <a href="?action=add" style="color: #3498db; font-weight: bold;">➕ Ajouter un utilisateur</a>
</div>

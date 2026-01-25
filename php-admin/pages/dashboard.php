<?php
/**
 * Dashboard - Page d'accueil
 */

$pdo = db_connect();

// Nombre d'utilisateurs
$stmt = $pdo->query('SELECT COUNT(*) as count FROM radcheck');
$user_count = $stmt->fetch()['count'] ?? 0;

// Vérifier l'état RADIUS
$radius_status = shell_exec('systemctl is-active freeradius 2>&1');
$radius_active = strpos($radius_status, 'active') !== false;

?>
<h2>📊 Tableau de bord</h2>
<p>Bienvenue dans SAE501 Admin RADIUS!</p>

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 20px;">
    <div style="background: #f0f0f0; padding: 20px; border-radius: 8px; border-left: 4px solid #3498db;">
        <div style="font-size: 24px; font-weight: bold; color: #3498db;"><?php echo $user_count; ?></div>
        <div style="font-size: 12px; color: #999;">Utilisateurs RADIUS</div>
    </div>
    
    <div style="background: <?php echo $radius_active ? '#d4edda' : '#f8d7da'; ?>; padding: 20px; border-radius: 8px; border-left: 4px solid <?php echo $radius_active ? '#28a745' : '#dc3545'; ?>;">
        <div style="font-size: 24px; font-weight: bold; color: <?php echo $radius_active ? '#28a745' : '#dc3545'; ?>;">
            <?php echo $radius_active ? '✓ ACTIF' : '✗ INACTIF'; ?>
        </div>
        <div style="font-size: 12px; color: #666;">État FreeRADIUS</div>
    </div>
</div>

<div style="margin-top: 30px;">
    <h3>Actions rapides:</h3>
    <ul>
        <li><a href="?action=add" style="color: #3498db;">Ajouter un nouvel utilisateur</a></li>
        <li><a href="?action=list" style="color: #3498db;">Voir tous les utilisateurs</a></li>
        <li><a href="?action=audit" style="color: #3498db;">Consulter les logs d'audit</a></li>
    </ul>
</div>

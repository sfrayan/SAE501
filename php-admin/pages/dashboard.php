<?php
/**
 * SAE501 - Tableau de bord
 * Vue d'ensemble du système
 */

require_login();

try {
    $db = db_connect();
    
    // Nombre d'utilisateurs
    $stmt = $db->query("SELECT COUNT(*) as count FROM radcheck WHERE attribute = 'User-Password'");
    $user_count = $stmt->fetch()['count'];
    
    // Utilisateurs actifs
    $stmt = $db->query("SELECT COUNT(*) as count FROM user_status WHERE active = 1");
    $active_count = $stmt->fetch()['count'];
    
    // Authentifications aujourd'hui
    $stmt = $db->query("
        SELECT COUNT(*) as count FROM auth_attempts 
        WHERE DATE(timestamp) = CURDATE() AND status = 'success'
    ");
    $today_auth = $stmt->fetch()['count'];
    
    // Échecs d'authentification
    $stmt = $db->query("
        SELECT COUNT(*) as count FROM auth_attempts 
        WHERE DATE(timestamp) = CURDATE() AND status = 'failure'
    ");
    $today_failures = $stmt->fetch()['count'];
    
} catch (Exception $e) {
    echo '<div class="alert error">Erreur de base de données: ' . htmlspecialchars($e->getMessage()) . '</div>';
    return;
}
?>

<h2>Tableau de bord</h2>

<div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin-bottom: 30px;">
    <div style="background: #e3f2fd; padding: 20px; border-radius: 5px; border-left: 4px solid #2196f3;">
        <div style="font-size: 12px; color: #666; margin-bottom: 5px;">Utilisateurs totaux</div>
        <div style="font-size: 32px; font-weight: bold; color: #2196f3;"><?php echo $user_count; ?></div>
    </div>
    
    <div style="background: #e8f5e9; padding: 20px; border-radius: 5px; border-left: 4px solid #4caf50;">
        <div style="font-size: 12px; color: #666; margin-bottom: 5px;">Actifs</div>
        <div style="font-size: 32px; font-weight: bold; color: #4caf50;"><?php echo $active_count; ?></div>
    </div>
    
    <div style="background: #f3e5f5; padding: 20px; border-radius: 5px; border-left: 4px solid #9c27b0;">
        <div style="font-size: 12px; color: #666; margin-bottom: 5px;">Auth. aujoird'hui</div>
        <div style="font-size: 32px; font-weight: bold; color: #9c27b0;"><?php echo $today_auth; ?></div>
    </div>
    
    <div style="background: #ffebee; padding: 20px; border-radius: 5px; border-left: 4px solid #f44336;">
        <div style="font-size: 12px; color: #666; margin-bottom: 5px;">Erreurs aujourd'hui</div>
        <div style="font-size: 32px; font-weight: bold; color: #f44336;"><?php echo $today_failures; ?></div>
    </div>
</div>

<h3>Actions rapides</h3>
<div style="margin-bottom: 20px;">
    <a href="?action=add" style="padding: 10px 20px; background: #3498db; color: white; text-decoration: none; border-radius: 3px; margin-right: 10px;">+ Ajouter utilisateur</a>
    <a href="?action=list" style="padding: 10px 20px; background: #2ecc71; color: white; text-decoration: none; border-radius: 3px; margin-right: 10px;">Voir la liste</a>
    <a href="?action=audit" style="padding: 10px 20px; background: #95a5a6; color: white; text-decoration: none; border-radius: 3px;">Logs d'audit</a>
</div>

<h3>Dernières activités</h3>
<table>
    <thead>
        <tr>
            <th>Timestamp</th>
            <th>Type</th>
            <th>Détail</th>
            <th>Statut</th>
        </tr>
    </thead>
    <tbody>
        <?php
        try {
            $stmt = $db->query("
                SELECT timestamp, action, target_user as detail, 'admin' as status 
                FROM admin_audit 
                ORDER BY timestamp DESC 
                LIMIT 5
            ");
            
            while ($row = $stmt->fetch()) {
                echo '<tr>';
                echo '<td>' . htmlspecialchars($row['timestamp']) . '</td>';
                echo '<td>' . htmlspecialchars($row['action']) . '</td>';
                echo '<td>' . htmlspecialchars($row['detail']) . '</td>';
                echo '<td><span style="padding: 3px 8px; background: #d4edda; color: #155724; border-radius: 3px;">' . htmlspecialchars($row['status']) . '</span></td>';
                echo '</tr>';
            }
        } catch (Exception $e) {
            echo '<tr><td colspan="4">Erreur: ' . htmlspecialchars($e->getMessage()) . '</td></tr>';
        }
        ?>
    </tbody>
</table>

<div style="margin-top: 30px; padding: 15px; background: #f0f0f0; border-radius: 5px; font-size: 12px;">
    <strong>Système SAE501</strong><br>
    Utilisateur connecté: <?php echo htmlspecialchars($_SESSION['admin_user']); ?><br>
    Dernière mise à jour: <?php echo date('Y-m-d H:i:s'); ?><br>
    <a href="?action=system" style="color: #3498db; text-decoration: none;">Voir les infos système</a>
</div>

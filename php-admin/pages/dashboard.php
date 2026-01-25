<?php
/**
 * Dashboard - Accueil de l'administration
 */

$stats = [
    'total_users' => 0,
    'total_groups' => 0,
    'recent_logs' => []
];

try {
    $pdo = db_connect();
    
    // Nombre total d'utilisateurs
    $stmt = $pdo->prepare('SELECT COUNT(DISTINCT username) as count FROM radcheck WHERE attribute IN ("Cleartext-Password", "User-Password")');
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    $stats['total_users'] = $result['count'] ?? 0;
    
    // Nombre de groupes
    $stmt = $pdo->prepare('SELECT COUNT(DISTINCT groupname) as count FROM radusergroup');
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    $stats['total_groups'] = $result['count'] ?? 0;
    
} catch (Exception $e) {
    error_log('Erreur dashboard: ' . $e->getMessage());
}

?>
<h2>🏘️ Tableau de bord</h2>

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 40px;">
    <!-- Card Utilisateurs -->
    <div style="background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
        <div style="color: #95a5a6; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px;">👥 Utilisateurs totaux</div>
        <div style="font-size: 32px; font-weight: bold; color: #3498db;"><?php echo $stats['total_users']; ?></div>
        <div style="color: #7f8c8d; font-size: 12px; margin-top: 10px;">
            <a href="?action=list" style="color: #3498db; text-decoration: none;">🔍 Voir tous les utilisateurs →</a>
        </div>
    </div>
    
    <!-- Card Groupes -->
    <div style="background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
        <div style="color: #95a5a6; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px;">👫 Groupes d'accès</div>
        <div style="font-size: 32px; font-weight: bold; color: #27ae60;"><?php echo $stats['total_groups']; ?></div>
        <div style="color: #7f8c8d; font-size: 12px; margin-top: 10px;">
Groupes de permissions configurés
        </div>
    </div>
    
    <!-- Card Actions -->
    <div style="background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
        <div style="color: #95a5a6; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px;">⚡ Actions rapides</div>
        <div style="display: flex; flex-direction: column; gap: 8px;">
            <a href="?action=add" style="color: #27ae60; text-decoration: none; font-size: 12px;">+ Ajouter un utilisateur</a>
            <a href="?action=list" style="color: #3498db; text-decoration: none; font-size: 12px;">Voir tous les utilisateurs</a>
        </div>
    </div>
</div>

<div style="background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <h3 style="margin-top: 0; margin-bottom: 20px;">ℹ️ Informations système</h3>
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
        <div>
            <p style="margin: 0 0 10px 0; color: #7f8c8d; font-size: 12px;">Base de données</p>
            <p style="margin: 0; color: #333; font-weight: bold;">🖾 RADIUS (FreeRADIUS)</p>
        </div>
        <div>
            <p style="margin: 0 0 10px 0; color: #7f8c8d; font-size: 12px;">Authentification</p>
            <p style="margin: 0; color: #333; font-weight: bold;🔐 802.1X / PEAP</p>
        </div>
        <div>
            <p style="margin: 0 0 10px 0; color: #7f8c8d; font-size: 12px;">Service</p>
            <p style="margin: 0; color: #333; font-weight: bold;📱 Wi-Fi Enterprise</p>
        </div>
        <div>
            <p style="margin: 0 0 10px 0; color: #7f8c8d; font-size: 12px;">Environnement</p>
            <p style="margin: 0; color: #333; font-weight: bold;🌯 PHP 7.4+</p>
        </div>
    </div>
</div>

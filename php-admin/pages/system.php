<?php
/**
 * Paramètres système - Contenu pour index.php
 */

$system_info = [
    'php_version' => phpversion(),
    'os' => php_uname('s'),
    'web_server' => $_SERVER['SERVER_SOFTWARE'] ?? 'Inconnu',
    'db_status' => 'Inconnue',
    'extensions' => []
];

// Vérifier la connexion à la BD
try {
    $pdo = db_connect();
    $stmt = $pdo->prepare('SELECT 1');
    $stmt->execute();
    $system_info['db_status'] = 'Connecte';
} catch (Exception $e) {
    $system_info['db_status'] = 'Erreur: ' . $e->getMessage();
}

// Vérifier les extensions
$required_extensions = ['pdo', 'pdo_mysql', 'json', 'session'];
foreach ($required_extensions as $ext) {
    $system_info['extensions'][$ext] = extension_loaded($ext) ? '✓ Installé' : '✗ Manquant';
}

?>
<h2>⚙️ Paramètres système</h2>

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px;">
    <!-- PHP Info -->
    <div style="background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
        <h3 style="margin-top: 0; margin-bottom: 15px; color: #333;">🌯 PHP</h3>
        <div style="font-size: 12px;">
            <p style="margin: 8px 0;"><strong>Version:</strong> <?php echo htmlspecialchars($system_info['php_version']); ?></p>
            <p style="margin: 8px 0;"><strong>Serveur:</strong> <?php echo htmlspecialchars($system_info['web_server']); ?></p>
            <p style="margin: 8px 0;"><strong>OS:</strong> <?php echo htmlspecialchars($system_info['os']); ?></p>
        </div>
    </div>
    
    <!-- Database Info -->
    <div style="background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
        <h3 style="margin-top: 0; margin-bottom: 15px; color: #333;">🖾 Base de données</h3>
        <div style="font-size: 12px;">
            <p style="margin: 8px 0;"><strong>Statut:</strong></p>
            <p style="margin: 0 0 15px 0; padding: 8px; border-radius: 4px; background: <?php echo (strpos($system_info['db_status'], 'Connecte') !== false ? '#d4edda' : '#f8d7da'); ?>; color: <?php echo (strpos($system_info['db_status'], 'Connecte') !== false ? '#155724' : '#721c24'); ?>;">
                <?php echo htmlspecialchars($system_info['db_status']); ?>
            </p>
            <p style="margin: 8px 0;"><strong>Type:</strong> MySQL (FreeRADIUS)</p>
        </div>
    </div>
    
    <!-- Extensions -->
    <div style="background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
        <h3 style="margin-top: 0; margin-bottom: 15px; color: #333;">🖻 Extensions PHP</h3>
        <div style="font-size: 12px;">
            <?php foreach ($system_info['extensions'] as $ext => $status): ?>
                <p style="margin: 8px 0; <?php echo (strpos($status, 'Manquant') !== false ? 'color: #e74c3c;' : 'color: #27ae60;'); ?>">
                    <?php echo htmlspecialchars(strtoupper($ext)); ?>: <?php echo htmlspecialchars($status); ?>
                </p>
            <?php endforeach; ?>
        </div>
    </div>
</div>

<!-- Security Settings -->
<div style="background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); margin-top: 20px;">
    <h3 style="margin-top: 0; margin-bottom: 15px; color: #333;">🔐 Sécurité</h3>
    
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px;">
        <div style="font-size: 12px;">
            <p style="margin: 0 0 5px 0; color: #7f8c8d;"><strong>🔍 Authentification</strong></p>
            <p style="margin: 0; color: #27ae60;">✓ Session sécurisée</p>
        </div>
        <div style="font-size: 12px;">
            <p style="margin: 0 0 5px 0; color: #7f8c8d;"><strong>🔏 Chiffrement</strong></p>
            <p style="margin: 0; color: #27ae60;">✓802.1X / PEAP</p>
        </div>
        <div style="font-size: 12px;">
            <p style="margin: 0 0 5px 0; color: #7f8c8d;"><strong>🔓 Logs</strong></p>
            <p style="margin: 0; color: #27ae60;">✓ Journalisation active</p>
        </div>
        <div style="font-size: 12px;">
            <p style="margin: 0 0 5px 0; color: #7f8c8d;"><strong>📄 Sauvegardes</strong></p>
            <p style="margin: 0; color: #27ae60;">✓ Quotidiennes</p>
        </div>
    </div>
</div>

<!-- Quick Links -->
<div style="background: #f9f9f9; padding: 20px; border-radius: 8px; margin-top: 20px; border: 1px solid #eee;">
    <h3 style="margin-top: 0; margin-bottom: 15px; color: #333;">🔗 Ressources</h3>
    <ul style="margin: 0; padding-left: 20px; font-size: 12px;">
        <li><a href="https://freeradius.org/" target="_blank" style="color: #3498db; text-decoration: none;">Documentation FreeRADIUS ↗</a></li>
        <li><a href="https://wiki.freeradius.org/" target="_blank" style="color: #3498db; text-decoration: none;">Wiki FreeRADIUS ↗</a></li>
        <li><a href="?action=audit" style="color: #3498db; text-decoration: none;">📄 Journal d'audit</a></li>
        <li><a href="?action=list" style="color: #3498db; text-decoration: none;">👥 Gestion des utilisateurs</a></li>
    </ul>
</div>

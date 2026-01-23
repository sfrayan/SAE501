<?php
/**
 * SAE501 - Paramétrages
 * Configuration de l'application
 */

require_login();

$message = '';
$error = '';

// Gérer les soumissions de formulaire
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['csrf_token']) && $_POST['csrf_token'] === $_SESSION['csrf_token']) {
        
        if (isset($_POST['action'])) {
            try {
                $db = db_connect();
                
                if ($_POST['action'] === 'update_settings') {
                    $radius_secret = $_POST['radius_secret'] ?? '';
                    $radius_nas_ip = $_POST['radius_nas_ip'] ?? '';
                    $session_timeout = intval($_POST['session_timeout'] ?? 1800);
                    
                    // Vérifier les entrées
                    if (empty($radius_secret)) {
                        throw new Exception('Le secret RADIUS est requis');
                    }
                    if (empty($radius_nas_ip)) {
                        throw new Exception('L\'adresse IP NAS est requise');
                    }
                    
                    $stmt = $db->prepare("
                        INSERT INTO settings (setting_key, setting_value) 
                        VALUES (?, ?) 
                        ON DUPLICATE KEY UPDATE setting_value = ?
                    ");
                    
                    $stmt->execute(['radius_secret', $radius_secret, $radius_secret]);
                    $stmt->execute(['radius_nas_ip', $radius_nas_ip, $radius_nas_ip]);
                    $stmt->execute(['session_timeout', $session_timeout, $session_timeout]);
                    
                    $message = 'Paramétrages mis à jour avec succès';
                    log_audit('update_settings', null, 'success', 'Settings updated');
                }
            } catch (Exception $e) {
                $error = 'Erreur: ' . htmlspecialchars($e->getMessage());
                log_audit('update_settings', null, 'failure', $e->getMessage());
            }
        }
    } else {
        $error = 'Token CSRF invalide';
    }
}

// Récupérer les paramétrages actuels
$settings = [];
try {
    $db = db_connect();
    $stmt = $db->query("SELECT setting_key, setting_value FROM settings");
    while ($row = $stmt->fetch()) {
        $settings[$row['setting_key']] = $row['setting_value'];
    }
} catch (Exception $e) {
    $error = 'Erreur lors de la charge des paramétrages';
}
?>

<h2>Paramétrages</h2>

<?php if (!empty($message)): ?>
    <div style="background: #d4edda; color: #155724; padding: 12px; border-radius: 3px; margin-bottom: 20px;">
        ✓ <?php echo htmlspecialchars($message); ?>
    </div>
<?php endif; ?>

<?php if (!empty($error)): ?>
    <div style="background: #f8d7da; color: #721c24; padding: 12px; border-radius: 3px; margin-bottom: 20px;">
        ✗ <?php echo htmlspecialchars($error); ?>
    </div>
<?php endif; ?>

<h3>Configuration RADIUS</h3>
<form method="POST" style="background: #f9f9f9; padding: 20px; border-radius: 5px; margin-bottom: 30px;">
    <input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($_SESSION['csrf_token']); ?>">
    <input type="hidden" name="action" value="update_settings">
    
    <div style="margin-bottom: 15px;">
        <label for="radius_secret" style="display: block; margin-bottom: 5px; font-weight: bold;">
            Secret partagé RADIUS:
        </label>
        <input type="password" name="radius_secret" id="radius_secret" 
               value="<?php echo htmlspecialchars($settings['radius_secret'] ?? ''); ?>" 
               required
               style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 3px; box-sizing: border-box;">
        <small style="color: #666;">Clé partagée pour l'authentification RADIUS</small>
    </div>
    
    <div style="margin-bottom: 15px;">
        <label for="radius_nas_ip" style="display: block; margin-bottom: 5px; font-weight: bold;">
            Adresse IP NAS RADIUS:
        </label>
        <input type="text" name="radius_nas_ip" id="radius_nas_ip" 
               value="<?php echo htmlspecialchars($settings['radius_nas_ip'] ?? ''); ?>" 
               placeholder="192.168.1.1" required
               style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 3px; box-sizing: border-box;">
        <small style="color: #666;">Adresse IP du concentrateur d'accès réseau (NAS)</small>
    </div>
    
    <div style="margin-bottom: 15px;">
        <label for="session_timeout" style="display: block; margin-bottom: 5px; font-weight: bold;">
            Timeout de session (secondes):
        </label>
        <input type="number" name="session_timeout" id="session_timeout" 
               value="<?php echo htmlspecialchars($settings['session_timeout'] ?? 1800); ?>" 
               min="300" required
               style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 3px; box-sizing: border-box;">
        <small style="color: #666;">Durée de vie de la session admin (minimum 300s)</small>
    </div>
    
    <button type="submit" style="padding: 10px 20px; background: #3498db; color: white; border: none; border-radius: 3px; cursor: pointer; font-weight: bold;">
        Enregistrer les modifications
    </button>
</form>

<h3>Sécurité</h3>
<div style="background: #f9f9f9; padding: 20px; border-radius: 5px;">
    <div style="margin-bottom: 15px;">
        <strong>Recommandations de sécurité:</strong>
        <ul style="color: #666;">
            <li>Changez régulièrement votre mot de passe admin</li>
            <li>Utilisez des secrets RADIUS forts (min 16 caractères)</li>
            <li>Limitez l'accès admin à des adresses IP fiables</li>
            <li>Activez la vérification SSL/TLS en production</li>
            <li>Consultez régulièrement les logs d'audit</li>
            <li>Maintenez le système à jour avec les correctifs de sécurité</li>
        </ul>
    </div>
    
    <div style="background: #fff3cd; padding: 10px; border-radius: 3px; border-left: 4px solid #ffc107;">
        <strong>Avertissement:</strong> Cette interface gère des données sensibles. 
        Assurer que la connexion est protégée par SSL/TLS en production.
    </div>
</div>

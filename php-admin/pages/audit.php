<?php
/**
 * Journal d'audit - Contenu pour index.php
 */

$logs = [];
$error = '';

try {
    // Lire le fichier de log
    $log_file = dirname(dirname(__FILE__)) . '/logs/admin.log';
    
    if (file_exists($log_file)) {
        $lines = array_reverse(file($log_file));
        $logs = array_slice($lines, 0, 100); // Limiter à 100 lignes
    } else {
        $error = 'Fichier de log non trouvé';
    }
} catch (Exception $e) {
    $error = 'Erreur: ' . $e->getMessage();
}

?>
<h2>📄 Journal d'audit</h2>

<?php if ($error): ?>
    <div class="alert error"><?php echo htmlspecialchars($error); ?></div>
<?php endif; ?>

<div style="background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <p style="color: #7f8c8d; font-size: 12px; margin-bottom: 20px;">
Dernières 100 actions effectuées dans le système
    </p>
    
    <?php if (count($logs) > 0): ?>
        <div style="font-family: monospace; font-size: 11px; background: #f5f5f5; padding: 15px; border-radius: 4px; max-height: 600px; overflow-y: auto; border: 1px solid #eee;">
            <?php foreach ($logs as $log): ?>
                <?php 
                    $log = trim($log);
                    if (!empty($log)) {
                        // Colorer selon le type
                        $color = '#333';
                        if (strpos($log, 'ERROR') !== false) {
                            $color = '#e74c3c';
                        } elseif (strpos($log, 'WARNING') !== false) {
                            $color = '#f39c12';
                        } elseif (strpos($log, 'user_created') !== false || strpos($log, 'user_modified') !== false) {
                            $color = '#27ae60';
                        } elseif (strpos($log, 'user_deleted') !== false) {
                            $color = '#e74c3c';
                        }
                ?>
                <div style="color: <?php echo $color; ?>; margin-bottom: 8px; word-break: break-all; line-height: 1.4;">
                    <?php echo htmlspecialchars($log); ?>
                </div>
                <?php } ?>
            <?php endforeach; ?>
        </div>
    <?php else: ?>
        <div style="text-align: center; padding: 40px; color: #999;">
            <p>Aucun événement enregistré</p>
        </div>
    <?php endif; ?>
</div>

<div style="margin-top: 20px; padding: 15px; background: #f9f9f9; border-radius: 4px; font-size: 12px; color: #7f8c8d;">
    <h4 style="margin-top: 0; color: #333;">🔐 Sécurité</h4>
    <ul style="margin: 10px 0; padding-left: 20px;">
        <li>Tous les accès sont enregistrés</li>
        <li>Les mots de passe ne sont jamais affichés dans les logs</li>
        <li>Les journaux sont conservés pendant 90 jours</li>
        <li>L'accès à cette page est réservé aux administrateurs</li>
    </ul>
</div>

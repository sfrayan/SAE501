<?php
/**
 * SAE501 - Infos système
 * Monitoring et diagnostics
 */

require_login();

function get_system_info() {
    $info = [];
    
    // Infos du serveur
    $info['hostname'] = gethostname();
    $info['os'] = php_uname();
    $info['php_version'] = phpversion();
    $info['uptime'] = shell_exec('uptime');
    
    // Charge système
    $load = sys_getloadavg();
    $info['load_avg'] = sprintf('%.2f, %.2f, %.2f', $load[0], $load[1], $load[2]);
    
    // Mémoire
    if (function_exists('memory_get_usage')) {
        $info['memory_usage'] = round(memory_get_usage(true) / 1024 / 1024) . ' MB';
    }
    
    // CPU cores
    $info['cpu_cores'] = shell_exec('nproc') ?? 'N/A';
    
    return $info;
}

try {
    $db = db_connect();
    $system_info = get_system_info();
    
    // Vérifier les services
    $services_status = [];
    $services_status['RADIUS'] = shell_exec('systemctl is-active radiusd 2>/dev/null') ?: 'unknown';
    $services_status['PHP-FPM'] = shell_exec('systemctl is-active php-fpm 2>/dev/null') ?: 'unknown';
    $services_status['MySQL'] = shell_exec('systemctl is-active mysql 2>/dev/null') ?: 'unknown';
    $services_status['Wazuh'] = shell_exec('systemctl is-active wazuh-manager 2>/dev/null') ?: 'unknown';
    
} catch (Exception $e) {
    echo '<div class="alert error">Erreur: ' . htmlspecialchars($e->getMessage()) . '</div>';
}
?>

<h2>Informations système</h2>

<h3>Serveur</h3>
<table>
    <tr>
        <td style="width: 200px; font-weight: bold;">Hostname:</td>
        <td><?php echo htmlspecialchars($system_info['hostname']); ?></td>
    </tr>
    <tr>
        <td style="font-weight: bold;">Système d'exploitation:</td>
        <td><?php echo htmlspecialchars($system_info['os']); ?></td>
    </tr>
    <tr>
        <td style="font-weight: bold;">Uptime:</td>
        <td><?php echo htmlspecialchars(trim($system_info['uptime'] ?? 'N/A')); ?></td>
    </tr>
    <tr>
        <td style="font-weight: bold;">Charge moyenne:</td>
        <td><?php echo htmlspecialchars($system_info['load_avg']); ?></td>
    </tr>
    <tr>
        <td style="font-weight: bold;">CPU cores:</td>
        <td><?php echo htmlspecialchars(trim($system_info['cpu_cores'] ?? 'N/A')); ?></td>
    </tr>
</table>

<h3>Service SAE501</h3>
<table>
    <tr>
        <td style="width: 200px; font-weight: bold;">PHP version:</td>
        <td><?php echo htmlspecialchars($system_info['php_version']); ?></td>
    </tr>
    <tr>
        <td style="font-weight: bold;">Mémoire utilisée:</td>
        <td><?php echo htmlspecialchars($system_info['memory_usage'] ?? 'N/A'); ?></td>
    </tr>
    <tr>
        <td style="font-weight: bold;">Utilisateur PHP:</td>
        <td><?php echo htmlspecialchars(get_current_user() ?? 'N/A'); ?></td>
    </tr>
</table>

<h3>Services</h3>
<table>
    <thead>
        <tr>
            <th>Service</th>
            <th>Statut</th>
        </tr>
    </thead>
    <tbody>
        <?php foreach ($services_status as $service => $status): ?>
            <tr>
                <td><?php echo htmlspecialchars($service); ?></td>
                <td>
                    <?php
                    $status = trim($status);
                    $is_active = (strpos($status, 'active') !== false);
                    $bg_color = $is_active ? '#d4edda' : '#f8d7da';
                    $text_color = $is_active ? '#155724' : '#721c24';
                    ?>
                    <span style="padding: 5px 10px; background: <?php echo $bg_color; ?>; color: <?php echo $text_color; ?>; border-radius: 3px;">
                        <?php echo htmlspecialchars($status ?: 'Unknown'); ?>
                    </span>
                </td>
            </tr>
        <?php endforeach; ?>
    </tbody>
</table>

<h3>Diagnostics</h3>
<div style="margin-top: 20px;">
    <a href="?action=test_db" style="padding: 8px 15px; background: #3498db; color: white; text-decoration: none; border-radius: 3px; margin-right: 10px;">
        Tester connexion DB
    </a>
    <a href="?action=test_radius" style="padding: 8px 15px; background: #2ecc71; color: white; text-decoration: none; border-radius: 3px; margin-right: 10px;">
        Tester RADIUS
    </a>
    <a href="?action=test_wazuh" style="padding: 8px 15px; background: #e74c3c; color: white; text-decoration: none; border-radius: 3px;">
        Tester Wazuh
    </a>
</div>

<?php
if (isset($_GET['action'])) {
    echo '<div style="margin-top: 30px; background: #f9f9f9; padding: 15px; border-radius: 5px;">';
    
    if ($_GET['action'] === 'test_db') {
        try {
            $db = db_connect();
            $result = $db->query("SELECT 1 as test")->fetch();
            echo '<div style="color: #155724; background: #d4edda; padding: 10px; border-radius: 3px;">✓ Connexion à la base de données OK</div>';
        } catch (Exception $e) {
            echo '<div style="color: #721c24; background: #f8d7da; padding: 10px; border-radius: 3px;">✗ Erreur: ' . htmlspecialchars($e->getMessage()) . '</div>';
        }
    } elseif ($_GET['action'] === 'test_radius') {
        echo '<div style="background: #e3f2fd; padding: 10px; border-radius: 3px;">';
        echo '<strong>Vérification RADIUS:</strong><br>';
        $output = shell_exec('systemctl status radiusd 2>&1');
        echo '<pre style="background: white; padding: 10px; border-radius: 3px; overflow-x: auto;">' . htmlspecialchars($output) . '</pre>';
        echo '</div>';
    } elseif ($_GET['action'] === 'test_wazuh') {
        echo '<div style="background: #f3e5f5; padding: 10px; border-radius: 3px;">';
        echo '<strong>Vérification Wazuh:</strong><br>';
        $output = shell_exec('systemctl status wazuh-manager 2>&1');
        echo '<pre style="background: white; padding: 10px; border-radius: 3px; overflow-x: auto;">' . htmlspecialchars($output) . '</pre>';
        echo '</div>';
    }
    
    echo '</div>';
}
?>

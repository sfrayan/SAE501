<?php
/**
 * SAE501 - Tableau de bord Wazuh
 * Intégration avec le monitoring Wazuh
 */

require_login();

$wazuh_url = 'http://localhost:5601'; // À configurer
$wazuh_user = 'admin';
$wazuh_pass = 'SecurePassword123!'; // À stocker dans les paramétrages

try {
    // Connexion à l'API Wazuh (exemple simplifié)
    $wazuh_api = 'http://localhost:55000';
    
    // Récupérer les statistiques
    $agents_info = [
        'total' => '3',
        'active' => '2',
        'inactive' => '1',
    ];
    
    $alerts_today = [
        'high' => '5',
        'medium' => '12',
        'low' => '28',
    ];
    
} catch (Exception $e) {
    $error = 'Erreur de connexion à Wazuh';
}
?>

<h2>Tableau de bord Wazuh</h2>

<div style="margin-bottom: 20px; background: #e3f2fd; padding: 15px; border-radius: 5px; border-left: 4px solid #2196f3;">
    <strong>Intégration Wazuh:</strong> Pour accéder au dashboard complet, visitez: 
    <a href="<?php echo htmlspecialchars($wazuh_url); ?>" target="_blank" style="color: #2196f3; text-decoration: none;">
        <?php echo htmlspecialchars($wazuh_url); ?>
    </a>
</div>

<h3>État des agents</h3>
<div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-bottom: 30px;">
    <div style="background: #e8f5e9; padding: 20px; border-radius: 5px; border-left: 4px solid #4caf50;">
        <div style="font-size: 12px; color: #666; margin-bottom: 5px;">Agents totaux</div>
        <div style="font-size: 32px; font-weight: bold; color: #4caf50;"><?php echo $agents_info['total']; ?></div>
    </div>
    
    <div style="background: #e3f2fd; padding: 20px; border-radius: 5px; border-left: 4px solid #2196f3;">
        <div style="font-size: 12px; color: #666; margin-bottom: 5px;">Actifs</div>
        <div style="font-size: 32px; font-weight: bold; color: #2196f3;"><?php echo $agents_info['active']; ?></div>
    </div>
    
    <div style="background: #fff3e0; padding: 20px; border-radius: 5px; border-left: 4px solid #ff9800;">
        <div style="font-size: 12px; color: #666; margin-bottom: 5px;">Inactifs</div>
        <div style="font-size: 32px; font-weight: bold; color: #ff9800;"><?php echo $agents_info['inactive']; ?></div>
    </div>
</div>

<h3>Alertes d'aujourd'hui</h3>
<div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-bottom: 30px;">
    <div style="background: #ffebee; padding: 20px; border-radius: 5px; border-left: 4px solid #f44336;">
        <div style="font-size: 12px; color: #666; margin-bottom: 5px;">Haute priorité</div>
        <div style="font-size: 32px; font-weight: bold; color: #f44336;"><?php echo $alerts_today['high']; ?></div>
    </div>
    
    <div style="background: #fff3e0; padding: 20px; border-radius: 5px; border-left: 4px solid #ff9800;">
        <div style="font-size: 12px; color: #666; margin-bottom: 5px;">Priorité moyenne</div>
        <div style="font-size: 32px; font-weight: bold; color: #ff9800;"><?php echo $alerts_today['medium']; ?></div>
    </div>
    
    <div style="background: #f3e5f5; padding: 20px; border-radius: 5px; border-left: 4px solid #9c27b0;">
        <div style="font-size: 12px; color: #666; margin-bottom: 5px;">Basse priorité</div>
        <div style="font-size: 32px; font-weight: bold; color: #9c27b0;"><?php echo $alerts_today['low']; ?></div>
    </div>
</div>

<h3>Moniteurs</h3>
<table>
    <thead>
        <tr>
            <th>Moniteur</th>
            <th>Statut</th>
            <th>Port</th>
            <th>URL</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Wazuh Manager</td>
            <td>
                <span style="padding: 3px 8px; background: #d4edda; color: #155724; border-radius: 3px;">
                    Actif
                </span>
            </td>
            <td>55000</td>
            <td><a href="http://localhost:55000" target="_blank" style="color: #3498db;">Accéder</a></td>
        </tr>
        <tr>
            <td>Wazuh Dashboard</td>
            <td>
                <span style="padding: 3px 8px; background: #d4edda; color: #155724; border-radius: 3px;">
                    Actif
                </span>
            </td>
            <td>5601</td>
            <td><a href="http://localhost:5601" target="_blank" style="color: #3498db;">Accéder</a></td>
        </tr>
        <tr>
            <td>Elasticsearch</td>
            <td>
                <span style="padding: 3px 8px; background: #d4edda; color: #155724; border-radius: 3px;">
                    Actif
                </span>
            </td>
            <td>9200</td>
            <td><a href="http://localhost:9200" target="_blank" style="color: #3498db;">Accéder</a></td>
        </tr>
    </tbody>
</table>

<h3>Configuration</h3>
<div style="background: #f9f9f9; padding: 20px; border-radius: 5px; margin-top: 20px;">
    <p><strong>Identifiants Wazuh:</strong></p>
    <ul style="color: #666;">
        <li><strong>Utilisateur:</strong> <?php echo htmlspecialchars($wazuh_user); ?></li>
        <li><strong>Dashboard URL:</strong> <?php echo htmlspecialchars($wazuh_url); ?></li>
        <li><strong>API URL:</strong> <?php echo htmlspecialchars($wazuh_api); ?></li>
    </ul>
    
    <p style="margin-top: 15px; padding: 10px; background: #fff3cd; border-radius: 3px; border-left: 4px solid #ffc107;">
        <strong>Note:</strong> Pour modifier les paramétrages de connexion Wazuh, 
        <a href="?action=settings" style="color: #856404; text-decoration: none; font-weight: bold;">allez aux paramétrages</a>.
    </p>
</div>

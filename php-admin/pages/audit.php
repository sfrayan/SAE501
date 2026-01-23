<?php
/**
 * SAE501 - Logs d'audit
 * Affichage et gestion des logs de sécurité
 */

require_login();

$filters = [
    'action' => $_GET['action'] ?? '',
    'date_from' => $_GET['date_from'] ?? date('Y-m-d', strtotime('-30 days')),
    'date_to' => $_GET['date_to'] ?? date('Y-m-d'),
    'status' => $_GET['status'] ?? '',
];

try {
    $db = db_connect();
    
    // Construction de la requête avec filtres
    $query = "SELECT * FROM admin_audit WHERE 1=1";
    $params = [];
    
    if (!empty($filters['action'])) {
        $query .= " AND action LIKE ?";
        $params[] = '%' . $filters['action'] . '%';
    }
    
    if (!empty($filters['date_from'])) {
        $query .= " AND DATE(timestamp) >= ?";
        $params[] = $filters['date_from'];
    }
    
    if (!empty($filters['date_to'])) {
        $query .= " AND DATE(timestamp) <= ?";
        $params[] = $filters['date_to'];
    }
    
    if (!empty($filters['status'])) {
        $query .= " AND status = ?";
        $params[] = $filters['status'];
    }
    
    $query .= " ORDER BY timestamp DESC LIMIT 500";
    
    $stmt = $db->prepare($query);
    $stmt->execute($params);
    $logs = $stmt->fetchAll();
    
} catch (Exception $e) {
    echo '<div class="alert error">Erreur: ' . htmlspecialchars($e->getMessage()) . '</div>';
    $logs = [];
}
?>

<h2>Logs d'audit</h2>

<div style="background: #f9f9f9; padding: 15px; border-radius: 5px; margin-bottom: 20px;">
    <form method="GET" style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px;">
        <input type="hidden" name="action" value="audit">
        
        <div>
            <label>Action:</label>
            <input type="text" name="action" value="<?php echo htmlspecialchars($filters['action']); ?>" placeholder="Toutes les actions">
        </div>
        
        <div>
            <label>Date depuis:</label>
            <input type="date" name="date_from" value="<?php echo htmlspecialchars($filters['date_from']); ?>">
        </div>
        
        <div>
            <label>Date jusqu'à:</label>
            <input type="date" name="date_to" value="<?php echo htmlspecialchars($filters['date_to']); ?>">
        </div>
        
        <div>
            <label>Statut:</label>
            <select name="status">
                <option value="">Tous les statuts</option>
                <option value="success" <?php echo $filters['status'] === 'success' ? 'selected' : ''; ?>>Succès</option>
                <option value="failure" <?php echo $filters['status'] === 'failure' ? 'selected' : ''; ?>>Erreur</option>
                <option value="info" <?php echo $filters['status'] === 'info' ? 'selected' : ''; ?>>Info</option>
            </select>
        </div>
        
        <div style="grid-column: span 4;">
            <button type="submit" style="padding: 8px 15px; background: #3498db; color: white; border: none; border-radius: 3px; cursor: pointer;">
                Filtrer
            </button>
            <a href="?action=audit" style="padding: 8px 15px; background: #95a5a6; color: white; text-decoration: none; border-radius: 3px; margin-left: 10px;">
                Réinitialiser
            </a>
        </div>
    </form>
</div>

<table>
    <thead>
        <tr>
            <th>Timestamp</th>
            <th>Admin</th>
            <th>Action</th>
            <th>Cible</th>
            <th>Statut</th>
            <th>IP</th>
            <th>Détails</th>
        </tr>
    </thead>
    <tbody>
        <?php if (empty($logs)): ?>
            <tr>
                <td colspan="7" style="text-align: center; padding: 20px; color: #999;">
                    Aucun log trouvé
                </td>
            </tr>
        <?php else: ?>
            <?php foreach ($logs as $log): ?>
                <tr>
                    <td style="font-size: 12px;"><?php echo htmlspecialchars($log['timestamp']); ?></td>
                    <td><?php echo htmlspecialchars($log['admin_user'] ?? 'N/A'); ?></td>
                    <td>
                        <span style="padding: 3px 8px; background: #e3f2fd; color: #1976d2; border-radius: 3px; font-size: 12px;">
                            <?php echo htmlspecialchars($log['action']); ?>
                        </span>
                    </td>
                    <td><?php echo htmlspecialchars($log['target_user'] ?? '-'); ?></td>
                    <td>
                        <?php
                        $status_colors = [
                            'success' => '#d4edda',
                            'failure' => '#f8d7da',
                            'info' => '#d1ecf1',
                        ];
                        $status_text_colors = [
                            'success' => '#155724',
                            'failure' => '#721c24',
                            'info' => '#0c5460',
                        ];
                        $bg = $status_colors[$log['status']] ?? '#f0f0f0';
                        $text = $status_text_colors[$log['status']] ?? '#333';
                        ?>
                        <span style="padding: 3px 8px; background: <?php echo $bg; ?>; color: <?php echo $text; ?>; border-radius: 3px; font-size: 12px;">
                            <?php echo htmlspecialchars($log['status']); ?>
                        </span>
                    </td>
                    <td style="font-family: monospace; font-size: 12px;"><?php echo htmlspecialchars($log['ip_address'] ?? 'N/A'); ?></td>
                    <td style="font-size: 12px;"><?php echo htmlspecialchars(substr($log['details'] ?? '', 0, 50)); ?></td>
                </tr>
            <?php endforeach; ?>
        <?php endif; ?>
    </tbody>
</table>

<div style="margin-top: 20px; text-align: right; font-size: 12px; color: #666;">
    Total: <?php echo count($logs); ?> entrée(s) affichée(s) (max 500)
</div>

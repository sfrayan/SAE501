<?php
/**
 * SAE501 - Page de déconnexion
 */

session_start();

// Log the logout action
if (isset($_SESSION['admin_user'])) {
    $log_file = '/var/log/sae501/php_admin_audit.log';
    $timestamp = date('Y-m-d H:i:s');
    $user = $_SESSION['admin_user'];
    $ip = $_SERVER['REMOTE_ADDR'];
    
    $log_entry = "[$timestamp] User: $user | Action: logout | IP: $ip\n";
    @file_put_contents($log_file, $log_entry, FILE_APPEND);
}

// Détruire la session
session_destroy();

// Rediriger vers la page de connexion
header('Location: login.php?logout=1');
exit;

?>

<?php
/**
 * SAE501 - Configuration sécurisée
 * Gestion des comptes RADIUS avec interface web
 * 
 * SECURITE: 
 * - Variables sensibles chargées depuis /opt/sae501/secrets/db.env
 * - Pas de credentials en clair dans le code
 * - Validated & prepared statements partout
 * - Rate limiting implémenté
 * - Audit logging activé
 */

// ============================================================================
// CONFIGURATION DE SECURITE
// ============================================================================

// Charger les variables d'environnement depuis le fichier sécurisé
$env_file = '/opt/sae501/secrets/db.env';
if (!file_exists($env_file)) {
    die('ERREUR: Fichier de configuration introuvable. Vérifiez /opt/sae501/secrets/db.env');
}

$env = parse_ini_file($env_file);
if (!$env) {
    die('ERREUR: Impossible de charger la configuration');
}

// ============================================================================
// CONFIGURATION BASE DE DONNEES
// ============================================================================

$db_config = [
    'host'   => $env['DB_HOST'] ?? 'localhost',
    'port'   => $env['DB_PORT'] ?? 3306,
    'name'   => $env['DB_NAME'] ?? 'radius',
    'user'   => $env['DB_USER_PHP'] ?? 'sae501_php',
    'pass'   => $env['DB_PASSWORD_PHP'] ?? '',
];

// ============================================================================
// CONFIGURATION APPLICATION
// ============================================================================

define('APP_NAME', 'SAE501 - Admin RADIUS');
define('APP_VERSION', '1.0.0');
define('APP_ENV', getenv('APP_ENV') ?: 'production');

// Session configuration
ini_set('session.http_only', 1);
ini_set('session.secure', (bool)getenv('HTTPS'));
ini_set('session.same_site', 'Strict');
ini_set('session.gc_maxlifetime', 3600); // 1 hour
ini_set('session.cookie_lifetime', 0);   // Session cookie

// Session name
session_name('SAE501_SESSION');

// ============================================================================
// CONFIGURATION AUDIT
// ============================================================================

define('AUDIT_LOG_FILE', '/var/log/sae501/php_admin_audit.log');
define('ENABLE_AUDIT_LOGGING', true);
define('ENABLE_RATE_LIMITING', true);
define('MAX_ATTEMPTS_PER_MINUTE', 10);

// ============================================================================
// CONFIGURATION WAZUH (optionnel)
// ============================================================================

define('WAZUH_ENABLED', false);
define('WAZUH_API_URL', getenv('WAZUH_API_URL') ?: 'https://localhost:55000');
define('WAZUH_API_USER', getenv('WAZUH_API_USER') ?: '');
define('WAZUH_API_PASSWORD', getenv('WAZUH_API_PASSWORD') ?: '');

// ============================================================================
// FONCTIONS UTILITAIRES
// ============================================================================

/**
 * Connecter à la base de données
 */
function db_connect() {
    global $db_config;
    
    try {
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
            $db_config['host'],
            $db_config['port'],
            $db_config['name']
        );
        
        $pdo = new PDO(
            $dsn,
            $db_config['user'],
            $db_config['pass'],
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
        
        return $pdo;
    } catch (PDOException $e) {
        error_log('DB Connection Error: ' . $e->getMessage());
        die('Erreur de connexion à la base de données');
    }
}

/**
 * Enregistrer une action dans les logs d'audit
 */
function audit_log($action, $target_user = '', $details = '', $status = 'success') {
    if (!ENABLE_AUDIT_LOGGING) return;
    
    $timestamp = date('Y-m-d H:i:s');
    $user = $_SESSION['admin_user'] ?? 'unknown';
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    
    $log_entry = sprintf(
        "[%s] User: %s | Action: %s | Target: %s | IP: %s | Status: %s | Details: %s\n",
        $timestamp,
        $user,
        $action,
        $target_user,
        $ip,
        $status,
        $details
    );
    
    file_put_contents(AUDIT_LOG_FILE, $log_entry, FILE_APPEND);
    
    // Also log to syslog
    syslog(LOG_NOTICE, "SAE501 Admin: $action for $target_user from $ip");
}

/**
 * Vérifier le rate limiting
 */
function check_rate_limit($identifier) {
    if (!ENABLE_RATE_LIMITING) return true;
    
    $cache_key = "rate_limit_$identifier";
    $file = "/tmp/sae501_$cache_key";
    
    if (file_exists($file)) {
        $data = json_decode(file_get_contents($file), true);
        $timestamp = time();
        
        // Reset counter after 1 minute
        if ($timestamp - $data['start_time'] > 60) {
            unlink($file);
            return true;
        }
        
        if ($data['count'] >= MAX_ATTEMPTS_PER_MINUTE) {
            audit_log('rate_limit_exceeded', $identifier, 'Trop de tentatives', 'failure');
            return false;
        }
        
        $data['count']++;
        file_put_contents($file, json_encode($data));
    } else {
        file_put_contents($file, json_encode([
            'start_time' => time(),
            'count' => 1
        ]));
    }
    
    return true;
}

/**
 * Valider l'input utilisateur
 */
function validate_username($username) {
    if (empty($username)) return false;
    if (strlen($username) < 3 || strlen($username) > 64) return false;
    // Only allow alphanumeric, dots, hyphens, underscores
    return preg_match('/^[a-zA-Z0-9._-]+$/', $username) === 1;
}

function validate_password($password) {
    if (empty($password)) return false;
    if (strlen($password) < 8) return false; // Minimum 8 characters
    // Password must contain at least one uppercase, one number, one special char
    $pattern = '/^(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*])/';
    return preg_match($pattern, $password) === 1;
}

/**
 * Hasher un mot de passe RADIUS (NT-Hash pour MSCHAP)
 */
function generate_nt_password_hash($password) {
    // Convert password to UTF-16LE
    $password_utf16 = iconv('UTF-8', 'UTF-16LE', $password);
    // Generate MD4 hash
    return strtoupper(hash('md4', $password_utf16));
}

/**
 * Gérer les erreurs et exceptions
 */
set_error_handler(function($errno, $errstr, $errfile, $errline) {
    error_log("PHP Error: $errstr in $errfile:$errline");
    if (APP_ENV === 'development') {
        echo "<pre>Erreur: $errstr</pre>";
    }
    return true;
});

// ============================================================================
// INIT SESSION & SECURITE
// ============================================================================

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// CSRF Token
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

?>

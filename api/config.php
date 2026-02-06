<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

// Short-circuit CORS preflight requests
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Enable PHP error logging to a local file to diagnose 500s on server
ini_set('display_errors', '0');
ini_set('log_errors', '1');
ini_set('error_log', __DIR__ . '/api_error.log');

// Determine application environment (prod/local) via env var or heuristics
function getAppEnv(): string {
    // Explicit override via env var
    $env = getenv('APP_ENV');
    if (!$env && isset($_ENV['APP_ENV'])) $env = $_ENV['APP_ENV'];
    if ($env) return strtolower($env);

    // Heuristics based on host
    $host = $_SERVER['HTTP_HOST'] ?? '';
    if ($host) {
        if (stripos($host, 'yourbizapps.com') !== false) return 'prod';
        if (stripos($host, 'planetapplis.fr') !== false) return 'prod';
        if (stripos($host, 'localhost') !== false) return 'local';
    }
    // Fallback to local in unknown cases to avoid hard failures during dev
    return 'local';
}

$__env = getAppEnv();
if ($__env === 'prod') {
    // Remote server credentials
    $host = getenv('DB_HOST_PROD') ?: "db5014964228.hosting-data.io";
    $db   = getenv('DB_NAME_PROD') ?: "dbs12436960";
    $user = getenv('DB_USER_PROD') ?: "dbu1316150";
    $pass = getenv('DB_PASS_PROD') ?: "Paris2024#";
} elseif ($__env === 'local') {
    // Local WAMP defaults
    $host = getenv('DB_HOST_LOCAL') ?: "localhost";
    $db   = getenv('DB_NAME_LOCAL') ?: "dbs12436960";   // adapte le nom
    $user = getenv('DB_USER_LOCAL') ?: "root";
    $pass = getenv('DB_PASS_LOCAL') ?: "";            // adapte selon ton serveur
} else {
    // Fallback (shouldn't happen as getAppEnv defaults to local)
    $host = getenv('DB_HOST') ?: "localhost";
    $db   = getenv('DB_NAME') ?: "dbs12436960";
    $user = getenv('DB_USER') ?: "root";
    $pass = getenv('DB_PASS') ?: "";
}

try {
    $pdo = new PDO(
        "mysql:host=$host;dbname=$db;charset=utf8mb4",
        $user,
        $pass,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "error" => "Connexion MySQL échouée",
        "details" => $e->getMessage()
    ]);
    exit;
}
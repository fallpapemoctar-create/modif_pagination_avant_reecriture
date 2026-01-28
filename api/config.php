<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

// Enable PHP error logging to a local file to diagnose 500s on server
ini_set('display_errors', '0');
ini_set('log_errors', '1');
ini_set('error_log', __DIR__ . '/api_error.log');

// Determine application environment (prod/local) via env var or heuristics
function getAppEnv(): string {
    $env = getenv('APP_ENV');
    if (!$env && isset($_ENV['APP_ENV'])) $env = $_ENV['APP_ENV'];
    if ($env) return strtolower($env);

    $host = $_SERVER['HTTP_HOST'] ?? '';
    if ($host && stripos($host, 'yourbizapps.com') !== false) return 'prod';
    if (PHP_OS_FAMILY === 'Windows' || stripos($host, 'localhost') !== false) return 'local';
    return 'unknown';
}

$__env = getAppEnv();
if ($__env === 'prod') {
    // Remote server credentials
    $host = "db5014964228.hosting-data.io";
    $db   = "dbs12436960";
    $user = "dbu1316150";
    $pass = "Paris2024#";
} elseif ($__env === 'local') {
    // Local WAMP defaults
    $host = "localhost";
    $db   = "dbs12436960";   // adapte le nom
    $user = "root";
    $pass = "";            // adapte selon ton serveur
} else {
    http_response_code(500);
    echo json_encode(["error" => "Environnement inconnu", "details" => $__env]);
    exit;
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
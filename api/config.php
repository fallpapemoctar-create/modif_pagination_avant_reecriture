<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

/* 
$host = "db5014964228.hosting-data.io";
$db   = "dbs12436960";
$user = "dbu1316150";
$pass = "Paris2024#";
*/

$host = "localhost";
$db   = "dbs12436960";   // adapte le nom
$user = "root";
$pass = "";            // adapte selon ton serveur

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
    echo json_encode(["error" => "Connexion MySQL échouée"]);
    exit;
}
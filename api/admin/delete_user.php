<?php
require_once __DIR__ . "/../config.php";

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "Aucune donnée reçue"]);
    exit;
}

$id = intval($data['id'] ?? 0);
if ($id <= 0) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "Invalid user id"]);
    exit;
}

try {
    // Remove rights
    $del = $pdo->prepare("DELETE FROM tble_user_rights WHERE user_id = ?");
    $del->execute([$id]);

    // Delete user
    $stmt = $pdo->prepare("DELETE FROM llx_user WHERE rowid = ?");
    $stmt->execute([$id]);

    echo json_encode(["success" => true]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "error" => $e->getMessage()]);
}


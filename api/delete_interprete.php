<?php
require_once "config.php";

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: DELETE, POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$data = json_decode(file_get_contents("php://input"), true);

$id = (int) ($data['id'] ?? $data['rowid'] ?? $data['id_tble_annuaire_interpretes'] ?? 0);

if ($id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'ID manquant ou invalide']);
    exit;
}

try {
    $pdo->beginTransaction();

    $delRights = $pdo->prepare("DELETE FROM tble_user_rights WHERE user_id = :id");
    $delRights->execute([':id' => $id]);

    $delUser = $pdo->prepare("DELETE FROM llx_user WHERE rowid = :id");
    $delUser->execute([':id' => $id]);

    if ($delUser->rowCount() === 0) {
        $pdo->rollBack();
        http_response_code(404);
        echo json_encode(['success' => false, 'error' => "Interprète introuvable"]);
        exit;
    }

    $pdo->commit();

    echo json_encode(['success' => true, 'message' => 'Interprète supprimé']);

} catch (Exception $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
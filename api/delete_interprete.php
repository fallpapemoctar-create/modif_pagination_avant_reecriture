<?php
require_once "config.php";

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

$data = json_decode(file_get_contents("php://input"), true);

if (!$data || !isset($data["id"])) {
    echo json_encode(["error" => "ID manquant"]);
    exit;
}

try {
    $stmt = $pdo->prepare("
        DELETE FROM tble_annuaire_interpretes
        WHERE id_tble_annuaire_interpretes = :id
    ");

    $stmt->execute([":id" => $data["id"]]);

    echo json_encode(["message" => "Interprète supprimé"]);

} catch (Exception $e) {
    echo json_encode(["error" => $e->getMessage()]);
}
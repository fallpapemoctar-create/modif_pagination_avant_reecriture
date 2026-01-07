<?php
header("Content-Type: application/json");
require_once "../config.php";

$data = json_decode(file_get_contents("php://input"), true);

$sql = "DELETE FROM missions WHERE id = :id";
$stmt = $pdo->prepare($sql);
$ok = $stmt->execute([":id" => $data["id"]]);

echo json_encode(["success" => $ok]);
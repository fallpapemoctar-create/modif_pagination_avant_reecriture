<?php
header("Content-Type: application/json");
require_once "../config.php";

$data = json_decode(file_get_contents("php://input"), true);

$sql = "UPDATE missions SET
            titre = :titre,
            client = :client,
            date = :date,
            ville = :ville,
            description = :description
        WHERE id = :id";

$stmt = $pdo->prepare($sql);
$ok = $stmt->execute([
    ":id" => $data["id"],
    ":titre" => $data["titre"],
    ":client" => $data["client"],
    ":date" => $data["date"],
    ":ville" => $data["ville"],
    ":description" => $data["description"],
]);

echo json_encode(["success" => $ok]);
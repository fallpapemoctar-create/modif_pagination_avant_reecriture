<?php
header("Content-Type: application/json");
require_once "../config.php";

$data = json_decode(file_get_contents("php://input"), true);

$sql = "INSERT INTO missions (titre, client, date, ville, description)
        VALUES (:titre, :client, :date, :ville, :description)";

$stmt = $pdo->prepare($sql);
$ok = $stmt->execute([
    ":titre" => $data["titre"],
    ":client" => $data["client"],
    ":date" => $data["date"],
    ":ville" => $data["ville"],
    ":description" => $data["description"],
]);

echo json_encode(["success" => $ok]);
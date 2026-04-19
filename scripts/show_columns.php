<?php
require_once __DIR__ . '/../api/config.php';

try {
    $stmt = $pdo->query("SHOW COLUMNS FROM llx_missionsplanet_mission");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode($columns, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}

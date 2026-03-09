<?php
require_once __DIR__ . '/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Content-Type: application/json; charset=UTF-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    $q = isset($_GET['q']) ? trim($_GET['q']) : '';
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 500;
    if ($limit <= 0 || $limit > 2000) {
        $limit = 500;
    }

    $sql = "SELECT DISTINCT nom AS client_name FROM llx_societe WHERE nom IS NOT NULL AND nom <> ''";
    $params = [];
    if ($q !== '') {
        $sql .= " AND nom LIKE :search";
        $params[':search'] = '%' . $q . '%';
    }
    $sql .= " ORDER BY nom ASC LIMIT :limit";

    $stmt = $pdo->prepare($sql);
    foreach ($params as $k => $v) {
        $stmt->bindValue($k, $v, PDO::PARAM_STR);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();

    $clients = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $clients[] = $row['client_name'];
    }

    echo json_encode([
        'success' => true,
        'count' => count($clients),
        'clients' => $clients,
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server error',
        'details' => $e->getMessage(),
    ]);
}

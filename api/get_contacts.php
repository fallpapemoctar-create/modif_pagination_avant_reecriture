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
    $clientId = isset($_GET['client_id']) ? (int)$_GET['client_id'] : 0;
    if ($clientId <= 0) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => 'client_id requis',
        ]);
        exit;
    }

    $q = isset($_GET['q']) ? trim($_GET['q']) : '';
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 500;
    if ($limit <= 0 || $limit > 2000) {
        $limit = 500;
    }

    $sql = "SELECT rowid AS id, firstname, lastname, email, phone, phone_mobile FROM llx_socpeople WHERE fk_soc = :socid";
    $params = [':socid' => $clientId];
    if ($q !== '') {
        $sql .= " AND (firstname LIKE :search OR lastname LIKE :search)";
        $params[':search'] = '%' . $q . '%';
    }
    $sql .= " ORDER BY lastname ASC, firstname ASC LIMIT :limit";

    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $value) {
        if ($key === ':socid') {
            $stmt->bindValue($key, $value, PDO::PARAM_INT);
        } elseif ($key === ':search') {
            $stmt->bindValue($key, $value, PDO::PARAM_STR);
        }
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();

    $contacts = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $contacts[] = [
            'id' => isset($row['id']) ? (int)$row['id'] : null,
            'firstname' => $row['firstname'] ?? '',
            'lastname' => $row['lastname'] ?? '',
            'email' => $row['email'] ?? '',
            'phone' => $row['phone'] ?? '',
            'phone_mobile' => $row['phone_mobile'] ?? '',
        ];
    }

    echo json_encode([
        'success' => true,
        'count' => count($contacts),
        'contacts' => $contacts,
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server error',
        'details' => $e->getMessage(),
    ]);
}

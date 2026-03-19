<?php
require_once __DIR__ . '/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Content-Type: application/json; charset=UTF-8');

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($method !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'error' => 'Méthode non autorisée',
    ]);
    exit;
}

try {
    $payload = json_decode(file_get_contents('php://input'), true);
    if (!is_array($payload)) {
        $payload = $_POST;
    }

    $ref = trim((string) ($payload['ref'] ?? ''));
    $label = trim((string) ($payload['label'] ?? ''));
    $type = isset($payload['type']) ? (int) $payload['type'] : 1; // 1 = service (langues)
    $price = isset($payload['price']) ? (float) $payload['price'] : null;
    $priceTtc = isset($payload['price_ttc']) ? (float) $payload['price_ttc'] : null;
    $tvaTx = isset($payload['tva_tx']) ? (float) $payload['tva_tx'] : null;
    $entity = isset($payload['entity']) ? (int) $payload['entity'] : 1;

    if ($ref === '' && $label === '') {
        throw new InvalidArgumentException("Le champ 'ref' ou 'label' est requis");
    }

    // Ensure unique ref: fallback to label if ref empty
    if ($ref === '') {
        $ref = preg_replace('/[^A-Za-z0-9_-]/', '-', strtolower($label));
        if ($ref === '') {
            $ref = 'LANG-' . uniqid();
        }
    }

    $checkStmt = $pdo->prepare('SELECT rowid FROM llx_product WHERE ref = :ref LIMIT 1');
    $checkStmt->execute([':ref' => $ref]);
    if ($checkStmt->fetchColumn()) {
        throw new InvalidArgumentException("Une langue avec la référence '$ref' existe déjà");
    }

    $insertSql = 'INSERT INTO llx_product (ref, label, price, price_ttc, tva_tx, type, entity, datec, tms) 
                  VALUES (:ref, :label, :price, :price_ttc, :tva_tx, :type, :entity, NOW(), NOW())';
    $stmt = $pdo->prepare($insertSql);
    $stmt->execute([
        ':ref' => $ref,
        ':label' => $label === '' ? $ref : $label,
        ':price' => $price,
        ':price_ttc' => $priceTtc,
        ':tva_tx' => $tvaTx,
        ':type' => $type,
        ':entity' => $entity,
    ]);

    $newId = (int) $pdo->lastInsertId();

    $resultStmt = $pdo->prepare('SELECT rowid, ref, label, price, price_ttc, tva_tx, type FROM llx_product WHERE rowid = :id');
    $resultStmt->execute([':id' => $newId]);
    $language = $resultStmt->fetch(PDO::FETCH_ASSOC);

    echo json_encode([
        'success' => true,
        'language' => $language,
    ], JSON_UNESCAPED_UNICODE);
} catch (InvalidArgumentException $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Erreur serveur',
        'details' => $e->getMessage(),
    ]);
}

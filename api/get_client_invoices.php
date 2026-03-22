<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/billing_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

function respond(int $status, array $payload): void {
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    $input = [];
}

$page = isset($input['page']) ? max(1, (int) $input['page']) : 1;
$pageSize = isset($input['pageSize']) ? (int) $input['pageSize'] : 50;
$pageSize = max(1, min(200, $pageSize));
$offset = ($page - 1) * $pageSize;

$client = trim((string) ($input['client'] ?? $input['client_name'] ?? ''));
$status = trim((string) ($input['status'] ?? $input['status_code'] ?? ''));
$invoiceNumber = trim((string) ($input['invoice_number'] ?? ''));
$missionRef = trim((string) ($input['mission_ref'] ?? ''));
$search = trim((string) ($input['search'] ?? $input['q'] ?? ''));

try {
    ensureClientBillingTable($pdo);

    $where = ["COALESCE(cb.category, '') IN ('', 'client')"];
    $params = [];

    if ($client !== '') {
        $where[] = 'cb.client_name LIKE :client';
        $params[':client'] = "%$client%";
    }
    if ($status !== '') {
        $where[] = '(cb.status_code = :status_code OR cb.status_label LIKE :status_label)';
        $params[':status_code'] = $status;
        $params[':status_label'] = "%$status%";
    }
    if ($invoiceNumber !== '') {
        $where[] = 'cb.invoice_number LIKE :invoice';
        $params[':invoice'] = "%$invoiceNumber%";
    }
    if ($missionRef !== '') {
        $where[] = 'cb.mission_ref LIKE :mission_ref';
        $params[':mission_ref'] = "%$missionRef%";
    }
    if ($search !== '') {
        $where[] = "(cb.invoice_number LIKE :search OR cb.client_name LIKE :search OR cb.mission_ref LIKE :search OR COALESCE(m.label, '') LIKE :search)";
        $params[':search'] = "%$search%";
    }

    $whereSql = implode(' AND ', $where);

    $countStmt = $pdo->prepare("SELECT COUNT(*) FROM tble_client_billed cb LEFT JOIN llx_missionsplanet_mission m ON m.ref = cb.mission_ref WHERE $whereSql");
    foreach ($params as $key => $value) {
        $countStmt->bindValue($key, $value);
    }
    $countStmt->execute();
    $total = (int) $countStmt->fetchColumn();

    $dataSql = "
        SELECT
            cb.id,
            cb.invoice_number,
            cb.invoice_total_ht,
            cb.amount_ht,
            cb.client_name,
            cb.mission_ref,
            cb.status_code,
            cb.status_label,
            cb.billed_at,
            cb.created_by,
            cb.created_by_name,
            cb.pdf_filename,
            cb.pdf_path,
            m.label AS mission_label
        FROM tble_client_billed cb
        LEFT JOIN llx_missionsplanet_mission m ON m.ref = cb.mission_ref
        WHERE $whereSql
        ORDER BY cb.billed_at DESC, cb.id DESC
        LIMIT :offset, :limit";

    $dataStmt = $pdo->prepare($dataSql);
    foreach ($params as $key => $value) {
        $dataStmt->bindValue($key, $value);
    }
    $dataStmt->bindValue(':offset', (int) $offset, PDO::PARAM_INT);
    $dataStmt->bindValue(':limit', (int) $pageSize, PDO::PARAM_INT);
    $dataStmt->execute();
    $rows = $dataStmt->fetchAll(PDO::FETCH_ASSOC);

    respond(200, [
        'success' => true,
        'page' => $page,
        'pageSize' => $pageSize,
        'total' => $total,
        'invoices' => $rows,
    ]);
} catch (Exception $e) {
    respond(500, ['success' => false, 'error' => $e->getMessage()]);
}

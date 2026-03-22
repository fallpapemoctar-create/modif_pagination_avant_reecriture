<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/billing_helpers.php';
require_once __DIR__ . '/invoice_line_helpers.php';

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
    respond(400, ['success' => false, 'error' => 'Payload JSON invalide.']);
}

$clientName = trim((string) ($input['client_name'] ?? ''));
$draftKeyInput = trim((string) ($input['draft_key'] ?? ''));
$periodMonthValue = $input['period_month'] ?? null;
$periodMonth = $periodMonthValue !== null ? invoiceParsePeriodMonth($periodMonthValue) : null;
$periodMonthKey = $periodMonth ? $periodMonth->format('Y-m-01') : null;

if ($draftKeyInput === '') {
    if ($clientName === '' || $periodMonthKey === null) {
        respond(400, ['success' => false, 'error' => 'draft_key ou (client_name + period_month) sont requis.']);
    }
    $draftKey = invoiceDraftKey($clientName, $periodMonthKey);
} else {
    $draftKey = $draftKeyInput;
}

try {
    ensureClientInvoiceLinesTable($pdo);

    $stmt = $pdo->prepare("SELECT
        mission_ref,
        designation,
        tva_rate,
        unit_price_ht,
        quantity,
        total_ht,
        notes,
        sort_order
    FROM tble_client_invoice_lines
    WHERE draft_key = :draft
    ORDER BY sort_order ASC, id ASC");

    $stmt->execute([':draft' => $draftKey]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $totalHt = 0.0;
    foreach ($rows as $row) {
        $totalHt += (float) ($row['total_ht'] ?? 0);
    }

    respond(200, [
        'success' => true,
        'draft_key' => $draftKey,
        'client_name' => $clientName,
        'period_month' => $periodMonthKey,
        'lines' => $rows,
        'total_ht' => round($totalHt, 2),
    ]);
} catch (Exception $e) {
    respond(500, ['success' => false, 'error' => $e->getMessage()]);
}

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
        respond(400, ['success' => false, 'error' => 'client_name et period_month sont requis pour générer le brouillon.']);
    }
    $draftKey = invoiceDraftKey($clientName, $periodMonthKey);
} else {
    $draftKey = $draftKeyInput;
}

$lines = $input['lines'] ?? [];
if (!is_array($lines) || empty($lines)) {
    respond(400, ['success' => false, 'error' => 'La liste des lignes est vide.']);
}

$userId = isset($input['user_id']) ? (int) $input['user_id'] : null;
$userName = trim((string) ($input['user_name'] ?? ''));

try {
    ensureClientInvoiceLinesTable($pdo);

    $pdo->beginTransaction();

    $deleteStmt = $pdo->prepare('DELETE FROM tble_client_invoice_lines WHERE draft_key = :draft');
    $deleteStmt->execute([':draft' => $draftKey]);

    $insertSql = "INSERT INTO tble_client_invoice_lines (
        draft_key,
        client_name,
        period_month,
        mission_ref,
        designation,
        tva_rate,
        unit_price_ht,
        quantity,
        total_ht,
        notes,
        sort_order,
        created_by,
        created_by_name
    ) VALUES (
        :draft_key,
        :client_name,
        :period_month,
        :mission_ref,
        :designation,
        :tva_rate,
        :unit_price_ht,
        :quantity,
        :total_ht,
        :notes,
        :sort_order,
        :created_by,
        :created_by_name
    )";

    $insertStmt = $pdo->prepare($insertSql);

    foreach ($lines as $idx => $line) {
        if (!is_array($line)) {
            continue;
        }
        $designation = trim((string) ($line['designation'] ?? ''));
        if ($designation === '') {
            $designation = 'Ligne de facture';
        }
        $missionRef = trim((string) ($line['mission_ref'] ?? ''));
        $tvaRate = invoiceNormalizeDecimal($line['tva_rate'] ?? 0);
        $unitPrice = invoiceNormalizeDecimal($line['unit_price_ht'] ?? $line['unit_price'] ?? 0);
        $quantity = invoiceNormalizeDecimal($line['quantity'] ?? 1, 1.0);
        $total = invoiceNormalizeDecimal($line['total_ht'] ?? ($unitPrice * $quantity));
        if ($total <= 0 && $unitPrice > 0 && $quantity > 0) {
            $total = $unitPrice * $quantity;
        }
        if ($unitPrice <= 0 && $quantity > 0 && $total > 0) {
            $unitPrice = $total / $quantity;
        }
        if ($quantity <= 0) {
            $quantity = 1.0;
        }

        $insertStmt->execute([
            ':draft_key' => $draftKey,
            ':client_name' => $clientName !== '' ? $clientName : null,
            ':period_month' => $periodMonthKey,
            ':mission_ref' => $missionRef === '' ? null : $missionRef,
            ':designation' => $designation,
            ':tva_rate' => $tvaRate,
            ':unit_price_ht' => $unitPrice,
            ':quantity' => $quantity,
            ':total_ht' => $total,
            ':notes' => trim((string) ($line['notes'] ?? '')) ?: null,
            ':sort_order' => (int) $idx,
            ':created_by' => $userId,
            ':created_by_name' => $userName !== '' ? $userName : null,
        ]);
    }

    $pdo->commit();

    respond(200, [
        'success' => true,
        'draft_key' => $draftKey,
        'lines' => count($lines),
    ]);
} catch (Exception $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    respond(500, ['success' => false, 'error' => $e->getMessage()]);
}

<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
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

$year = isset($_GET['year']) ? intval($_GET['year']) : null;
$month = isset($_GET['month']) ? intval($_GET['month']) : null;
if ($year === null || $year < 2000 || $year > 9999) {
    $year = intval(date('Y'));
}
if ($month === null || $month < 1 || $month > 12) {
    $month = intval(date('n'));
}

try {
    ensureClientBillingTable($pdo);

    $prefix = sprintf('FAC-%04d%02d-', $year, $month);
    $stmt = $pdo->prepare("SELECT invoice_number FROM tble_client_billed WHERE invoice_number LIKE :prefix ORDER BY invoice_number DESC LIMIT 1");
    $stmt->execute([':prefix' => $prefix . '%']);
    $lastNumber = 0;
    if ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $existing = $row['invoice_number'] ?? '';
        if (is_string($existing) && $existing !== '') {
            $parts = explode('-', $existing);
            $lastPart = end($parts);
            if ($lastPart !== false) {
                $lastNumber = intval($lastPart);
            }
        }
    }
    $nextNumber = $lastNumber + 1;
    $nextSuffix = str_pad((string) $nextNumber, 3, '0', STR_PAD_LEFT);
    $invoiceNumber = $prefix . $nextSuffix;

    respond(200, [
        'success' => true,
        'invoice_number' => $invoiceNumber,
        'sequence' => $nextNumber,
    ]);
} catch (Exception $e) {
    respond(500, ['success' => false, 'error' => $e->getMessage()]);
}

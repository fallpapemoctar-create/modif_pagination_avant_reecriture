<?php
require_once __DIR__ . '/../api/config.php';

$stmt = $pdo->query("SELECT invoice_number, total_ht, amount_ht FROM tble_client_billed WHERE invoice_number='FAC-202605-037'");
$row = $stmt->fetch(PDO::FETCH_ASSOC);
echo 'HEADER: ' . json_encode($row) . PHP_EOL;

$stmt2 = $pdo->query("SELECT id, mission_ref, unit_price_ht, quantity, discount, total_ht FROM tble_client_invoice_lines WHERE invoice_number='FAC-202605-037' ORDER BY sort_order, id");
$lines = $stmt2->fetchAll(PDO::FETCH_ASSOC);
foreach ($lines as $l) {
    $raw = round((float)$l['unit_price_ht'] * (float)$l['quantity'], 2);
    echo 'LINE: unit=' . $l['unit_price_ht'] . ' qty=' . $l['quantity'] . ' discount=' . $l['discount'] . ' stored_total=' . $l['total_ht'] . ' raw=' . $raw . PHP_EOL;
}
$sum = array_sum(array_column($lines, 'total_ht'));
echo 'SUM_LINES_total_ht: ' . $sum . PHP_EOL;

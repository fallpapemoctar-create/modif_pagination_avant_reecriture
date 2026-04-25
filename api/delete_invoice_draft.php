<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . '/config.php';

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

$draftId = isset($input['draft_id']) ? (int) $input['draft_id'] : 0;

if ($draftId <= 0) {
    respond(400, ['success' => false, 'error' => 'draft_id est requis.']);
}

try {
    // Vérifier que la table existe
    $tableCheck = $pdo->query("SHOW TABLES LIKE 'invoice_draft'");
    if (!$tableCheck || $tableCheck->rowCount() === 0) {
        respond(404, ['success' => false, 'error' => 'Draft introuvable.']);
    }

    // Lire le draft pour vérifier le statut (RM-05 : draft finalisé est verrouillé, RM-06 : supprimable si non finalisé)
    $checkStmt = $pdo->prepare("SELECT id, status FROM invoice_draft WHERE id = :id");
    $checkStmt->execute([':id' => $draftId]);
    $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);

    if (!$existing) {
        respond(404, ['success' => false, 'error' => "Draft introuvable (id=$draftId)."]);
    }
    if ($existing['status'] === 'finalized') {
        respond(409, ['success' => false, 'error' => 'Un draft finalisé ne peut pas être supprimé.']);
    }

    // Suppression — les lignes invoice_draft_lines sont supprimées en CASCADE
    $deleteStmt = $pdo->prepare("DELETE FROM invoice_draft WHERE id = :id AND status = 'draft'");
    $deleteStmt->execute([':id' => $draftId]);

    if ($deleteStmt->rowCount() === 0) {
        respond(409, ['success' => false, 'error' => 'Suppression impossible (draft déjà finalisé ou inexistant).']);
    }

    respond(200, ['success' => true, 'draft_id' => $draftId, 'deleted' => true]);

} catch (Exception $e) {
    respond(500, ['success' => false, 'error' => $e->getMessage()]);
}

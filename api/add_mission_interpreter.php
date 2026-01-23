<?php
header("Content-Type: application/json");
require_once "config.php";

try {
    $data = json_decode(file_get_contents("php://input"), true);
    if (!is_array($data)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Invalid JSON payload"]);
        exit;
    }

    $interpreterId = isset($data['interpreter_id']) ? (int)$data['interpreter_id'] : 0;
    $ref = isset($data['reference_devis']) ? trim($data['reference_devis']) : '';
    $produitRef = isset($data['id_produit_service']) ? (int)$data['id_produit_service'] : null;
    if (!$produitRef && isset($data['produit_ref'])) {
        // If a textual product ref is provided, try to resolve to llx_product.rowid
        $stmtProd = $pdo->prepare("SELECT rowid FROM llx_product WHERE ref = :ref LIMIT 1");
        $stmtProd->execute([':ref' => trim($data['produit_ref'])]);
        $row = $stmtProd->fetch();
        if ($row && isset($row['rowid'])) $produitRef = (int)$row['rowid'];
    }

    $debut = isset($data['debutmission']) ? trim($data['debutmission']) : null; // yyyy-mm-dd
    $fin = isset($data['finmission']) ? trim($data['finmission']) : null;       // yyyy-mm-dd
    $tarifHoraire = isset($data['tarif_horaire']) ? (float)$data['tarif_horaire'] : 0.0;
    $paid = isset($data['status_payment']) ? (int)$data['status_payment'] : 0;

    if ($interpreterId <= 0) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "interpreter_id requis"]);
        exit;
    }

    // Compute montant if possible
    $montant = 0.0;
    if ($debut && $fin && $tarifHoraire > 0) {
        $debutTs = strtotime($debut);
        $finTs = strtotime($fin);
        if ($debutTs && $finTs && $finTs > $debutTs) {
            $hours = ($finTs - $debutTs) / 3600.0;
            $montant = $tarifHoraire * $hours;
        }
    }

    $sql = "INSERT INTO llx_missionsplanet_mission (
                nominterprete, ref, debutmission, finmission, montant_mission, status_payment, langue, status
            ) VALUES (
                :nominterprete, :ref, :debutmission, :finmission, :montant_mission, :status_payment, :langue, 1
            )";
    $stmt = $pdo->prepare($sql);
    $ok = $stmt->execute([
        ':nominterprete'   => $interpreterId,
        ':ref'             => $ref,
        ':debutmission'    => $debut,
        ':finmission'      => $fin,
        ':montant_mission' => $montant,
        ':status_payment'  => $paid,
        ':langue'          => $produitRef,
    ]);

    echo json_encode(["success" => $ok]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>

<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Content-Type: application/json");
require_once "config.php";

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    $data = json_decode(file_get_contents("php://input"), true);
    if (!is_array($data)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Invalid JSON payload"]);
        exit;
    }

    $id = isset($data['id']) ? (int)$data['id'] : 0;
    if ($id <= 0) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "id requis"]);
        exit;
    }

    $fields = [];
    $params = [':id' => $id];

    if (isset($data['interpreter_id'])) { $fields[] = 'nominterprete = :nominterprete'; $params[':nominterprete'] = (int)$data['interpreter_id']; }
    if (isset($data['reference_devis'])) { $fields[] = 'ref = :ref'; $params[':ref'] = trim($data['reference_devis']); }
    if (isset($data['debutmission'])) { $fields[] = 'debutmission = :debutmission'; $params[':debutmission'] = trim($data['debutmission']); }
    if (isset($data['finmission'])) { $fields[] = 'finmission = :finmission'; $params[':finmission'] = trim($data['finmission']); }
    if (isset($data['status_payment'])) { $fields[] = 'status_payment = :status_payment'; $params[':status_payment'] = (int)$data['status_payment']; }

    // Raw mission fields
    if (isset($data['datemission'])) { $fields[] = 'datemission = :datemission'; $params[':datemission'] = trim($data['datemission']); }
    if (isset($data['heuredebutmission'])) { $fields[] = 'heuredebutmission = :heuredebutmission'; $params[':heuredebutmission'] = trim($data['heuredebutmission']); }
    if (isset($data['dureemission'])) { $fields[] = 'dureemission = :dureemission'; $params[':dureemission'] = (int)$data['dureemission']; }
    if (isset($data['mission_status'])) { $fields[] = 'status = :status'; $params[':status'] = (int)$data['mission_status']; }

    // langue/product
    if (isset($data['id_produit_service'])) { $fields[] = 'langue = :langue'; $params[':langue'] = (int)$data['id_produit_service']; }
    else if (isset($data['produit_ref'])) {
        $stmtProd = $pdo->prepare("SELECT rowid FROM llx_product WHERE ref = :ref LIMIT 1");
        $stmtProd->execute([':ref' => trim($data['produit_ref'])]);
        $row = $stmtProd->fetch();
        if ($row && isset($row['rowid'])) { $fields[] = 'langue = :langue'; $params[':langue'] = (int)$row['rowid']; }
    }

    // montant_mission recompute if tarif provided and dates available
    $tarifHoraire = isset($data['tarif_horaire']) ? (float)$data['tarif_horaire'] : null;
    if ($tarifHoraire !== null) {
        // We need debut and fin; if not provided in payload, fetch current values
        $stmtCurrent = $pdo->prepare("SELECT debutmission, finmission FROM llx_missionsplanet_mission WHERE rowid = :id");
        $stmtCurrent->execute([':id' => $id]);
        $cur = $stmtCurrent->fetch();
        $debut = isset($params[':debutmission']) ? $params[':debutmission'] : ($cur['debutmission'] ?? null);
        $fin = isset($params[':finmission']) ? $params[':finmission'] : ($cur['finmission'] ?? null);
        $montant = 0.0;
        if ($debut && $fin) {
            $dt1 = strtotime($debut); $dt2 = strtotime($fin);
            if ($dt1 && $dt2 && $dt2 > $dt1) {
                $hours = ($dt2 - $dt1) / 3600.0;
                $montant = $tarifHoraire * $hours;
            }
        }
        $fields[] = 'montant_mission = :montant_mission';
        $params[':montant_mission'] = $montant;
    }

    if (empty($fields)) {
        echo json_encode(["success" => false, "message" => "Aucun champ à mettre à jour"]);
        exit;
    }

    $sql = "UPDATE llx_missionsplanet_mission SET " . implode(', ', $fields) . " WHERE rowid = :id";
    $stmt = $pdo->prepare($sql);
    $ok = $stmt->execute($params);

    echo json_encode(["success" => $ok]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>

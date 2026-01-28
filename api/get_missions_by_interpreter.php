<?php
header("Content-Type: application/json");
require_once "config.php";

// Récupérer les données JSON envoyées
$input = json_decode(file_get_contents('php://input'), true);
$interpreter_id = $input['interpreter_id'] ?? null;

try {
    if ($interpreter_id) {
        // Return missions for the specified interpreter (existing behavior)
        $sql = "SELECT
            m.rowid,
            m.ref as reference_devis,
            m.nominterprete,
            m.debutmission,
            m.finmission,
            m.montant_mission,
            m.status_payment,
            m.date_payment,
            u.firstname,
            u.lastname,
            p.ref as produit_ref,
            p.rowid as id_produit_service,
            s.prix_achat_ht,
            s.prix_vente_ht
        FROM llx_missionsplanet_mission m
        INNER JOIN llx_user u ON m.nominterprete = u.rowid
        LEFT JOIN llx_product p ON m.langue = p.rowid
        LEFT JOIN tble_ref_services s ON p.rowid = s.id_libelle_service
        WHERE m.nominterprete = :interpreter_id
        AND m.status <> 9
        ORDER BY m.debutmission DESC";

        $stmt = $pdo->prepare($sql);
        $stmt->execute(['interpreter_id' => $interpreter_id]);
        $missions = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode(['total' => count($missions), 'data' => $missions]);
        exit;
    }

    // When no interpreter_id provided, return interpreters who have at least one mission
    // (this lets the client display a list with a 'consulter' button for each interpreter)
    $sqlInterpreters = "SELECT
        u.rowid as id,
        u.firstname,
        u.lastname,
        COUNT(m.rowid) as missions_count
    FROM llx_user u
    INNER JOIN llx_missionsplanet_mission m ON m.nominterprete = u.rowid
    WHERE m.status <> 9
    GROUP BY u.rowid, u.firstname, u.lastname
    HAVING COUNT(m.rowid) >= 1
    ORDER BY u.lastname ASC, u.firstname ASC";

    $stmt = $pdo->prepare($sqlInterpreters);
    $stmt->execute();
    $interpreters = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Map to UI-friendly structure
    $result = array_map(function($r) {
        $display = trim((($r['lastname'] ?? '') . ' ' . ($r['firstname'] ?? '')));
        return [
            'id' => $r['id'],
            'display_name' => mb_strtoupper($display, 'UTF-8'),
            'firstname' => $r['firstname'] ?? '',
            'lastname' => $r['lastname'] ?? '',
            'missions_count' => (int)$r['missions_count'],
            // client will call this same endpoint with interpreter_id to get missions
            'can_consulter' => true,
        ];
    }, $interpreters);

    echo json_encode($result, JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "error" => "Erreur serveur",
        "details" => $e->getMessage()
    ]);
}
?>
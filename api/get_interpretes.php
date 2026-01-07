<?php
require_once "config.php";

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

try {
    // Requête SQL
    $sql = "
        SELECT 
            id_tble_annuaire_interpretes,
            Numero,
            Nom,
            Prenom,
            Email,
            Tel_Mobile,
            Tel_domicile,
            Langues_parlees,
            Adresse,
            Code_postal,
            Ville,
            Pays,
            Commentaires
        FROM tble_annuaire_interpretes
        ORDER BY Nom ASC, Prenom ASC
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute();

    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Map rows to a UI-friendly structure for card display
    $interpretes = array_map(function($r) {
        $nom = trim(($r['Nom'] ?? '') . ' ' . ($r['Prenom'] ?? ''));

        // Determine status from DB if available. Support common column names.
        $status = null;
        $possibleStatusCols = ['status', 'statut', 'Disponible', 'disponible', 'available', 'etat', 'etat_disponible'];
        foreach ($possibleStatusCols as $col) {
            if (array_key_exists($col, $r) && $r[$col] !== null && $r[$col] !== '') {
                $status = $r[$col];
                break;
            }
        }

        // Normalize boolean/numeric values
        if ($status !== null) {
            if (is_numeric($status)) {
                $status = intval($status) === 1 ? 'Disponible' : 'Indisponible';
            } else {
                // keep DB-provided string (trimmed)
                $status = trim((string)$status);
            }
        } else {
            // fallback
            $status = 'Disponible';
        }

        return [
            'id' => $r['id_tble_annuaire_interpretes'] ?? null,
            'numero' => $r['Numero'] ?? null,
            'display_name' => mb_strtoupper($nom, 'UTF-8'),
            'firstname' => $r['Prenom'] ?? null,
            'lastname' => $r['Nom'] ?? null,
            'email' => $r['Email'] ?? null,
            'tel_mobile' => $r['Tel_Mobile'] ?? null,
            'tel_domicile' => $r['Tel_domicile'] ?? null,
            'langues_parlees' => $r['Langues_parlees'] ?? null,
            'adresse' => $r['Adresse'] ?? null,
            'code_postal' => $r['Code_postal'] ?? null,
            'ville' => $r['Ville'] ?? null,
            'pays' => $r['Pays'] ?? null,
            'commentaires' => $r['Commentaires'] ?? null,
            'status' => $status,
        ];
    }, $rows);

    echo json_encode($interpretes, JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "error" => "Erreur serveur",
        "details" => $e->getMessage()
    ]);
}
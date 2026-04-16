<?php
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/interprete_helpers.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Content-Type: application/json; charset=UTF-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    $clientId = isset($_GET['client_id']) ? (int)$_GET['client_id'] : 0;
    $activeOnly = isset($_GET['active_only']) && $_GET['active_only'] === '1';
    if ($clientId <= 0) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => 'client_id requis',
        ]);
        exit;
    }

    $q = isset($_GET['q']) ? trim($_GET['q']) : '';
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 500;
    if ($limit <= 0 || $limit > 2000) {
        $limit = 500;
    }

        $sql = "SELECT p.rowid AS id, p.fk_soc, p.civility, p.firstname, p.lastname, p.email, p.phone, p.phone_perso, p.phone_mobile,
                   fax, birthday, poste, address, zip, town, note_private, note_public,
                 p.fk_pays, p.fk_departement,
                 c.label AS country_label, d.nom AS department_label,
                 COALESCE(p.statut, 1) AS statut
             FROM llx_socpeople p
             LEFT JOIN llx_c_country c ON c.rowid = p.fk_pays
             LEFT JOIN llx_c_departements d ON d.rowid = p.fk_departement
             WHERE p.fk_soc = :socid";
    $params = [':socid' => $clientId];
    if ($activeOnly) {
        $sql .= " AND COALESCE(statut, 1) <> 0";
    }
    if ($q !== '') {
        $sql .= " AND (firstname LIKE :search OR lastname LIKE :search OR email LIKE :search OR phone LIKE :search OR phone_perso LIKE :search OR phone_mobile LIKE :search OR fax LIKE :search OR poste LIKE :search)";
        $params[':search'] = '%' . $q . '%';
    }
    $sql .= " ORDER BY lastname ASC, firstname ASC LIMIT :limit";

    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $value) {
        if ($key === ':socid') {
            $stmt->bindValue($key, $value, PDO::PARAM_INT);
        } elseif ($key === ':search') {
            $stmt->bindValue($key, $value, PDO::PARAM_STR);
        }
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();

    $contacts = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $contacts[] = [
            'id' => isset($row['id']) ? (int)$row['id'] : null,
            'client_id' => isset($row['fk_soc']) ? (int)$row['fk_soc'] : null,
            'civility' => $row['civility'] ?? '',
            'firstname' => $row['firstname'] ?? '',
            'lastname' => $row['lastname'] ?? '',
            'email' => $row['email'] ?? '',
            'phone' => $row['phone'] ?? '',
            'phone_perso' => $row['phone_perso'] ?? '',
            'phone_mobile' => $row['phone_mobile'] ?? '',
            'fax' => $row['fax'] ?? '',
            'birthday' => $row['birthday'] ?? '',
            'position' => $row['poste'] ?? '',
            'address' => $row['address'] ?? '',
            'zip' => $row['zip'] ?? '',
            'town' => $row['town'] ?? '',
            'note_private' => $row['note_private'] ?? '',
            'note_public' => $row['note_public'] ?? '',
            'fk_pays' => isset($row['fk_pays']) ? (int)$row['fk_pays'] : 0,
            'country_label' => $row['country_label'] ?? '',
            'fk_departement' => isset($row['fk_departement']) ? (int)$row['fk_departement'] : 0,
            'department_label' => $row['department_label'] ?? '',
            'status' => isset($row['statut']) ? (int)$row['statut'] : 1,
        ];
    }

    echo json_encode([
        'success' => true,
        'count' => count($contacts),
        'contacts' => $contacts,
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server error',
        'details' => $e->getMessage(),
    ]);
}

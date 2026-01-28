<?php
require_once __DIR__ . "/config.php";

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    // Params: page, pageSize, q (search)
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $pageSize = isset($_GET['pageSize']) ? intval($_GET['pageSize']) : 50;
    if ($pageSize <= 0) $pageSize = 50;
    if ($pageSize > 500) $pageSize = 500; // safety cap
    $offset = ($page - 1) * $pageSize;
    $q = isset($_GET['q']) ? trim($_GET['q']) : '';
    $exportAll = isset($_GET['exportAll']) && ($_GET['exportAll'] === '1' || strtolower($_GET['exportAll']) === 'true');

    $where = "m.status <> 9";
    $params = [];
    if ($q !== '') {
        $where .= " AND (m.ref LIKE :q OR u.firstname LIKE :q OR u.lastname LIKE :q OR s.nom LIKE :q OR p.ref LIKE :q)";
        $params[':q'] = "%$q%";
    }

    // Count total
    $countSql = "
        SELECT COUNT(*) AS total
        FROM llx_missionsplanet_mission m
        INNER JOIN llx_user u ON m.nominterprete = u.rowid
        LEFT JOIN llx_product p ON m.langue = p.rowid
        LEFT JOIN llx_societe s ON s.rowid = m.fk_soc
        WHERE $where";
    $countStmt = $pdo->prepare($countSql);
    foreach ($params as $k => $v) $countStmt->bindValue($k, $v);
    $countStmt->execute();
    $total = (int)$countStmt->fetchColumn();

    // Page data
    $sql = "
        SELECT
            m.rowid,
            m.ref AS reference_devis,
            m.nominterprete,
            m.debutmission,
            u.firstname,
            u.lastname,
            p.ref AS produit_ref,
            p.rowid AS id_produit_service,
            s.nom AS client_name
        FROM llx_missionsplanet_mission m
        INNER JOIN llx_user u ON m.nominterprete = u.rowid
        LEFT JOIN llx_product p ON m.langue = p.rowid
        LEFT JOIN llx_societe s ON s.rowid = m.fk_soc
        WHERE $where
        ORDER BY m.debutmission DESC
    ";

    if (!$exportAll) {
        $sql .= " LIMIT :limit OFFSET :offset";
    }

    $stmt = $pdo->prepare($sql);
    foreach ($params as $k => $v) $stmt->bindValue($k, $v);
    if (!$exportAll) {
        $stmt->bindValue(':limit', $pageSize, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    }
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Normalize/format fields
    foreach ($rows as &$r) {
        // Build interpreter full name
        $r['interpreter_name'] = trim(($r['firstname'] ?? '') . ' ' . ($r['lastname'] ?? ''));
        // Format date to ISO if needed
        if (!empty($r['debutmission'])) {
            try {
                $dt = new DateTime($r['debutmission']);
                $r['debutmission_iso'] = $dt->format('Y-m-d H:i:s');
            } catch (Exception $e) {
                $r['debutmission_iso'] = $r['debutmission'];
            }
        } else {
            $r['debutmission_iso'] = null;
        }
    }

    echo json_encode([
        'success' => true,
        'count' => count($rows),
        'total' => $total,
        'page' => $exportAll ? 1 : $page,
        'pageSize' => $exportAll ? $total : $pageSize,
        'missions' => $rows
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Server error', 'details' => $e->getMessage()]);
}

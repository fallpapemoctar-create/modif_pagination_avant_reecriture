<?php
require_once 'c:/wamp64/www/gesplanet_01/ami/api/config.php';

// 1. Liste des interpretes dans llx_user
echo "=== USERS IN llx_user ===\n";
$stmt = $pdo->query('SELECT rowid, lastname, firstname, login FROM llx_user ORDER BY rowid LIMIT 10');
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($rows as $r) {
    echo "rowid={$r['rowid']} | {$r['lastname']} {$r['firstname']} | login={$r['login']}\n";
}

// 2. Tenter de supprimer le premier (dry run - on rollback)
if (!empty($rows)) {
    $id = (int)$rows[0]['rowid'];
    echo "\n=== TEST DELETE rowid=$id (ROLLBACK) ===\n";
    try {
        $pdo->beginTransaction();
        $del = $pdo->prepare("DELETE FROM llx_user WHERE rowid = :id");
        $del->execute([':id' => $id]);
        $count = $del->rowCount();
        echo "rowCount=$count\n";
        $pdo->rollBack();
        echo "Rollback OK\n";
    } catch (Exception $e) {
        $pdo->rollBack();
        echo "ERREUR: " . $e->getMessage() . "\n";
    }
}

// 3. Verifier FK constraints sur llx_user
echo "\n=== FK CONSTRAINTS ON llx_user ===\n";
$fkStmt = $pdo->query("
    SELECT TABLE_NAME, COLUMN_NAME, CONSTRAINT_NAME
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE REFERENCED_TABLE_NAME = 'llx_user'
    AND TABLE_SCHEMA = DATABASE()
    ORDER BY TABLE_NAME
    LIMIT 20
");
$fks = $fkStmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($fks as $fk) {
    echo "Table: {$fk['TABLE_NAME']}.{$fk['COLUMN_NAME']} (constraint: {$fk['CONSTRAINT_NAME']})\n";
}
if (empty($fks)) {
    echo "Aucune FK trouvee\n";
}

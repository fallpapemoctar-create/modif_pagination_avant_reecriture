<?php
require_once __DIR__ . '/../api/config.php';

$check = $pdo->query("SHOW COLUMNS FROM llx_missionsplanet_mission LIKE 'mission_types'");
if ($check && $check->fetch()) {
    echo "MISSION_TYPES_COLUMN_ALREADY_EXISTS\n";
    exit(0);
}

$sql = file_get_contents(__DIR__ . '/sql/add_mission_types_column.sql');
if ($sql === false) {
    fwrite(STDERR, "Unable to read migration file.\n");
    exit(1);
}

try {
    $pdo->exec($sql);
    echo "MISSION_TYPES_COLUMN_OK\n";
} catch (Throwable $error) {
    fwrite(STDERR, $error->getMessage() . "\n");
    exit(1);
}
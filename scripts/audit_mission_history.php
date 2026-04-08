<?php
require_once __DIR__ . '/../api/config.php';

function columnExists(PDO $pdo, string $table, string $column): bool
{
    $statement = $pdo->prepare("SHOW COLUMNS FROM {$table} LIKE :column");
    $statement->execute([':column' => $column]);
    return (bool) $statement->fetch(PDO::FETCH_ASSOC);
}

function isInvalidDateValue($value): bool
{
    if ($value === null) {
        return true;
    }

    $trimmed = trim((string) $value);
    if ($trimmed === '') {
        return true;
    }

    return preg_match('/^0{4}-0{2}-0{2}(?: 0{2}:0{2}:0{2})?$/', $trimmed) === 1;
}

function dumpJson($value): void
{
    echo json_encode($value, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE), PHP_EOL;
}

$columns = [
    'rowid',
    'ref',
    'date_creation',
    'datemission',
    'debutmission',
    'finmission',
    'tms',
    'mission_types',
    'status',
    'fk_user_author',
];

$availableColumns = [];
foreach ($columns as $column) {
    if (columnExists($pdo, 'llx_missionsplanet_mission', $column)) {
        $availableColumns[] = $column;
    }
}

$invalidCreationWhere = "date_creation IS NULL OR TRIM(date_creation) = '' OR date_creation = '0000-00-00' OR date_creation = '0000-00-00 00:00:00'";
$emptyMissionTypesWhere = "mission_types IS NULL OR TRIM(mission_types) = '' OR mission_types = '[]'";

$summary = [
    'available_columns' => $availableColumns,
    'invalid_date_creation' => 0,
    'empty_mission_types' => null,
    'candidate_sources_for_creation_backfill' => [],
];

$summary['invalid_date_creation'] = (int) $pdo
    ->query("SELECT COUNT(*) FROM llx_missionsplanet_mission WHERE {$invalidCreationWhere}")
    ->fetchColumn();

if (columnExists($pdo, 'llx_missionsplanet_mission', 'mission_types')) {
    $summary['empty_mission_types'] = (int) $pdo
        ->query("SELECT COUNT(*) FROM llx_missionsplanet_mission WHERE {$emptyMissionTypesWhere}")
        ->fetchColumn();
}

foreach (['tms', 'debutmission', 'datemission'] as $candidateColumn) {
    if (!columnExists($pdo, 'llx_missionsplanet_mission', $candidateColumn)) {
        continue;
    }

    $count = (int) $pdo
        ->query(
            "SELECT COUNT(*) FROM llx_missionsplanet_mission WHERE {$invalidCreationWhere} AND {$candidateColumn} IS NOT NULL AND TRIM({$candidateColumn}) <> '' AND {$candidateColumn} <> '0000-00-00' AND {$candidateColumn} <> '0000-00-00 00:00:00'"
        )
        ->fetchColumn();

    $summary['candidate_sources_for_creation_backfill'][$candidateColumn] = $count;
}

$sampleColumns = array_values(
    array_filter(
        ['rowid', 'ref', 'date_creation', 'datemission', 'debutmission', 'finmission', 'tms', 'mission_types', 'status'],
        static fn(string $column): bool => in_array($column, $availableColumns, true)
    )
);

$sampleSql = sprintf(
    'SELECT %s FROM llx_missionsplanet_mission WHERE %s ORDER BY rowid DESC LIMIT 15',
    implode(', ', $sampleColumns),
    $invalidCreationWhere
);

$sampleRows = $pdo->query($sampleSql)->fetchAll(PDO::FETCH_ASSOC);

dumpJson([
    'summary' => $summary,
    'sample_rows' => $sampleRows,
]);
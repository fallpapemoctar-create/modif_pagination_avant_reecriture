<?php
require_once __DIR__ . '/../api/config.php';

function columnExists(PDO $pdo, string $table, string $column): bool
{
    $statement = $pdo->prepare("SHOW COLUMNS FROM {$table} LIKE :column");
    $statement->execute([':column' => $column]);
    return (bool) $statement->fetch(PDO::FETCH_ASSOC);
}

function zeroOrEmptySqlDateCondition(string $column): string
{
    return "{$column} IS NULL OR TRIM({$column}) = '' OR {$column} = '0000-00-00' OR {$column} = '0000-00-00 00:00:00'";
}

function buildFallbackExpression(PDO $pdo): string
{
    $fallbacks = [];

    if (columnExists($pdo, 'llx_missionsplanet_mission', 'tms')) {
        $fallbacks[] = "NULLIF(NULLIF(NULLIF(TRIM(CAST(tms AS CHAR)), ''), '0000-00-00'), '0000-00-00 00:00:00')";
    }

    if (columnExists($pdo, 'llx_missionsplanet_mission', 'debutmission')) {
        $fallbacks[] = "NULLIF(NULLIF(NULLIF(TRIM(CAST(debutmission AS CHAR)), ''), '0000-00-00'), '0000-00-00 00:00:00')";
    }

    if (columnExists($pdo, 'llx_missionsplanet_mission', 'datemission')) {
        $fallbacks[] = "CASE
            WHEN datemission IS NULL OR TRIM(CAST(datemission AS CHAR)) = '' OR datemission = '0000-00-00' THEN NULL
            ELSE CONCAT(CAST(datemission AS CHAR), ' 00:00:00')
        END";
    }

    if ($fallbacks === []) {
        throw new RuntimeException('Aucune colonne de secours disponible pour reconstruire date_creation.');
    }

    return 'COALESCE(' . implode(",\n            ", $fallbacks) . ')';
}

$apply = in_array('--apply', $argv, true);
$invalidWhere = zeroOrEmptySqlDateCondition('date_creation');
$fallbackExpression = buildFallbackExpression($pdo);

$previewSql = "SELECT rowid, ref, date_creation, {$fallbackExpression} AS proposed_date_creation
FROM llx_missionsplanet_mission
WHERE {$invalidWhere}
ORDER BY rowid ASC";

$previewRows = $pdo->query($previewSql)->fetchAll(PDO::FETCH_ASSOC);
$fillableRows = array_values(array_filter(
    $previewRows,
    static fn(array $row): bool => !empty($row['proposed_date_creation'])
));

if (!$apply) {
    echo json_encode([
        'mode' => 'dry-run',
        'rows_with_invalid_date_creation' => count($previewRows),
        'rows_fixable' => count($fillableRows),
        'rows' => $previewRows,
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE), PHP_EOL;
    exit(0);
}

$pdo->beginTransaction();

try {
    $updateSql = "UPDATE llx_missionsplanet_mission
    SET date_creation = {$fallbackExpression}
    WHERE {$invalidWhere}
      AND {$fallbackExpression} IS NOT NULL";

    $updatedRows = $pdo->exec($updateSql);
    $pdo->commit();

    echo json_encode([
        'mode' => 'apply',
        'updated_rows' => $updatedRows,
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE), PHP_EOL;
} catch (Throwable $error) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    fwrite(STDERR, $error->getMessage() . PHP_EOL);
    exit(1);
}
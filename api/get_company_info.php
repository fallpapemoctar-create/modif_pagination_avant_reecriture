<?php
require_once __DIR__ . '/config.php';

function fetchCompanyTimestamps(PDO $pdo, int $entityId): array {
    $stmt = $pdo->prepare(
        "SELECT MIN(tms) AS createdAt, MAX(tms) AS updatedAt\n"
        . "FROM llx_const\n"
        . "WHERE entity = :entity AND name LIKE 'MAIN_INFO_SOCIETE_%'"
    );
    $stmt->execute([':entity' => $entityId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];

    return [
        'createdAt' => $row['createdAt'] ?? null,
        'updatedAt' => $row['updatedAt'] ?? null,
    ];
}

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Content-Type: application/json; charset=UTF-8');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$defaults = [
    'name' => 'Planet Traduction',
    'addressLine1' => '13 chemin des Champcueil',
    'addressLine2' => '91220 Brétigny Sur Orge',
    'postalCode' => '91220',
    'city' => 'Brétigny Sur Orge',
    'siret' => '91282415800014',
    'phone' => '0178908756',
    'email' => 'contact@planettraduction.fr',
    'website' => 'https://planet-traduction.fr/',
    'logoUrl' => '',
];

$mapping = [
    'MAIN_INFO_SOCIETE_NOM' => 'name',
    'MAIN_INFO_SOCIETE_ADRESSE' => 'addressLine1',
    'MAIN_INFO_SOCIETE_ADDRESS' => 'addressLine1',
    'MAIN_INFO_SOCIETE_ADRESSE2' => 'addressLine2',
    'MAIN_INFO_SOCIETE_ADDRESS2' => 'addressLine2',
    'MAIN_INFO_SOCIETE_CP' => 'postalCode',
    'MAIN_INFO_SOCIETE_ZIP' => 'postalCode',
    'MAIN_INFO_SOCIETE_VILLE' => 'city',
    'MAIN_INFO_SOCIETE_TOWN' => 'city',
    'MAIN_INFO_SOCIETE_TEL' => 'phone',
    'MAIN_INFO_SOCIETE_MAIL' => 'email',
    'MAIN_INFO_SOCIETE_WEB' => 'website',
    'MAIN_INFO_SOCIETE_LOGO_URL' => 'logoUrl',
    'MAIN_INFO_SOCIETE_LOGO' => 'logoUrl',
];

$entityId = (int) (getenv('DOLIBARR_ENTITY') ?: 1);

try {
    $stmt = $pdo->prepare("SELECT name, value FROM llx_const WHERE entity = :entity AND name LIKE 'MAIN_INFO_SOCIETE_%'");
    $stmt->execute([':entity' => $entityId]);
    $pairs = $stmt->fetchAll(PDO::FETCH_KEY_PAIR);

    $company = $defaults;
    foreach ($pairs as $name => $value) {
        $value = trim((string) $value);

        if ($name === 'MAIN_INFO_SOCIETE_SIRET' || $name === 'MAIN_INFO_SOCIETE_SIREN') {
            if ($name === 'MAIN_INFO_SOCIETE_SIRET' || $company['siret'] === $defaults['siret']) {
                $company['siret'] = $value;
            }
            continue;
        }

        $key = $mapping[$name] ?? null;
        if ($key !== null) {
            $company[$key] = $value;
        }
    }

    $meta = fetchCompanyTimestamps($pdo, $entityId);

    echo json_encode([
        'success' => true,
        'company' => $company,
        'meta' => $meta,
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Unable to load company info',
        'details' => $e->getMessage(),
    ], JSON_UNESCAPED_UNICODE);
}

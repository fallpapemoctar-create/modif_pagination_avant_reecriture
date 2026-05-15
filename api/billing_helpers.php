<?php

function billingColumnExists(PDO $pdo, string $table, string $column): bool {
    try {
        $table = str_replace('`', '', $table);
        $column = str_replace('`', '', $column);
        $stmt = $pdo->query("SHOW COLUMNS FROM `$table` LIKE " . $pdo->quote($column));
        return $stmt && $stmt->rowCount() > 0;
    } catch (Exception $e) {
        return false;
    }
}

function ensureClientBillingTable(PDO $pdo): void {
    static $ensured = false;
    if ($ensured) {
        return;
    }

    $sql = "CREATE TABLE IF NOT EXISTS tble_client_billed (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        mission_ref VARCHAR(128) NOT NULL,
        client_name VARCHAR(255) DEFAULT NULL,
        invoice_number VARCHAR(128) NOT NULL,
        invoice_total_ht DECIMAL(15,2) DEFAULT NULL,
        amount_ht DECIMAL(15,2) DEFAULT NULL,
        billed_at DATETIME NOT NULL,
        status_code VARCHAR(32) NOT NULL,
        status_label VARCHAR(128) DEFAULT NULL,
        category VARCHAR(32) NOT NULL DEFAULT 'client',
        pdf_path VARCHAR(255) DEFAULT NULL,
        pdf_filename VARCHAR(255) DEFAULT NULL,
        pdf_size INT DEFAULT NULL,
        created_by INT DEFAULT NULL,
        created_by_name VARCHAR(255) DEFAULT NULL,
        notes TEXT DEFAULT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_client_billed_ref_invoice (mission_ref, invoice_number),
        KEY idx_client_billed_invoice (invoice_number),
        KEY idx_client_billed_mission (mission_ref),
        KEY idx_client_billed_category (category)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci";

    $pdo->exec($sql);

    // Ensure columns added after initial creation are present
    $clientBilledMigrations = [
        'status_code'      => "status_code VARCHAR(32) NOT NULL DEFAULT 'draft' AFTER billed_at",
        'status_label'     => "status_label VARCHAR(128) DEFAULT NULL AFTER status_code",
        'category'         => "category VARCHAR(32) NOT NULL DEFAULT 'client' AFTER status_label",
        'pdf_path'         => "pdf_path VARCHAR(255) DEFAULT NULL AFTER category",
        'pdf_filename'     => "pdf_filename VARCHAR(255) DEFAULT NULL AFTER pdf_path",
        'pdf_size'         => "pdf_size INT DEFAULT NULL AFTER pdf_filename",
        'created_by'       => "created_by INT DEFAULT NULL AFTER pdf_size",
        'created_by_name'  => "created_by_name VARCHAR(255) DEFAULT NULL AFTER created_by",
        'notes'            => "notes TEXT DEFAULT NULL AFTER created_by_name",
        'invoice_total_ht' => "invoice_total_ht DECIMAL(15,2) DEFAULT NULL AFTER invoice_number",
        'amount_ht'        => "amount_ht DECIMAL(15,2) DEFAULT NULL AFTER invoice_total_ht",
    ];
    foreach ($clientBilledMigrations as $col => $def) {
        if (!billingColumnExists($pdo, 'tble_client_billed', $col)) {
            try {
                $pdo->exec("ALTER TABLE tble_client_billed ADD COLUMN $def");
            } catch (Exception $e) {
                // ignore if already exists (race condition)
            }
        }
    }

    $ensured = true;
}

function ensureClientInvoiceLinesTable(PDO $pdo): void {
    static $ensuredLines = false;
    if ($ensuredLines) {
        return;
    }

    $sql = "CREATE TABLE IF NOT EXISTS tble_client_invoice_lines (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        invoice_id INT DEFAULT NULL,
        invoice_number VARCHAR(128) NOT NULL,
        draft_key VARCHAR(64) DEFAULT NULL,
        client_name VARCHAR(255) DEFAULT NULL,
        period_month DATE DEFAULT NULL,
        mission_ref VARCHAR(128) DEFAULT NULL,
        designation TEXT,
        tva_rate DECIMAL(6,3) DEFAULT 0,
        unit_price_ht DECIMAL(15,4) DEFAULT 0,
        quantity DECIMAL(15,4) DEFAULT 0,
        total_ht DECIMAL(15,4) DEFAULT 0,
        discount DECIMAL(6,3) DEFAULT 0,
        notes TEXT,
        sort_order INT DEFAULT 0,
        created_by INT DEFAULT NULL,
        created_by_name VARCHAR(255) DEFAULT NULL,
        updated_by INT DEFAULT NULL,
        updated_by_name VARCHAR(255) DEFAULT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        KEY idx_invoice_lines_invoice (invoice_number),
        KEY idx_invoice_lines_draft (draft_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci";

    $pdo->exec($sql);

    // Ensure new columns exist even if table was created previously
    $columnsToAdd = [
        'invoice_id INT DEFAULT NULL AFTER id',
        'draft_key VARCHAR(64) DEFAULT NULL AFTER invoice_number',
        'client_name VARCHAR(255) DEFAULT NULL AFTER draft_key',
        'period_month DATE DEFAULT NULL AFTER client_name',
        'created_by INT DEFAULT NULL AFTER sort_order',
        'created_by_name VARCHAR(255) DEFAULT NULL AFTER created_by',
        'updated_by INT DEFAULT NULL AFTER created_by_name',
        'updated_by_name VARCHAR(255) DEFAULT NULL AFTER updated_by'
    ];

    $columnMap = [
        'invoice_id' => $columnsToAdd[0],
        'draft_key' => $columnsToAdd[1],
        'client_name' => $columnsToAdd[2],
        'period_month' => $columnsToAdd[3],
        'created_by' => $columnsToAdd[4],
        'created_by_name' => $columnsToAdd[5],
        'updated_by' => $columnsToAdd[6],
        'updated_by_name' => $columnsToAdd[7],
        'discount' => 'discount DECIMAL(6,3) DEFAULT 0 AFTER total_ht',
    ];

    foreach ($columnMap as $column => $definition) {
        if (!billingColumnExists($pdo, 'tble_client_invoice_lines', $column)) {
            $pdo->exec("ALTER TABLE tble_client_invoice_lines ADD COLUMN $definition");
        }
    }

    // Ensure new index exists
    $indexCheck = $pdo->query("SHOW INDEX FROM tble_client_invoice_lines WHERE Key_name = 'idx_invoice_lines_draft'");
    if (!$indexCheck || $indexCheck->rowCount() === 0) {
        $pdo->exec("ALTER TABLE tble_client_invoice_lines ADD KEY idx_invoice_lines_draft (draft_key)");
    }

    $ensuredLines = true;
}

function invoiceIsLocked(PDO $pdo, string $invoiceNumber): bool {
    $stmt = $pdo->prepare("SELECT status_code FROM tble_client_billed WHERE invoice_number = :invoice ORDER BY billed_at DESC LIMIT 1");
    $stmt->execute([':invoice' => $invoiceNumber]);
    $status = $stmt->fetchColumn();
    if (!$status) {
        return false;
    }
    $status = strtolower(trim((string) $status));
    $lockedStatuses = ['paid', 'payee', 'payée', 'reglee', 'réglée', 'paid_partially', 'payee_partiellement'];
    return in_array($status, $lockedStatuses, true);
}

function normalizeClientBillingStatus($value): array {
    $code = 'draft';
    $label = 'Brouillon';
    if ($value === null) {
        return [$code, $label];
    }

    $normalized = strtolower(trim((string) $value));
    switch ($normalized) {
        case 'annulee':
        case 'annulée':
        case 'annule':
        case 'annulé':
        case 'cancelled':
        case 'canceled':
        case 'cancel':
            $code = 'cancelled';
            $label = 'Annulée';
            break;
        case 'validée':
        case 'validee':
        case 'valide':
        case 'validated':
        case 'validate':
            $code = 'validated';
            $label = 'Validée';
            break;
        case 'envoyee':
        case 'envoyée':
        case 'envoye':
        case 'envoyé':
        case 'sent':
        case 'env':
            $code = 'sent';
            $label = 'Envoyée';
            break;
        case 'payee':
        case 'payée':
        case 'payee_partiellement':
        case 'payee partiellement':
        case 'reglee':
        case 'réglée':
        case 'paid':
        case 'paid_partially':
            $code = 'paid';
            $label = 'Payée';
            break;
        case 'impayee':
        case 'impayée':
        case 'overdue':
        case 'unpaid':
        case 'retard':
            $code = 'unpaid';
            $label = 'Impayée';
            break;
        case 'brouillon':
        case 'draft':
        case 'afacturer':
        case 'a_facturer':
        default:
            $code = 'draft';
            $label = 'Brouillon';
            break;
    }
    return [$code, $label];
}

function sanitizeInvoiceFilename(string $value): string {
    $value = trim($value);
    if ($value === '') {
        return 'facture-client';
    }
    $value = preg_replace('/[^A-Za-z0-9-_]/', '_', $value);
    return $value !== '' ? strtolower($value) : 'facture-client';
}

function decodePdfPayload(?string $value): ?string {
    if ($value === null) {
        return null;
    }
    $value = trim($value);
    if ($value === '') {
        return null;
    }
    if (strpos($value, 'base64,') !== false) {
        $parts = explode('base64,', $value, 2);
        $value = $parts[1];
    }
    $decoded = base64_decode($value, true);
    return $decoded === false ? null : $decoded;
}

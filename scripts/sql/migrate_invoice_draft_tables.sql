-- Migration AMI v1.3 — Tables invoice_draft et invoice_draft_lines
-- Exécuter une seule fois sur la base de données cible.
-- Compatibilité : MySQL 5.7+ / MariaDB 10.3+

-- ---------------------------------------------------------------
-- 1. Table invoice_draft (header de préparation)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `invoice_draft` (
    `id`                   INT          NOT NULL AUTO_INCREMENT,
    `client_id`            INT          DEFAULT NULL,
    `client_name`          VARCHAR(255) DEFAULT NULL,
    `month`                VARCHAR(7)   NOT NULL COMMENT 'Format YYYY-MM',
    `payment_condition_id` INT          DEFAULT NULL,
    `bank_account_id`      INT          DEFAULT NULL,
    `total_ht`             DECIMAL(10,2) DEFAULT 0.00,
    `created_by`           INT          DEFAULT NULL,
    `status`               ENUM('draft','finalized') NOT NULL DEFAULT 'draft',
    `created_at`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_invoice_draft_client_id`   (`client_id`),
    KEY `idx_invoice_draft_client_name` (`client_name`(64)),
    KEY `idx_invoice_draft_status`      (`status`),
    KEY `idx_invoice_draft_month`       (`month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------
-- 2. Table invoice_draft_lines (lignes d'une préparation)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `invoice_draft_lines` (
    `id`          INT          NOT NULL AUTO_INCREMENT,
    `draft_id`    INT          NOT NULL,
    `mission_id`  INT          DEFAULT NULL,
    `description` TEXT         DEFAULT NULL,
    `quantity`    DECIMAL(15,4) DEFAULT 1.0000,
    `unit_price`  DECIMAL(15,4) DEFAULT 0.0000,
    `total`       DECIMAL(15,4) DEFAULT 0.0000,
    `sort_order`  INT          DEFAULT 0,
    `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_invoice_draft_lines_draft` (`draft_id`),
    CONSTRAINT `fk_invoice_draft_lines_draft`
        FOREIGN KEY (`draft_id`) REFERENCES `invoice_draft` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

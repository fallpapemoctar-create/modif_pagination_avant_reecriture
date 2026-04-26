-- Migration AMI v1.4 — Module Devis
-- Étend invoice_draft pour supporter le cycle de vie complet du devis.
-- Exécuter une seule fois sur la base de données cible.
-- Compatibilité : MySQL 5.7+ / MariaDB 10.3+
-- Non destructif : utilise IF NOT EXISTS / MODIFY avec valeur par défaut.

-- ---------------------------------------------------------------
-- 1. Étendre le statut (ENUM élargi)
-- ---------------------------------------------------------------
ALTER TABLE `invoice_draft`
    MODIFY COLUMN `status` ENUM(
        'draft',
        'sent',
        'accepted',
        'rejected',
        'expired',
        'finalized',
        'accepted_converted'
    ) NOT NULL DEFAULT 'draft';

-- ---------------------------------------------------------------
-- 2. Ajouter les colonnes manquantes (idempotent via procédure)
-- ---------------------------------------------------------------

-- date_valid_until : date de validité du devis
ALTER TABLE `invoice_draft`
    ADD COLUMN IF NOT EXISTS `date_valid_until` DATE DEFAULT NULL
        COMMENT 'Date limite de validité du devis';

-- mission_id : mission source du devis
ALTER TABLE `invoice_draft`
    ADD COLUMN IF NOT EXISTS `mission_id` INT DEFAULT NULL
        COMMENT 'Mission source du devis (FK logique)';

-- notes : conditions particulières / message au client
ALTER TABLE `invoice_draft`
    ADD COLUMN IF NOT EXISTS `notes` TEXT DEFAULT NULL
        COMMENT 'Conditions, message au client';

-- sent_at : date d envoi au client
ALTER TABLE `invoice_draft`
    ADD COLUMN IF NOT EXISTS `sent_at` DATETIME DEFAULT NULL
        COMMENT 'Date d envoi du devis';

-- converted_invoice_number : numéro de facture après conversion
ALTER TABLE `invoice_draft`
    ADD COLUMN IF NOT EXISTS `converted_invoice_number` VARCHAR(128) DEFAULT NULL
        COMMENT 'Numéro de facture après conversion devis→facture';

-- ---------------------------------------------------------------
-- 3. Ajouter colonnes manquantes dans invoice_draft_lines
-- ---------------------------------------------------------------

-- tva_rate : taux de TVA par ligne
ALTER TABLE `invoice_draft_lines`
    ADD COLUMN IF NOT EXISTS `tva_rate` DECIMAL(5,2) DEFAULT 0.00
        COMMENT 'Taux de TVA en % (ex: 20.00)';

-- discount : réduction en % par ligne
ALTER TABLE `invoice_draft_lines`
    ADD COLUMN IF NOT EXISTS `discount` DECIMAL(5,2) DEFAULT 0.00
        COMMENT 'Réduction en % (0–100)';

-- ---------------------------------------------------------------
-- 4. Index utiles
-- ---------------------------------------------------------------
CREATE INDEX IF NOT EXISTS `idx_invoice_draft_mission_id`
    ON `invoice_draft` (`mission_id`);

CREATE INDEX IF NOT EXISTS `idx_invoice_draft_status_created`
    ON `invoice_draft` (`status`, `created_at`);

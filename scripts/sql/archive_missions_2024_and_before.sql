-- ============================================================
-- ARCHIVAGE DES MISSIONS 2024 ET ANTERIEURES
-- Critere : datemission < '2025-01-01'
-- Tables archivees :
--   llx_missionsplanet_mission        -> llx_missionsplanet_mission_archive
--   tble_mission_billed               -> tble_mission_billed_archive
--   tble_client_billed                -> tble_client_billed_archive
--
-- USAGE : executer sur la base de prod apres sauvegarde (dump).
-- Le script est transactionnel : en cas d'erreur, ROLLBACK.
-- Pour valider definitivement, executer COMMIT a la fin.
-- ============================================================

-- ============================================================
-- ETAPE 0 : VERIFICATION PRE-ARCHIVAGE
-- ============================================================

-- Nombre de missions a archiver (critere datemission)
SELECT
    COUNT(*) AS nb_missions_a_archiver,
    MIN(datemission) AS date_min,
    MAX(datemission) AS date_max
FROM llx_missionsplanet_mission
WHERE datemission < '2025-01-01';

-- Nombre de missions avec datemission NULL
SELECT COUNT(*) AS nb_datemission_null FROM llx_missionsplanet_mission WHERE datemission IS NULL;

-- Nombre de missions avec debutmission avant 2025 (colonne de repli)
SELECT
    COUNT(*) AS nb_via_debutmission,
    MIN(DATE(debutmission)) AS date_min,
    MAX(DATE(debutmission)) AS date_max
FROM llx_missionsplanet_mission
WHERE DATE(debutmission) < '2025-01-01';

-- Nombre total de missions actuelles
SELECT COUNT(*) AS nb_missions_total FROM llx_missionsplanet_mission;

-- ============================================================
-- ETAPE 1 : CREATION DES TABLES D'ARCHIVE (si elles n'existent pas)
-- ============================================================

-- Archive principale missions
CREATE TABLE IF NOT EXISTS llx_missionsplanet_mission_archive LIKE llx_missionsplanet_mission;

-- Supprimer l'auto_increment sur rowid dans l'archive (on conserve les rowid d'origine)
ALTER TABLE llx_missionsplanet_mission_archive
    MODIFY rowid INT NOT NULL,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (rowid);

-- Ajouter colonne de traçabilite (idempotent)
SET @sql_arch1 = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'llx_missionsplanet_mission_archive'
       AND COLUMN_NAME = 'archived_at') = 0,
    'ALTER TABLE llx_missionsplanet_mission_archive ADD COLUMN archived_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'SELECT 1'
);
PREPARE _stmt FROM @sql_arch1;
EXECUTE _stmt;
DEALLOCATE PREPARE _stmt;

-- Archive tble_mission_billed
CREATE TABLE IF NOT EXISTS tble_mission_billed_archive LIKE tble_mission_billed;

SET @sql_arch2 = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'tble_mission_billed_archive'
       AND COLUMN_NAME = 'archived_at') = 0,
    'ALTER TABLE tble_mission_billed_archive ADD COLUMN archived_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'SELECT 1'
);
PREPARE _stmt FROM @sql_arch2;
EXECUTE _stmt;
DEALLOCATE PREPARE _stmt;

-- Archive tble_client_billed
CREATE TABLE IF NOT EXISTS tble_client_billed_archive LIKE tble_client_billed;

SET @sql_arch3 = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'tble_client_billed_archive'
       AND COLUMN_NAME = 'archived_at') = 0,
    'ALTER TABLE tble_client_billed_archive ADD COLUMN archived_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'SELECT 1'
);
PREPARE _stmt FROM @sql_arch3;
EXECUTE _stmt;
DEALLOCATE PREPARE _stmt;

-- ============================================================
-- ETAPE 2 A 7 : ARCHIVAGE + VALIDATION
-- IMPORTANT : Copier-coller CE BLOC ENTIER dans phpMyAdmin
-- et l'executer en une seule fois (START TRANSACTION...COMMIT).
-- Ne pas executer ligne par ligne.
-- ============================================================

START TRANSACTION;

-- ============================================================
-- ETAPE 3 : COPIE DES DONNEES DANS LES TABLES D'ARCHIVE
-- ============================================================

-- 3a. Missions 2024 et avant -> archive
INSERT INTO llx_missionsplanet_mission_archive
    (rowid, ref, fk_soc, fk_project, description, note_public, note_private,
     date_creation, tms, fk_user_creat, fk_user_modif, last_main_doc, import_key,
     model_pdf, status, mission_types, contactdemandeur, nominterprete, langue,
     fk_propal, fk_invoice, debutmission, finmission, montant_mission, label,
     datemission, dureemission, heuredebutmission,
     archived_at)
SELECT
    rowid, ref, fk_soc, fk_project, description, note_public, note_private,
    date_creation, tms, fk_user_creat, fk_user_modif, last_main_doc, import_key,
    model_pdf, status, mission_types, contactdemandeur, nominterprete, langue,
    fk_propal, fk_invoice, debutmission, finmission, montant_mission, label,
    datemission, dureemission, heuredebutmission,
    NOW()
FROM llx_missionsplanet_mission
WHERE datemission < '2025-01-01';

-- 3b. tble_mission_billed correspondants -> archive
INSERT INTO tble_mission_billed_archive
SELECT mb.*, NOW() AS archived_at
FROM tble_mission_billed mb
WHERE mb.ref IN (
    SELECT ref FROM llx_missionsplanet_mission WHERE datemission < '2025-01-01'
);

-- 3c. tble_client_billed correspondants -> archive
INSERT INTO tble_client_billed_archive
SELECT cb.*, NOW() AS archived_at
FROM tble_client_billed cb
WHERE cb.mission_ref IN (
    SELECT ref FROM llx_missionsplanet_mission WHERE datemission < '2025-01-01'
);

-- ============================================================
-- ETAPE 5 : SUPPRESSION DES DONNEES DE LA TABLE PRINCIPALE
-- ============================================================

-- 5a. Supprimer les lignes tble_mission_billed archivees
DELETE FROM tble_mission_billed
WHERE ref IN (
    SELECT ref FROM llx_missionsplanet_mission WHERE datemission < '2025-01-01'
);

-- 5b. Supprimer les lignes tble_client_billed archivees
DELETE FROM tble_client_billed
WHERE mission_ref IN (
    SELECT ref FROM llx_missionsplanet_mission WHERE datemission < '2025-01-01'
);

-- 5c. Supprimer les missions archivees de la table principale
DELETE FROM llx_missionsplanet_mission
WHERE datemission < '2025-01-01';

-- ============================================================
-- ETAPE 7 : COMMIT
-- ============================================================

COMMIT;

-- ============================================================
-- ETAPE 8 (OPTIONNELLE) : OPTIMISER LA TABLE PRINCIPALE
-- A executer APRES le COMMIT, hors transaction :
-- ============================================================

-- OPTIMIZE TABLE llx_missionsplanet_mission;
-- OPTIMIZE TABLE tble_mission_billed;
-- OPTIMIZE TABLE tble_client_billed;

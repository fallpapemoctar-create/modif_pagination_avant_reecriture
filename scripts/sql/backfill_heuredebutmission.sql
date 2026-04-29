-- Backfill heuredebutmission depuis debutmission pour les missions sans heure début
-- À exécuter manuellement sur phpMyAdmin (prod: dbs12436960)
-- Date: 2026-04-27

UPDATE llx_missionsplanet_mission
SET heuredebutmission = TIME(debutmission)
WHERE heuredebutmission IS NULL
  AND debutmission IS NOT NULL;

SELECT ROW_COUNT() AS nb_lignes_modifiees;

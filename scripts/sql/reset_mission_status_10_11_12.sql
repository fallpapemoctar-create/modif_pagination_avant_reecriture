-- Reset des missions avec status 10, 11 ou 12 vers status = 1
-- À exécuter manuellement sur phpMyAdmin (prod: dbs12436960)
-- Date: 2026-04-27

START TRANSACTION;

SELECT COUNT(*) AS missions_a_convertir
FROM llx_missionsplanet_mission
WHERE status IN (10, 11, 12);

UPDATE llx_missionsplanet_mission
SET status = 1
WHERE status IN (10, 11, 12);

SELECT ROW_COUNT() AS missions_mises_a_jour;

COMMIT;

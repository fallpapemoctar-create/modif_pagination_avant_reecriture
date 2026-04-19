START TRANSACTION;

SELECT COUNT(*) AS nb_missions_a_corriger
FROM llx_missionsplanet_mission
WHERE datemission IS NULL
  AND debutmission IS NOT NULL;

SELECT
  rowid,
  ref,
  datemission,
  debutmission,
  DATE(debutmission) AS datemission_calculee
FROM llx_missionsplanet_mission
WHERE datemission IS NULL
  AND debutmission IS NOT NULL
ORDER BY debutmission DESC;

UPDATE llx_missionsplanet_mission
SET datemission = DATE(debutmission)
WHERE datemission IS NULL
  AND debutmission IS NOT NULL;

SELECT ROW_COUNT() AS nb_lignes_modifiees;

SELECT COUNT(*) AS nb_restant_a_corriger
FROM llx_missionsplanet_mission
WHERE datemission IS NULL
  AND debutmission IS NOT NULL;

COMMIT;

SELECT COUNT(*) AS nb_restant_a_corriger
FROM llx_missionsplanet_mission
WHERE datemission IS NULL
  AND debutmission IS NOT NULL;
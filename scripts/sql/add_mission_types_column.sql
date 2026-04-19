ALTER TABLE llx_missionsplanet_mission
    ADD COLUMN mission_types TEXT NULL
    COMMENT 'JSON array of mission types selected in the mission form'
    AFTER status;
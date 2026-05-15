CREATE OR REPLACE PROCEDURE affecter_localisation_equipement(
    p_equip_name    IN VARCHAR2,
    p_salle_name    IN VARCHAR2
) AS
    v_equip_id      NUMBER;
    v_entities_id   NUMBER;
    v_location_id   NUMBER;
BEGIN
    -- Récupérer l'équipement
    SELECT id, entities_id
    INTO v_equip_id, v_entities_id
    FROM glpi_equipments
    WHERE UPPER(name) = UPPER(p_equip_name)
    AND ROWNUM = 1;

    -- Trouver la salle sur le même site que l'équipement
    -- (unicité du nom garantie par la séquence, pas besoin de ROWNUM)
    SELECT id INTO v_location_id
    FROM glpi_locations
    WHERE UPPER(name) = UPPER(p_salle_name)
    AND entities_id   = v_entities_id;

    -- Mettre à jour
    UPDATE glpi_equipments
    SET locations_id = v_location_id
    WHERE id = v_equip_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Équipement ' || p_equip_name ||
                         ' affecté à la salle ' || p_salle_name);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20090,
            'Équipement ou salle introuvable : ' ||
            p_equip_name || ' / ' || p_salle_name);
END;
/
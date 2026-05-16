CREATE OR REPLACE PROCEDURE affecter_localisation_equipement(
    p_equip_name    IN VARCHAR2,
    p_salle_name    IN VARCHAR2
) AS
    v_equip_id      NUMBER;
    v_entities_id   NUMBER;
    v_location_id   NUMBER;
BEGIN
    -- ----------------------------------------------------
    -- 1. Récupérer l'équipement
    -- ----------------------------------------------------
    BEGIN
        SELECT id, entities_id
        INTO v_equip_id, v_entities_id
        FROM glpi_equipments
        WHERE UPPER(name) = UPPER(p_equip_name)
        AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20091, 'Erreur : L''équipement [' || p_equip_name || '] n''existe pas dans la base.');
    END;

    -- ----------------------------------------------------
    -- 2. Trouver la salle (avec vérification du site)
    -- ----------------------------------------------------
    BEGIN
        SELECT id INTO v_location_id
        FROM glpi_locations
        WHERE UPPER(name) = UPPER(p_salle_name)
        AND entities_id   = v_entities_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Le message est maintenant ultra-précis !
            RAISE_APPLICATION_ERROR(-20092, 'Erreur : La salle [' || p_salle_name || '] est introuvable sur le même site que l''équipement.');
        -- On ajoute une sécurité au cas où deux salles s'appelleraient pareil sur le même site
        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(-20093, 'Erreur : Plusieurs salles portent le nom [' || p_salle_name || '] sur ce site. Casse-tête d''architecture !');
    END;

    -- ----------------------------------------------------
    -- 3. Mise à jour de l'équipement
    -- ----------------------------------------------------
    UPDATE glpi_equipments
    SET locations_id = v_location_id
    WHERE id = v_equip_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Équipement ' || p_equip_name ||
                         ' affecté à la salle ' || p_salle_name);

EXCEPTION
    -- Gestion globale pour toute autre erreur SQL inattendue (ex: base déconnectée)
    WHEN OTHERS THEN
        ROLLBACK; -- TRÈS IMPORTANT : On annule tout s'il y a un crash grave
        RAISE_APPLICATION_ERROR(-20099, 'Erreur inattendue : ' || SQLERRM);
END;
/

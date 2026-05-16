CREATE OR REPLACE PROCEDURE supprimer_technicien(
    p_pseudo IN VARCHAR2
) AS
    v_tech_id       NUMBER;
    v_entities_id   NUMBER;
    v_site          VARCHAR2(50);
    v_ent_site      NUMBER;
    v_is_tech       NUMBER;
    v_equip_ids     t_ids;
BEGIN
    -- Site de l'admin connecté
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    SELECT id INTO v_ent_site
    FROM glpi_entities WHERE UPPER(name) = v_site;

    -- Récupérer le technicien
    SELECT id, entities_id
    INTO v_tech_id, v_entities_id
    FROM glpi_users
    WHERE UPPER(pseudo) = UPPER(p_pseudo)
    AND is_active = 1;

    -- Vérifier que c'est bien un technicien
    SELECT COUNT(*) INTO v_is_tech
    FROM glpi_profiles_users pu
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE pu.users_id = v_tech_id
    AND UPPER(p.name) = 'TECHNICIEN';

    IF v_is_tech = 0 THEN
        RAISE_APPLICATION_ERROR(-20100,
            p_pseudo || ' n''est pas un technicien.');
    END IF;

    -- Vérifier que le technicien est sur le site de l'admin
    IF v_entities_id != v_ent_site THEN
        RAISE_APPLICATION_ERROR(-20101,
            'Ce technicien n''est pas sur votre site.');
    END IF;

    -- Récupérer ses équipements
    v_equip_ids := get_equip_technicien(v_tech_id);

    -- Redistribuer les équipements
    IF v_equip_ids.COUNT > 0 THEN
        redistribuer_equip(v_equip_ids, v_entities_id, v_tech_id);
        DBMS_OUTPUT.PUT_LINE(v_equip_ids.COUNT ||
                             ' équipements redistribués.');
    END IF;

    -- Désactiver le technicien
    UPDATE glpi_users SET is_active = 0 WHERE id = v_tech_id;
    DELETE FROM glpi_profiles_users
    WHERE users_id = v_tech_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Technicien ' || p_pseudo || ' désactivé.');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20102,
            'Technicien introuvable ou déjà inactif : ' || p_pseudo);
END;
/
CREATE OR REPLACE PROCEDURE ajouter_technicien(
    p_firstname IN VARCHAR2,
    p_realname  IN VARCHAR2,
    p_password  IN VARCHAR2
) AS
    v_pseudo        VARCHAR2(255);
    v_entities_id   NUMBER;
    v_site          VARCHAR2(50);
    v_count         NUMBER;
    v_user_id       NUMBER;
    v_equip_ids     t_ids;
BEGIN
    -- Récupérer le site de l'admin connecté
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    SELECT id INTO v_entities_id
    FROM glpi_entities
    WHERE UPPER(name) = v_site;

    -- Générer le pseudo
    v_pseudo := UPPER(SUBSTR(p_firstname, 1, 1)) || UPPER(p_realname);

    SELECT COUNT(*) INTO v_count
    FROM glpi_users WHERE pseudo = v_pseudo;

    IF v_count > 0 THEN
        v_pseudo := v_pseudo || seq_users_pseudo.NEXTVAL;
    END IF;

    -- Créer le compte Oracle
    EXECUTE IMMEDIATE
        'CREATE USER ' || v_pseudo || '_' || v_site ||
        ' IDENTIFIED BY "' || p_password || '"' ||
        ' DEFAULT TABLESPACE TS_GLPI_' || v_site;

    EXECUTE IMMEDIATE
        'GRANT R_GLPI_TECH, R_GLPI_READ TO ' || v_pseudo || '_' || v_site;

    -- Insérer dans glpi_users
    INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
    VALUES (v_pseudo, p_firstname, p_realname, v_entities_id, 1)
    RETURNING id INTO v_user_id;

    -- Insérer dans glpi_profiles_users
    INSERT INTO glpi_profiles_users (users_id, profiles_id, entities_id, is_recursive)
    VALUES (
        v_user_id,
        (SELECT id FROM glpi_profiles WHERE UPPER(name) = 'TECHNICIEN'),
        v_entities_id,
        0   -- droits sur ce site uniquement
    );

    -- À ajouter dans ajouter_admin
    INSERT INTO glpi_profiles_users (users_id, profiles_id, entities_id)
    VALUES (
        v_user_id,
        (SELECT id FROM glpi_profiles WHERE UPPER(name) = 'ADMINISTRATEUR'),
        v_entities_id,
        0
    );


    -- Répartir les équipements
    v_equip_ids := repartition_charge_nouveau_tech(v_entities_id);

    -- Attribuer les équipements au nouveau technicien
    FORALL i IN 1..v_equip_ids.COUNT
        UPDATE glpi_computers
        SET users_id_tech = v_user_id
        WHERE id = v_equip_ids(i);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Technicien créé : ' || v_pseudo || '_' || v_site ||
                         ' — ' || v_equip_ids.COUNT || ' équipements attribués.');
END;
/
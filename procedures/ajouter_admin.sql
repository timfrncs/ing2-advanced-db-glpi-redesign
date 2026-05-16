CREATE OR REPLACE PROCEDURE ajouter_admin(
    p_firstname   IN VARCHAR2,
    p_realname    IN VARCHAR2,
    p_password    IN VARCHAR2,
    p_site        IN VARCHAR2 DEFAULT NULL  -- NULL = hérité de l'admin connecté
) AS
    v_pseudo        VARCHAR2(255);
    v_site          VARCHAR2(50);
    v_entities_id   NUMBER;
    v_count         NUMBER;
BEGIN
    -- Déterminer le site
    IF p_site IS NOT NULL THEN
        v_site := UPPER(p_site);
    ELSE
        v_site := SUBSTR(
            SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
            INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
        );
    END IF;

    IF v_site NOT IN ('CERGY', 'PAU') THEN
        RAISE_APPLICATION_ERROR(-20011,
            'Site invalide : ' || v_site || '. Valeurs acceptées : CERGY, PAU.');
    END IF;

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
        ' DEFAULT TABLESPACE TS_GLPI_REF';

    EXECUTE IMMEDIATE
        'GRANT R_GLPI_ADMIN TO ' || v_pseudo || '_' || v_site;

    -- Insérer dans glpi_users
    INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
    VALUES (v_pseudo, p_firstname, p_realname, v_entities_id, 1);

    -- Insérer dans glpi_profiles_users
    INSERT INTO glpi_profiles_users (users_id, profiles_id, entities_id)
    VALUES (
        v_user_id,
        (SELECT id FROM glpi_profiles WHERE UPPER(name) = 'ADMINISTRATEUR'),
        v_entities_id,
        0
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Admin créé : ' || v_pseudo || '_' || v_site);
END;
/
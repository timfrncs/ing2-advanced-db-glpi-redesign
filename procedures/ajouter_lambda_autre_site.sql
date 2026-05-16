-- Renommer l'existante pour être explicite
CREATE OR REPLACE PROCEDURE ajouter_lambda_autre_site(
    p_pseudo_existant IN VARCHAR2
) AS
    v_firstname     VARCHAR2(255);
    v_realname      VARCHAR2(255);
    v_new_pseudo    VARCHAR2(255);
    v_site          VARCHAR2(50);
    v_entities_id   NUMBER;
    v_count         NUMBER;
    v_old_ent       NUMBER;
BEGIN
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    SELECT id INTO v_entities_id
    FROM glpi_entities WHERE UPPER(name) = v_site;

    SELECT firstname, realname, entities_id
    INTO v_firstname, v_realname, v_old_ent
    FROM glpi_users
    WHERE UPPER(pseudo) = UPPER(p_pseudo_existant)
    AND is_active = 1
    AND ROWNUM = 1;

    IF v_old_ent = v_entities_id THEN
        RAISE_APPLICATION_ERROR(-20110,
            'Cet utilisateur est déjà rattaché à votre site.');
    END IF;

    -- Vérifier que c'est bien un lambda
    SELECT COUNT(*) INTO v_count
    FROM glpi_profiles_users pu
    WHERE pu.users_id = (
        SELECT id FROM glpi_users
        WHERE UPPER(pseudo) = UPPER(p_pseudo_existant)
        AND ROWNUM = 1
    );

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20111,
            'Cet utilisateur a un profil (admin/technicien). '  ||
            'Utilisez ajouter_tech_ou_admin_autre_site.');
    END IF;

    v_new_pseudo := UPPER(p_pseudo_existant) || '_' || v_site;

    SELECT COUNT(*) INTO v_count
    FROM glpi_users WHERE UPPER(pseudo) = v_new_pseudo;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20112,
            'Pseudo déjà existant : ' || v_new_pseudo);
    END IF;

    INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
    VALUES (v_new_pseudo, v_firstname, v_realname, v_entities_id, 1);

    -- Pas d'insertion dans glpi_profiles_users : c'est un lambda
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Lambda ' || p_pseudo_existant ||
                         ' ajouté sur ' || v_site ||
                         ' → ' || v_new_pseudo);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20113,
            'Utilisateur introuvable : ' || p_pseudo_existant);
END;
/
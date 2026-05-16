CREATE OR REPLACE PROCEDURE ajouter_user_autre_site(
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
    -- Site de l'admin connecté
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    SELECT id INTO v_entities_id
    FROM glpi_entities WHERE UPPER(name) = v_site;

    -- Récupérer les infos du user existant
    SELECT firstname, realname, entities_id
    INTO v_firstname, v_realname, v_old_ent
    FROM glpi_users
    WHERE UPPER(pseudo) = UPPER(p_pseudo_existant)
    AND is_active = 1
    AND ROWNUM = 1;

    -- Vérifier que le user existant n'est pas déjà sur ce site
    IF v_old_ent = v_entities_id THEN
        RAISE_APPLICATION_ERROR(-20110,
            'Cet utilisateur est déjà rattaché à votre site.');
    END IF;

    -- Vérifier que ce n'est pas un admin ou technicien
    SELECT COUNT(*) INTO v_count
    FROM glpi_profiles_users pu
    WHERE pu.users_id = (
        SELECT id FROM glpi_users
        WHERE UPPER(pseudo) = UPPER(p_pseudo_existant)
        AND ROWNUM = 1
    );

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20111,
            'Cette procédure est réservée aux utilisateurs lambda. '  ||
            'Les admins et techniciens sont gérés par leurs procédures dédiées.');
    END IF;

    -- Générer le nouveau pseudo : pseudo_original + '_' + SITE
    -- Si le pseudo contient déjà un suffixe de site, on prend la racine
    v_new_pseudo := UPPER(p_pseudo_existant) || '_' || v_site;

    -- Vérifier que ce pseudo n'existe pas déjà
    SELECT COUNT(*) INTO v_count
    FROM glpi_users
    WHERE UPPER(pseudo) = v_new_pseudo;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20112,
            'Un utilisateur avec le pseudo ' || v_new_pseudo ||
            ' existe déjà.');
    END IF;

    -- Créer la nouvelle entrée
    INSERT INTO glpi_users (
        pseudo, firstname, realname,
        entities_id, is_active
    ) VALUES (
        v_new_pseudo, v_firstname, v_realname,
        v_entities_id, 1
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE(
        'Utilisateur ' || p_pseudo_existant ||
        ' ajouté sur ' || v_site ||
        ' avec le pseudo ' || v_new_pseudo
    );

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20113,
            'Utilisateur introuvable : ' || p_pseudo_existant);
END;
/
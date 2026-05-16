CREATE OR REPLACE PROCEDURE ajouter_tech_ou_admin_autre_site(
    p_pseudo_existant   IN VARCHAR2,
    p_password          IN VARCHAR2
) AS
    v_firstname     VARCHAR2(255);
    v_realname      VARCHAR2(255);
    v_new_pseudo    VARCHAR2(255);
    v_site          VARCHAR2(50);
    v_entities_id   NUMBER;
    v_old_ent       NUMBER;
    v_count         NUMBER;
    v_new_user_id   NUMBER;
    v_profile_id    NUMBER;
    v_profile_name  VARCHAR2(255);
    v_oracle_role   VARCHAR2(50);
BEGIN
    -- Site de l'admin connecté
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    SELECT id INTO v_entities_id
    FROM glpi_entities WHERE UPPER(name) = v_site;

    -- Récupérer les infos du user existant
    SELECT u.firstname, u.realname, u.entities_id,
           p.id, UPPER(p.name)
    INTO v_firstname, v_realname, v_old_ent,
         v_profile_id, v_profile_name
    FROM glpi_users u
    JOIN glpi_profiles_users pu ON pu.users_id   = u.id
    JOIN glpi_profiles       p  ON p.id          = pu.profiles_id
    WHERE UPPER(u.pseudo) = UPPER(p_pseudo_existant)
    AND u.is_active = 1
    AND ROWNUM = 1;

    -- Vérifier que ce n'est pas déjà sur ce site
    IF v_old_ent = v_entities_id THEN
        RAISE_APPLICATION_ERROR(-20120,
            'Cet utilisateur est déjà rattaché à votre site.');
    END IF;

    -- Vérifier que l'admin ne peut pas ajouter un admin d'un autre site
    -- (un admin Cergy ne peut ajouter que sur Cergy)
    IF v_profile_name = 'ADMINISTRATEUR' THEN
        -- Seul l'owner peut dupliquer un admin sur un autre site
        -- On le vérifie en contrôlant que USER = GLPI_OWNER
        IF USER != 'GLPI_OWNER' THEN
            RAISE_APPLICATION_ERROR(-20121,
                'Seul GLPI_OWNER peut dupliquer un admin sur un autre site.');
        END IF;
    END IF;

    -- Déterminer le rôle Oracle selon le profil
    IF v_profile_name = 'ADMINISTRATEUR' THEN
        v_oracle_role := 'R_GLPI_ADMIN';
    ELSIF v_profile_name = 'TECHNICIEN' THEN
        v_oracle_role := 'R_GLPI_TECH, R_GLPI_READ';
    ELSE
        RAISE_APPLICATION_ERROR(-20122,
            'Profil non reconnu : ' || v_profile_name);
    END IF;

    -- Générer le nouveau pseudo
    v_new_pseudo := UPPER(p_pseudo_existant) || '_' || v_site;

    SELECT COUNT(*) INTO v_count
    FROM glpi_users WHERE UPPER(pseudo) = v_new_pseudo;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20123,
            'Pseudo déjà existant : ' || v_new_pseudo);
    END IF;

    -- Créer le compte Oracle
    EXECUTE IMMEDIATE
        'CREATE USER ' || v_new_pseudo ||
        ' IDENTIFIED BY "' || p_password || '"' ||
        ' DEFAULT TABLESPACE TS_GLPI_' || v_site;

    EXECUTE IMMEDIATE
        'GRANT ' || v_oracle_role || ' TO ' || v_new_pseudo;

    -- Insérer dans glpi_users
    INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
    VALUES (v_new_pseudo, v_firstname, v_realname, v_entities_id, 1)
    RETURNING id INTO v_new_user_id;

    -- Insérer dans glpi_profiles_users avec le même profil
    INSERT INTO glpi_profiles_users (users_id, profiles_id, entities_id)
    VALUES (v_new_user_id, v_profile_id, v_entities_id);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE(v_profile_name || ' ' || p_pseudo_existant ||
                         ' ajouté sur ' || v_site ||
                         ' → compte Oracle : ' || v_new_pseudo);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20124,
            'Utilisateur introuvable ou sans profil : ' || p_pseudo_existant);
END;
/
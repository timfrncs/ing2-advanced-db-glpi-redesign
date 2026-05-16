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
BEGIN
    -- Site de l'admin connecté
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    BEGIN
        SELECT id INTO v_entities_id
        FROM glpi_entities WHERE UPPER(name) = v_site;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20120, 'Erreur : Le site de destination [' || v_site || '] est introuvable.');
    END;

    -- Récupérer les infos du user existant
    BEGIN
        SELECT u.firstname, u.realname, u.entities_id, p.id, UPPER(p.name)
        INTO v_firstname, v_realname, v_old_ent, v_profile_id, v_profile_name
        FROM glpi_users u
        JOIN glpi_profiles_users pu ON pu.users_id   = u.id
        JOIN glpi_profiles         p  ON p.id          = pu.profiles_id
        WHERE UPPER(u.pseudo) = UPPER(p_pseudo_existant)
        AND u.is_active = 1
        AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20121, 'Erreur : Utilisateur informatique actif introuvable ou sans profil associé pour : ' || p_pseudo_existant);
    END;

    -- Vérifier que ce n'est pas déjà sur ce site
    IF v_old_ent = v_entities_id THEN
        RAISE_APPLICATION_ERROR(-20122, 'Cet utilisateur est déjà rattaché à votre site.');
    END IF;

    -- Vérifier les droits sur le profil ADMINISTRATEUR
    IF v_profile_name = 'ADMINISTRATEUR' THEN
        IF USER != 'GLPI_OWNER' THEN
            RAISE_APPLICATION_ERROR(-20123, 'Seul GLPI_OWNER peut dupliquer un admin sur un autre site.');
        END IF;
    END IF;

    -- Validation du profil
    IF v_profile_name NOT IN ('ADMINISTRATEUR', 'TECHNICIEN') THEN
        RAISE_APPLICATION_ERROR(-20124, 'Profil non reconnu ou non autorisé : ' || v_profile_name);
    END IF;

    -- Générer le nouveau pseudo
    v_new_pseudo := UPPER(p_pseudo_existant) || '_' || v_site;

    SELECT COUNT(*) INTO v_count
    FROM glpi_users WHERE UPPER(pseudo) = v_new_pseudo;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20125, 'Pseudo déjà existant : ' || v_new_pseudo);
    END IF;

    -- Insérer dans glpi_users et profil (D'ABORD)
    BEGIN
        -- Insertion Utilisateur
        INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
        VALUES (v_new_pseudo, v_firstname, v_realname, v_entities_id, 1)
        RETURNING id INTO v_new_user_id;

        -- Insertion Profil
        INSERT INTO glpi_profiles_users (users_id, profiles_id, entities_id)
        VALUES (v_new_user_id, v_profile_id, v_entities_id);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20126, 'Erreur lors de l''écriture dans les tables GLPI : ' || SQLERRM);
    END;

    -- Créer le compte Oracle (EN DERNIER - Sans le point-virgule après le BEGIN)
    BEGIN 
        EXECUTE IMMEDIATE
            'CREATE USER ' || v_new_pseudo ||
            ' IDENTIFIED BY "' || REPLACE(p_password, '"', '""') || '"' ||
            ' DEFAULT TABLESPACE TS_GLPI_' || v_site;

        -- Attribution des privilèges séparée (Évite le crash réseau)
        IF v_profile_name = 'ADMINISTRATEUR' THEN
            EXECUTE IMMEDIATE 'GRANT R_GLPI_ADMIN TO ' || v_new_pseudo;
        ELSIF v_profile_name = 'TECHNICIEN' THEN
            EXECUTE IMMEDIATE 'GRANT R_GLPI_TECH TO ' || v_new_pseudo;
            EXECUTE IMMEDIATE 'GRANT R_GLPI_READ TO ' || v_new_pseudo;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            -- Le ROLLBACK magique : efface les inserts du bloc précédent si Oracle échoue ici
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20127, 'Erreur critique lors de la création du compte Oracle. Opération d''écriture annulée : ' || SQLERRM);
    END;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE(v_profile_name || ' ' || p_pseudo_existant ||
                         ' ajouté sur ' || v_site ||
                         ' → compte Oracle : ' || v_new_pseudo);
END;
/

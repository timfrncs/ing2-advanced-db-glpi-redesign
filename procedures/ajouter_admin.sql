CREATE OR REPLACE PROCEDURE ajouter_admin(
    p_firstname   IN VARCHAR2,
    p_realname    IN VARCHAR2,
    p_password    IN VARCHAR2,
    p_site        IN VARCHAR2 DEFAULT NULL
) AS
    v_pseudo        VARCHAR2(255);
    v_site          VARCHAR2(50);
    v_entities_id   NUMBER;
    v_count         NUMBER;
    
    v_user_id       NUMBER; 
    v_profile_id    NUMBER; -- NOUVEAU : Pour stocker l'ID du profil Admin
    v_pseudo_base   VARCHAR2(255);
    v_i             NUMBER := 1;
BEGIN
    -- ----------------------------------------------------
    -- 1. Déterminer et Valider le site
    -- ----------------------------------------------------
    IF p_site IS NOT NULL THEN
        v_site := UPPER(p_site);
    ELSE
        v_site := SUBSTR(
            SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
            INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
        );
    END IF;

    IF v_site NOT IN ('CERGY', 'PAU') THEN
        RAISE_APPLICATION_ERROR(-20011, 'Site invalide : ' || v_site || '. Valeurs acceptées : CERGY, PAU.');
    END IF;

    -- ----------------------------------------------------
    -- 2. Récupérer l'ID de l'entité (AVEC EXCEPTION)
    -- ----------------------------------------------------
    BEGIN
        SELECT id INTO v_entities_id
        FROM glpi_entities
        WHERE UPPER(name) = v_site;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20012, 'Erreur : L''entité [' || v_site || '] n''existe pas dans la base de données.');
    END;

    -- ----------------------------------------------------
    -- 3. Récupérer l'ID du profil (AVEC EXCEPTION)
    -- ----------------------------------------------------
    BEGIN
        SELECT id INTO v_profile_id 
        FROM glpi_profiles 
        WHERE UPPER(name) = 'ADMINISTRATEUR';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20013, 'Erreur : Le profil [ADMINISTRATEUR] est introuvable dans la table glpi_profiles.');
    END;

    -- ----------------------------------------------------
    -- 4. Générer le pseudo anti-doublon
    -- ----------------------------------------------------
    v_pseudo_base := UPPER(SUBSTR(p_firstname, 1, 1)) || UPPER(p_realname);
    v_pseudo := v_pseudo_base;
    
    LOOP
        SELECT COUNT(*) INTO v_count FROM glpi_users WHERE pseudo = v_pseudo;
        EXIT WHEN v_count = 0;
        v_pseudo := v_pseudo_base || v_i;
        v_i := v_i + 1;
    END LOOP;

    -- ----------------------------------------------------
    -- 5. Insérer dans l'application (D'ABORD)
    -- ----------------------------------------------------
    BEGIN
        -- On insère l'utilisateur et on récupère son ID généré
        INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
        VALUES (v_pseudo, p_firstname, p_realname, v_entities_id, 1)
        RETURNING id INTO v_user_id;

        -- On le lie à son profil (SANS le 0 !)
        INSERT INTO glpi_profiles_users (users_id, profiles_id, entities_id)
        VALUES (v_user_id, v_profile_id, v_entities_id);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20014, 'Erreur inattendue lors de l''insertion dans les tables applicatives : ' || SQLERRM);
    END;

    -- ----------------------------------------------------
    -- 6. Créer le compte Oracle (À LA FIN)
    -- ----------------------------------------------------
    BEGIN
        EXECUTE IMMEDIATE
            'CREATE USER ' || v_pseudo || '_' || v_site ||
            ' IDENTIFIED BY "' || REPLACE(p_password, '"', '""') || '"' ||
            ' DEFAULT TABLESPACE TS_GLPI_REF';

        EXECUTE IMMEDIATE
            'GRANT R_GLPI_ADMIN TO ' || v_pseudo || '_' || v_site;
            
    EXCEPTION
        WHEN OTHERS THEN
            -- Le ROLLBACK annule les deux INSERT de l'étape 5 si la création Oracle plante !
            ROLLBACK; 
            RAISE_APPLICATION_ERROR(-20015, 'Erreur lors de la création de l''utilisateur Oracle. Action annulée. Cause : ' || SQLERRM);
    END;

    -- Si on arrive ici, tout s'est bien passé
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Admin créé : ' || v_pseudo || '_' || v_site);
END;
/

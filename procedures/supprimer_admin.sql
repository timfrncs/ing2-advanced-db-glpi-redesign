CREATE OR REPLACE PROCEDURE supprimer_admin(
    p_pseudo IN VARCHAR2
) AS
    v_user_id       NUMBER;
    v_entities_id   NUMBER;
    v_site          VARCHAR2(50);
    v_caller_site   VARCHAR2(50);
    v_nb_admins     NUMBER;
    v_is_admin      NUMBER;
    v_oracle_user   VARCHAR2(255);
BEGIN
    -- ----------------------------------------------------
    -- 1. Identifier l'appelant (Fail-Fast)
    -- ----------------------------------------------------
    IF USER != 'GLPI_OWNER' THEN
        v_caller_site := SUBSTR(
            SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
            INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
        );
    END IF;

    -- ----------------------------------------------------
    -- 2. Récupérer la cible (Isolé)
    -- ----------------------------------------------------
    BEGIN
        SELECT u.id, u.entities_id, UPPER(e.name)
        INTO v_user_id, v_entities_id, v_site
        FROM glpi_users u
        JOIN glpi_entities e ON e.id = u.entities_id
        WHERE UPPER(u.pseudo) = UPPER(p_pseudo)
        AND u.is_active = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20050, 'Erreur : Utilisateur introuvable ou déjà inactif (' || p_pseudo || ').');
    END;

    -- ----------------------------------------------------
    -- 3. Sécurité inter-sites
    -- ----------------------------------------------------
    IF USER != 'GLPI_OWNER' AND v_caller_site != v_site THEN
        RAISE_APPLICATION_ERROR(-20051, 'Action refusée : Vous ne pouvez supprimer que les administrateurs de votre propre site (' || v_caller_site || ').');
    END IF;

    -- ----------------------------------------------------
    -- 4. Validation du profil cible
    -- ----------------------------------------------------
    SELECT COUNT(*) INTO v_is_admin
    FROM glpi_profiles_users pu
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE pu.users_id = v_user_id
    AND UPPER(p.name) = 'ADMINISTRATEUR';

    IF v_is_admin = 0 THEN
        RAISE_APPLICATION_ERROR(-20052, 'Action refusée : L''utilisateur [' || p_pseudo || '] n''est pas un administrateur.');
    END IF;

    -- ----------------------------------------------------
    -- 5. Règle de sécurité "Last Man Standing"
    -- ----------------------------------------------------
    SELECT COUNT(*) INTO v_nb_admins
    FROM glpi_users u
    JOIN glpi_profiles_users pu ON pu.users_id = u.id
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE u.entities_id = v_entities_id
    AND u.is_active = 1
    AND UPPER(p.name) = 'ADMINISTRATEUR';

    IF v_nb_admins <= 1 THEN
        RAISE_APPLICATION_ERROR(-20053, 'Sécurité critique : Le site de ' || v_site || ' doit conserver au minimum 1 administrateur actif. Suppression annulée.');
    END IF;

    -- ----------------------------------------------------
    -- 6. Désactivation Applicative (Zone Transactionnelle)
    -- ----------------------------------------------------
    BEGIN
        -- Soft Delete dans la table
        UPDATE glpi_users SET is_active = 0 WHERE id = v_user_id;
        
        -- Révocation des droits GLPI
        DELETE FROM glpi_profiles_users WHERE users_id = v_user_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20054, 'Erreur lors de la mise à jour des tables GLPI : ' || SQLERRM);
    END;

    -- ----------------------------------------------------
    -- 7. Désactivation ORACLE (Le correctif de sécurité vital)
    -- ----------------------------------------------------
    BEGIN
        -- Reconstitution du nom du compte Oracle (comme fait dans ajouter_admin)
        v_oracle_user := UPPER(p_pseudo) || '_' || UPPER(v_site);
        
        -- On verrouille le compte au niveau du système Oracle
        EXECUTE IMMEDIATE 'ALTER USER ' || v_oracle_user || ' ACCOUNT LOCK';
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK; -- On annule la désactivation GLPI si le lock Oracle échoue
            RAISE_APPLICATION_ERROR(-20055, 'Erreur critique lors du verrouillage du compte système Oracle : ' || SQLERRM);
    END;

    -- ----------------------------------------------------
    -- 8. Validation finale
    -- ----------------------------------------------------
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCÈS : Admin [' || p_pseudo || '] désactivé sur ' || v_site || ' (Compte Oracle verrouillé).');
END;
/

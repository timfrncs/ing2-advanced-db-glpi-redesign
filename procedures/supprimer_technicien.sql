CREATE OR REPLACE PROCEDURE supprimer_technicien(
    p_pseudo IN VARCHAR2
) AS
    v_tech_id       NUMBER;
    v_entities_id   NUMBER;
    v_site          VARCHAR2(50);
    v_ent_site      NUMBER;
    v_is_tech       NUMBER;
    v_equip_ids     t_ids;
    v_oracle_user   VARCHAR2(255);
BEGIN
    -- ----------------------------------------------------
    -- 1. Identifier le site de l'appelant (Fail-Fast)
    -- ----------------------------------------------------
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    BEGIN
        SELECT id INTO v_ent_site
        FROM glpi_entities 
        WHERE UPPER(name) = v_site;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20100, 'Erreur de contexte : Votre site [' || v_site || '] est introuvable.');
    END;

    -- ----------------------------------------------------
    -- 2. Récupérer la cible (Isolé)
    -- ----------------------------------------------------
    BEGIN
        SELECT id, entities_id
        INTO v_tech_id, v_entities_id
        FROM glpi_users
        WHERE UPPER(pseudo) = UPPER(p_pseudo)
        AND is_active = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20101, 'Erreur : Technicien introuvable ou déjà inactif (' || p_pseudo || ').');
    END;

    -- ----------------------------------------------------
    -- 3. Contrôles de sécurité (Site et Rôle)
    -- ----------------------------------------------------
    IF v_entities_id != v_ent_site THEN
        RAISE_APPLICATION_ERROR(-20102, 'Action refusée : Ce technicien n''appartient pas à votre campus.');
    END IF;

    SELECT COUNT(*) INTO v_is_tech
    FROM glpi_profiles_users pu
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE pu.users_id = v_tech_id
    AND UPPER(p.name) = 'TECHNICIEN';

    IF v_is_tech = 0 THEN
        RAISE_APPLICATION_ERROR(-20103, 'Action refusée : L''utilisateur [' || p_pseudo || '] n''est pas un technicien.');
    END IF;

    -- ----------------------------------------------------
    -- 4. Actions Métier (Zone Transactionnelle Sécurisée)
    -- ----------------------------------------------------
    BEGIN
        -- Étape A : Récupérer et redistribuer ses équipements
        v_equip_ids := get_equip_technicien(v_tech_id);

        IF v_equip_ids.COUNT > 0 THEN
            redistribuer_equip(v_equip_ids, v_entities_id, v_tech_id);
            DBMS_OUTPUT.PUT_LINE('Information : ' || v_equip_ids.COUNT || ' équipement(s) réattribué(s) à d''autres techniciens.');
        END IF;

        -- Étape B : Soft Delete dans l'application
        UPDATE glpi_users SET is_active = 0 WHERE id = v_tech_id;
        DELETE FROM glpi_profiles_users WHERE users_id = v_tech_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20104, 'Erreur critique lors de la redistribution ou de la suppression applicative : ' || SQLERRM);
    END;

    -- ----------------------------------------------------
    -- 5. Désactivation ORACLE (La sécurité vitale)
    -- ----------------------------------------------------
    BEGIN
        -- Cas standard        : pseudo sans site -> FMARTIN_CERGY
        -- Cas copie cross-site : pseudo contient deja le site -> CBERNARD_CERGY
        --   => on essaie pseudo_SITE en premier ; si ORA-01918 (inexistant),
        --      on retente avec le pseudo tel quel (le site est deja inclus).
        v_oracle_user := UPPER(p_pseudo) || '_' || UPPER(v_site);
        BEGIN
            EXECUTE IMMEDIATE 'ALTER USER ' || v_oracle_user || ' ACCOUNT LOCK';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -1918 THEN
                    v_oracle_user := UPPER(p_pseudo);
                    EXECUTE IMMEDIATE 'ALTER USER ' || v_oracle_user || ' ACCOUNT LOCK';
                ELSE
                    RAISE;
                END IF;
        END;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20105, 'Erreur lors du verrouillage du compte Oracle. Opération totalement annulée : ' || SQLERRM);
    END;

    -- ----------------------------------------------------
    -- 6. Validation finale
    -- ----------------------------------------------------
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCÈS : Technicien [' || p_pseudo || '] désactivé avec succès (Accès applicatif retiré et compte système Oracle verrouillé).');

END;
/

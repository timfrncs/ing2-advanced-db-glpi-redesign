CREATE OR REPLACE PROCEDURE supprimer_utilisateur_lambda(
    p_pseudo IN VARCHAR2
) AS
    v_user_id       NUMBER;
    v_entities_id   NUMBER;
    v_site          VARCHAR2(50);
    v_ent_site      NUMBER;         -- Remonté ici
    v_has_profile   NUMBER;         -- Renommé pour plus de clarté
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
        FROM glpi_entities WHERE UPPER(name) = v_site;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20040, 'Erreur de contexte : Votre site [' || v_site || '] est introuvable.');
    END;

    -- ----------------------------------------------------
    -- 2. Récupérer la cible (Isolé)
    -- ----------------------------------------------------
    BEGIN
        SELECT id, entities_id INTO v_user_id, v_entities_id
        FROM glpi_users
        WHERE UPPER(pseudo) = UPPER(p_pseudo)
        AND is_active = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20041, 'Erreur : Utilisateur Lambda introuvable ou déjà inactif (' || p_pseudo || ').');
    END;

    -- ----------------------------------------------------
    -- 3. Contrôle de sécurité (Site)
    -- ----------------------------------------------------
    IF v_entities_id != v_ent_site THEN
        RAISE_APPLICATION_ERROR(-20042, 'Action refusée : Cet utilisateur n''appartient pas à votre campus (' || v_site || ').');
    END IF;

    -- ----------------------------------------------------
    -- 4. Vérifier que c'est bien un profil Lambda (Ni Tech, Ni Admin)
    -- ----------------------------------------------------
    SELECT COUNT(*) INTO v_has_profile
    FROM glpi_profiles_users pu
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE pu.users_id = v_user_id
    AND UPPER(p.name) IN ('TECHNICIEN', 'ADMINISTRATEUR');

    IF v_has_profile > 0 THEN
        RAISE_APPLICATION_ERROR(-20043, 'Action refusée : L''utilisateur [' || p_pseudo || '] possède des privilèges étendus. Utilisez la procédure appropriée (supprimer_technicien ou supprimer_admin).');
    END IF;

    -- ----------------------------------------------------
    -- 5. Désactivation Applicative (Zone Transactionnelle)
    -- ----------------------------------------------------
    BEGIN
        UPDATE glpi_users SET is_active = 0 WHERE id = v_user_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20044, 'Erreur critique lors de la désactivation applicative : ' || SQLERRM);
    END;

    -- ----------------------------------------------------
    -- 6. Validation finale
    -- ----------------------------------------------------
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCÈS : Utilisateur Lambda [' || p_pseudo || '] désactivé avec succès.');
END;
/

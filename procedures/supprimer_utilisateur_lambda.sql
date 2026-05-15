CREATE OR REPLACE PROCEDURE supprimer_utilisateur_lambda(
    p_pseudo IN VARCHAR2
) AS
    v_user_id       NUMBER;
    v_entities_id   NUMBER;
    v_site          VARCHAR2(50);
    v_is_tech       NUMBER;
    v_is_admin      NUMBER;
BEGIN
    -- Site de l'admin connecté
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    SELECT id, entities_id INTO v_user_id, v_entities_id
    FROM glpi_users
    WHERE UPPER(pseudo) = UPPER(p_pseudo)
    AND is_active = 1;

    -- Vérifier que l'user est bien sur le site de l'admin
    DECLARE v_ent_site NUMBER;
    BEGIN
        SELECT id INTO v_ent_site
        FROM glpi_entities WHERE UPPER(name) = v_site;

        IF v_entities_id != v_ent_site THEN
            RAISE_APPLICATION_ERROR(-20040,
                'Cet utilisateur n''appartient pas à votre site.');
        END IF;
    END;

    -- Vérifier que ce n'est ni un admin ni un technicien
    SELECT COUNT(*) INTO v_is_tech
    FROM glpi_profiles_users pu
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE pu.users_id = v_user_id
    AND UPPER(p.name) IN ('TECHNICIEN', 'ADMINISTRATEUR');

    IF v_is_tech > 0 THEN
        RAISE_APPLICATION_ERROR(-20041,
            'Utilisateur ' || p_pseudo ||
            ' est un technicien ou admin. Utilisez la procédure appropriée.');
    END IF;

    -- Désactiver
    UPDATE glpi_users SET is_active = 0 WHERE id = v_user_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Utilisateur ' || p_pseudo || ' désactivé.');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20042,
            'Utilisateur introuvable ou déjà inactif : ' || p_pseudo);
END;
/
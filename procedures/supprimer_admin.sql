CREATE OR REPLACE PROCEDURE supprimer_admin(
    p_pseudo IN VARCHAR2
) AS
    v_user_id       NUMBER;
    v_entities_id   NUMBER;
    v_site          VARCHAR2(50);
    v_caller_site   VARCHAR2(50);
    v_nb_admins     NUMBER;
    v_is_admin      NUMBER;
BEGIN
    -- Récupérer les infos de l'admin à supprimer
    SELECT u.id, u.entities_id, UPPER(e.name)
    INTO v_user_id, v_entities_id, v_site
    FROM glpi_users u
    JOIN glpi_entities e ON e.id = u.entities_id
    WHERE UPPER(u.pseudo) = UPPER(p_pseudo)
    AND u.is_active = 1;

    -- Vérifier que c'est bien un admin
    SELECT COUNT(*) INTO v_is_admin
    FROM glpi_profiles_users pu
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE pu.users_id = v_user_id
    AND UPPER(p.name) = 'ADMINISTRATEUR';

    IF v_is_admin = 0 THEN
        RAISE_APPLICATION_ERROR(-20050,
            p_pseudo || ' n''est pas un administrateur.');
    END IF;

    -- Si l'appelant est un admin (pas l'owner), vérifier le site
    IF SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER') IS NOT NULL THEN
        v_caller_site := SUBSTR(
            SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
            INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
        );

        IF v_caller_site != v_site THEN
            RAISE_APPLICATION_ERROR(-20051,
                'Vous ne pouvez supprimer que les admins de votre site.');
        END IF;
    END IF;

    -- Vérifier qu'il reste au moins 2 admins sur le site
    SELECT COUNT(*) INTO v_nb_admins
    FROM glpi_users u
    JOIN glpi_profiles_users pu ON pu.users_id = u.id
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE u.entities_id = v_entities_id
    AND u.is_active = 1
    AND UPPER(p.name) = 'ADMINISTRATEUR';

    IF v_nb_admins <= 1 THEN
        RAISE_APPLICATION_ERROR(-20052,
            'Impossible : ' || v_site ||
            ' doit conserver au minimum 1 administrateur actif.');
    END IF;

    -- Désactiver
    UPDATE glpi_users SET is_active = 0 WHERE id = v_user_id;
    DELETE FROM glpi_profiles_users
    WHERE users_id = v_user_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Admin ' || p_pseudo || ' désactivé sur ' || v_site);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20053,
            'Admin introuvable ou déjà inactif : ' || p_pseudo);
END;
/
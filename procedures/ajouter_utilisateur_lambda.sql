CREATE OR REPLACE PROCEDURE ajouter_utilisateur_lambda(
    p_firstname IN VARCHAR2,
    p_realname  IN VARCHAR2
) AS
    v_pseudo        VARCHAR2(255);
    v_entities_id   NUMBER;
    v_count         NUMBER;
BEGIN
    -- Vérifier que l'appelant est un admin
    IF SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER') NOT LIKE '%|CERGY%'
    AND SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER') NOT LIKE '%|PAU%' THEN
        RAISE_APPLICATION_ERROR(-20010, 
            'Seul un admin peut créer un utilisateur.');
    END IF;

    -- Récupérer le site de l'admin connecté
    SELECT id INTO v_entities_id
    FROM glpi_entities
    WHERE UPPER(name) = SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    -- Générer le pseudo : initiale prénom + nom en majuscules
    v_pseudo := UPPER(SUBSTR(p_firstname, 1, 1)) || UPPER(p_realname);

    -- Gérer les homonymes avec la séquence de secours
    SELECT COUNT(*) INTO v_count
    FROM glpi_users
    WHERE pseudo = v_pseudo;

    IF v_count > 0 THEN
        v_pseudo := v_pseudo || seq_users_pseudo.NEXTVAL;
    END IF;

    INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
    VALUES (v_pseudo, p_firstname, p_realname, v_entities_id, 1);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Utilisateur créé : ' || v_pseudo);
END;
/
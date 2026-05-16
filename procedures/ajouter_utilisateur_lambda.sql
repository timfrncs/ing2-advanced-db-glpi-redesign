CREATE OR REPLACE PROCEDURE ajouter_utilisateur_lambda(
    p_firstname IN VARCHAR2,
    p_realname  IN VARCHAR2
) AS
    v_pseudo        VARCHAR2(255);
    v_pseudo_base   VARCHAR2(255);
    v_entities_id   NUMBER;
    v_site          VARCHAR2(50);
    v_count         NUMBER;
    v_i             NUMBER := 1; -- Utilisé pour gérer les homonymes proprement
BEGIN
    -- ----------------------------------------------------
    -- 1. Contrôle de sécurité sur l'appelant
    -- ----------------------------------------------------
    IF SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER') NOT LIKE '%|CERGY%'
    AND SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER') NOT LIKE '%|PAU%' THEN
        RAISE_APPLICATION_ERROR(-20010, 'Privilège insuffisant : Seul un administrateur connecté à un site peut créer un utilisateur.');
    END IF;

    -- Extraction propre du nom du site pour le message d'erreur au cas où
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    -- ----------------------------------------------------
    -- 2. Récupérer l'ID de l'entité (Isolé)
    -- ----------------------------------------------------
    BEGIN
        SELECT id INTO v_entities_id
        FROM glpi_entities
        WHERE UPPER(name) = UPPER(v_site);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20011, 'Erreur : Impossible de lier l''utilisateur. Le site [' || v_site || '] extrait de votre session est introuvable.');
    END;

    -- ----------------------------------------------------
    -- 3. Générer le pseudo avec boucle anti-homonymes
    -- ----------------------------------------------------
    v_pseudo_base := UPPER(SUBSTR(p_firstname, 1, 1)) || UPPER(p_realname);
    v_pseudo := v_pseudo_base;

    -- Boucle infinie sécurisée qui teste jusqu'à trouver un pseudo totalement libre
    LOOP
        SELECT COUNT(*) INTO v_count FROM glpi_users WHERE pseudo = v_pseudo;
        EXIT WHEN v_count = 0;
        v_pseudo := v_pseudo_base || v_i;
        v_i := v_i + 1;
    END LOOP;

    -- ----------------------------------------------------
    -- 4. Insertion applicative (Sécurisée)
    -- ----------------------------------------------------
    BEGIN
        INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
        VALUES (v_pseudo, p_firstname, p_realname, v_entities_id, 1);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK; -- On annule si la base refuse l'écriture
            RAISE_APPLICATION_ERROR(-20012, 'Erreur critique lors de l''insertion de l''utilisateur Lambda : ' || SQLERRM);
    END;

    -- Validation de la transaction
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCÈS : Utilisateur Lambda créé : ' || v_pseudo || ' sur le site ' || v_site);
END;
/

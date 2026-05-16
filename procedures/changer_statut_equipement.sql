CREATE OR REPLACE PROCEDURE changer_statut_equipement(
    p_equip_name IN VARCHAR2,
    p_new_status IN NUMBER
) AS
    v_equip_id      NUMBER;
    v_entities_id   NUMBER;
    v_site          VARCHAR2(50);
    v_ent_site      NUMBER;
    v_itemtype      VARCHAR2(100);
BEGIN
    -- ----------------------------------------------------
    -- 1. Validation métier du statut
    -- ----------------------------------------------------
    IF p_new_status NOT IN (1, 2, 3, 4) THEN
        RAISE_APPLICATION_ERROR(-20060, 'Erreur : Statut invalide. Valeurs autorisées : 1=En service, 2=En stock, 3=En réparation, 4=Rebut.');
    END IF;

    -- ----------------------------------------------------
    -- 2. Identifier le site de l'appelant (Contexte)
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
            RAISE_APPLICATION_ERROR(-20061, 'Erreur de contexte : Le site [' || v_site || '] est introuvable.');
    END;

    -- ----------------------------------------------------
    -- 3. Récupérer les informations de l'équipement
    -- ----------------------------------------------------
    BEGIN
        SELECT id, entities_id, itemtype
        INTO v_equip_id, v_entities_id, v_itemtype
        FROM glpi_equipments
        WHERE UPPER(name) = UPPER(p_equip_name)
        AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20062, 'Erreur : Équipement introuvable pour le nom : ' || p_equip_name);
    END;

    -- ----------------------------------------------------
    -- 4. Sécurité : Vérifier les droits sur le site
    -- ----------------------------------------------------
    IF v_entities_id != v_ent_site THEN
        RAISE_APPLICATION_ERROR(-20063, 'Action refusée : Cet équipement appartient à un autre campus. Vous ne pouvez modifier que les équipements de votre site.');
    END IF;

    -- ----------------------------------------------------
    -- 5. Mise à jour (Zone transactionnelle sécurisée)
    -- ----------------------------------------------------
    BEGIN
        IF v_itemtype = 'Computer' THEN
            UPDATE glpi_computers 
            SET states_id = p_new_status
            WHERE id = v_equip_id;
        ELSIF v_itemtype = 'Printer' THEN
            UPDATE glpi_printers 
            SET states_id = p_new_status
            WHERE id = v_equip_id;
        ELSE
            -- Sécurité au cas où un nouveau type d'équipement serait ajouté plus tard sans mettre à jour cette procédure
            RAISE_APPLICATION_ERROR(-20064, 'Type d''équipement non pris en charge : ' || v_itemtype);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20065, 'Erreur critique lors de la mise à jour du statut : ' || SQLERRM);
    END;

    -- ----------------------------------------------------
    -- 6. Validation finale
    -- ----------------------------------------------------
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCÈS : Le statut de l''équipement [' || p_equip_name || '] a bien été mis à jour (Nouveau statut : ' || p_new_status || ').');

END;
/

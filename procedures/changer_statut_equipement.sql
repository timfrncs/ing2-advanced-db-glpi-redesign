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
    -- Vérifier le statut
    IF p_new_status NOT IN (1, 2, 3, 4) THEN
        RAISE_APPLICATION_ERROR(-20060,
            'Statut invalide. Valeurs : 1=En service, 2=En stock, ' ||
            '3=En réparation, 4=Rebut.');
    END IF;

    -- Récupérer l'équipement
    SELECT id, entities_id, itemtype
    INTO v_equip_id, v_entities_id, v_itemtype
    FROM glpi_equipments
    WHERE UPPER(name) = UPPER(p_equip_name)
    AND ROWNUM = 1;

    -- Vérifier que l'équipement est sur le site de l'appelant
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    SELECT id INTO v_ent_site
    FROM glpi_entities WHERE UPPER(name) = v_site;

    IF v_entities_id != v_ent_site THEN
        RAISE_APPLICATION_ERROR(-20061,
            'Équipement hors de votre site.');
    END IF;

    -- Mettre à jour dans la bonne table fille
    IF v_itemtype = 'Computer' THEN
        UPDATE glpi_computers SET states_id = p_new_status
        WHERE id = v_equip_id;
    ELSIF v_itemtype = 'Printer' THEN
        UPDATE glpi_printers SET states_id = p_new_status
        WHERE id = v_equip_id;
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Statut de ' || p_equip_name ||
                         ' mis à jour : ' || p_new_status);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20062,
            'Équipement introuvable : ' || p_equip_name);
END;
/
CREATE OR REPLACE PROCEDURE ajouter_equipement(
    p_serial    IN VARCHAR2,
    p_itemtype  IN VARCHAR2   -- 'Computer' ou 'Printer'
) AS
    v_site          VARCHAR2(50);
    v_entities_id   NUMBER;
    v_network_id    NUMBER;
    v_ip_id         NUMBER;
    v_equip_id      NUMBER;
    v_ip_address    VARCHAR2(20);
    v_equip_name    VARCHAR2(255);
    v_host_seq      NUMBER;
BEGIN
    -- Valider le type
    IF p_itemtype NOT IN ('Computer', 'Printer') THEN
        RAISE_APPLICATION_ERROR(-20080,
            'Type invalide. Valeurs acceptées : Computer, Printer.');
    END IF;

    -- Récupérer le site de l'appelant
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    SELECT id INTO v_entities_id
    FROM glpi_entities WHERE UPPER(name) = v_site;

    -- Récupérer le réseau du site
    SELECT id INTO v_network_id
    FROM glpi_networks
    WHERE entities_id = v_entities_id
    AND ROWNUM = 1;

    -- Générer l'IP selon le site
    v_host_seq := seq_ip_host.NEXTVAL;

    IF v_site = 'CERGY' THEN
    v_ip_address := '10.1.0.' || seq_ip_host_cergy.NEXTVAL;
    ELSE
    v_ip_address := '10.2.0.' || seq_ip_host_pau.NEXTVAL;
    END IF;

    -- Insérer l'adresse IP
    INSERT INTO glpi_ipaddresses (name, networks_id)
    VALUES (v_ip_address, v_network_id)
    RETURNING id INTO v_ip_id;

    -- Insérer dans glpi_equipments (table mère)
    INSERT INTO glpi_equipments (
        name, itemtype, entities_id, ipaddresses_id
    ) VALUES (
        v_equip_name, p_itemtype, v_entities_id, v_ip_id
    )
    RETURNING id INTO v_equip_id;

    -- Insérer dans la table fille avec statut En stock (2)
    IF p_itemtype = 'Computer' THEN
        INSERT INTO glpi_computers (id, serial, states_id)
        VALUES (v_equip_id, p_serial, 2);
    ELSE
        INSERT INTO glpi_printers (id, serial, states_id)
        VALUES (v_equip_id, p_serial, 2);
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Équipement créé : ' || v_equip_name ||
                         ' — IP : ' || v_ip_address ||
                         ' — Série : ' || p_serial);

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20081,
            'Numéro de série déjà existant : ' || p_serial);
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20082,
            'Site ou réseau introuvable pour : ' || v_site);
END;
/
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
BEGIN
    -- ----------------------------------------------------
    -- 1. Validation métier initiale
    -- ----------------------------------------------------
    IF p_itemtype NOT IN ('Computer', 'Printer') THEN
        RAISE_APPLICATION_ERROR(-20080, 'Erreur : Type invalide. Valeurs acceptées : Computer, Printer.');
    END IF;

    -- Récupérer le site de l'appelant
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    -- ----------------------------------------------------
    -- 2. Recherche du Site et du Réseau (Exceptions isolées)
    -- ----------------------------------------------------
    BEGIN
        SELECT id INTO v_entities_id
        FROM glpi_entities 
        WHERE UPPER(name) = v_site;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20081, 'Erreur : Le site [' || v_site || '] est introuvable.');
    END;

    BEGIN
        SELECT id INTO v_network_id
        FROM glpi_networks
        WHERE entities_id = v_entities_id
        AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20082, 'Erreur : Aucun réseau (network) configuré pour le site [' || v_site || '].');
    END;

    -- ----------------------------------------------------
    -- 3. Génération des noms et IPs
    -- ----------------------------------------------------
    IF v_site = 'CERGY' THEN
        v_ip_address := '10.1.0.' || seq_ip_host_cergy.NEXTVAL;
        v_equip_name := 'EQ-' || seq_equip_cergy.NEXTVAL;
    ELSE
        v_ip_address := '10.2.0.' || seq_ip_host_pau.NEXTVAL;
        v_equip_name := 'EQ-' || seq_equip_pau.NEXTVAL;
    END IF;

    -- ----------------------------------------------------
    -- 4. Insertions en cascade (Zone transactionnelle)
    -- ----------------------------------------------------
    BEGIN
        -- Insérer l'adresse IP
        INSERT INTO glpi_ipaddresses (name, networks_id)
        VALUES (v_ip_address, v_network_id)
        RETURNING id INTO v_ip_id;

        -- Insérer dans glpi_equipments (table mère)
        INSERT INTO glpi_equipments (name, itemtype, entities_id, ipaddresses_id) 
        VALUES (v_equip_name, p_itemtype, v_entities_id, v_ip_id)
        RETURNING id INTO v_equip_id;

        -- Insérer dans la table fille avec statut En stock (2)
        IF p_itemtype = 'Computer' THEN
            INSERT INTO glpi_computers (id, serial, states_id)
            VALUES (v_equip_id, p_serial, 2);
        ELSE
            INSERT INTO glpi_printers (id, serial, states_id)
            VALUES (v_equip_id, p_serial, 2);
        END IF;

    EXCEPTION
        -- Si un doublon (Numéro de série) ou toute autre erreur arrive ici, on annule TOUT.
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20083, 'Erreur : Le numéro de série [' || p_serial || '] existe déjà dans le parc.');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20084, 'Erreur critique lors des insertions : ' || SQLERRM);
    END;

    -- ----------------------------------------------------
    -- 5. Validation finale
    -- ----------------------------------------------------
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCÈS : Équipement créé : ' || v_equip_name ||
                         ' — IP : ' || v_ip_address ||
                         ' — Série : ' || p_serial);
END;
/

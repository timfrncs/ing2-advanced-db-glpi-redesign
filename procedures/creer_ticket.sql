CREATE OR REPLACE PROCEDURE creer_ticket(
    p_users_id      IN NUMBER,
    p_equip_name    IN VARCHAR2,
    p_contenu       IN CLOB
) AS
    v_equip_id      NUMBER;
    v_entities_id   NUMBER;
    v_location_id   NUMBER;
    v_count         NUMBER;
    v_ticket_name   VARCHAR2(255);
    v_site          VARCHAR2(50);
BEGIN
    -- Retrouver l'équipement par son nom
    SELECT eq.id, eq.entities_id, eq.locations_id, UPPER(e.name)
    INTO v_equip_id, v_entities_id, v_location_id, v_site
    FROM glpi_equipments eq
    JOIN glpi_entities e ON e.id = eq.entities_id
    WHERE UPPER(eq.name) = UPPER(p_equip_name)
    AND ROWNUM = 1;

    -- Vérifier que le user existe et est actif
    SELECT COUNT(*) INTO v_count
    FROM glpi_users WHERE id = p_users_id AND is_active = 1;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20020,
            'Utilisateur introuvable ou inactif : id=' || p_users_id);
    END IF;

    -- Générer le nom du ticket selon le site
    IF v_site = 'CERGY' THEN
        v_ticket_name := 'TKT-' || seq_ticket_cergy.NEXTVAL;
    ELSE
        v_ticket_name := 'TKT-' || seq_ticket_pau.NEXTVAL;
    END IF;

    -- Insérer le ticket
    -- tr_ticket_equip_entity vérifie automatiquement la cohérence des entités
    INSERT INTO glpi_tickets (
        name, content, status,
        entities_id, locations_id,
        equipment_id, users_id
    ) VALUES (
        v_ticket_name, p_contenu, 1,
        v_entities_id, v_location_id,
        v_equip_id, p_users_id
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Ticket créé : ' || v_ticket_name ||
                         ' sur équipement : ' || p_equip_name);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20021,
            'Équipement introuvable : ' || p_equip_name);
END;
/
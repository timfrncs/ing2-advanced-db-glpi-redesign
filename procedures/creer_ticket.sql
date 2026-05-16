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
    v_states_id     NUMBER; -- Remonté ici pour plus de propreté
BEGIN
    -- ----------------------------------------------------
    -- 1. Validation Fail-Fast : L'utilisateur d'abord
    -- ----------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM glpi_users 
    WHERE id = p_users_id AND is_active = 1;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20020, 'Action refusée : Utilisateur introuvable ou inactif (ID=' || p_users_id || ').');
    END IF;

    -- ----------------------------------------------------
    -- 2. Récupération GLOBALE de l'équipement (Optimisé en 1 requête)
    -- ----------------------------------------------------
    BEGIN
        SELECT eq.id, 
               eq.entities_id, 
               eq.locations_id, 
               UPPER(e.name),
               COALESCE(c.states_id, p.states_id) -- On récupère l'état directement ici !
        INTO v_equip_id, v_entities_id, v_location_id, v_site, v_states_id
        FROM glpi_equipments eq
        JOIN glpi_entities e ON e.id = eq.entities_id
        LEFT JOIN glpi_computers c ON c.id = eq.id
        LEFT JOIN glpi_printers  p ON p.id = eq.id
        WHERE UPPER(eq.name) = UPPER(p_equip_name)
        AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20021, 'Erreur : Équipement introuvable sous le nom : ' || p_equip_name);
    END;

    -- ----------------------------------------------------
    -- 3. Validation Métier : L'équipement doit être "En service" (1)
    -- ----------------------------------------------------
    IF v_states_id != 1 THEN
        RAISE_APPLICATION_ERROR(-20022, 
            'Création de ticket impossible : l''équipement [' || p_equip_name || 
            '] n''est pas actuellement en service (Statut actuel = ' || v_states_id || ').');
    END IF;

    -- ----------------------------------------------------
    -- 4. Génération du numéro de ticket (Selon le site)
    -- ----------------------------------------------------
    IF v_site = 'CERGY' THEN
        v_ticket_name := 'TKT-' || seq_ticket_cergy.NEXTVAL;
    ELSE
        v_ticket_name := 'TKT-' || seq_ticket_pau.NEXTVAL;
    END IF;

    -- ----------------------------------------------------
    -- 5. Insertion (Zone Transactionnelle Sécurisée)
    -- ----------------------------------------------------
    BEGIN
        -- Note: le trigger tr_ticket_equip_entity vérifie la cohérence derrière
        INSERT INTO glpi_tickets (
            name, content, status, entities_id, locations_id, equipment_id, users_id
        ) VALUES (
            v_ticket_name, p_contenu, 1, v_entities_id, v_location_id, v_equip_id, p_users_id
        );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20023, 'Erreur critique lors de l''enregistrement du ticket : ' || SQLERRM);
    END;

    -- ----------------------------------------------------
    -- 6. Validation Finale
    -- ----------------------------------------------------
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCÈS : Ticket ouvert [' || v_ticket_name || '] sur l''équipement [' || p_equip_name || '].');

END;
/

CREATE OR REPLACE PROCEDURE modifier_statut_ticket(
    p_ticket_id     IN NUMBER,
    p_new_status    IN NUMBER
) AS
    v_old_status    NUMBER;
    v_equip_ent     NUMBER;
    v_ticket_equip  NUMBER;
    
    v_pseudo        VARCHAR2(255);
    v_site          VARCHAR2(50);
    v_ent_site      NUMBER;         -- Remonté
    v_is_admin      NUMBER := 0;
    
    v_tech_id       NUMBER;
    v_tech_equip    NUMBER;
BEGIN
    -- ----------------------------------------------------
    -- 1. Identifier l'appelant en premier (Fail-Fast)
    -- ----------------------------------------------------
    v_pseudo := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), 1,
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') - 1
    );
    
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    BEGIN
        SELECT id INTO v_ent_site FROM glpi_entities WHERE UPPER(name) = v_site;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20030, 'Erreur de sécurité : Site [' || v_site || '] introuvable.');
    END;

    -- ----------------------------------------------------
    -- 2. Récupérer les infos du ticket (Isolé)
    -- ----------------------------------------------------
    BEGIN
        SELECT t.status, t.equipment_id, eq.entities_id
        INTO v_old_status, v_ticket_equip, v_equip_ent
        FROM glpi_tickets t
        JOIN glpi_equipments eq ON eq.id = t.equipment_id
        WHERE t.id = p_ticket_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20031, 'Erreur : Ticket introuvable (ID: ' || p_ticket_id || ').');
    END;

    -- ----------------------------------------------------
    -- 3. Logique de transition (Machine à états)
    -- ----------------------------------------------------
    IF v_old_status IN (4, 5) THEN
        RAISE_APPLICATION_ERROR(-20032, 'Action refusée : Impossible de modifier un ticket Résolu(4) ou Clos(5).');
    END IF;

    IF v_old_status = 1 AND p_new_status NOT IN (2, 3, 5) THEN
        RAISE_APPLICATION_ERROR(-20033, 'Transition invalide : Impossible de passer de Nouveau(1) à ' || p_new_status);
    ELSIF v_old_status = 2 AND p_new_status NOT IN (3, 4, 5) THEN
        RAISE_APPLICATION_ERROR(-20033, 'Transition invalide : Impossible de passer de En cours(2) à ' || p_new_status);
    ELSIF v_old_status = 3 AND p_new_status NOT IN (2, 5) THEN
        RAISE_APPLICATION_ERROR(-20033, 'Transition invalide : Impossible de passer de En attente(3) à ' || p_new_status);
    END IF;

    -- ----------------------------------------------------
    -- 4. Sécurité d'accès (Admin vs Technicien)
    -- ----------------------------------------------------
    -- L'utilisateur est-il Admin ?
    SELECT COUNT(*) INTO v_is_admin
    FROM glpi_users u
    JOIN glpi_profiles_users pu ON pu.users_id = u.id
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE UPPER(u.pseudo) = v_pseudo
    AND UPPER(p.name) = 'ADMINISTRATEUR';

    IF v_is_admin = 1 THEN
        -- Règle Admin : Il doit être sur le même site que l'équipement du ticket
        IF v_equip_ent != v_ent_site THEN
            RAISE_APPLICATION_ERROR(-20034, 'Action refusée (Admin) : Ce ticket appartient à un autre campus.');
        END IF;
    ELSE
        -- Règle Technicien : Il doit être le responsable attitré de la machine
        BEGIN
            SELECT id INTO v_tech_id FROM glpi_users WHERE UPPER(pseudo) = v_pseudo AND is_active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20035, 'Erreur : Technicien introuvable ou inactif.');
        END;

        
        SELECT COUNT(*) INTO v_tech_equip
        FROM glpi_equipments eq
        LEFT JOIN glpi_computers c ON c.id = eq.id
        LEFT JOIN glpi_printers p ON p.id = eq.id
        WHERE eq.id = v_ticket_equip
        AND (c.users_id_tech = v_tech_id OR p.users_id_tech = v_tech_id);

        IF v_tech_equip = 0 THEN
            RAISE_APPLICATION_ERROR(-20036, 'Action refusée (Tech) : Vous n''êtes pas le technicien assigné à l''équipement concerné par ce ticket.');
        END IF;
    END IF;

    -- ----------------------------------------------------
    -- 5. Mise à jour (Zone Transactionnelle)
    -- ----------------------------------------------------
    BEGIN
        UPDATE glpi_tickets
        SET status = p_new_status
        WHERE id = p_ticket_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20037, 'Erreur critique lors de la mise à jour du ticket : ' || SQLERRM);
    END;

    -- ----------------------------------------------------
    -- 6. Validation
    -- ----------------------------------------------------
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCÈS : Ticket ' || p_ticket_id || ' avancé (Statut ' || v_old_status || ' → ' || p_new_status || ').');

END;
/

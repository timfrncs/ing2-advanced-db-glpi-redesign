CREATE OR REPLACE PROCEDURE modifier_statut_ticket(
    p_ticket_id     IN NUMBER,
    p_new_status    IN NUMBER
) AS
    v_old_status    NUMBER;
    v_equip_ent     NUMBER;
    v_ticket_equip  NUMBER;
    v_tech_id       NUMBER;
    v_tech_equip    NUMBER;
    v_site          VARCHAR2(50);
    v_pseudo        VARCHAR2(255);
    v_is_admin      NUMBER := 0;

    -- Transitions autorisées
    TYPE t_transitions IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    -- On vérifiera manuellement selon le statut courant
BEGIN
    -- Récupérer les infos du ticket
    SELECT t.status, t.equipment_id, eq.entities_id
    INTO v_old_status, v_ticket_equip, v_equip_ent
    FROM glpi_tickets t
    JOIN glpi_equipments eq ON eq.id = t.equipment_id
    WHERE t.id = p_ticket_id;

    -- Bloquer les tickets terminaux
    IF v_old_status IN (4, 5) THEN
        RAISE_APPLICATION_ERROR(-20030,
            'Impossible de modifier un ticket Résolu ou Clos.');
    END IF;

    -- Vérifier la transition
    IF v_old_status = 1 AND p_new_status NOT IN (2, 3, 5) THEN
        RAISE_APPLICATION_ERROR(-20031,
            'Transition invalide depuis Nouveau vers statut ' || p_new_status);
    ELSIF v_old_status = 2 AND p_new_status NOT IN (3, 4, 5) THEN
        RAISE_APPLICATION_ERROR(-20031,
            'Transition invalide depuis En cours vers statut ' || p_new_status);
    ELSIF v_old_status = 3 AND p_new_status NOT IN (2, 5) THEN
        RAISE_APPLICATION_ERROR(-20031,
            'Transition invalide depuis En attente vers statut ' || p_new_status);
    END IF;

    -- Identifier l'appelant
    v_pseudo := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), 1,
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') - 1
    );
    v_site := SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
    );

    -- Est-ce un admin ?
    SELECT COUNT(*) INTO v_is_admin
    FROM glpi_users u
    JOIN glpi_profiles_users pu ON pu.users_id = u.id
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE UPPER(u.pseudo) = v_pseudo
    AND UPPER(p.name) = 'ADMINISTRATEUR';

    IF v_is_admin = 1 THEN
        -- Admin : peut modifier tous les tickets de son site
        DECLARE v_ent_site NUMBER;
        BEGIN
            SELECT id INTO v_ent_site
            FROM glpi_entities WHERE UPPER(name) = v_site;

            IF v_equip_ent != v_ent_site THEN
                RAISE_APPLICATION_ERROR(-20032,
                    'Ce ticket n''appartient pas à votre site.');
            END IF;
        END;
    ELSE
        -- Technicien : uniquement ses propres équipements
        SELECT u.id INTO v_tech_id
        FROM glpi_users u
        WHERE UPPER(u.pseudo) = v_pseudo;

        SELECT COUNT(*) INTO v_tech_equip
        FROM glpi_computers
        WHERE id = v_ticket_equip
        AND users_id_tech = v_tech_id;

        IF v_tech_equip = 0 THEN
            RAISE_APPLICATION_ERROR(-20033,
                'Ce ticket ne concerne pas un de vos équipements.');
        END IF;
    END IF;

    -- Mettre à jour le statut
    UPDATE glpi_tickets
    SET status = p_new_status
    WHERE id = p_ticket_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Ticket ' || p_ticket_id ||
                         ' : statut ' || v_old_status ||
                         ' → ' || p_new_status);
END;
/
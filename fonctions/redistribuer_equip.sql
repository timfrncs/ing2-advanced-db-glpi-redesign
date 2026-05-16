-- Fonction : redistribue une liste d'équipements entre les techniciens restants
CREATE OR REPLACE PROCEDURE redistribuer_equip(
    p_equip_ids     IN t_ids,
    p_entities_id   IN NUMBER,
    p_tech_exclu    IN NUMBER   -- ID du technicien supprimé, à exclure
) AS
    TYPE t_tech_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_tech_ids      t_tech_ids;
    v_nb_tech       NUMBER;
    v_idx_tech      NUMBER := 1;

    CURSOR cur_techniciens IS
        SELECT DISTINCT users_id_tech
        FROM glpi_computers c
        JOIN glpi_equipments eq ON eq.id = c.id
        WHERE eq.entities_id = p_entities_id
        AND c.users_id_tech IS NOT NULL
        AND c.users_id_tech != p_tech_exclu
        UNION
        SELECT DISTINCT users_id_tech
        FROM glpi_printers p
        JOIN glpi_equipments eq ON eq.id = p.id
        WHERE eq.entities_id = p_entities_id
        AND p.users_id_tech IS NOT NULL
        AND p.users_id_tech != p_tech_exclu;
BEGIN
    -- Charger les techniciens restants
    FOR rec IN cur_techniciens LOOP
        v_tech_ids(v_tech_ids.COUNT + 1) := rec.users_id_tech;
    END LOOP;

    v_nb_tech := v_tech_ids.COUNT;

    IF v_nb_tech = 0 THEN
        -- Aucun technicien restant : on laisse les équipements sans responsable
        DBMS_OUTPUT.PUT_LINE('Aucun technicien restant sur le site.');
        RETURN;
    END IF;

    -- Distribuer round-robin : équipement 1 → tech 1, équipement 2 → tech 2...
    FOR i IN 1..p_equip_ids.COUNT LOOP
        -- Déterminer dans quelle table mettre à jour
        DECLARE
            v_itemtype VARCHAR2(100);
        BEGIN
            SELECT itemtype INTO v_itemtype
            FROM glpi_equipments WHERE id = p_equip_ids(i);

            IF v_itemtype = 'Computer' THEN
                UPDATE glpi_computers SET users_id_tech = v_tech_ids(v_idx_tech)
                WHERE id = p_equip_ids(i);
            ELSE
                UPDATE glpi_printers SET users_id_tech = v_tech_ids(v_idx_tech)
                WHERE id = p_equip_ids(i);
            END IF;
        END;

        -- Passer au technicien suivant (round-robin)
        v_idx_tech := MOD(v_idx_tech, v_nb_tech) + 1;
    END LOOP;
END;
/
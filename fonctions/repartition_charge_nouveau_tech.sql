-- TYPE nécessaire pour retourner une liste d'IDs
CREATE OR REPLACE TYPE t_ids AS TABLE OF NUMBER;
/

CREATE OR REPLACE FUNCTION repartition_charge_nouveau_tech(
    p_entities_id IN NUMBER
) RETURN t_ids AS
    v_ids           t_ids := t_ids();
    v_nb_equip      NUMBER;
    v_nb_tech       NUMBER;
    v_quota         NUMBER;  -- équipements par technicien après répartition
    v_a_retirer     NUMBER;  -- équipements à retirer à chaque technicien existant

    -- Charge totale (computers + printers) par technicien
    CURSOR cur_techniciens IS
        SELECT tech_id, SUM(nb) AS nb_equip
        FROM (
            SELECT c.users_id_tech AS tech_id, COUNT(*) AS nb
            FROM glpi_computers c
            JOIN glpi_equipments eq ON eq.id = c.id
            WHERE eq.entities_id = p_entities_id
            AND c.users_id_tech IS NOT NULL
            GROUP BY c.users_id_tech
            UNION ALL
            SELECT p.users_id_tech AS tech_id, COUNT(*) AS nb
            FROM glpi_printers p
            JOIN glpi_equipments eq ON eq.id = p.id
            WHERE eq.entities_id = p_entities_id
            AND p.users_id_tech IS NOT NULL
            GROUP BY p.users_id_tech
        )
        GROUP BY tech_id;

    -- Équipements redistribuables (computers ET printers) sans ticket bloquant
    CURSOR cur_equip_eligible(p_tech_id NUMBER, p_nb NUMBER) IS
        SELECT eq.id
        FROM glpi_equipments eq
        WHERE eq.entities_id = p_entities_id
        AND (
            (eq.itemtype = 'Computer' AND EXISTS (
                SELECT 1 FROM glpi_computers c
                WHERE c.id = eq.id AND c.users_id_tech = p_tech_id
            ))
            OR
            (eq.itemtype = 'Printer' AND EXISTS (
                SELECT 1 FROM glpi_printers p
                WHERE p.id = eq.id AND p.users_id_tech = p_tech_id
            ))
        )
        AND NOT EXISTS (
            SELECT 1 FROM glpi_tickets t
            WHERE t.equipment_id = eq.id
            AND t.status IN (2, 3)  -- En cours ou En attente = bloquant
        )
        ORDER BY DBMS_RANDOM.VALUE
        FETCH FIRST p_nb ROWS ONLY;

BEGIN
    -- Total équipements du site (computers + printers)
    SELECT COUNT(*) INTO v_nb_equip
    FROM glpi_equipments
    WHERE entities_id = p_entities_id;

    -- Techniciens actuels : ceux ayant au moins un équipement assigné (computer ou printer)
    SELECT COUNT(DISTINCT tech_id) INTO v_nb_tech
    FROM (
        SELECT c.users_id_tech AS tech_id
        FROM glpi_computers c
        JOIN glpi_equipments eq ON eq.id = c.id
        WHERE eq.entities_id = p_entities_id
        AND c.users_id_tech IS NOT NULL
        UNION
        SELECT p.users_id_tech AS tech_id
        FROM glpi_printers p
        JOIN glpi_equipments eq ON eq.id = p.id
        WHERE eq.entities_id = p_entities_id
        AND p.users_id_tech IS NOT NULL
    );

    -- Quota cible après ajout du nouveau technicien
    v_quota := FLOOR(v_nb_equip / (v_nb_tech + 1));

    -- Pour chaque technicien existant, on retire les équipements excédentaires
    FOR rec IN cur_techniciens LOOP
        v_a_retirer := rec.nb_equip - v_quota;

        IF v_a_retirer > 0 THEN
            FOR eq_rec IN cur_equip_eligible(rec.tech_id, v_a_retirer) LOOP
                v_ids.EXTEND;
                v_ids(v_ids.COUNT) := eq_rec.id;

                -- Désassigner selon le type
                UPDATE glpi_computers
                SET users_id_tech = NULL
                WHERE id = eq_rec.id
                AND EXISTS (SELECT 1 FROM glpi_equipments WHERE id = eq_rec.id AND itemtype = 'Computer');

                UPDATE glpi_printers
                SET users_id_tech = NULL
                WHERE id = eq_rec.id
                AND EXISTS (SELECT 1 FROM glpi_equipments WHERE id = eq_rec.id AND itemtype = 'Printer');
            END LOOP;
        END IF;
    END LOOP;

    RETURN v_ids;
END;
/

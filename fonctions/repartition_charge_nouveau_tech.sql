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

    CURSOR cur_techniciens IS
        SELECT DISTINCT c.users_id_tech AS tech_id,
               COUNT(c.id) AS nb_equip
        FROM glpi_computers c
        JOIN glpi_equipments eq ON eq.id = c.id
        WHERE eq.entities_id = p_entities_id
        AND c.users_id_tech IS NOT NULL
        -- Technicien éligible : ses équipements n'ont pas de ticket bloquant
        GROUP BY c.users_id_tech;

    CURSOR cur_equip_eligible(p_tech_id NUMBER, p_nb NUMBER) IS
        -- Équipements sans ticket ou avec ticket nouveau seulement
        SELECT eq.id
        FROM glpi_equipments eq
        JOIN glpi_computers c ON c.id = eq.id
        WHERE c.users_id_tech = p_tech_id
        AND eq.entities_id = p_entities_id
        AND NOT EXISTS (
            SELECT 1 FROM glpi_tickets t
            WHERE t.equipment_id = eq.id
            AND t.status IN (2, 3)  -- En cours ou En attente = bloquant
        )
        ORDER BY DBMS_RANDOM.VALUE  -- tirage aléatoire
        FETCH FIRST p_nb ROWS ONLY;

BEGIN
    -- Compter uniquement les ordinateurs (seuls équipements redistribuables via cur_equip_eligible)
    SELECT COUNT(*) INTO v_nb_equip
    FROM glpi_equipments
    WHERE entities_id = p_entities_id
    AND itemtype = 'Computer';

    -- Compter les techniciens actuels (avant ajout du nouveau)
    SELECT COUNT(DISTINCT users_id_tech) INTO v_nb_tech
    FROM glpi_computers c
    JOIN glpi_equipments eq ON eq.id = c.id
    WHERE eq.entities_id = p_entities_id
    AND c.users_id_tech IS NOT NULL;

    -- Quota cible après ajout du nouveau technicien
    v_quota := FLOOR(v_nb_equip / (v_nb_tech + 1));

    -- Pour chaque technicien existant, on retire des équipements
    FOR rec IN cur_techniciens LOOP
        v_a_retirer := rec.nb_equip - v_quota;

        IF v_a_retirer > 0 THEN
            FOR eq_rec IN cur_equip_eligible(rec.tech_id, v_a_retirer) LOOP
                v_ids.EXTEND;
                v_ids(v_ids.COUNT) := eq_rec.id;

                -- Désassigner le technicien actuel
                UPDATE glpi_computers
                SET users_id_tech = NULL
                WHERE id = eq_rec.id;
            END LOOP;
        END IF;
    END LOOP;

    RETURN v_ids;
END;
/
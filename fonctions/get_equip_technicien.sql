-- Fonction : récupère les IDs des équipements d'un technicien
CREATE OR REPLACE FUNCTION get_equip_technicien(
    p_tech_id IN NUMBER
) RETURN t_ids AS
    v_ids t_ids := t_ids();
BEGIN
    SELECT id BULK COLLECT INTO v_ids
    FROM glpi_computers
    WHERE users_id_tech = p_tech_id
    UNION ALL
    SELECT id
    FROM glpi_printers
    WHERE users_id_tech = p_tech_id;

    RETURN v_ids;
END;
/
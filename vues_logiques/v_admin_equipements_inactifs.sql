CREATE OR REPLACE VIEW v_admin_equipements_inactifs AS
SELECT
    eq.id                               AS equipment_id,
    eq.name                             AS equipement,
    eq.itemtype,
    l.name                              AS salle,
    e.name                              AS site,
    CASE COALESCE(c.states_id, p.states_id)
        WHEN 2 THEN 'En stock'
        WHEN 3 THEN 'En réparation'
        WHEN 4 THEN 'Rebut'
    END                                 AS statut,
    COALESCE(c.serial, p.serial)        AS serial
FROM glpi_equipments                    eq
JOIN  glpi_entities                     e  ON e.id  = eq.entities_id
LEFT JOIN glpi_locations                l  ON l.id  = eq.locations_id
LEFT JOIN glpi_computers                c  ON c.id  = eq.id
LEFT JOIN glpi_printers                 p  ON p.id  = eq.id
WHERE COALESCE(c.states_id, p.states_id) IN (2, 3, 4)
AND   UPPER(e.name) = SUBSTR(
          SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
          INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
      );
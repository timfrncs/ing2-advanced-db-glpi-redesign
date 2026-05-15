CREATE OR REPLACE VIEW v_admin_tickets_en_retard AS
SELECT
    t.id                                        AS ticket_id,
    t.name                                      AS sujet,
    t.date_issue,
    ROUND(CURRENT_TIMESTAMP - t.date_issue)     AS jours_ouverts,
    CASE t.status
        WHEN 1 THEN 'Nouveau'
        WHEN 2 THEN 'En cours'
        WHEN 3 THEN 'En attente'
    END                                         AS statut,
    e.name                                      AS site,
    l.name                                      AS localisation,
    u.firstname  || ' ' || u.realname           AS demandeur,
    eq.name                                     AS equipement_concerne,
    tech.firstname || ' ' || tech.realname      AS technicien_responsable
FROM glpi_tickets                               t
JOIN  glpi_entities                             e    ON e.id   = t.entities_id
JOIN  glpi_equipments                           eq   ON eq.id  = t.equipment_id
LEFT JOIN glpi_locations                        l    ON l.id   = t.locations_id
LEFT JOIN glpi_users                            u    ON u.id   = t.users_id
LEFT JOIN glpi_computers                        c    ON c.id   = eq.id
LEFT JOIN glpi_printers                         p    ON p.id   = eq.id
LEFT JOIN glpi_users                            tech ON tech.id = COALESCE(c.users_id_tech, p.users_id_tech)
WHERE t.status IN (1, 2, 3)
AND   CURRENT_TIMESTAMP - t.date_issue >= 15
AND   UPPER(e.name) = SUBSTR(
          SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
          INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') + 1
      );
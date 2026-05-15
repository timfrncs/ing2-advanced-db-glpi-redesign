CREATE MATERIALIZED VIEW mv_charge_techniciens
BUILD IMMEDIATE
REFRESH COMPLETE
START WITH SYSDATE
NEXT TRUNC(SYSDATE + 7)
AS
SELECT
    tech.id                                         AS tech_id,
    tech.firstname || ' ' || tech.realname          AS technicien,
    e.name                                          AS site,
    COUNT(DISTINCT c.id)                            AS nb_computers,
    COUNT(DISTINCT p.id)                            AS nb_printers,
    COUNT(DISTINCT c.id) + COUNT(DISTINCT p.id)     AS total_equipements
FROM glpi_users tech
LEFT JOIN glpi_computers  c  ON c.users_id_tech  = tech.id
LEFT JOIN glpi_printers   p  ON p.users_id_tech  = tech.id
LEFT JOIN glpi_equipments eq ON eq.id = COALESCE(c.id, p.id)
LEFT JOIN glpi_entities   e  ON e.id  = eq.entities_id
WHERE tech.id IN (
    SELECT users_id_tech FROM glpi_computers
    UNION
    SELECT users_id_tech FROM glpi_printers
)
GROUP BY tech.id, tech.firstname, tech.realname, e.name;
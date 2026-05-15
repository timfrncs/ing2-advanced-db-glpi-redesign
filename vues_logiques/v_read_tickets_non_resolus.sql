CREATE OR REPLACE VIEW v_read_tickets_non_resolus AS
SELECT
    e.name                          AS site,
    COUNT(*)                        AS nb_tickets_ouverts,
    SUM(CASE WHEN t.status = 1 
             THEN 1 ELSE 0 END)     AS nb_nouveaux,
    SUM(CASE WHEN t.status = 2 
             THEN 1 ELSE 0 END)     AS nb_en_cours,
    SUM(CASE WHEN t.status = 3 
             THEN 1 ELSE 0 END)     AS nb_en_attente
FROM glpi_tickets       t
JOIN glpi_entities      e  ON e.id = t.entities_id
WHERE t.status IN (1, 2, 3)
GROUP BY e.name;
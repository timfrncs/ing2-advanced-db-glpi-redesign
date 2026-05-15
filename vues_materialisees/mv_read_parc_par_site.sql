CREATE MATERIALIZED VIEW mv_read_parc_par_site
BUILD IMMEDIATE
REFRESH COMPLETE
START WITH SYSDATE
NEXT TRUNC(SYSDATE + 7)
AS
SELECT
    e.name                                          AS site,
    SUM(CASE WHEN eq.itemtype = 'Computer' 
             THEN 1 ELSE 0 END)                     AS nb_computers,
    SUM(CASE WHEN eq.itemtype = 'Printer'  
             THEN 1 ELSE 0 END)                     AS nb_printers,
    COUNT(*)                                        AS total_equipements
FROM glpi_equipments    eq
JOIN glpi_entities      e  ON e.id = eq.entities_id
GROUP BY e.name;
CREATE OR REPLACE VIEW v_tech_tickets_actifs AS
WITH tech_actuel AS (
    SELECT id, firstname, realname, entities_id
    FROM glpi_users
    WHERE UPPER(pseudo) = SUBSTR(
        SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), 1,
        INSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '|') - 1
    )
),
equip_tech AS (
    SELECT eq.id AS equipment_id, c.serial, c.states_id,
           eq.name, eq.itemtype, eq.entities_id, eq.locations_id, eq.ipaddresses_id
    FROM tech_actuel ta
    JOIN glpi_computers  c  ON c.users_id_tech = ta.id
    JOIN glpi_equipments eq ON eq.id           = c.id
    UNION ALL
    SELECT eq.id AS equipment_id, p.serial, p.states_id,
           eq.name, eq.itemtype, eq.entities_id, eq.locations_id, eq.ipaddresses_id
    FROM tech_actuel ta
    JOIN glpi_printers   p  ON p.users_id_tech = ta.id
    JOIN glpi_equipments eq ON eq.id           = p.id
)
SELECT
    et.equipment_id,
    et.name                                      AS equipement,
    et.itemtype,
    e.name                                       AS site,
    l.name                                       AS localisation,
    ip.name                                      AS adresse_ip,
    et.serial,
    CASE et.states_id
        WHEN 1 THEN 'En service'
        WHEN 2 THEN 'En stock'
        WHEN 3 THEN 'En réparation'
        WHEN 4 THEN 'Rebut'
    END                                          AS etat_equipement,
    t.id                                         AS ticket_id,
    t.name                                       AS sujet_ticket,
    t.date_issue,
    TRUNC(SYSDATE - CAST(t.date_issue AS DATE))  AS jours_ouverts,
    CASE t.status
        WHEN 1 THEN 'Nouveau'
        WHEN 2 THEN 'En cours'
        WHEN 3 THEN 'En attente'
        WHEN 4 THEN 'Résolu'
        WHEN 5 THEN 'Clos'
    END                                          AS statut_ticket,
    u_dem.firstname || ' ' || u_dem.realname     AS demandeur
FROM equip_tech                                  et
JOIN glpi_entities                               e     ON e.id           = et.entities_id
LEFT JOIN glpi_locations                         l     ON l.id           = et.locations_id
LEFT JOIN glpi_ipaddresses                       ip    ON ip.id          = et.ipaddresses_id
JOIN glpi_tickets                                t     ON t.equipment_id = et.equipment_id
LEFT JOIN glpi_users                             u_dem ON u_dem.id       = t.users_id
WHERE t.status IN (1, 2, 3);

-- ARCHITECTURE BDDR - CAMPUS PAU si la ligne using ne marche pas taper SHOW PARAMETER service_names; et prendre la valeur affiché au lieu du free
CREATE PUBLIC DATABASE LINK dblink_vers_cergy
CONNECT TO GLPI_TECH_CERGY IDENTIFIED BY "Cergy2026"
USING 'localhost:1521/FREE';

-- Vues globales réparties
CREATE OR REPLACE VIEW v_global_equipements AS
    SELECT id, name, itemtype, locations_id, 'PAU' AS site_origine
    FROM glpi_equipments
    WHERE entities_id = 2
    UNION ALL
    SELECT id, name, itemtype, locations_id, 'CERGY' AS site_origine
    FROM glpi_equipments@dblink_vers_cergy
    WHERE entities_id = 1;

CREATE OR REPLACE VIEW v_global_users AS
    SELECT id, pseudo, realname, firstname, 'PAU' AS site_origine
    FROM glpi_users
    WHERE entities_id = 2
    UNION ALL
    SELECT id, pseudo, realname, firstname, 'CERGY' AS site_origine
    FROM glpi_users@dblink_vers_cergy
    WHERE entities_id = 1;

CREATE OR REPLACE VIEW v_global_tickets AS
    SELECT id, name, status, date_issue, 'PAU' AS site_origine
    FROM glpi_tickets
    WHERE entities_id = 2
    UNION ALL
    SELECT id, name, status, date_issue, 'CERGY' AS site_origine
    FROM glpi_tickets@dblink_vers_cergy
    WHERE entities_id = 1;

-- Droits de lecture
GRANT SELECT ON v_global_equipements TO R_GLPI_READ;
GRANT SELECT ON v_global_users       TO R_GLPI_READ;
GRANT SELECT ON v_global_tickets     TO R_GLPI_READ;

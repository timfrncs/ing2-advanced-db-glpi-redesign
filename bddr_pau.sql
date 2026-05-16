-- ARCHITECTURE BDDR - CAMPUS PAU
-- Ce fichier s'execute sur l'instance PAU (en tant que SYS ou GLPI_OWNER).
-- Le compte GLPI_DBLINK_CERGY doit exister sur l'instance CERGY avant d'executer ce fichier.
-- Pour connaitre le service name : SHOW PARAMETER service_names;

CREATE PUBLIC DATABASE LINK dblink_vers_cergy
CONNECT TO GLPI_DBLINK_CERGY IDENTIFIED BY "DbCergy2026!"
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

-- Les GRANTs et synonymes publics sur ces vues sont centralises dans acces.sql.

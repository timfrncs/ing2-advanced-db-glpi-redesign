
-- Création des DB Links (Liens réseaux entre les sites)

-- Site de Cergy et  Pau 
-- en cas d'ereur utilisé la commande SHOW PARAMETER service_names; pour remplacer le free avec la veleur indiqué 
CREATE PUBLIC DATABASE LINK dblink_vers_pau
CONNECT TO GLPI_TECH_PAU IDENTIFIED BY "Pau2026"
USING 'localhost:1521/FREE'; 

-- Lien permettant au site de Pau d'interroger les données de Cergy
CREATE PUBLIC DATABASE LINK dblink_vers_cergy
CONNECT TO GLPI_TECH_CERGY IDENTIFIED BY "Cergy2026"
USING 'localhost:1521/FREE';


--  Création des Vues Globales Réparties

-- Vue Globale : Le Parc Matériel (Cergy + Pau)
CREATE OR REPLACE VIEW v_global_equipements AS
    -- Données locales (Cergy)
    SELECT id, name, itemtype, locations_id, 'CERGY' AS site_origine
    FROM glpi_equipments
    WHERE entities_id = 1
    UNION ALL
    -- Données distantes (Pau) via le DB Link
    SELECT id, name, itemtype, locations_id, 'PAU' AS site_origine
    FROM glpi_equipments@dblink_vers_pau
    WHERE entities_id = 2;

-- Vue Globale : Les Utilisateurs 
CREATE OR REPLACE VIEW v_global_users AS
    SELECT id, pseudo, realname, firstname, 'CERGY' AS site_origine
    FROM glpi_users
    WHERE entities_id = 1
    UNION ALL
    SELECT id, pseudo, realname, firstname, 'PAU' AS site_origine
    FROM glpi_users@dblink_vers_pau
    WHERE entities_id = 2;

-- Vue Globale : les ticketss
CREATE OR REPLACE VIEW v_global_tickets AS
    SELECT id, name, status, date_issue, 'CERGY' AS site_origine
    FROM glpi_tickets
    WHERE entities_id = 1
    UNION ALL
    SELECT id, name, status, date_issue, 'PAU' AS site_origine
    FROM glpi_tickets@dblink_vers_pau
    WHERE entities_id = 2;

--  Attribution des droits sur les vues globales
GRANT SELECT ON v_global_equipements TO R_GLPI_READ;
GRANT SELECT ON v_global_users       TO R_GLPI_READ;
GRANT SELECT ON v_global_tickets     TO R_GLPI_READ;

-- =============================================================================
-- FIN DU SCRIPT D'INSTALLATION
-- =============================================================================

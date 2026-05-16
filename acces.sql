-- =============================================================================
-- GLPI CY Tech - Droits applicatifs
-- Fichier    : 07_grants.sql
-- Connexion  : GLPI_OWNER
-- Dependances: 05_procedures_fonctions.sql + 06_vues.sql executes avant
-- Contenu    : GRANTs sur vues / MV / procedures + synonymes publics
-- =============================================================================
-- Principe du moindre privilege :
--   - Aucun GRANT DML direct sur les tables vers les roles applicatifs.
--   - Les procedures s executent avec les droits de GLPI_OWNER (AUTHID DEFINER).
--   - Les vues resolvent leurs droits au niveau du proprietaire du schema.
--   - Les roles applicatifs n acccedent aux donnees QUE via les vues et
--     procedures qui leur sont accordees.
-- =============================================================================


-- =============================================================================
-- 1. GRANTS SUR LES VUES ET VUES MATERIALISEES
-- =============================================================================

-- ---- R_GLPI_TECH : vue personnelle du technicien connecte -------------------
-- Filtree dynamiquement par CLIENT_IDENTIFIER -> chaque technicien ne voit
-- que ses propres equipements avec tickets ouverts.
GRANT SELECT ON v_tech_tickets_actifs        TO R_GLPI_TECH;

-- ---- R_GLPI_ADMIN : vues de supervision par site ----------------------------
-- Toutes filtrees par CLIENT_IDENTIFIER -> chaque admin ne voit que son site.
GRANT SELECT ON v_admin_tickets_en_retard    TO R_GLPI_ADMIN;
GRANT SELECT ON v_admin_equipements_inactifs TO R_GLPI_ADMIN;
GRANT SELECT ON v_admin_charge_techniciens   TO R_GLPI_ADMIN;

-- MV sous-jacente : accordee aussi pour permettre des requetes directes
-- si besoin (ex : debug, requete ad hoc en soutenance).
GRANT SELECT ON mv_charge_techniciens        TO R_GLPI_ADMIN;

-- Rapport parc global : l admin peut aussi le consulter
GRANT SELECT ON mv_read_parc_par_site        TO R_GLPI_ADMIN;

-- ---- R_GLPI_READ : rapports globaux pour les auditeurs ----------------------
-- Pas de filtre par site : l auditeur voit les deux sites.
GRANT SELECT ON v_read_tickets_non_resolus   TO R_GLPI_READ;
GRANT SELECT ON mv_read_parc_par_site        TO R_GLPI_READ;


-- =============================================================================
-- 2. GRANTS SUR LES PROCEDURES ET FONCTIONS
-- =============================================================================

-- ---- R_GLPI_ADMIN : gestion des utilisateurs --------------------------------
GRANT EXECUTE ON ajouter_utilisateur_lambda        TO R_GLPI_ADMIN;
GRANT EXECUTE ON ajouter_technicien                TO R_GLPI_ADMIN;
GRANT EXECUTE ON ajouter_admin                     TO R_GLPI_ADMIN;
GRANT EXECUTE ON supprimer_utilisateur_lambda      TO R_GLPI_ADMIN;
GRANT EXECUTE ON supprimer_technicien              TO R_GLPI_ADMIN;
GRANT EXECUTE ON supprimer_admin                   TO R_GLPI_ADMIN;
GRANT EXECUTE ON ajouter_lambda_autre_site         TO R_GLPI_ADMIN;
GRANT EXECUTE ON ajouter_tech_ou_admin_autre_site  TO R_GLPI_ADMIN;

-- ---- R_GLPI_ADMIN : gestion du parc et des tickets --------------------------
GRANT EXECUTE ON ajouter_equipement                TO R_GLPI_ADMIN;
GRANT EXECUTE ON changer_statut_equipement         TO R_GLPI_ADMIN;
GRANT EXECUTE ON affecter_localisation_equipement  TO R_GLPI_ADMIN;
GRANT EXECUTE ON affecter_technicien_equipement    TO R_GLPI_ADMIN;
GRANT EXECUTE ON modifier_statut_ticket            TO R_GLPI_ADMIN;

-- ---- R_GLPI_TECH : actions metier sur le parc et les tickets ----------------
-- Un technicien peut ajouter/modifier des equipements et gerer les tickets
-- de ses equipements. Il ne peut pas gerer les utilisateurs.
GRANT EXECUTE ON ajouter_equipement                TO R_GLPI_TECH;
GRANT EXECUTE ON changer_statut_equipement         TO R_GLPI_TECH;
GRANT EXECUTE ON affecter_localisation_equipement  TO R_GLPI_TECH;
GRANT EXECUTE ON modifier_statut_ticket            TO R_GLPI_TECH;

-- ---- R_GLPI_TICKET_HELP : creation de ticket uniquement ---------------------
-- Role dedie a l interface de declaration d incident (compte GLPI_HELP).
-- Acces minimal : une seule procedure.
GRANT EXECUTE ON creer_ticket                      TO R_GLPI_TICKET_HELP;


-- =============================================================================
-- 3. SYNONYMES PUBLICS
-- =============================================================================
-- Permettent aux comptes applicatifs d appeler les objets sans prefixer
-- GLPI_OWNER. Ex : SELECT * FROM v_tech_tickets_actifs au lieu de
-- SELECT * FROM GLPI_OWNER.v_tech_tickets_actifs.
-- CREATE PUBLIC SYNONYM est accorde a GLPI_OWNER dans 01_owner.sql.

-- ---- Vues logiques ----------------------------------------------------------
CREATE OR REPLACE PUBLIC SYNONYM v_tech_tickets_actifs
  FOR GLPI_OWNER.v_tech_tickets_actifs;

CREATE OR REPLACE PUBLIC SYNONYM v_admin_tickets_en_retard
  FOR GLPI_OWNER.v_admin_tickets_en_retard;

CREATE OR REPLACE PUBLIC SYNONYM v_admin_equipements_inactifs
  FOR GLPI_OWNER.v_admin_equipements_inactifs;

CREATE OR REPLACE PUBLIC SYNONYM v_admin_charge_techniciens
  FOR GLPI_OWNER.v_admin_charge_techniciens;

CREATE OR REPLACE PUBLIC SYNONYM v_read_tickets_non_resolus
  FOR GLPI_OWNER.v_read_tickets_non_resolus;

-- ---- Vues materialisees -----------------------------------------------------
CREATE OR REPLACE PUBLIC SYNONYM mv_charge_techniciens
  FOR GLPI_OWNER.mv_charge_techniciens;

CREATE OR REPLACE PUBLIC SYNONYM mv_read_parc_par_site
  FOR GLPI_OWNER.mv_read_parc_par_site;

-- ---- Procedures : gestion des utilisateurs ----------------------------------
CREATE OR REPLACE PUBLIC SYNONYM ajouter_utilisateur_lambda
  FOR GLPI_OWNER.ajouter_utilisateur_lambda;

CREATE OR REPLACE PUBLIC SYNONYM ajouter_technicien
  FOR GLPI_OWNER.ajouter_technicien;

CREATE OR REPLACE PUBLIC SYNONYM ajouter_admin
  FOR GLPI_OWNER.ajouter_admin;

CREATE OR REPLACE PUBLIC SYNONYM supprimer_utilisateur_lambda
  FOR GLPI_OWNER.supprimer_utilisateur_lambda;

CREATE OR REPLACE PUBLIC SYNONYM supprimer_technicien
  FOR GLPI_OWNER.supprimer_technicien;

CREATE OR REPLACE PUBLIC SYNONYM supprimer_admin
  FOR GLPI_OWNER.supprimer_admin;

CREATE OR REPLACE PUBLIC SYNONYM ajouter_lambda_autre_site
  FOR GLPI_OWNER.ajouter_lambda_autre_site;

CREATE OR REPLACE PUBLIC SYNONYM ajouter_tech_ou_admin_autre_site
  FOR GLPI_OWNER.ajouter_tech_ou_admin_autre_site;

-- ---- Procedures : gestion du parc ------------------------------------------
CREATE OR REPLACE PUBLIC SYNONYM ajouter_equipement
  FOR GLPI_OWNER.ajouter_equipement;

CREATE OR REPLACE PUBLIC SYNONYM changer_statut_equipement
  FOR GLPI_OWNER.changer_statut_equipement;

CREATE OR REPLACE PUBLIC SYNONYM affecter_localisation_equipement
  FOR GLPI_OWNER.affecter_localisation_equipement;

CREATE OR REPLACE PUBLIC SYNONYM affecter_technicien_equipement
  FOR GLPI_OWNER.affecter_technicien_equipement;

-- ---- Procedures : gestion des tickets ---------------------------------------
CREATE OR REPLACE PUBLIC SYNONYM creer_ticket
  FOR GLPI_OWNER.creer_ticket;

CREATE OR REPLACE PUBLIC SYNONYM modifier_statut_ticket
  FOR GLPI_OWNER.modifier_statut_ticket;

-- ---- Type (necessaire pour les procedures qui utilisent t_ids) --------------
CREATE OR REPLACE PUBLIC SYNONYM t_ids
  FOR GLPI_OWNER.t_ids;
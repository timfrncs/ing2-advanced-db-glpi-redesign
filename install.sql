-- =============================================================================
-- GLPI CY Tech - Script d installation complet
-- Fichier    : install.sql
-- Prerequis  : etre connecte en SYSDBA sur XEPDB1 + fix file paths to project in this file + ajuster les chemins vers le projet
-- Resultat   : base entierement deployee + donnees de test + affichage des tables
-- =============================================================================

SET ECHO        OFF
SET SERVEROUTPUT ON  SIZE UNLIMITED
SET LINESIZE    200
SET PAGESIZE    50
SET TRIMSPOOL   ON
SET FEEDBACK    ON
WHENEVER SQLERROR CONTINUE


-- =============================================================================
-- PHASE 1 : Infrastructure et comptes Oracle (connexion SYS AS SYSDBA)
-- =============================================================================

PROMPT
PROMPT ================================================================
PROMPT  [1/8] INFRASTRUCTURE : tablespaces + roles
PROMPT ================================================================
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/infrastructure.sql

PROMPT
PROMPT ================================================================
PROMPT  [2/8] COMPTES ORACLE
PROMPT ================================================================
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/owner.sql


-- =============================================================================
-- PHASE 2 : Schema, sequences, triggers (connexion GLPI_OWNER)
-- =============================================================================

PROMPT
PROMPT  Connexion en tant que GLPI_OWNER...
CONNECT GLPI_OWNER/"GlpiOwner#2024"@//localhost:1521/XEPDB1

PROMPT
PROMPT ================================================================
PROMPT  [3/8] SCHEMA : tables, index, cles etrangeres, contraintes
PROMPT ================================================================
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/schema.sql

PROMPT
PROMPT ================================================================
PROMPT  [4/8] SEQUENCES
PROMPT ================================================================
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/sequences.sql

PROMPT
PROMPT ================================================================
PROMPT  [5/8] TRIGGERS ET AUDIT
PROMPT ================================================================
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/triggers.sql


-- =============================================================================
-- PHASE 3 : Fonctions et procedures metier
-- =============================================================================

PROMPT
PROMPT ================================================================
PROMPT  [6/8] FONCTIONS ET PROCEDURES METIER
PROMPT ================================================================

PROMPT   > Type t_ids + repartition_charge_nouveau_tech
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/fonctions/repartition_charge_nouveau_tech.sql

PROMPT   > get_equip_technicien
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/fonctions/get_equip_technicien.sql

PROMPT   > redistribuer_equip
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/fonctions/redistribuer_equip.sql

PROMPT   > ajouter_utilisateur_lambda
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/ajouter_utilisateur_lambda.sql

PROMPT   > ajouter_admin
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/ajouter_admin.sql

PROMPT   > ajouter_technicien
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/ajouter_technicien.sql

PROMPT   > supprimer_utilisateur_lambda
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/supprimer_utilisateur_lambda.sql

PROMPT   > supprimer_admin
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/supprimer_admin.sql

PROMPT   > supprimer_technicien
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/supprimer_technicien.sql

PROMPT   > ajouter_lambda_autre_site
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/ajouter_lambda_autre_site.sql

PROMPT   > ajouter_tech_ou_admin_autre_site
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/ajouter_tech_ou_admin_autre_site.sql

PROMPT   > ajouter_equipement
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/ajouter_equipement.sql

PROMPT   > changer_statut_equipement
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/changer_statut_equipement.sql

PROMPT   > affecter_localisation_equipement
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/affecter_localisation_equipement.sql

PROMPT   > affecter_technicien_equipement
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/affecter_technicien_equipement.sql

PROMPT   > creer_ticket
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/creer_ticket.sql

PROMPT   > modifier_statut_ticket
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/procedures/modifier_statut_ticket.sql


-- =============================================================================
-- PHASE 4 : Vues logiques et vues materialisees
-- =============================================================================

PROMPT
PROMPT ================================================================
PROMPT  [7/8] VUES LOGIQUES ET VUES MATERIALISEES
PROMPT ================================================================

PROMPT   > v_tech_tickets_actifs
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/vues_logiques/v_tech_tickets_actifs.sql

PROMPT   > v_admin_tickets_en_retard
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/vues_logiques/v_admin_tickets_en_retard.sql

PROMPT   > v_admin_equipements_inactifs
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/vues_logiques/v_admin_equipements_inactifs.sql

PROMPT   > v_read_tickets_non_resolus
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/vues_logiques/v_read_tickets_non_resolus.sql

PROMPT   > mv_charge_techniciens
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/vues_materialisees/mv_admin_charge_technicien.sql

PROMPT   > mv_read_parc_par_site
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/vues_materialisees/mv_read_parc_par_site.sql

PROMPT   > v_admin_charge_techniciens
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/vues_logiques/v_admin_charge_techniciens.sql


-- =============================================================================
-- PHASE 5 : Droits applicatifs et synonymes publics
-- =============================================================================

PROMPT
PROMPT ================================================================
PROMPT  [8/8] DROITS, GRANTS ET SYNONYMES PUBLICS
PROMPT ================================================================
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/acces.sql


-- =============================================================================
-- PHASE 6 : Donnees initiales et donnees de test
-- =============================================================================

PROMPT
PROMPT ================================================================
PROMPT  DONNEES INITIALES + DONNEES DE TEST
PROMPT ================================================================
@H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/donnees_initiales.sql


-- =============================================================================
-- PHASE 7 : Architecture distribuee BDDR (optionnel)
-- =============================================================================
-- Decommenter la ligne correspondant a l instance en cours d execution.
-- @H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/bddr_cergy.sql
-- @H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/bddr_pau.sql


-- =============================================================================
-- BILAN FINAL
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  BILAN FINAL : COMPTAGES ATTENDUS vs REELS
PROMPT ================================================================

SELECT 'glpi_entities'       AS nom_table,   2   AS attendu, COUNT(*) AS reel FROM glpi_entities
UNION ALL
SELECT 'glpi_profiles',                       3,              COUNT(*) FROM glpi_profiles
UNION ALL
SELECT 'glpi_networks',                       2,              COUNT(*) FROM glpi_networks
UNION ALL
SELECT 'glpi_locations',                      16,             COUNT(*) FROM glpi_locations
UNION ALL
SELECT 'glpi_profilerights',                  0,              COUNT(*) FROM glpi_profilerights
UNION ALL
SELECT 'glpi_users',                          604,            COUNT(*) FROM glpi_users
UNION ALL
SELECT 'glpi_profiles_users',                 4,              COUNT(*) FROM glpi_profiles_users
UNION ALL
SELECT 'glpi_ipaddresses',                    150,            COUNT(*) FROM glpi_ipaddresses
UNION ALL
SELECT 'glpi_equipments',                     150,            COUNT(*) FROM glpi_equipments
UNION ALL
SELECT 'glpi_computers',                      100,            COUNT(*) FROM glpi_computers
UNION ALL
SELECT 'glpi_printers',                       50,             COUNT(*) FROM glpi_printers
UNION ALL
SELECT 'glpi_tickets',                        20,             COUNT(*) FROM glpi_tickets
UNION ALL
SELECT 'glpi_history (>0)',                   0,              COUNT(*) FROM glpi_history
ORDER BY 1;

PROMPT
PROMPT
PROMPT ================================================================
PROMPT  INSTALLATION TERMINEE
PROMPT  Remise a zero : @H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/cleanup.sql
PROMPT  BDDR Cergy    : @H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/bddr_cergy.sql
PROMPT  BDDR Pau      : @H:/Documents/COURS/ing2/S2/TAD/Projet/ing2-advanced-db-glpi-redesign/bddr_pau.sql
PROMPT ================================================================
PROMPT

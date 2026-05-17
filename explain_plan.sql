-- =============================================================================
-- GLPI CY Tech - Analyse des performances (EXPLAIN PLAN)
-- Fichier    : explain_plan.sql
-- Connexion  : GLPI_OWNER
-- Prerequis  : scenario.sql execute (donnees de demo presentes)
--
-- Objectif   : produire les 16 plans du tableau comparatif optimise/non-optimise.
--              Un plan par procedure ou vue metier, avec la requete SQL interne
--              la plus representative de la charge de travail.
--
-- Note       : EXPLAIN PLAN ne peut pas s'appliquer a un appel de procedure.
--              Pour chaque procedure, on explique la requete SQL interne cle.
--              Pour les vues, on explique directement la requete sur la vue.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE     200
SET PAGESIZE     0
SET FEEDBACK     OFF
WHENEVER SQLERROR CONTINUE

-- Mise a jour des statistiques sur toutes les tables impliquees
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_TICKETS',        CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_EQUIPMENTS',     CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_COMPUTERS',      CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_PRINTERS',       CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_USERS',          CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_PROFILES',       CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_PROFILES_USERS', CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_LOCATIONS',      CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_ENTITIES',       CASCADE => TRUE);
    DBMS_OUTPUT.PUT_LINE('Statistiques mises a jour (9 tables).');
END;
/


-- =============================================================================
-- ACTE 1 : CREATION D'UNE NOUVELLE EQUIPE
-- =============================================================================

-- ---- EP11 : ajouter_admin ---------------------------------------------------
-- Requete interne : INSERT dans glpi_users
-- Interet : montre le cout d'insertion dans une table non partitionnee
PROMPT
PROMPT [EP11] ajouter_admin : INSERT utilisateur dans glpi_users
EXPLAIN PLAN SET STATEMENT_ID = 'EP11_AJ_ADMIN' FOR
INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
VALUES ('ETEST_CERGY', 'Test', 'AdminPlan', 1, 1);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP11_AJ_ADMIN', 'TYPICAL'));

-- ---- EP04 : ajouter_technicien ----------------------------------------------
-- Requete interne : repartition_charge_nouveau_tech
-- Interet : UNION ALL sur deux tables partitionnees + GROUP BY -> mesure l'impact
--           des index sur users_id_tech et du partition pruning (entities_id = 1)
PROMPT
PROMPT [EP04] ajouter_technicien : agregation charge par technicien (repartition_charge_nouveau_tech)
EXPLAIN PLAN SET STATEMENT_ID = 'EP04_REPARTITION' FOR
SELECT tech_id, SUM(nb) AS nb_equip
FROM (
    SELECT c.users_id_tech AS tech_id, COUNT(*) AS nb
    FROM glpi_computers c
    JOIN glpi_equipments eq ON eq.id = c.id
    WHERE eq.entities_id = 1 AND c.users_id_tech IS NOT NULL
    GROUP BY c.users_id_tech
    UNION ALL
    SELECT p.users_id_tech AS tech_id, COUNT(*) AS nb
    FROM glpi_printers p
    JOIN glpi_equipments eq ON eq.id = p.id
    WHERE eq.entities_id = 1 AND p.users_id_tech IS NOT NULL
    GROUP BY p.users_id_tech
)
GROUP BY tech_id;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP04_REPARTITION', 'TYPICAL'));

-- ---- EP14 : ajouter_utilisateur_lambda --------------------------------------
-- Requete interne : boucle anti-doublon pseudo
-- Interet : montre si glpi_users a un index sur la colonne pseudo
PROMPT
PROMPT [EP14] ajouter_utilisateur_lambda : controle doublon pseudo dans glpi_users
EXPLAIN PLAN SET STATEMENT_ID = 'EP14_AJ_LAMBDA' FOR
SELECT COUNT(*) FROM glpi_users WHERE pseudo = 'TDEMO';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP14_AJ_LAMBDA', 'TYPICAL'));

-- ---- EP12 : ajouter_equipement ----------------------------------------------
-- Requete interne : INSERT dans glpi_equipments (table partitionnee par entities_id)
-- Interet : Oracle doit router l'insertion vers la bonne partition (Cergy=1 / Pau=2)
PROMPT
PROMPT [EP12] ajouter_equipement : INSERT dans glpi_equipments partitionne (entities_id=1 -> Cergy)
EXPLAIN PLAN SET STATEMENT_ID = 'EP12_AJ_EQUIP' FOR
INSERT INTO glpi_equipments (name, itemtype, entities_id, ipaddresses_id)
VALUES ('EQ-PLAN', 'Computer', 1, 1);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP12_AJ_EQUIP', 'TYPICAL'));

-- ---- EP07 : affecter_localisation_equipement --------------------------------
-- Requete interne : lookup salle par nom avec filtre entities_id
-- Interet : filtre composite (UPPER(name), entities_id) -> index ou full scan ?
PROMPT
PROMPT [EP07] affecter_localisation_equipement : lookup salle par nom + entities_id
EXPLAIN PLAN SET STATEMENT_ID = 'EP07_AFF_LOC' FOR
SELECT id FROM glpi_locations
WHERE UPPER(name) = UPPER('LOC-1')
AND entities_id = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP07_AFF_LOC', 'TYPICAL'));

-- ---- EP06 : affecter_technicien_equipement ----------------------------------
-- Requete interne : lookup technicien par pseudo + verification profil
-- Interet : JOIN sur 3 tables (glpi_users, glpi_profiles_users, glpi_profiles)
PROMPT
PROMPT [EP06] affecter_technicien_equipement : lookup technicien par pseudo + profil (3 JOIN)
EXPLAIN PLAN SET STATEMENT_ID = 'EP06_AFF_TECH' FOR
SELECT u.id FROM glpi_users u
JOIN glpi_profiles_users pu ON pu.users_id = u.id
JOIN glpi_profiles       p  ON p.id        = pu.profiles_id
WHERE UPPER(u.pseudo) = UPPER('BMARTIN')
AND UPPER(p.name) = 'TECHNICIEN'
AND u.is_active = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP06_AFF_TECH', 'TYPICAL'));

-- ---- EP08 : changer_statut_equipement ---------------------------------------
-- Requete interne : recuperation equipement par nom dans table partitionnee
-- Interet : UPPER(name) sans filtre entities_id -> scan des deux partitions ?
PROMPT
PROMPT [EP08] changer_statut_equipement : lookup equipement par name dans glpi_equipments
EXPLAIN PLAN SET STATEMENT_ID = 'EP08_CHANGER_STATUT' FOR
SELECT id, entities_id, itemtype FROM glpi_equipments
WHERE UPPER(name) = UPPER('EQ-1')
AND ROWNUM = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP08_CHANGER_STATUT', 'TYPICAL'));


-- =============================================================================
-- ACTE 2 : CREATION D'UN TICKET
-- =============================================================================

-- ---- EP05 : creer_ticket ----------------------------------------------------
-- Requete interne : recuperation globale equipement (1 requete optimisee)
-- Interet : LEFT JOIN computers + printers pour recuperer states_id en une passe
PROMPT
PROMPT [EP05] creer_ticket : lookup equipement avec LEFT JOIN computers/printers
EXPLAIN PLAN SET STATEMENT_ID = 'EP05_CREER_TICKET' FOR
SELECT eq.id, eq.entities_id, eq.locations_id,
       UPPER(e.name),
       COALESCE(c.states_id, p.states_id)
FROM glpi_equipments eq
JOIN glpi_entities       e ON e.id = eq.entities_id
LEFT JOIN glpi_computers c ON c.id = eq.id
LEFT JOIN glpi_printers  p ON p.id = eq.id
WHERE UPPER(eq.name) = UPPER('EQ-1')
AND ROWNUM = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP05_CREER_TICKET', 'TYPICAL'));


-- =============================================================================
-- ACTE 3 : TRAITEMENT D'UN TICKET PAR LE TECHNICIEN
-- =============================================================================

-- ---- EP03 : v_tech_tickets_actifs -------------------------------------------
-- Vue interrogee directement (plan complet avec filtre CLIENT_IDENTIFIER)
-- Interet : CTE + UNION ALL + multi-JOIN + filtre partition sur glpi_tickets
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('FMARTIN|CERGY');
END;
/
PROMPT
PROMPT [EP03] v_tech_tickets_actifs : plan complet (CLIENT_IDENTIFIER = FMARTIN|CERGY)
EXPLAIN PLAN SET STATEMENT_ID = 'EP03_VUE_TECH' FOR
SELECT ticket_id, equipement, statut_ticket, jours_ouverts
FROM   v_tech_tickets_actifs;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP03_VUE_TECH', 'TYPICAL'));
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('ADUPONT|CERGY');
END;
/

-- ---- EP13 : modifier_statut_ticket ------------------------------------------
-- Requete interne : recuperation ticket avec JOIN equipement
-- Interet : acces par cle primaire t.id -> index unique + JOIN partition pruning
PROMPT
PROMPT [EP13] modifier_statut_ticket : SELECT ticket JOIN glpi_equipments (par t.id)
EXPLAIN PLAN SET STATEMENT_ID = 'EP13_MOD_TICKET' FOR
SELECT t.status, t.equipment_id, eq.entities_id
FROM glpi_tickets t
JOIN glpi_equipments eq ON eq.id = t.equipment_id
WHERE t.id = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP13_MOD_TICKET', 'TYPICAL'));


-- =============================================================================
-- ACTE 5 : OPERATIONS CROSS-SITE
-- =============================================================================

-- ---- EP15 : ajouter_lambda_autre_site ---------------------------------------
-- Requete interne : recherche utilisateur lambda par pseudo sur autre site
-- Interet : UPPER(pseudo) + is_active -> index ou full scan sur 604 lignes ?
PROMPT
PROMPT [EP15] ajouter_lambda_autre_site : lookup utilisateur lambda par pseudo
EXPLAIN PLAN SET STATEMENT_ID = 'EP15_LAMBDA_SITE' FOR
SELECT id, firstname, realname, entities_id FROM glpi_users
WHERE UPPER(pseudo) = UPPER('UP005')
AND is_active = 1
AND ROWNUM = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP15_LAMBDA_SITE', 'TYPICAL'));

-- ---- EP16 : ajouter_tech_ou_admin_autre_site --------------------------------
-- Requete interne : recuperation user + profil pour copie cross-site
-- Interet : JOIN 3 tables (users + profiles_users + profiles) avec filtre pseudo
PROMPT
PROMPT [EP16] ajouter_tech_ou_admin_autre_site : lookup user + profil (3 tables jointes)
EXPLAIN PLAN SET STATEMENT_ID = 'EP16_TECH_SITE' FOR
SELECT u.firstname, u.realname, u.entities_id, p.id, UPPER(p.name)
FROM glpi_users u
JOIN glpi_profiles_users pu ON pu.users_id = u.id
JOIN glpi_profiles       p  ON p.id        = pu.profiles_id
WHERE UPPER(u.pseudo) = UPPER('CBERNARD')
AND u.is_active = 1
AND ROWNUM = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP16_TECH_SITE', 'TYPICAL'));


-- =============================================================================
-- ACTE 7 : RAPPORTS GLOBAUX
-- =============================================================================

-- ---- EP01 : v_read_tickets_non_resolus --------------------------------------
-- Vue interrogee directement (agregation par site)
-- Interet : GROUP BY sur glpi_tickets partitionne -> partition pruning ou full scan ?
PROMPT
PROMPT [EP01] v_read_tickets_non_resolus : agregation tickets par site
EXPLAIN PLAN SET STATEMENT_ID = 'EP01_RAPPORT_SITE' FOR
SELECT site, nb_tickets_ouverts, nb_nouveaux, nb_en_cours, nb_en_attente
FROM   v_read_tickets_non_resolus
ORDER BY site;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP01_RAPPORT_SITE', 'TYPICAL'));


-- =============================================================================
-- ACTE 8 : NETTOYAGE
-- =============================================================================

-- ---- EP10 : supprimer_utilisateur_lambda ------------------------------------
-- Requete interne : recherche utilisateur par pseudo + is_active
-- Interet : UPPER(pseudo) + is_active -> selectivite sur 604 utilisateurs
PROMPT
PROMPT [EP10] supprimer_utilisateur_lambda : lookup utilisateur par pseudo
EXPLAIN PLAN SET STATEMENT_ID = 'EP10_SUPP_LAMBDA' FOR
SELECT id, entities_id FROM glpi_users
WHERE UPPER(pseudo) = UPPER('TDEMO')
AND is_active = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP10_SUPP_LAMBDA', 'TYPICAL'));

-- ---- EP02 : supprimer_technicien --------------------------------------------
-- Requete interne : verification role TECHNICIEN via profil
-- Interet : sous-requete scalaire + JOIN profiles -> NL ou HASH JOIN ?
PROMPT
PROMPT [EP02] supprimer_technicien : verification role TECHNICIEN (JOIN glpi_profiles)
EXPLAIN PLAN SET STATEMENT_ID = 'EP02_SUPP_TECH' FOR
SELECT COUNT(*)
FROM glpi_profiles_users pu
JOIN glpi_profiles p ON p.id = pu.profiles_id
WHERE pu.users_id = (SELECT id FROM glpi_users WHERE UPPER(pseudo) = 'FMARTIN' AND is_active = 1)
AND UPPER(p.name) = 'TECHNICIEN';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP02_SUPP_TECH', 'TYPICAL'));

-- ---- EP09 : supprimer_admin (Last Man Standing) -----------------------------
-- Requete interne : comptage des admins actifs du site
-- Interet : JOIN 3 tables avec double filtre (entities_id + is_active + profil)
PROMPT
PROMPT [EP09] supprimer_admin : comptage admins actifs du site (regle Last Man Standing)
EXPLAIN PLAN SET STATEMENT_ID = 'EP09_LAST_ADMIN' FOR
SELECT COUNT(*) FROM glpi_users u
JOIN glpi_profiles_users pu ON pu.users_id = u.id
JOIN glpi_profiles       p  ON p.id        = pu.profiles_id
WHERE u.entities_id = 1
AND u.is_active = 1
AND UPPER(p.name) = 'ADMINISTRATEUR';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP09_LAST_ADMIN', 'TYPICAL'));


PROMPT
PROMPT ================================================================
PROMPT  EXPLAIN PLAN TERMINE - 16 plans generes
PROMPT  Tableau : EP01 a EP16 couvrent les 14 procedures + 2 vues
PROMPT ================================================================

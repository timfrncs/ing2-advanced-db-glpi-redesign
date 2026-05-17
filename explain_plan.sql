-- =============================================================================
-- GLPI CY Tech - Plans d'execution
-- Fichier    : explain_plan.sql
-- Connexion  : GLPI_OWNER
-- Prerequis  : install.sql + donnees_initiales.sql executes
--
-- Objectif   : generer le cout estime (EXPLAIN PLAN) de chaque requete SQL
--              issue des vues logiques, vues materialisees et procedures metier,
--              afin de les comparer a des requetes equivalentes non optimisees.
--
-- Couverture : SELECT + UPDATE + INSERT de chaque objet
--   Vues logiques  (4) : v_tech_tickets_actifs, v_admin_tickets_en_retard,
--                        v_admin_equipements_inactifs, v_read_tickets_non_resolus
--   Vue filtree    (1) : v_admin_charge_techniciens  (sur mv_charge_techniciens)
--   Vues mat.      (2) : mv_charge_techniciens, mv_read_parc_par_site
--   Fonctions      (3) : get_equip_technicien, redistribuer_equip,
--                        repartition_charge_nouveau_tech
--   Procedures    (14) : ajouter_admin, ajouter_technicien,
--                        ajouter_utilisateur_lambda, ajouter_equipement,
--                        ajouter_lambda_autre_site, ajouter_tech_ou_admin_autre_site,
--                        affecter_localisation_equipement, affecter_technicien_equipement,
--                        changer_statut_equipement, creer_ticket,
--                        modifier_statut_ticket, supprimer_admin,
--                        supprimer_technicien, supprimer_utilisateur_lambda
--
-- Format     : DBMS_XPLAN.DISPLAY avec format='ALL' pour obtenir :
--              Cost (%CPU), Cardinality (Rows), Bytes, predicats d'acces/filtre
--
-- Note sur les index disponibles (schema.sql) :
--   glpi_users        : idx_usr_pseudo, idx_usr_ent_id, idx_usr_is_active
--   glpi_equipments   : idx_equip_name, idx_equip_ent, idx_equip_type (LOCAL)
--   glpi_computers    : idx_comp_usr_tch, idx_comp_states (LOCAL), uk_comp_serial
--   glpi_printers     : idx_print_usr_tch, idx_print_states (LOCAL), uk_print_serial
--   glpi_tickets      : idx_tick_equip_id, idx_tick_status, idx_tick_ent_id (LOCAL)
--   glpi_profiles     : idx_prof_name
--   glpi_profiles_users : idx_pu_usr_id, idx_pu_prof_id
--   glpi_locations    : uk_loc_ent_name (LOCAL)
--   glpi_entities     : uk_ent_name
-- =============================================================================

SET LINESIZE   200
SET PAGESIZE     0
SET LONG      10000
SET FEEDBACK     ON
SET SERVEROUTPUT ON

-- Nettoyage prealable de la PLAN_TABLE (evite les residus de sessions precedentes)
DELETE FROM plan_table;
COMMIT;


-- =============================================================================
-- SECTION 1 : VUES LOGIQUES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- [V1] v_tech_tickets_actifs
-- Requete principale : CTE tech_actuel + equip_tech (UNION ALL) + jointures tickets
-- Index attendus :
--   - idx_usr_pseudo sur glpi_users (filtre CLIENT_IDENTIFIER)
--   - idx_comp_usr_tch / idx_print_usr_tch (jointure technicien -> equipements)
--   - idx_tick_equip_id + idx_tick_status (filtre tickets actifs)
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [V1] v_tech_tickets_actifs
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'V_TECH_TICKETS' FOR
SELECT
    et_eq.id                                        AS equipment_id,
    et_eq.name                                      AS equipement,
    et_eq.itemtype,
    e.name                                          AS site,
    l.name                                          AS localisation,
    ip.name                                         AS adresse_ip,
    et_c.serial,
    CASE et_c.states_id
        WHEN 1 THEN 'En service'
        WHEN 2 THEN 'En stock'
        WHEN 3 THEN 'En reparation'
        WHEN 4 THEN 'Rebut'
    END                                             AS etat_equipement,
    t.id                                            AS ticket_id,
    t.name                                          AS sujet_ticket,
    t.date_issue,
    TRUNC(SYSDATE - CAST(t.date_issue AS DATE))     AS jours_ouverts,
    CASE t.status
        WHEN 1 THEN 'Nouveau'
        WHEN 2 THEN 'En cours'
        WHEN 3 THEN 'En attente'
        WHEN 4 THEN 'Resolu'
        WHEN 5 THEN 'Clos'
    END                                             AS statut_ticket,
    u_dem.firstname || ' ' || u_dem.realname        AS demandeur
FROM (
    -- Equipements Computer du technicien
    SELECT eq.id, eq.name, eq.itemtype, eq.entities_id, eq.locations_id,
           eq.ipaddresses_id, c.serial, c.states_id
    FROM glpi_users          ta
    JOIN glpi_computers      c  ON c.users_id_tech = ta.id
    JOIN glpi_equipments     eq ON eq.id           = c.id
    WHERE UPPER(ta.pseudo) = SUBSTR(
        SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'), 1,
        INSTR(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),'|') - 1)
    UNION ALL
    -- Equipements Printer du technicien
    SELECT eq.id, eq.name, eq.itemtype, eq.entities_id, eq.locations_id,
           eq.ipaddresses_id, p.serial, p.states_id
    FROM glpi_users          ta
    JOIN glpi_printers       p  ON p.users_id_tech = ta.id
    JOIN glpi_equipments     eq ON eq.id           = p.id
    WHERE UPPER(ta.pseudo) = SUBSTR(
        SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'), 1,
        INSTR(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),'|') - 1)
) et_eq
JOIN glpi_computers          et_c  ON et_c.id          = et_eq.id  -- pour serial/states (Computer)
JOIN glpi_entities           e     ON e.id             = et_eq.entities_id
LEFT JOIN glpi_locations     l     ON l.id             = et_eq.locations_id
LEFT JOIN glpi_ipaddresses   ip    ON ip.id            = et_eq.ipaddresses_id
JOIN glpi_tickets            t     ON t.equipment_id   = et_eq.id
                                   AND t.entities_id   = et_eq.entities_id
LEFT JOIN glpi_users         u_dem ON u_dem.id         = t.users_id
WHERE t.status IN (1, 2, 3);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'V_TECH_TICKETS', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [V2] v_admin_tickets_en_retard
-- Requete principale : tickets ouverts >= 15 jours, filtres par site (CLIENT_ID)
-- Index attendus :
--   - idx_tick_status (filtre status IN (1,2,3))
--   - idx_tick_ent_id (filtre site)
--   - idx_tick_equip_id (jointure equipment)
--   - idx_comp_usr_tch / idx_print_usr_tch (technicien responsable)
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [V2] v_admin_tickets_en_retard
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'V_ADMIN_RETARD' FOR
SELECT
    t.id                                            AS ticket_id,
    t.name                                          AS sujet,
    t.date_issue,
    TRUNC(SYSDATE - CAST(t.date_issue AS DATE))     AS jours_ouverts,
    CASE t.status
        WHEN 1 THEN 'Nouveau'
        WHEN 2 THEN 'En cours'
        WHEN 3 THEN 'En attente'
    END                                             AS statut,
    e.name                                          AS site,
    l.name                                          AS localisation,
    u.firstname  || ' ' || u.realname               AS demandeur,
    eq.name                                         AS equipement_concerne,
    tech.firstname || ' ' || tech.realname          AS technicien_responsable
FROM glpi_tickets                                   t
JOIN  glpi_entities                                 e    ON e.id    = t.entities_id
JOIN  glpi_equipments                               eq   ON eq.id   = t.equipment_id
LEFT JOIN glpi_locations                            l    ON l.id    = t.locations_id
LEFT JOIN glpi_users                                u    ON u.id    = t.users_id
LEFT JOIN glpi_computers                            c    ON c.id    = eq.id
LEFT JOIN glpi_printers                             p    ON p.id    = eq.id
LEFT JOIN glpi_users                                tech ON tech.id = COALESCE(c.users_id_tech, p.users_id_tech)
WHERE t.status IN (1, 2, 3)
AND  (SYSDATE - CAST(t.date_issue AS DATE)) >= 15
AND   UPPER(e.name) = SUBSTR(
          SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),
          INSTR(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),'|') + 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'V_ADMIN_RETARD', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [V3] v_admin_equipements_inactifs
-- Requete principale : equipements en stock/reparation/rebut du site courant
-- Index attendus :
--   - idx_comp_states / idx_print_states (filtre states_id IN (2,3,4))
--   - idx_equip_ent (filtre site)
--   - uk_ent_name sur glpi_entities (filtre UPPER(e.name))
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [V3] v_admin_equipements_inactifs
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'V_ADMIN_INACTIFS' FOR
SELECT
    eq.id                               AS equipment_id,
    eq.name                             AS equipement,
    eq.itemtype,
    l.name                              AS salle,
    e.name                              AS site,
    CASE COALESCE(c.states_id, p.states_id)
        WHEN 2 THEN 'En stock'
        WHEN 3 THEN 'En reparation'
        WHEN 4 THEN 'Rebut'
    END                                 AS statut,
    COALESCE(c.serial, p.serial)        AS serial
FROM glpi_equipments                    eq
JOIN  glpi_entities                     e  ON e.id  = eq.entities_id
LEFT JOIN glpi_locations                l  ON l.id  = eq.locations_id
LEFT JOIN glpi_computers                c  ON c.id  = eq.id
LEFT JOIN glpi_printers                 p  ON p.id  = eq.id
WHERE COALESCE(c.states_id, p.states_id) IN (2, 3, 4)
AND   UPPER(e.name) = SUBSTR(
          SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),
          INSTR(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),'|') + 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'V_ADMIN_INACTIFS', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [V4] v_read_tickets_non_resolus
-- Requete principale : agregation COUNT/SUM par site, tous status actifs
-- Index attendus :
--   - idx_tick_status (filtre + full scan reduit)
--   - idx_tick_ent_id (GROUP BY entities_id -> partition pruning)
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [V4] v_read_tickets_non_resolus
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'V_READ_TICKETS' FOR
SELECT
    e.name                          AS site,
    COUNT(*)                        AS nb_tickets_ouverts,
    SUM(CASE WHEN t.status = 1 THEN 1 ELSE 0 END)  AS nb_nouveaux,
    SUM(CASE WHEN t.status = 2 THEN 1 ELSE 0 END)  AS nb_en_cours,
    SUM(CASE WHEN t.status = 3 THEN 1 ELSE 0 END)  AS nb_en_attente
FROM glpi_tickets       t
JOIN glpi_entities      e  ON e.id = t.entities_id
WHERE t.status IN (1, 2, 3)
GROUP BY e.name;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'V_READ_TICKETS', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [V5] v_admin_charge_techniciens
-- Vue logique sur mv_charge_techniciens avec filtre CLIENT_IDENTIFIER
-- La MV est une table physique : acces direct par Full Table Scan ou index site
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [V5] v_admin_charge_techniciens (MV filtree par site)
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'V_ADMIN_CHARGE' FOR
SELECT technicien, site, nb_computers, nb_printers, total_equipements
FROM mv_charge_techniciens
WHERE UPPER(site) = SUBSTR(
    SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),
    INSTR(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),'|') + 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'V_ADMIN_CHARGE', format => 'ALL'));


-- =============================================================================
-- SECTION 2 : VUES MATERIALISEES (requete de construction)
-- Note : EXPLAIN PLAN sur une MV = plan de la requete sous-jacente,
--        pas du refresh lui-meme (qui est gere par DBMS_MVIEW)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- [MV1] mv_charge_techniciens
-- Requete : agregation COUNT DISTINCT par technicien et site
-- Jointures : glpi_users -> computers/printers -> equipments -> entities
-- Index attendus :
--   - idx_comp_usr_tch / idx_print_usr_tch (filtrage techniciens assignes)
--   - idx_equip_ent (jointure entities)
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [MV1] mv_charge_techniciens (requete de construction)
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'MV_CHARGE' FOR
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
    SELECT users_id_tech FROM glpi_computers  WHERE users_id_tech IS NOT NULL
    UNION
    SELECT users_id_tech FROM glpi_printers   WHERE users_id_tech IS NOT NULL
)
GROUP BY tech.id, tech.firstname, tech.realname, e.name;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'MV_CHARGE', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [MV2] mv_read_parc_par_site
-- Requete : agregation SUM CASE par type d'equipement et site
-- Index attendus :
--   - idx_equip_ent (GROUP BY entities_id -> partition pruning)
--   - idx_equip_type (filtre itemtype dans CASE)
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [MV2] mv_read_parc_par_site (requete de construction)
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'MV_PARC' FOR
SELECT
    e.name                                          AS site,
    SUM(CASE WHEN eq.itemtype = 'Computer' THEN 1 ELSE 0 END)  AS nb_computers,
    SUM(CASE WHEN eq.itemtype = 'Printer'  THEN 1 ELSE 0 END)  AS nb_printers,
    COUNT(*)                                        AS total_equipements
FROM glpi_equipments    eq
JOIN glpi_entities      e  ON e.id = eq.entities_id
GROUP BY e.name;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'MV_PARC', format => 'ALL'));


-- =============================================================================
-- SECTION 3 : FONCTIONS METIER
-- =============================================================================

-- -----------------------------------------------------------------------------
-- [F1] get_equip_technicien
-- SELECT BULK COLLECT : computers + printers d'un technicien donne
-- Index attendus :
--   - idx_comp_usr_tch (filtre users_id_tech = p_tech_id)
--   - idx_print_usr_tch (idem pour printers)
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [F1] get_equip_technicien - SELECT computers
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_GET_EQUIP_COMP' FOR
SELECT id FROM glpi_computers
WHERE users_id_tech = 1;  -- parametre p_tech_id

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_GET_EQUIP_COMP', format => 'ALL'));

PROMPT ============================================================
PROMPT  [F1] get_equip_technicien - SELECT printers
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_GET_EQUIP_PRINT' FOR
SELECT id FROM glpi_printers
WHERE users_id_tech = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_GET_EQUIP_PRINT', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [F2] redistribuer_equip
-- CURSOR + UPDATE round-robin : techniciens restants sur un site, puis UPDATE
-- Index attendus :
--   - idx_comp_usr_tch / idx_print_usr_tch (CURSOR techniciens)
--   - idx_equip_ent (filtre entities_id dans le curseur)
--   - idx_equip_type (UPDATE selon itemtype)
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [F2] redistribuer_equip - CURSOR techniciens restants
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_REDISTRIB_CUR' FOR
SELECT DISTINCT c.users_id_tech
FROM glpi_computers c
JOIN glpi_equipments eq ON eq.id = c.id
WHERE eq.entities_id = 1        -- parametre p_entities_id
AND c.users_id_tech IS NOT NULL
AND c.users_id_tech != 99       -- parametre p_tech_exclu
UNION
SELECT DISTINCT p.users_id_tech
FROM glpi_printers p
JOIN glpi_equipments eq ON eq.id = p.id
WHERE eq.entities_id = 1
AND p.users_id_tech IS NOT NULL
AND p.users_id_tech != 99;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_REDISTRIB_CUR', format => 'ALL'));

PROMPT ============================================================
PROMPT  [F2] redistribuer_equip - SELECT itemtype
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_REDISTRIB_TYPE' FOR
SELECT itemtype FROM glpi_equipments WHERE id = 1;  -- parametre p_equip_ids(i)

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_REDISTRIB_TYPE', format => 'ALL'));

PROMPT ============================================================
PROMPT  [F2] redistribuer_equip - UPDATE glpi_computers
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_REDISTRIB_UPD_C' FOR
UPDATE glpi_computers SET users_id_tech = 2
WHERE id = 1;  -- parametre p_equip_ids(i) apres verification itemtype

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_REDISTRIB_UPD_C', format => 'ALL'));

PROMPT ============================================================
PROMPT  [F2] redistribuer_equip - UPDATE glpi_printers
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_REDISTRIB_UPD_P' FOR
UPDATE glpi_printers SET users_id_tech = 2
WHERE id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_REDISTRIB_UPD_P', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [F3] repartition_charge_nouveau_tech
-- Requetes : COUNT equipements site, COUNT techniciens, CURSOR charge, CURSOR eligible
-- Index attendus :
--   - idx_equip_ent (COUNT equipements)
--   - idx_comp_usr_tch / idx_print_usr_tch (COUNT techniciens, CURSOR charge)
--   - idx_tick_equip_id + idx_tick_status (NOT EXISTS tickets bloquants)
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [F3] repartition_charge_nouveau_tech - COUNT equipements du site
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_REPT_CNT_EQ' FOR
SELECT COUNT(*) FROM glpi_equipments WHERE entities_id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_REPT_CNT_EQ', format => 'ALL'));

PROMPT ============================================================
PROMPT  [F3] repartition_charge_nouveau_tech - COUNT techniciens distincts du site
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_REPT_CNT_TCH' FOR
SELECT COUNT(DISTINCT tech_id)
FROM (
    SELECT c.users_id_tech AS tech_id
    FROM glpi_computers c
    JOIN glpi_equipments eq ON eq.id = c.id
    WHERE eq.entities_id = 1 AND c.users_id_tech IS NOT NULL
    UNION
    SELECT p.users_id_tech AS tech_id
    FROM glpi_printers p
    JOIN glpi_equipments eq ON eq.id = p.id
    WHERE eq.entities_id = 1 AND p.users_id_tech IS NOT NULL
);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_REPT_CNT_TCH', format => 'ALL'));

PROMPT ============================================================
PROMPT  [F3] repartition_charge_nouveau_tech - CURSOR charge par technicien
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_REPT_CUR_CHARGE' FOR
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

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_REPT_CUR_CHARGE', format => 'ALL'));

PROMPT ============================================================
PROMPT  [F3] repartition_charge_nouveau_tech - CURSOR equipements eligibles
PROMPT        (sans ticket bloquant, ordre aleatoire, FETCH FIRST n ROWS ONLY)
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_REPT_CUR_ELIG' FOR
SELECT eq.id
FROM glpi_equipments eq
WHERE eq.entities_id = 1
AND (
    (eq.itemtype = 'Computer' AND EXISTS (
        SELECT 1 FROM glpi_computers c
        WHERE c.id = eq.id AND c.users_id_tech = 2  -- parametre p_tech_id
    ))
    OR
    (eq.itemtype = 'Printer' AND EXISTS (
        SELECT 1 FROM glpi_printers p
        WHERE p.id = eq.id AND p.users_id_tech = 2
    ))
)
AND NOT EXISTS (
    SELECT 1 FROM glpi_tickets t
    WHERE t.equipment_id = eq.id
    AND t.status IN (2, 3)
)
ORDER BY DBMS_RANDOM.VALUE
FETCH FIRST 3 ROWS ONLY;  -- parametre p_nb

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_REPT_CUR_ELIG', format => 'ALL'));

PROMPT ============================================================
PROMPT  [F3] repartition_charge_nouveau_tech - UPDATE desaffectation Computer
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_REPT_UPD_C' FOR
UPDATE glpi_computers SET users_id_tech = NULL
WHERE id = 1
AND EXISTS (SELECT 1 FROM glpi_equipments WHERE id = 1 AND itemtype = 'Computer');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_REPT_UPD_C', format => 'ALL'));

PROMPT ============================================================
PROMPT  [F3] repartition_charge_nouveau_tech - UPDATE desaffectation Printer
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'F_REPT_UPD_P' FOR
UPDATE glpi_printers SET users_id_tech = NULL
WHERE id = 1
AND EXISTS (SELECT 1 FROM glpi_equipments WHERE id = 1 AND itemtype = 'Printer');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'F_REPT_UPD_P', format => 'ALL'));


-- =============================================================================
-- SECTION 4 : PROCEDURES METIER (14 procedures)
-- Chaque requete SQL interne est expliquee separement avec un STATEMENT_ID unique.
-- Les litteraux scalaires remplacent les variables PL/SQL (:bind non gere par EXPLAIN PLAN).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- [P01] ajouter_admin
-- Requetes : SELECT id FROM glpi_entities, SELECT id FROM glpi_profiles,
--            SELECT COUNT(*) FROM glpi_users (boucle pseudo),
--            INSERT glpi_users, INSERT glpi_profiles_users
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P01] ajouter_admin
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P01_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P01_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P01_SEL_PROF' FOR
SELECT id FROM glpi_profiles WHERE UPPER(name) = 'ADMINISTRATEUR';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P01_SEL_PROF', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P01_SEL_PSEUDO' FOR
SELECT COUNT(*) FROM glpi_users WHERE pseudo = 'JADMIN';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P01_SEL_PSEUDO', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P01_INS_USR' FOR
INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
VALUES ('JADMIN', 'Jean', 'Admin', 1, 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P01_INS_USR', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P01_INS_PU' FOR
INSERT INTO glpi_profiles_users (users_id, profiles_id, entities_id)
VALUES (999, 1, 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P01_INS_PU', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P02] ajouter_technicien
-- Requetes : SELECT id FROM glpi_entities, SELECT COUNT(*) FROM glpi_users,
--            INSERT glpi_users, INSERT glpi_profiles_users (subquery profil),
--            + appel repartition_charge_nouveau_tech (voir section F3),
--            + UPDATE computers/printers (loop attribution)
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P02] ajouter_technicien
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P02_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P02_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P02_SEL_PSEUDO' FOR
SELECT COUNT(*) FROM glpi_users WHERE pseudo = 'FMARTIN';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P02_SEL_PSEUDO', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P02_INS_USR' FOR
INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
VALUES ('FMARTIN', 'Fabrice', 'Martin', 1, 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P02_INS_USR', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P02_INS_PU' FOR
INSERT INTO glpi_profiles_users (users_id, profiles_id, entities_id)
VALUES (999, (SELECT id FROM glpi_profiles WHERE UPPER(name) = 'TECHNICIEN'), 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P02_INS_PU', format => 'ALL'));

-- UPDATE attribution equipements (loop) -> meme plan que F2
EXPLAIN PLAN SET STATEMENT_ID = 'P02_SEL_ITYPE' FOR
SELECT itemtype FROM glpi_equipments WHERE id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P02_SEL_ITYPE', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P02_UPD_COMP' FOR
UPDATE glpi_computers SET users_id_tech = 999 WHERE id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P02_UPD_COMP', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P02_UPD_PRINT' FOR
UPDATE glpi_printers SET users_id_tech = 999 WHERE id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P02_UPD_PRINT', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P03] ajouter_utilisateur_lambda
-- Requetes : SELECT id FROM glpi_entities,
--            SELECT COUNT(*) FROM glpi_users (boucle pseudo),
--            INSERT glpi_users
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P03] ajouter_utilisateur_lambda
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P03_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P03_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P03_SEL_PSEUDO' FOR
SELECT COUNT(*) FROM glpi_users WHERE pseudo = 'TDEMO';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P03_SEL_PSEUDO', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P03_INS_USR' FOR
INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
VALUES ('TDEMO', 'Test', 'Demo', 1, 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P03_INS_USR', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P04] ajouter_equipement
-- Requetes : SELECT id FROM glpi_entities, SELECT id FROM glpi_networks,
--            INSERT glpi_ipaddresses, INSERT glpi_equipments,
--            INSERT glpi_computers / INSERT glpi_printers
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P04] ajouter_equipement
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P04_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P04_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P04_SEL_NET' FOR
SELECT id FROM glpi_networks WHERE entities_id = 1 AND ROWNUM = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P04_SEL_NET', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P04_INS_IP' FOR
INSERT INTO glpi_ipaddresses (name, networks_id) VALUES ('10.1.0.101', 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P04_INS_IP', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P04_INS_EQ' FOR
INSERT INTO glpi_equipments (name, itemtype, entities_id, ipaddresses_id)
VALUES ('EQ-10101', 'Computer', 1, 999);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P04_INS_EQ', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P04_INS_COMP' FOR
INSERT INTO glpi_computers (id, serial, states_id) VALUES (999, 'SER-001', 2);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P04_INS_COMP', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P04_INS_PRINT' FOR
INSERT INTO glpi_printers (id, serial, states_id) VALUES (999, 'SER-P01', 2);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P04_INS_PRINT', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P05] affecter_localisation_equipement
-- Requetes : SELECT id FROM glpi_equipments (name),
--            SELECT id FROM glpi_locations (name + entities_id),
--            UPDATE glpi_equipments SET locations_id
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P05] affecter_localisation_equipement
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P05_SEL_EQ' FOR
SELECT id, entities_id FROM glpi_equipments
WHERE UPPER(name) = UPPER('EQ-10001') AND ROWNUM = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P05_SEL_EQ', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P05_SEL_LOC' FOR
SELECT id FROM glpi_locations
WHERE UPPER(name) = UPPER('LOC-1') AND entities_id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P05_SEL_LOC', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P05_UPD_EQ' FOR
UPDATE glpi_equipments SET locations_id = 1 WHERE id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P05_UPD_EQ', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P06] affecter_technicien_equipement
-- Requetes : SELECT id FROM glpi_entities (site),
--            SELECT id+entities_id+itemtype FROM glpi_equipments,
--            SELECT u.id FROM glpi_users JOIN profiles (technicien actif),
--            UPDATE glpi_computers ou glpi_printers
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P06] affecter_technicien_equipement
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P06_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P06_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P06_SEL_EQ' FOR
SELECT id, entities_id, itemtype FROM glpi_equipments
WHERE UPPER(name) = UPPER('EQ-10001') AND ROWNUM = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P06_SEL_EQ', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P06_SEL_TECH' FOR
SELECT u.id FROM glpi_users u
JOIN glpi_profiles_users pu ON pu.users_id = u.id
JOIN glpi_profiles p ON p.id = pu.profiles_id
WHERE UPPER(u.pseudo) = UPPER('FMARTIN')
AND UPPER(p.name) = 'TECHNICIEN' AND u.is_active = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P06_SEL_TECH', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P06_UPD_COMP' FOR
UPDATE glpi_computers SET users_id_tech = 999 WHERE id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P06_UPD_COMP', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P06_UPD_PRINT' FOR
UPDATE glpi_printers SET users_id_tech = 999 WHERE id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P06_UPD_PRINT', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P07] changer_statut_equipement
-- Requetes : SELECT id FROM glpi_entities (site),
--            SELECT id+entities_id+itemtype FROM glpi_equipments,
--            UPDATE glpi_computers ou glpi_printers SET states_id
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P07] changer_statut_equipement
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P07_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P07_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P07_SEL_EQ' FOR
SELECT id, entities_id, itemtype FROM glpi_equipments
WHERE UPPER(name) = UPPER('EQ-10001') AND ROWNUM = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P07_SEL_EQ', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P07_UPD_COMP' FOR
UPDATE glpi_computers SET states_id = 1 WHERE id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P07_UPD_COMP', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P07_UPD_PRINT' FOR
UPDATE glpi_printers SET states_id = 1 WHERE id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P07_UPD_PRINT', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P08] creer_ticket
-- Requetes : SELECT COUNT(*) FROM glpi_users (utilisateur actif),
--            SELECT eq+entities+location+site+states FROM glpi_equipments JOIN ...,
--            INSERT glpi_tickets
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P08] creer_ticket
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P08_SEL_USR' FOR
SELECT COUNT(*) FROM glpi_users WHERE id = 1 AND is_active = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P08_SEL_USR', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P08_SEL_EQ' FOR
SELECT eq.id, eq.entities_id, eq.locations_id,
       UPPER(e.name),
       COALESCE(c.states_id, p.states_id)
FROM glpi_equipments eq
JOIN glpi_entities   e ON e.id = eq.entities_id
LEFT JOIN glpi_computers c ON c.id = eq.id
LEFT JOIN glpi_printers  p ON p.id = eq.id
WHERE UPPER(eq.name) = UPPER('EQ-10001') AND ROWNUM = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P08_SEL_EQ', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P08_INS_TKT' FOR
INSERT INTO glpi_tickets (name, content, status, entities_id, locations_id, equipment_id, users_id)
VALUES ('TKT-100001', 'Panne ecran.', 1, 1, 1, 1, 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P08_INS_TKT', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P09] modifier_statut_ticket
-- Requetes : SELECT id FROM glpi_entities (site),
--            SELECT status+equipment_id+entities_id FROM glpi_tickets JOIN equipments,
--            SELECT COUNT(*) admin check (profiles),
--            SELECT id FROM glpi_users (tech lookup),
--            SELECT COUNT(*) tech ownership (computers/printers),
--            UPDATE glpi_tickets SET status
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P09] modifier_statut_ticket
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P09_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P09_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P09_SEL_TKT' FOR
SELECT t.status, t.equipment_id, eq.entities_id
FROM glpi_tickets t
JOIN glpi_equipments eq ON eq.id = t.equipment_id
WHERE t.id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P09_SEL_TKT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P09_SEL_ADMIN' FOR
SELECT COUNT(*) FROM glpi_users u
JOIN glpi_profiles_users pu ON pu.users_id = u.id
JOIN glpi_profiles p ON p.id = pu.profiles_id
WHERE UPPER(u.pseudo) = 'ADUPONT'
AND UPPER(p.name) = 'ADMINISTRATEUR';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P09_SEL_ADMIN', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P09_SEL_TECH_ID' FOR
SELECT id FROM glpi_users WHERE UPPER(pseudo) = 'FMARTIN' AND is_active = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P09_SEL_TECH_ID', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P09_SEL_TECH_OWN' FOR
SELECT COUNT(*) FROM glpi_equipments eq
LEFT JOIN glpi_computers c ON c.id = eq.id
LEFT JOIN glpi_printers  p ON p.id = eq.id
WHERE eq.id = 1
AND (c.users_id_tech = 999 OR p.users_id_tech = 999);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P09_SEL_TECH_OWN', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P09_UPD_TKT' FOR
UPDATE glpi_tickets SET status = 2 WHERE id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P09_UPD_TKT', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P10] ajouter_lambda_autre_site
-- Requetes : SELECT id FROM glpi_entities (site destination),
--            SELECT id+firstname+realname+entities_id FROM glpi_users (source),
--            SELECT COUNT(*) FROM glpi_profiles_users (lambda check),
--            SELECT COUNT(*) FROM glpi_users (pseudo doublon),
--            INSERT glpi_users
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P10] ajouter_lambda_autre_site
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P10_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P10_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P10_SEL_USR_SRC' FOR
SELECT id, firstname, realname, entities_id
FROM glpi_users
WHERE UPPER(pseudo) = UPPER('UP005') AND is_active = 1 AND ROWNUM = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P10_SEL_USR_SRC', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P10_SEL_PU' FOR
SELECT COUNT(*) FROM glpi_profiles_users WHERE users_id = 999;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P10_SEL_PU', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P10_SEL_PSEUDO' FOR
SELECT COUNT(*) FROM glpi_users WHERE UPPER(pseudo) = 'UP005_CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P10_SEL_PSEUDO', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P10_INS_USR' FOR
INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
VALUES ('UP005_CERGY', 'Jean', 'Dupont', 1, 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P10_INS_USR', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P11] ajouter_tech_ou_admin_autre_site
-- Requetes : SELECT id FROM glpi_entities (destination),
--            SELECT firstname+realname+entities_id+profile FROM glpi_users JOIN profiles,
--            SELECT COUNT(*) FROM glpi_users (doublon pseudo),
--            INSERT glpi_users, INSERT glpi_profiles_users
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P11] ajouter_tech_ou_admin_autre_site
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P11_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P11_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P11_SEL_USR_PROF' FOR
SELECT u.firstname, u.realname, u.entities_id, p.id, UPPER(p.name)
FROM glpi_users u
JOIN glpi_profiles_users pu ON pu.users_id = u.id
JOIN glpi_profiles p        ON p.id        = pu.profiles_id
WHERE UPPER(u.pseudo) = UPPER('CBERNARD')
AND u.is_active = 1 AND ROWNUM = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P11_SEL_USR_PROF', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P11_SEL_PSEUDO' FOR
SELECT COUNT(*) FROM glpi_users WHERE UPPER(pseudo) = 'CBERNARD_CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P11_SEL_PSEUDO', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P11_INS_USR' FOR
INSERT INTO glpi_users (pseudo, firstname, realname, entities_id, is_active)
VALUES ('CBERNARD_CERGY', 'Carlos', 'Bernard', 1, 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P11_INS_USR', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P11_INS_PU' FOR
INSERT INTO glpi_profiles_users (users_id, profiles_id, entities_id)
VALUES (999, 2, 1);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P11_INS_PU', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P12] supprimer_utilisateur_lambda
-- Requetes : SELECT id FROM glpi_entities (site appelant),
--            SELECT id+entities_id FROM glpi_users (cible),
--            SELECT COUNT(*) profil non lambda (TECHNICIEN/ADMIN),
--            UPDATE glpi_users SET is_active = 0
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P12] supprimer_utilisateur_lambda
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P12_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P12_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P12_SEL_USR' FOR
SELECT id, entities_id FROM glpi_users
WHERE UPPER(pseudo) = UPPER('TDEMO') AND is_active = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P12_SEL_USR', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P12_SEL_PROFIL' FOR
SELECT COUNT(*) FROM glpi_profiles_users pu
JOIN glpi_profiles p ON p.id = pu.profiles_id
WHERE pu.users_id = 999
AND UPPER(p.name) IN ('TECHNICIEN', 'ADMINISTRATEUR');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P12_SEL_PROFIL', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P12_UPD_USR' FOR
UPDATE glpi_users SET is_active = 0 WHERE id = 999;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P12_UPD_USR', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P13] supprimer_admin
-- Requetes : SELECT id+entities_id+site FROM glpi_users JOIN entities,
--            SELECT COUNT(*) is_admin check,
--            SELECT COUNT(*) last man standing,
--            UPDATE glpi_users SET is_active = 0,
--            DELETE FROM glpi_profiles_users
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P13] supprimer_admin
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P13_SEL_USR' FOR
SELECT u.id, u.entities_id, UPPER(e.name)
FROM glpi_users u
JOIN glpi_entities e ON e.id = u.entities_id
WHERE UPPER(u.pseudo) = UPPER('EPERON') AND u.is_active = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P13_SEL_USR', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P13_SEL_IS_ADMIN' FOR
SELECT COUNT(*) FROM glpi_profiles_users pu
JOIN glpi_profiles p ON p.id = pu.profiles_id
WHERE pu.users_id = 999 AND UPPER(p.name) = 'ADMINISTRATEUR';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P13_SEL_IS_ADMIN', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P13_SEL_LMS' FOR
SELECT COUNT(*) FROM glpi_users u
JOIN glpi_profiles_users pu ON pu.users_id = u.id
JOIN glpi_profiles p ON p.id = pu.profiles_id
WHERE u.entities_id = 1
AND u.is_active = 1
AND UPPER(p.name) = 'ADMINISTRATEUR';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P13_SEL_LMS', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P13_UPD_USR' FOR
UPDATE glpi_users SET is_active = 0 WHERE id = 999;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P13_UPD_USR', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P13_DEL_PU' FOR
DELETE FROM glpi_profiles_users WHERE users_id = 999;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P13_DEL_PU', format => 'ALL'));


-- -----------------------------------------------------------------------------
-- [P14] supprimer_technicien
-- Requetes : SELECT id FROM glpi_entities (site appelant),
--            SELECT id+entities_id FROM glpi_users (cible),
--            SELECT COUNT(*) is_tech check,
--            + appels get_equip_technicien et redistribuer_equip (voir F1, F2),
--            UPDATE glpi_users SET is_active = 0,
--            DELETE FROM glpi_profiles_users
-- -----------------------------------------------------------------------------
PROMPT ============================================================
PROMPT  [P14] supprimer_technicien
PROMPT ============================================================

EXPLAIN PLAN SET STATEMENT_ID = 'P14_SEL_ENT' FOR
SELECT id FROM glpi_entities WHERE UPPER(name) = 'CERGY';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P14_SEL_ENT', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P14_SEL_USR' FOR
SELECT id, entities_id FROM glpi_users
WHERE UPPER(pseudo) = UPPER('FMARTIN') AND is_active = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P14_SEL_USR', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P14_SEL_IS_TECH' FOR
SELECT COUNT(*) FROM glpi_profiles_users pu
JOIN glpi_profiles p ON p.id = pu.profiles_id
WHERE pu.users_id = 999 AND UPPER(p.name) = 'TECHNICIEN';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P14_SEL_IS_TECH', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P14_UPD_USR' FOR
UPDATE glpi_users SET is_active = 0 WHERE id = 999;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P14_UPD_USR', format => 'ALL'));

EXPLAIN PLAN SET STATEMENT_ID = 'P14_DEL_PU' FOR
DELETE FROM glpi_profiles_users WHERE users_id = 999;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'P14_DEL_PU', format => 'ALL'));


-- =============================================================================
-- RECAPITULATIF : nom de l'objet + cout total estime
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  RECAPITULATIF - Cout estime par objet (tri decroissant)
PROMPT ================================================================

COLUMN nom_objet  FORMAT A40  HEADING 'OBJET'
COLUMN cout_total FORMAT 9999 HEADING 'COUT TOTAL'

SELECT
    CASE
        WHEN statement_id LIKE 'V1_%'  THEN 'v_tech_tickets_actifs'
        WHEN statement_id LIKE 'V2_%'  THEN 'v_admin_tickets_en_retard'
        WHEN statement_id LIKE 'V3_%'  THEN 'v_admin_equipements_inactifs'
        WHEN statement_id LIKE 'V4_%'  THEN 'v_read_tickets_non_resolus'
        WHEN statement_id LIKE 'V5_%'  THEN 'v_admin_charge_techniciens'
        WHEN statement_id LIKE 'MV1_%' THEN 'mv_charge_techniciens'
        WHEN statement_id LIKE 'MV2_%' THEN 'mv_read_parc_par_site'
        WHEN statement_id LIKE 'F1_%'  THEN 'get_equip_technicien'
        WHEN statement_id LIKE 'F2_%'  THEN 'redistribuer_equip'
        WHEN statement_id LIKE 'F3_%'  THEN 'repartition_charge_nouveau_tech'
        WHEN statement_id LIKE 'P01_%' THEN 'ajouter_admin'
        WHEN statement_id LIKE 'P02_%' THEN 'ajouter_technicien'
        WHEN statement_id LIKE 'P03_%' THEN 'ajouter_utilisateur_lambda'
        WHEN statement_id LIKE 'P04_%' THEN 'ajouter_equipement'
        WHEN statement_id LIKE 'P05_%' THEN 'affecter_localisation_equipement'
        WHEN statement_id LIKE 'P06_%' THEN 'affecter_technicien_equipement'
        WHEN statement_id LIKE 'P07_%' THEN 'changer_statut_equipement'
        WHEN statement_id LIKE 'P08_%' THEN 'creer_ticket'
        WHEN statement_id LIKE 'P09_%' THEN 'modifier_statut_ticket'
        WHEN statement_id LIKE 'P10_%' THEN 'ajouter_lambda_autre_site'
        WHEN statement_id LIKE 'P11_%' THEN 'ajouter_tech_ou_admin_autre_site'
        WHEN statement_id LIKE 'P12_%' THEN 'supprimer_utilisateur_lambda'
        WHEN statement_id LIKE 'P13_%' THEN 'supprimer_admin'
        WHEN statement_id LIKE 'P14_%' THEN 'supprimer_technicien'
    END             AS nom_objet,
    SUM(NVL(COST,0)) AS cout_total
FROM plan_table
WHERE id = 0
GROUP BY
    CASE
        WHEN statement_id LIKE 'V1_%'  THEN 'v_tech_tickets_actifs'
        WHEN statement_id LIKE 'V2_%'  THEN 'v_admin_tickets_en_retard'
        WHEN statement_id LIKE 'V3_%'  THEN 'v_admin_equipements_inactifs'
        WHEN statement_id LIKE 'V4_%'  THEN 'v_read_tickets_non_resolus'
        WHEN statement_id LIKE 'V5_%'  THEN 'v_admin_charge_techniciens'
        WHEN statement_id LIKE 'MV1_%' THEN 'mv_charge_techniciens'
        WHEN statement_id LIKE 'MV2_%' THEN 'mv_read_parc_par_site'
        WHEN statement_id LIKE 'F1_%'  THEN 'get_equip_technicien'
        WHEN statement_id LIKE 'F2_%'  THEN 'redistribuer_equip'
        WHEN statement_id LIKE 'F3_%'  THEN 'repartition_charge_nouveau_tech'
        WHEN statement_id LIKE 'P01_%' THEN 'ajouter_admin'
        WHEN statement_id LIKE 'P02_%' THEN 'ajouter_technicien'
        WHEN statement_id LIKE 'P03_%' THEN 'ajouter_utilisateur_lambda'
        WHEN statement_id LIKE 'P04_%' THEN 'ajouter_equipement'
        WHEN statement_id LIKE 'P05_%' THEN 'affecter_localisation_equipement'
        WHEN statement_id LIKE 'P06_%' THEN 'affecter_technicien_equipement'
        WHEN statement_id LIKE 'P07_%' THEN 'changer_statut_equipement'
        WHEN statement_id LIKE 'P08_%' THEN 'creer_ticket'
        WHEN statement_id LIKE 'P09_%' THEN 'modifier_statut_ticket'
        WHEN statement_id LIKE 'P10_%' THEN 'ajouter_lambda_autre_site'
        WHEN statement_id LIKE 'P11_%' THEN 'ajouter_tech_ou_admin_autre_site'
        WHEN statement_id LIKE 'P12_%' THEN 'supprimer_utilisateur_lambda'
        WHEN statement_id LIKE 'P13_%' THEN 'supprimer_admin'
        WHEN statement_id LIKE 'P14_%' THEN 'supprimer_technicien'
    END
ORDER BY cout_total DESC NULLS LAST;

PROMPT ================================================================
PROMPT  Fichier termine - explain_plan.sql
PROMPT ================================================================
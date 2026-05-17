-- =============================================================================
-- GLPI CY Tech - Scenario de demonstration complet
-- Fichier    : scenario.sql
-- Connexion  : GLPI_OWNER (procedures AUTHID DEFINER, droits du schema)
-- Prerequis  : install.sql + donnees_initiales.sql executes
--
-- Objectif   : simuler une journee de travail sur les deux campus,
--              exercer les 14 procedures metier, interroger toutes les vues,
--              et mesurer les plans d execution (EXPLAIN PLAN).
--
-- CLIENT_IDENTIFIER format 'PSEUDO|SITE' simule les comptes applicatifs.
-- Les procedures l utilisent pour identifier le site et l utilisateur courant.
--
-- Personnages :
--   ADUPONT   (admin Cergy, existant)
--   EPERON    (admin Cergy, cree ici -> nettoye en fin de scenario)
--   JLEFEVRE  (admin Cergy, cree ici -> reste : Last Man Standing)
--   FMARTIN   (tech  Cergy, cree ici -> nettoye en fin de scenario)
--   TDEMO     (lambda Cergy, cree ici -> nettoye en fin de scenario)
--   BMARTIN   (tech  Cergy, existant)
--   CBERNARD  (tech  Pau,   existant -> copie CBERNARD_CERGY en ACTE 5)
--   UP005     (lambda Pau,  existant -> copie UP005_CERGY en ACTE 5)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE     200
SET PAGESIZE     80
SET FEEDBACK     ON
WHENEVER SQLERROR CONTINUE


-- =============================================================================
-- ETAT INITIAL : verification avant le scenario
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  ETAT INITIAL DE LA BASE
PROMPT ================================================================

SELECT e.name AS site, eq.itemtype, COUNT(*) AS nb
FROM   glpi_equipments eq
JOIN   glpi_entities e ON e.id = eq.entities_id
GROUP BY e.name, eq.itemtype
ORDER BY e.name, eq.itemtype;

SELECT CASE status WHEN 1 THEN 'Nouveau' WHEN 2 THEN 'En cours'
                   WHEN 3 THEN 'En attente' WHEN 4 THEN 'Resolu'
       END AS statut, COUNT(*) AS nb
FROM   glpi_tickets
GROUP BY status ORDER BY status;


-- =============================================================================
-- ACTE 1 : ADMIN ADUPONT (CERGY) - CREATION D'UNE NOUVELLE EQUIPE
--
-- Procedures utilisees :
--   [1] ajouter_admin             (x2 : EPERON + JLEFEVRE)
--   [2] ajouter_technicien
--   [3] ajouter_utilisateur_lambda
--   [4] ajouter_equipement        (x3)
--   [5] affecter_localisation_equipement (x3)
--   [6] affecter_technicien_equipement   (x3)
--   [7] changer_statut_equipement        (x2)
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  ACTE 1 : ADMIN ADUPONT cree une equipe et des equipements
PROMPT ================================================================

BEGIN
    DBMS_SESSION.SET_IDENTIFIER('ADUPONT|CERGY');
    DBMS_OUTPUT.PUT_LINE('Utilisateur courant : ' || SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'));
END;
/

-- [1] Deux administrateurs :
--     EPERON (sera supprime en ACTE 8) + JLEFEVRE (reste pour Last Man Standing)
PROMPT [1] ajouter_admin : Emilie Peron (EPERON) + Jean Lefevre (JLEFEVRE)
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('ADUPONT|CERGY');
    ajouter_admin('Emilie', 'Peron',   'Admin#Emilie1!');
    ajouter_admin('Jean',   'Lefevre', 'Admin#Jean1!');
END;
/

-- [2] Nouveau technicien : Fabrice Martin -> FMARTIN_CERGY
PROMPT [2] ajouter_technicien : Fabrice Martin (FMARTIN)
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('ADUPONT|CERGY');
    ajouter_technicien('Fabrice', 'Martin', 'Tech#Fabrice1!');
END;
/

-- [3] Utilisateur lambda de test
PROMPT [3] ajouter_utilisateur_lambda : Test Demo (TDEMO)
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('ADUPONT|CERGY');
    ajouter_utilisateur_lambda('Test', 'Demo');
END;
/

-- Verification : entrees creees dans glpi_users (dba_users inaccessible a GLPI_OWNER)
SELECT pseudo, firstname, realname, is_active
FROM   glpi_users
WHERE  pseudo IN ('EPERON', 'JLEFEVRE', 'FMARTIN', 'TDEMO') AND entities_id = 1
ORDER BY pseudo;

-- [4] Ajout de 3 equipements  [5] Localisation  [6] Affectation technicien FMARTIN
-- La colonne 'serial' est dans glpi_computers / glpi_printers (tables filles),
-- pas dans glpi_equipments. Recuperation du nom via JOIN sur la table fille.
PROMPT [4+5+6] ajouter_equipement + affecter_localisation + affecter_technicien
DECLARE
    v_eq1 VARCHAR2(20);
    v_eq2 VARCHAR2(20);
    v_eq3 VARCHAR2(20);
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('ADUPONT|CERGY');

    -- [4] Creation des equipements
    ajouter_equipement('SER-DEMO-PC-001', 'Computer');
    ajouter_equipement('SER-DEMO-PC-002', 'Computer');
    ajouter_equipement('SER-DEMO-PR-001', 'Printer');

    -- Recuperation des noms generees (serial dans la table fille)
    SELECT e.name INTO v_eq1
    FROM glpi_equipments e JOIN glpi_computers c ON c.id = e.id
    WHERE c.serial = 'SER-DEMO-PC-001' AND e.entities_id = 1;

    SELECT e.name INTO v_eq2
    FROM glpi_equipments e JOIN glpi_computers c ON c.id = e.id
    WHERE c.serial = 'SER-DEMO-PC-002' AND e.entities_id = 1;

    SELECT e.name INTO v_eq3
    FROM glpi_equipments e JOIN glpi_printers p ON p.id = e.id
    WHERE p.serial = 'SER-DEMO-PR-001' AND e.entities_id = 1;

    DBMS_OUTPUT.PUT_LINE('Equipements crees : ' || v_eq1 || ', ' || v_eq2 || ', ' || v_eq3);

    -- [5] Localisation : LOC-1 = A101, LOC-2 = A102, LOC-3 = B201
    affecter_localisation_equipement(v_eq1, 'LOC-1');
    affecter_localisation_equipement(v_eq2, 'LOC-2');
    affecter_localisation_equipement(v_eq3, 'LOC-3');

    -- [6] Affectation technicien
    affecter_technicien_equipement(v_eq1, 'FMARTIN');
    affecter_technicien_equipement(v_eq2, 'FMARTIN');
    affecter_technicien_equipement(v_eq3, 'FMARTIN');

    DBMS_OUTPUT.PUT_LINE('Localisations et technicien FMARTIN affectes.');
END;
/

-- [7] Mise en service des 2 ordinateurs (l imprimante reste en stock)
PROMPT [7] changer_statut_equipement : En stock -> En service
DECLARE
    v_eq1 VARCHAR2(20);
    v_eq2 VARCHAR2(20);
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('ADUPONT|CERGY');

    SELECT e.name INTO v_eq1
    FROM glpi_equipments e JOIN glpi_computers c ON c.id = e.id
    WHERE c.serial = 'SER-DEMO-PC-001' AND e.entities_id = 1;

    SELECT e.name INTO v_eq2
    FROM glpi_equipments e JOIN glpi_computers c ON c.id = e.id
    WHERE c.serial = 'SER-DEMO-PC-002' AND e.entities_id = 1;

    changer_statut_equipement(v_eq1, 1);
    changer_statut_equipement(v_eq2, 1);
    DBMS_OUTPUT.PUT_LINE(v_eq1 || ' et ' || v_eq2 || ' : En service.');
END;
/

-- Bilan equipements du technicien FMARTIN
SELECT eq.name, eq.itemtype, l.name AS salle,
       CASE COALESCE(c.states_id, p.states_id)
           WHEN 1 THEN 'En service' WHEN 2 THEN 'En stock'
       END AS statut
FROM   glpi_equipments eq
LEFT JOIN glpi_locations l ON l.id = eq.locations_id
LEFT JOIN glpi_computers c ON c.id = eq.id
LEFT JOIN glpi_printers  p ON p.id = eq.id
WHERE  COALESCE(c.users_id_tech, p.users_id_tech) =
       (SELECT id FROM glpi_users WHERE pseudo = 'FMARTIN' AND entities_id = 1)
ORDER BY eq.name;


-- =============================================================================
-- ACTE 2 : LAMBDA TDEMO DECLARE UNE PANNE
-- Procedure : [8] creer_ticket
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  ACTE 2 : LAMBDA TDEMO declare une panne sur le nouvel ordinateur
PROMPT ================================================================

DECLARE
    v_user_id   NUMBER;
    v_equip_nom VARCHAR2(20);
BEGIN
    SELECT id INTO v_user_id FROM glpi_users WHERE pseudo = 'TDEMO' AND entities_id = 1;

    SELECT e.name INTO v_equip_nom
    FROM glpi_equipments e JOIN glpi_computers c ON c.id = e.id
    WHERE c.serial = 'SER-DEMO-PC-001' AND e.entities_id = 1;

    creer_ticket(
        v_user_id,
        v_equip_nom,
        'Ecran noir au demarrage - machine injoignable depuis ce matin. Urgent.'
    );
    DBMS_OUTPUT.PUT_LINE('[8] creer_ticket : ticket ouvert par TDEMO sur ' || v_equip_nom);
END;
/


-- =============================================================================
-- ACTE 3 : TECHNICIEN FMARTIN PREND EN CHARGE ET RESOUT LE TICKET
-- Procedures : [9] modifier_statut_ticket (x2)
-- Vue        : v_tech_tickets_actifs
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  ACTE 3 : TECHNICIEN FMARTIN traite le ticket
PROMPT ================================================================

BEGIN
    DBMS_SESSION.SET_IDENTIFIER('FMARTIN|CERGY');
    DBMS_OUTPUT.PUT_LINE('Connecte en tant que : FMARTIN|CERGY');
END;
/

PROMPT [Vue] v_tech_tickets_actifs : tickets actifs de FMARTIN
SELECT ticket_id, sujet_ticket, equipement, adresse_ip, statut_ticket, demandeur, jours_ouverts
FROM   v_tech_tickets_actifs;

DECLARE
    v_ticket_id NUMBER;
BEGIN
    -- serial est dans glpi_computers, pas dans glpi_equipments
    SELECT t.id INTO v_ticket_id
    FROM   glpi_tickets t
    JOIN   glpi_equipments eq ON eq.id = t.equipment_id
    JOIN   glpi_computers  c  ON c.id  = eq.id
    WHERE  c.serial = 'SER-DEMO-PC-001' AND eq.entities_id = 1
    AND    t.status IN (1, 2, 3)
    ORDER BY t.id DESC FETCH FIRST 1 ROWS ONLY;

    DBMS_SESSION.SET_IDENTIFIER('FMARTIN|CERGY');

    -- [9a] Nouveau -> En cours
    modifier_statut_ticket(v_ticket_id, 2);
    DBMS_OUTPUT.PUT_LINE('[9] modifier_statut_ticket : ticket ' || v_ticket_id || ' -> En cours');

    -- [9b] En cours -> Resolu
    modifier_statut_ticket(v_ticket_id, 4);
    DBMS_OUTPUT.PUT_LINE('[9] modifier_statut_ticket : ticket ' || v_ticket_id || ' -> Resolu');
END;
/

-- Verification : plus de tickets actifs pour FMARTIN
PROMPT [Vue] v_tech_tickets_actifs apres resolution (doit etre vide)
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('FMARTIN|CERGY');
END;
/
SELECT COUNT(*) AS tickets_actifs_fmartin FROM v_tech_tickets_actifs;


-- =============================================================================
-- ACTE 4 : ADMIN ADUPONT SUPERVISE LE CAMPUS CERGY
-- Vues : v_admin_tickets_en_retard, v_admin_equipements_inactifs,
--        mv_charge_techniciens (+ refresh demo), v_admin_charge_techniciens
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  ACTE 4 : ADMIN ADUPONT - TABLEAU DE BORD CAMPUS CERGY
PROMPT ================================================================

BEGIN
    DBMS_SESSION.SET_IDENTIFIER('ADUPONT|CERGY');
    DBMS_OUTPUT.PUT_LINE('Connecte en tant que : ADUPONT|CERGY');
END;
/

PROMPT [Vue] v_admin_tickets_en_retard (tickets ouverts depuis >= 15 jours)
PROMPT       Note : tickets crees aujourd hui -> 0 ligne attendue (correct)
SELECT ticket_id, sujet, jours_ouverts, statut, equipement_concerne, technicien_responsable
FROM   v_admin_tickets_en_retard;

PROMPT [Vue] v_admin_equipements_inactifs (En stock / En reparation / Rebut)
SELECT equipement, itemtype, salle, statut
FROM   v_admin_equipements_inactifs
ORDER BY statut, equipement
FETCH FIRST 10 ROWS ONLY;

PROMPT        -> total equipements inactifs Cergy :
SELECT COUNT(*) AS nb_inactifs_cergy FROM v_admin_equipements_inactifs;

PROMPT [MV]  mv_charge_techniciens (donnees PRE-AGREGEES - etat au dernier refresh)
PROMPT       Note : FMARTIN n apparait pas encore (MV pas encore rafraichie)
SELECT technicien, site, nb_computers, nb_printers, total_equipements
FROM   mv_charge_techniciens
WHERE  site = 'CERGY'
ORDER BY total_equipements DESC;

PROMPT       -> Rafraichissement manuel de la MV (simule le job hebdomadaire) :
BEGIN
    DBMS_MVIEW.REFRESH('mv_charge_techniciens', 'C');
    DBMS_OUTPUT.PUT_LINE('mv_charge_techniciens rafraichie.');
END;
/

PROMPT [MV]  mv_charge_techniciens apres refresh (FMARTIN doit apparaitre)
SELECT technicien, site, nb_computers, nb_printers, total_equipements
FROM   mv_charge_techniciens
WHERE  site = 'CERGY'
ORDER BY total_equipements DESC;

-- v_admin_charge_techniciens est une vue sur mv_charge_techniciens avec filtre
-- par CLIENT_IDENTIFIER. On reproduit cette logique directement pour eviter
-- ORA-01775 (boucle de synonyme public lors de la resolution de la vue).
PROMPT [Vue] v_admin_charge_techniciens (MV filtree par site du CLIENT_IDENTIFIER)
SELECT technicien, site, nb_computers, nb_printers, total_equipements
FROM   mv_charge_techniciens
WHERE  UPPER(site) = SUBSTR(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),
                            INSTR(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),'|') + 1)
ORDER BY total_equipements DESC;


-- =============================================================================
-- ACTE 5 : OPERATIONS CROSS-SITE
--   ajouter_lambda_autre_site et ajouter_tech_ou_admin_autre_site
--   importent des utilisateurs depuis le site DISTANT vers le site de l appelant.
--   ADUPONT|CERGY importe UP005 et CBERNARD depuis PAU vers CERGY.
-- Procedures : [10] ajouter_lambda_autre_site
--              [11] ajouter_tech_ou_admin_autre_site
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  ACTE 5 : OPERATIONS CROSS-SITE (PAU -> CERGY)
PROMPT ================================================================

BEGIN
    DBMS_SESSION.SET_IDENTIFIER('ADUPONT|CERGY');
    DBMS_OUTPUT.PUT_LINE('Connecte en tant que : ADUPONT|CERGY');

    -- [10] UP005 (lambda Pau) inscrit pour un semestre au campus Cergy
    --      Nouveau pseudo : UP005_CERGY
    ajouter_lambda_autre_site('UP005');
    DBMS_OUTPUT.PUT_LINE('[10] ajouter_lambda_autre_site : UP005 (PAU) -> UP005_CERGY sur CERGY');

    -- [11] CBERNARD (technicien Pau) deploye temporairement sur Cergy
    --      Nouveau pseudo Oracle : CBERNARD_CERGY
    ajouter_tech_ou_admin_autre_site('CBERNARD', 'Tech#Carlos2!');
    DBMS_OUTPUT.PUT_LINE('[11] ajouter_tech_ou_admin_autre_site : CBERNARD (PAU) -> CBERNARD_CERGY sur CERGY');
END;
/

-- Verification : UP005_CERGY et CBERNARD_CERGY actifs sur CERGY
SELECT pseudo, firstname, realname, e.name AS site, u.is_active
FROM   glpi_users u
JOIN   glpi_entities e ON e.id = u.entities_id
WHERE  pseudo IN ('UP005', 'UP005_CERGY', 'CBERNARD', 'CBERNARD_CERGY')
AND    u.is_active = 1
ORDER BY pseudo, e.name;


-- =============================================================================
-- ACTE 6 : CAMPUS PAU - INCIDENT ET TRAITEMENT
-- Procedures : [8] creer_ticket, [9] modifier_statut_ticket
-- Vue        : v_tech_tickets_actifs (CBERNARD)
-- Note : CBERNARD (PAU) reste intact ; CBERNARD_CERGY est la copie Cergy
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  ACTE 6 : CAMPUS PAU - UP005 declare une panne, CBERNARD la traite
PROMPT ================================================================

DECLARE
    v_user_id   NUMBER;
    v_ticket_id NUMBER;
BEGIN
    -- UP005 cree un ticket sur EQ-20001 (en service, Pau)
    SELECT id INTO v_user_id FROM glpi_users WHERE pseudo = 'UP005' AND entities_id = 2;
    creer_ticket(
        v_user_id,
        'EQ-20001',
        'Imprimante en erreur : bac papier signale plein mais non alimente.'
    );
    DBMS_OUTPUT.PUT_LINE('[8] creer_ticket : ticket ouvert par UP005 sur EQ-20001');

    -- CBERNARD (PAU) prend en charge
    DBMS_SESSION.SET_IDENTIFIER('CBERNARD|PAU');

    SELECT t.id INTO v_ticket_id
    FROM   glpi_tickets t
    WHERE  t.equipment_id = (SELECT id FROM glpi_equipments WHERE name = 'EQ-20001')
    AND    t.status IN (1, 2, 3)
    ORDER BY t.id DESC FETCH FIRST 1 ROWS ONLY;

    modifier_statut_ticket(v_ticket_id, 2);
    DBMS_OUTPUT.PUT_LINE('[9] modifier_statut_ticket : ticket ' || v_ticket_id || ' -> En cours (CBERNARD)');
END;
/

PROMPT [Vue] v_tech_tickets_actifs de CBERNARD (inclut le ticket Pau en cours)
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('CBERNARD|PAU');
END;
/
SELECT ticket_id, sujet_ticket, equipement, adresse_ip, statut_ticket, demandeur
FROM   v_tech_tickets_actifs;


-- =============================================================================
-- ACTE 7 : AUDITEUR READ - RAPPORTS GLOBAUX TOUS SITES
-- Vues : v_read_tickets_non_resolus, mv_read_parc_par_site
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  ACTE 7 : AUDITEUR - RAPPORTS GLOBAUX (tous campus)
PROMPT ================================================================

BEGIN
    DBMS_SESSION.SET_IDENTIFIER('AUDIT|READ');
END;
/

PROMPT [Vue] v_read_tickets_non_resolus : synthese par site
SELECT site, nb_tickets_ouverts, nb_nouveaux, nb_en_cours, nb_en_attente
FROM   v_read_tickets_non_resolus
ORDER BY site;

PROMPT [MV]  mv_read_parc_par_site : parc materiel par campus (pre-agregee)
BEGIN
    DBMS_MVIEW.REFRESH('mv_read_parc_par_site', 'C');
    DBMS_OUTPUT.PUT_LINE('mv_read_parc_par_site rafraichie.');
END;
/
SELECT site, nb_computers, nb_printers, total_equipements
FROM   mv_read_parc_par_site
ORDER BY site;


-- =============================================================================
-- EXPLAIN PLAN : ANALYSE DES ACCES ET PERFORMANCES
-- Effectue AVANT le nettoyage (FMARTIN et les donnees de demo encore presentes)
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  EXPLAIN PLAN - PERFORMANCE ET PARTITIONNEMENT
PROMPT ================================================================

-- Mise a jour des statistiques pour des plans representatifs
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_TICKETS',    CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME => 'GLPI_OWNER', TABNAME => 'GLPI_EQUIPMENTS', CASCADE => TRUE);
    DBMS_OUTPUT.PUT_LINE('Statistiques mises a jour.');
END;
/

-- ---- EP1 : Requete AVEC filtre entities_id (partition pruning) ---------------
PROMPT [EP1] Partition pruning : tickets Cergy uniquement (entities_id = 1)
EXPLAIN PLAN SET STATEMENT_ID = 'EP1_PRUNING' FOR
SELECT t.id, t.name, t.status
FROM   glpi_tickets t
WHERE  t.entities_id = 1
AND    t.status IN (1, 2, 3);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP1_PRUNING', 'TYPICAL'));

-- ---- EP2 : Requete SANS filtre site (scan des deux partitions) ---------------
PROMPT [EP2] Full-partition scan : tickets tous sites (pas de filtre entities_id)
EXPLAIN PLAN SET STATEMENT_ID = 'EP2_FULLSCAN' FOR
SELECT t.id, t.name, t.status
FROM   glpi_tickets t
WHERE  t.status IN (1, 2, 3);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP2_FULLSCAN', 'TYPICAL'));

-- ---- EP3 : Vue v_tech_tickets_actifs (CLIENT_IDENTIFIER + multi-join) --------
PROMPT [EP3] Vue v_tech_tickets_actifs : plan complet (BMARTIN|CERGY)
PROMPT       -> observe partition pruning + index idx_tick_equip_id
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('BMARTIN|CERGY');
END;
/
EXPLAIN PLAN SET STATEMENT_ID = 'EP3_TECH_VIEW' FOR
SELECT ticket_id, sujet_ticket, equipement, adresse_ip, statut_ticket
FROM   v_tech_tickets_actifs;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP3_TECH_VIEW', 'TYPICAL'));

-- ---- EP4 : Acces direct a la MV (lecture d un segment preagregee) -----------
PROMPT [EP4] MV mv_read_parc_par_site : acces direct a l agregat precompute
EXPLAIN PLAN SET STATEMENT_ID = 'EP4_MV_DIRECT' FOR
SELECT * FROM mv_read_parc_par_site;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP4_MV_DIRECT', 'TYPICAL'));

-- ---- EP5 : Requete directe equivalente (sans MV) ----------------------------
PROMPT [EP5] Requete directe equivalente (sans MV) : comparer le cout avec EP4
EXPLAIN PLAN SET STATEMENT_ID = 'EP5_EQUIV_DIRECT' FOR
SELECT e.name AS site,
       SUM(CASE WHEN eq.itemtype = 'Computer' THEN 1 ELSE 0 END) AS nb_computers,
       SUM(CASE WHEN eq.itemtype = 'Printer'  THEN 1 ELSE 0 END) AS nb_printers,
       COUNT(*) AS total_equipements
FROM   glpi_equipments eq
JOIN   glpi_entities e ON e.id = eq.entities_id
GROUP BY e.name;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP5_EQUIV_DIRECT', 'TYPICAL'));

-- ---- EP6 : Index sur equipment_id (lookup des tickets d un equipement) ------
PROMPT [EP6] Index idx_tick_equip_id : tickets d un seul equipement (id=1)
EXPLAIN PLAN SET STATEMENT_ID = 'EP6_IDX_EQUIP' FOR
SELECT t.id, t.name, t.status, t.date_issue
FROM   glpi_tickets t
WHERE  t.equipment_id = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'EP6_IDX_EQUIP', 'TYPICAL'));


-- =============================================================================
-- ACTE 8 : NETTOYAGE DES COMPTES DE DEMO
-- Procedures : [12] supprimer_utilisateur_lambda  (TDEMO + UP005_CERGY)
--              [13] supprimer_technicien           (FMARTIN + CBERNARD_CERGY)
--              [14] supprimer_admin                (EPERON ; JLEFEVRE reste)
--
-- JLEFEVRE reste en base : la regle "Last Man Standing" exige au moins
-- 1 admin actif par site. Sa presence permet la suppression d EPERON.
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  ACTE 8 : NETTOYAGE - suppression des comptes crees pendant le scenario
PROMPT ================================================================

BEGIN
    DBMS_SESSION.SET_IDENTIFIER('ADUPONT|CERGY');
    DBMS_OUTPUT.PUT_LINE('Connecte en tant que : ADUPONT|CERGY');

    -- [12a] Supprimer TDEMO (lambda Cergy, cree en ACTE 1)
    supprimer_utilisateur_lambda('TDEMO');
    DBMS_OUTPUT.PUT_LINE('[12] supprimer_utilisateur_lambda : TDEMO supprime');

    -- [12b] Supprimer UP005_CERGY (copie Cergy du lambda PAU, creee en ACTE 5)
    supprimer_utilisateur_lambda('UP005_CERGY');
    DBMS_OUTPUT.PUT_LINE('[12] supprimer_utilisateur_lambda : UP005_CERGY supprime');

    -- [13a] Supprimer FMARTIN (technicien Cergy, cree en ACTE 1)
    supprimer_technicien('FMARTIN');
    DBMS_OUTPUT.PUT_LINE('[13] supprimer_technicien : FMARTIN supprime');

    -- [13b] Supprimer CBERNARD_CERGY (copie Cergy du tech PAU, creee en ACTE 5)
    supprimer_technicien('CBERNARD_CERGY');
    DBMS_OUTPUT.PUT_LINE('[13] supprimer_technicien : CBERNARD_CERGY supprime');

    -- [14] Supprimer EPERON (JLEFEVRE reste -> Last Man Standing respecte)
    supprimer_admin('EPERON');
    DBMS_OUTPUT.PUT_LINE('[14] supprimer_admin : EPERON supprime (JLEFEVRE reste admin Cergy)');
END;
/

-- Verification : is_active = 0 pour les comptes supprimes, JLEFEVRE = 1
SELECT pseudo, entities_id, is_active
FROM   glpi_users
WHERE  pseudo IN ('EPERON', 'JLEFEVRE', 'FMARTIN', 'TDEMO', 'UP005_CERGY', 'CBERNARD_CERGY')
ORDER BY pseudo;

PROMPT Note : is_active=0 = desactive (soft delete). JLEFEVRE doit rester is_active=1.
PROMPT Note : les originaux PAU (CBERNARD, UP005) ne sont pas affectes.


-- =============================================================================
-- BILAN FINAL DU SCENARIO
-- =============================================================================
PROMPT
PROMPT ================================================================
PROMPT  BILAN FINAL
PROMPT ================================================================

SELECT 'Equipements Cergy'          AS element, COUNT(*) AS nb FROM glpi_equipments WHERE entities_id = 1
UNION ALL
SELECT 'Equipements Pau',                       COUNT(*) FROM glpi_equipments WHERE entities_id = 2
UNION ALL
SELECT 'Tickets Nouveau',                       COUNT(*) FROM glpi_tickets WHERE status = 1
UNION ALL
SELECT 'Tickets En cours',                      COUNT(*) FROM glpi_tickets WHERE status = 2
UNION ALL
SELECT 'Tickets Resolu',                        COUNT(*) FROM glpi_tickets WHERE status = 4
UNION ALL
SELECT 'Techniciens actifs Cergy', COUNT(*)
FROM   glpi_users u
JOIN   glpi_profiles_users pu ON pu.users_id = u.id
JOIN   glpi_profiles p ON p.id = pu.profiles_id
WHERE  UPPER(p.name) = 'TECHNICIEN' AND u.entities_id = 1 AND u.is_active = 1
UNION ALL
SELECT 'Admins actifs Cergy', COUNT(*)
FROM   glpi_users u
JOIN   glpi_profiles_users pu ON pu.users_id = u.id
JOIN   glpi_profiles p ON p.id = pu.profiles_id
WHERE  UPPER(p.name) = 'ADMINISTRATEUR' AND u.entities_id = 1 AND u.is_active = 1
UNION ALL
SELECT 'Evenements audit (history)', COUNT(*) FROM glpi_history
ORDER BY 1;

PROMPT
PROMPT  Procedures utilisees : 14/14
PROMPT  [1]  ajouter_admin                    ACTE 1 (x2 : EPERON + JLEFEVRE)
PROMPT  [2]  ajouter_technicien               ACTE 1
PROMPT  [3]  ajouter_utilisateur_lambda        ACTE 1
PROMPT  [4]  ajouter_equipement               ACTE 1 (x3)
PROMPT  [5]  affecter_localisation_equipement  ACTE 1 (x3)
PROMPT  [6]  affecter_technicien_equipement    ACTE 1 (x3)
PROMPT  [7]  changer_statut_equipement         ACTE 1 (x2)
PROMPT  [8]  creer_ticket                     ACTES 2 et 6
PROMPT  [9]  modifier_statut_ticket           ACTES 3 et 6
PROMPT  [10] ajouter_lambda_autre_site         ACTE 5
PROMPT  [11] ajouter_tech_ou_admin_autre_site  ACTE 5
PROMPT  [12] supprimer_utilisateur_lambda      ACTE 8 (x2 : TDEMO + UP005_CERGY)
PROMPT  [13] supprimer_technicien              ACTE 8 (x2 : FMARTIN + CBERNARD_CERGY)
PROMPT  [14] supprimer_admin                   ACTE 8 (EPERON)
PROMPT
PROMPT  Vues interrogees :
PROMPT   v_tech_tickets_actifs        ACTES 3 et 6
PROMPT   v_admin_tickets_en_retard    ACTE 4
PROMPT   v_admin_equipements_inactifs ACTE 4
PROMPT   v_admin_charge_techniciens   ACTE 4 (logique inline depuis mv_charge_techniciens)
PROMPT   mv_charge_techniciens        ACTE 4 (+ refresh manuel)
PROMPT   v_read_tickets_non_resolus   ACTE 7
PROMPT   mv_read_parc_par_site        ACTE 7 (+ refresh manuel)
PROMPT
PROMPT  EXPLAIN PLAN : EP1 pruning site | EP2 full scan | EP3 vue tech
PROMPT                 EP4 MV direct   | EP5 equiv direct | EP6 index equip
PROMPT ================================================================
PROMPT  Lancer cleanup.sql (en tant que SYS SYSDBA) pour remettre a zero.
PROMPT ================================================================

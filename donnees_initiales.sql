-- =============================================================================
-- GLPI CY Tech - Donnees initiales
-- Fichier    : donnees_initiales.sql
-- Connexion  : GLPI_OWNER
-- Dependances: schema.sql + sequences.sql executes avant
-- Contenu    : donnees necessaires au fonctionnement des procedures AVANT
--              le scenario. Sans ces donnees, ajouter_admin, ajouter_technicien
--              et ajouter_equipement echouent immediatement.
-- =============================================================================
-- Ce fichier NE contient PAS de donnees de test (users, equipements, tickets).
-- Ces donnees sont generees dans scenario.sql via les procedures metier.
-- =============================================================================


-- =============================================================================
-- 1. PROFILS GLPI
-- =============================================================================
-- Requis par ajouter_admin et ajouter_technicien qui font :
--   SELECT id FROM glpi_profiles WHERE UPPER(name) = 'ADMINISTRATEUR'
--   SELECT id FROM glpi_profiles WHERE UPPER(name) = 'TECHNICIEN'
-- Sans ces lignes, les deux procedures levent NO_DATA_FOUND au demarrage.

INSERT INTO glpi_profiles (name, interface) VALUES ('Administrateur', 'central');
INSERT INTO glpi_profiles (name, interface) VALUES ('Technicien',     'central');
INSERT INTO glpi_profiles (name, interface) VALUES ('Lecture seule',  'helpdesk');


-- =============================================================================
-- 2. DROITS PAR PROFIL (glpi_profilerights)
-- =============================================================================
-- Dans notre architecture, les droits reels sont geres par les roles Oracle
-- (R_GLPI_ADMIN, R_GLPI_TECH, R_GLPI_READ) et les GRANTs sur les procedures
-- et vues (fichier acces.sql).
--
-- glpi_profilerights sert ici de DOCUMENTATION EN BASE de ces droits :
-- chaque ligne correspond a un GRANT Oracle reel.
-- Le champ name designe la procedure ou la vue concernee.
-- Le champ rights vaut 1 (acces accorde) ou 0 (acces refuse).
--
-- Contrainte uk_profrights_prof_name : unicite sur (profiles_id, name).
-- profiles_id 1 = Administrateur, 2 = Technicien, 3 = Lecture seule.

-- ---- Profil Administrateur (id=1) -------------------------------------------
-- Vues accordees
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'v_admin_tickets_en_retard',    1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'v_admin_equipements_inactifs', 1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'v_admin_charge_techniciens',   1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'mv_charge_techniciens',        1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'mv_read_parc_par_site',        1);
-- Procedures utilisateurs accordees
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'ajouter_utilisateur_lambda',       1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'ajouter_technicien',               1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'ajouter_admin',                    1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'supprimer_utilisateur_lambda',     1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'supprimer_technicien',             1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'supprimer_admin',                  1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'ajouter_lambda_autre_site',        1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'ajouter_tech_ou_admin_autre_site', 1);
-- Procedures parc et tickets accordees
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'ajouter_equipement',               1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'changer_statut_equipement',        1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'affecter_localisation_equipement', 1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'affecter_technicien_equipement',   1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'modifier_statut_ticket',           1);
-- Vues globales BDDR accordees (supervision cross-campus)
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'v_global_equipements',       1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'v_global_users',             1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'v_global_tickets',           1);
-- Non accordes
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'creer_ticket',               0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'v_tech_tickets_actifs',      0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (1, 'v_read_tickets_non_resolus', 0);

-- ---- Profil Technicien (id=2) -----------------------------------------------
-- Vues accordees
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'v_tech_tickets_actifs', 1);
-- Procedures parc et tickets accordees
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'ajouter_equipement',               1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'changer_statut_equipement',        1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'affecter_localisation_equipement', 1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'modifier_statut_ticket',           1);
-- Non accordes
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'ajouter_utilisateur_lambda',       0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'ajouter_technicien',               0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'ajouter_admin',                    0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'supprimer_utilisateur_lambda',     0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'supprimer_technicien',             0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'supprimer_admin',                  0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'ajouter_lambda_autre_site',        0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'ajouter_tech_ou_admin_autre_site', 0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'affecter_technicien_equipement',   0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'creer_ticket',                     0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'v_admin_tickets_en_retard',        0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'v_admin_equipements_inactifs',     0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'v_admin_charge_techniciens',       0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'mv_charge_techniciens',            0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'v_read_tickets_non_resolus',       0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'mv_read_parc_par_site',            0);
-- Vues globales BDDR non accordees au technicien
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'v_global_equipements',             0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'v_global_users',                   0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (2, 'v_global_tickets',                 0);

-- ---- Profil Lecture seule (id=3) --------------------------------------------
-- Vues accordees
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'v_read_tickets_non_resolus', 1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'mv_read_parc_par_site',      1);
-- Vues globales BDDR accordees (audit global tous sites)
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'v_global_equipements',       1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'v_global_users',             1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'v_global_tickets',           1);
-- Non accordes
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'v_tech_tickets_actifs',            0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'v_admin_tickets_en_retard',        0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'v_admin_equipements_inactifs',     0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'v_admin_charge_techniciens',       0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'mv_charge_techniciens',            0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'ajouter_utilisateur_lambda',       0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'ajouter_technicien',               0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'ajouter_admin',                    0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'supprimer_utilisateur_lambda',     0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'supprimer_technicien',             0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'supprimer_admin',                  0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'ajouter_lambda_autre_site',        0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'ajouter_tech_ou_admin_autre_site', 0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'ajouter_equipement',               0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'changer_statut_equipement',        0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'affecter_localisation_equipement', 0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'affecter_technicien_equipement',   0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'modifier_statut_ticket',           0);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'creer_ticket',                     0);


-- =============================================================================
-- 3. RESEAUX PAR SITE
-- =============================================================================
-- Requis par ajouter_equipement qui fait :
--   SELECT id FROM glpi_networks WHERE entities_id = v_entities_id AND ROWNUM = 1
-- Un reseau par site : plan d adressage simple CY Tech.

INSERT INTO glpi_networks (name, entities_id) VALUES ('10.1.0.0/24', 1);
INSERT INTO glpi_networks (name, entities_id) VALUES ('10.2.0.0/24', 2);


-- =============================================================================
-- 4. LOCALISATIONS DE BASE
-- =============================================================================
-- 8 salles par site, noms fixes LOC-1..LOC-8 (Cergy) et LOC-9..LOC-16 (Pau).
-- uk_loc_ent_name est composite (entities_id, name) : LOC-x peut coexister
-- sur les deux sites sans collision.
-- Bloc PL/SQL pour coherence avec le reste du fichier et pour eviter les
-- problemes SQL*Plus avec NEXTVAL dans une expression VALUES directe.

BEGIN
    -- Cergy (entities_id = 1)
    INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-1');   -- Salle Informatique A101
    INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-2');   -- Salle Informatique A102
    INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-3');   -- Salle Informatique B201
    INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-4');   -- Bureau Technicien IT
    INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-5');   -- Salle de Cours C301
    INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-6');   -- Amphitheatre D001
    INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-7');   -- Bibliotheque E101
    INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-8');   -- Salle Serveurs

    -- Pau (entities_id = 2)
    INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-9');   -- Salle Informatique P101
    INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-10');  -- Salle Informatique P102
    INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-11');  -- Salle Informatique P201
    INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-12');  -- Bureau Technicien IT
    INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-13');  -- Salle de Cours P301
    INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-14');  -- Amphitheatre P001
    INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-15');  -- Bibliotheque P101
    INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-16');  -- Salle Serveurs
END;
/


COMMIT;


-- =============================================================================
-- 5. DONNEES DE TEST
-- =============================================================================
-- Connexion  : GLPI_OWNER
-- DBMS_SESSION.SET_IDENTIFIER simule le CLIENT_IDENTIFIER attendu par les
-- procedures metier. Format : 'QUELCONQUE|SITE' (ex : 'INIT|CERGY').
-- Ordre     : equipements -> techniciens -> affectation -> lambda
--             -> mise en service -> tickets
--
-- Etat des sequences apres execution complete :
--   seq_equip_cergy   : dernier = 10075  ->  prochain EQ-10076
--   seq_equip_pau     : dernier = 20075  ->  prochain EQ-20076
--   seq_ip_host_cergy : dernier = 75     ->  prochaine 10.1.0.76
--   seq_ip_host_pau   : dernier = 75     ->  prochaine 10.2.0.76
--   seq_ticket_cergy  : dernier = 1000010  ->  prochain TKT-1000011
--   seq_ticket_pau    : dernier = 2000010  ->  prochain TKT-2000011
-- =============================================================================

SET SERVEROUTPUT ON


-- =============================================================================
-- 5.1 EQUIPEMENTS CERGY
-- 50 ordinateurs : EQ-10001..EQ-10050  /  10.1.0.1..10.1.0.50
-- 25 imprimantes : EQ-10051..EQ-10075  /  10.1.0.51..10.1.0.75
-- Serials        : SER-C-PC-001..050, SER-C-PR-001..025
-- =============================================================================
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('INIT|CERGY');
    FOR i IN 1..50 LOOP
        ajouter_equipement('SER-C-PC-' || LPAD(i, 3, '0'), 'Computer');
    END LOOP;
    FOR i IN 1..25 LOOP
        ajouter_equipement('SER-C-PR-' || LPAD(i, 3, '0'), 'Printer');
    END LOOP;
END;
/


-- =============================================================================
-- 5.2 EQUIPEMENTS PAU
-- 50 ordinateurs : EQ-20001..EQ-20050  /  10.2.0.1..10.2.0.50
-- 25 imprimantes : EQ-20051..EQ-20075  /  10.2.0.51..10.2.0.75
-- Serials        : SER-P-PC-001..050, SER-P-PR-001..025
-- =============================================================================
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('INIT|PAU');
    FOR i IN 1..50 LOOP
        ajouter_equipement('SER-P-PC-' || LPAD(i, 3, '0'), 'Computer');
    END LOOP;
    FOR i IN 1..25 LOOP
        ajouter_equipement('SER-P-PR-' || LPAD(i, 3, '0'), 'Printer');
    END LOOP;
END;
/


-- =============================================================================
-- 5.3 TECHNICIENS CERGY
-- Comptes Oracle crees : ADUPONT_CERGY (Alice Dupont), BMARTIN_CERGY (Bob Martin)
-- repartition_charge_nouveau_tech retourne vide : les equipements ci-dessus
-- ont tous users_id_tech=NULL, aucun tech precedent ne depasse le quota.
-- L affectation manuelle est faite en 5.5 via affecter_technicien_equipement.
-- =============================================================================
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('INIT|CERGY');
    ajouter_technicien('Alice', 'Dupont', 'Tech#Alice1!');
    ajouter_technicien('Bob',   'Martin', 'Tech#Bob1!');
END;
/


-- =============================================================================
-- 5.4 TECHNICIENS PAU
-- Comptes Oracle crees : CBERNARD_PAU (Claire Bernard), DPETIT_PAU (David Petit)
-- =============================================================================
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('INIT|PAU');
    ajouter_technicien('Claire', 'Bernard', 'Tech#Claire1!');
    ajouter_technicien('David',  'Petit',   'Tech#David1!');
END;
/


-- =============================================================================
-- 5.5 AFFECTATION DES EQUIPEMENTS AUX TECHNICIENS (round-robin)
-- Cergy : ADUPONT <- rangs impairs (38 equip) / BMARTIN <- rangs pairs (37)
-- Pau   : CBERNARD <- rangs impairs (38 equip) / DPETIT  <- rangs pairs (37)
-- affecter_technicien_equipement commit a chaque appel ; le CLIENT_IDENTIFIER
-- de session persiste entre les commits.
-- =============================================================================
DECLARE
    v_rn NUMBER := 0;
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('INIT|CERGY');
    FOR eq IN (
        SELECT e.name
        FROM   glpi_equipments e
        WHERE  e.entities_id = 1
        ORDER BY e.id
    ) LOOP
        v_rn := v_rn + 1;
        IF MOD(v_rn, 2) = 1 THEN
            affecter_technicien_equipement(eq.name, 'ADUPONT');
        ELSE
            affecter_technicien_equipement(eq.name, 'BMARTIN');
        END IF;
    END LOOP;
END;
/

DECLARE
    v_rn NUMBER := 0;
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('INIT|PAU');
    FOR eq IN (
        SELECT e.name
        FROM   glpi_equipments e
        WHERE  e.entities_id = 2
        ORDER BY e.id
    ) LOOP
        v_rn := v_rn + 1;
        IF MOD(v_rn, 2) = 1 THEN
            affecter_technicien_equipement(eq.name, 'CBERNARD');
        ELSE
            affecter_technicien_equipement(eq.name, 'DPETIT');
        END IF;
    END LOOP;
END;
/


-- =============================================================================
-- 5.6 UTILISATEURS LAMBDA CERGY (300)
-- firstname='User', realname='C001'..'C300'
-- Pseudos generes : UC001..UC300
-- Pas de compte Oracle (lambdas = etudiants sans acces direct a la base).
-- =============================================================================
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('INIT|CERGY');
    FOR i IN 1..300 LOOP
        ajouter_utilisateur_lambda('User', 'C' || LPAD(i, 3, '0'));
    END LOOP;
END;
/


-- =============================================================================
-- 5.7 UTILISATEURS LAMBDA PAU (300)
-- firstname='User', realname='P001'..'P300'
-- Pseudos generes : UP001..UP300 (aucune collision avec UC* de Cergy)
-- =============================================================================
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('INIT|PAU');
    FOR i IN 1..300 LOOP
        ajouter_utilisateur_lambda('User', 'P' || LPAD(i, 3, '0'));
    END LOOP;
END;
/


-- =============================================================================
-- 5.8 MISE EN SERVICE DE 10 EQUIPEMENTS PAR SITE
-- Les 10 premiers ordinateurs de chaque site passent a states_id=1 (En service)
-- afin de pouvoir recevoir des tickets (creer_ticket exige states_id=1).
-- Cergy : EQ-10001..EQ-10010  /  Pau : EQ-20001..EQ-20010
-- Les sequences garantissent ces noms : 50 premiers appels Computer pour Cergy
-- consomment seq_equip_cergy 10001..10050 ; idem pour Pau avec 20001..20050.
-- =============================================================================
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('INIT|CERGY');
    FOR i IN 10001..10010 LOOP
        changer_statut_equipement('EQ-' || i, 1);
    END LOOP;
END;
/

BEGIN
    DBMS_SESSION.SET_IDENTIFIER('INIT|PAU');
    FOR i IN 20001..20010 LOOP
        changer_statut_equipement('EQ-' || i, 1);
    END LOOP;
END;
/


-- =============================================================================
-- 5.9 TICKETS (10 par site)
-- Demandeur Cergy : UC001 (premier lambda Cergy, entities_id=1)
-- Demandeur Pau   : UP001 (premier lambda Pau,   entities_id=2)
-- Equipements     : EQ-10001..EQ-10010 (Cergy), EQ-20001..EQ-20010 (Pau)
-- Noms generes    : TKT-1000001..TKT-1000010, TKT-2000001..TKT-2000010
-- creer_ticket deduit le site de l equipement, CLIENT_IDENTIFIER non requis.
-- =============================================================================
DECLARE
    v_user_cergy NUMBER;
    v_user_pau   NUMBER;
BEGIN
    SELECT id INTO v_user_cergy
    FROM   glpi_users
    WHERE  pseudo = 'UC001' AND entities_id = 1;

    SELECT id INTO v_user_pau
    FROM   glpi_users
    WHERE  pseudo = 'UP001' AND entities_id = 2;

    FOR i IN 10001..10010 LOOP
        creer_ticket(
            v_user_cergy,
            'EQ-' || i,
            'Ticket de test : panne signalee sur EQ-' || i || ' au campus Cergy.'
        );
    END LOOP;

    FOR i IN 20001..20010 LOOP
        creer_ticket(
            v_user_pau,
            'EQ-' || i,
            'Ticket de test : panne signalee sur EQ-' || i || ' au campus Pau.'
        );
    END LOOP;
END;
/
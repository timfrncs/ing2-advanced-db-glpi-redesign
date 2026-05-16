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

-- ---- Profil Lecture seule (id=3) --------------------------------------------
-- Vues accordees
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'v_read_tickets_non_resolus', 1);
INSERT INTO glpi_profilerights (profiles_id, name, rights) VALUES (3, 'mv_read_parc_par_site',      1);
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
-- Noms generes par seq_locations_name pour garantir l unicite et la coherence
-- avec la contrainte uk_loc_ent_name (entities_id, name).
-- Format : 'LOC-{sequence}' -> LOC-1, LOC-2... lisible et coherent.
--
-- La sequence est partagee entre les deux sites mais il n y a pas de risque
-- de collision sur la contrainte uk_loc_ent_name car celle-ci est composite
-- (entities_id, name) : LOC-1 peut exister a la fois pour Cergy (entities_id=1)
-- et pour Pau (entities_id=2) sans violer l unicite.
--
-- Les commentaires indiquent la destination reelle de chaque salle,
-- utilisee comme reference dans le scenario.

-- Cergy (entities_id = 1)
INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-1  : Salle Informatique A101
INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-2  : Salle Informatique A102
INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-3  : Salle Informatique B201
INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-4  : Bureau Technicien IT
INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-5  : Salle de Cours C301
INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-6  : Amphitheatre D001
INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-7  : Bibliotheque E101
INSERT INTO glpi_locations (entities_id, name) VALUES (1, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-8  : Salle Serveurs

-- Pau (entities_id = 2)
INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-9  : Salle Informatique P101
INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-10 : Salle Informatique P102
INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-11 : Salle Informatique P201
INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-12 : Bureau Technicien IT
INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-13 : Salle de Cours P301
INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-14 : Amphitheatre P001
INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-15 : Bibliotheque P101
INSERT INTO glpi_locations (entities_id, name) VALUES (2, 'LOC-' || seq_locations_name.NEXTVAL);  -- LOC-16 : Salle Serveurs


COMMIT;
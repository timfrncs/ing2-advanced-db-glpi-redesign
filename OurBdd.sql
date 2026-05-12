-- =============================================================================
-- GLPI CY Tech - Schema complet (multi-sites Cergy / Pau)
-- =============================================================================
-- A executer en SYS / SYSTEM (SYSDBA).
--
-- Plan du script :
--   0.a TABLESPACES        -- ou seront physiquement stockees les donnees
--   0.b ROLES              -- profils de droits reutilisables
--   0.c UTILISATEURS       -- comptes Oracle (proprietaire + applicatifs)
--   1.  DROP des tables    -- remise a zero
--   2.  CREATE des tables  -- DDL applicatif (livre par l equipe)
--   3.  INDEX              -- index secondaires
--   4.  CLES ETRANGERES    -- contraintes referentielles
--   5.  GRANTS sur tables  -- droits objets attribues aux roles
-- =============================================================================


-- =============================================================================
-- 0.a TABLESPACES
-- =============================================================================
-- Pourquoi separer en plusieurs tablespaces plutot que tout mettre dans
-- USERS (defaut Oracle) ?
--
--   1. ISOLATION MULTI-SITES : Cergy et Pau doivent pouvoir etre sauvegardes,
--      archives ou meme transportes independamment (cf. BDDR de l etape 4).
--      Avec deux tablespaces distincts, un "expdp TABLESPACES=TS_GLPI_PAU"
--      suffit a basculer le site Pau sur une autre instance.
--
--   2. PERFORMANCE IO : sur une vraie machine, on place chaque tablespace
--      sur un disque different. Les ecritures sur les index ne ralentissent
--      plus les lectures de donnees, et inversement.
--
--   3. SAUVEGARDE DIFFERENCIEE : RMAN sait sauvegarder un tablespace a la
--      fois. On peut donc sauvegarder TS_GLPI_REF (stable) une fois par
--      semaine et TS_GLPI_CERGY (volatile) toutes les heures.
--
--   4. QUOTAS : on peut interdire a un compte de creer des segments dans
--      un tablespace donne (ex. GLPI_TECH_CERGY n a aucun quota sur
--      TS_GLPI_PAU, donc impossible d ecrire par erreur cote Pau).
--
-- AUTOEXTEND ON : Oracle agrandit automatiquement le datafile quand il se
-- remplit, ce qui evite l erreur ORA-01653 "unable to extend table".
-- MAXSIZE borne quand meme la croissance pour ne pas saturer le disque.
-- =============================================================================

-- Referentiels partages (entities, locations, profiles, networks...).
-- Volumetrie faible et stable -> datafile initial reduit.
CREATE TABLESPACE TS_GLPI_REF
  DATAFILE SIZE 50M AUTOEXTEND ON NEXT 25M MAXSIZE 500M;

-- Donnees actives du site Cergy (lignes avec entities_id = 1).
-- Volumetrie croissante (chaque nouvel ordinateur / IP s ajoute).
CREATE TABLESPACE TS_GLPI_CERGY
  DATAFILE SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 2G;

-- Donnees actives du site Pau (lignes avec entities_id = 2).
-- Symetrique de Cergy.
CREATE TABLESPACE TS_GLPI_PAU
  DATAFILE SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 2G;

-- Tous les index applicatifs.
-- Separes des donnees pour eviter la contention IO blocs data / blocs index.
-- Permet aussi un "ALTER INDEX ... REBUILD" sans toucher au tablespace data.
CREATE TABLESPACE TS_GLPI_INDX
  DATAFILE SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 2G;


-- =============================================================================
-- 0.b ROLES METIER
-- =============================================================================
-- Un ROLE = un sac de privileges nomme, qu on peut attribuer a plusieurs
-- utilisateurs. Si demain on ajoute la table glpi_tickets, on fera un seul
-- GRANT SELECT ON glpi_tickets TO R_GLPI_READ -> tous les comptes lecteurs
-- y auront acces, sans avoir a refaire le GRANT pour chacun.
--
-- On retient le PRINCIPE DU MOINDRE PRIVILEGE :
--   - R_GLPI_READ  : juste lire (reporting, consultation, BI).
--   - R_GLPI_TECH  : ajouter / modifier / supprimer des machines, ports IP,
--                    imprimantes, datacenters. Ne touche PAS aux referentiels
--                    ni aux comptes utilisateurs.
--   - R_GLPI_ADMIN : full DML, herite des deux roles ci-dessus (cf. fin du
--                    script ou le GRANT R_GLPI_READ, R_GLPI_TECH TO
--                    R_GLPI_ADMIN cumule les droits).
-- =============================================================================

CREATE ROLE R_GLPI_READ;    -- lecture seule (SELECT sur toutes les tables)
CREATE ROLE R_GLPI_TECH;    -- DML sur les actifs (computers, printers, ipaddresses, datacenters)
CREATE ROLE R_GLPI_ADMIN;   -- super-utilisateur fonctionnel (cumule READ + TECH)

-- Privilege SYSTEME minimal : sans CREATE SESSION un compte ne peut meme pas
-- se connecter, meme s il possede tous les droits objets du monde.
GRANT CREATE SESSION TO R_GLPI_READ, R_GLPI_TECH, R_GLPI_ADMIN;


-- =============================================================================
-- 0.c SCHEMA PROPRIETAIRE + COMPTES APPLICATIFS
-- =============================================================================
-- ATTENTION TERMINOLOGIE : il faut bien distinguer
--   - utilisateur ORACLE (CREATE USER, se connecte avec un mot de passe)
--   - utilisateur METIER GLPI (ligne dans la table glpi_users)
-- Ce bloc ne concerne QUE les comptes Oracle.
--
-- Architecture choisie :
--
--   GLPI_OWNER       -> POSSEDE les tables. Sert UNIQUEMENT a creer / migrer
--                       le schema. Aucun utilisateur final ne s y connecte.
--                       C est lui qui a CREATE TABLE et les QUOTAS sur tous
--                       les tablespaces (pour pouvoir y creer des segments).
--
--   GLPI_ADMIN       -> compte applicatif admin (DBA fonctionnel).
--   GLPI_TECH_CERGY  -> technicien parc / reseau Cergy.
--   GLPI_TECH_PAU    -> technicien parc / reseau Pau.
--   GLPI_READ        -> reporting / lecture seule.
--
-- Les comptes applicatifs n ont PAS de QUOTA sur les tablespaces. Cela
-- signifie qu ils ne peuvent pas creer de segment (table, index...) meme
-- s ils avaient le privilege CREATE TABLE. C est une protection contre
-- la corruption du schema par une application bugguee.
--
-- Le DEFAULT TABLESPACE de chaque technicien est celui de SON site : si
-- jamais Oracle a besoin de creer un objet implicite pour son compte (ex.
-- table temporaire de tri), il atterrira au bon endroit.
-- =============================================================================

-- GLPI_OWNER : proprietaire des tables. QUOTA UNLIMITED partout car c est
-- lui qui va creer chaque segment dans le bon tablespace.
CREATE USER GLPI_OWNER IDENTIFIED BY "Owner2026"
  DEFAULT TABLESPACE TS_GLPI_REF
  QUOTA UNLIMITED ON TS_GLPI_REF
  QUOTA UNLIMITED ON TS_GLPI_CERGY
  QUOTA UNLIMITED ON TS_GLPI_PAU
  QUOTA UNLIMITED ON TS_GLPI_INDX;

-- Privileges SYSTEME pour la creation du schema (DDL). Volontairement
-- restreint : pas de DROP ANY TABLE, pas de GRANT ANY PRIVILEGE, etc.
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER TO GLPI_OWNER;

-- Comptes applicatifs : pas de quota, pas de droits DDL. Ils n acceedent
-- aux tables que via les GRANTs de la section 5 (en bas du script).
CREATE USER GLPI_ADMIN      IDENTIFIED BY "Admin2026" DEFAULT TABLESPACE TS_GLPI_REF;
CREATE USER GLPI_TECH_CERGY IDENTIFIED BY "Cergy2026" DEFAULT TABLESPACE TS_GLPI_CERGY;
CREATE USER GLPI_TECH_PAU   IDENTIFIED BY "Pau2026"   DEFAULT TABLESPACE TS_GLPI_PAU;
CREATE USER GLPI_READ       IDENTIFIED BY "Read2026"  DEFAULT TABLESPACE TS_GLPI_REF;

-- Attribution des roles : chaque compte recoit le(s) role(s) qui correspond
-- a son metier. Les techniciens cumulent TECH (ecriture sur les actifs) et
-- READ (lecture sur le reste : referentiels, utilisateurs GLPI...).
GRANT R_GLPI_ADMIN              TO GLPI_ADMIN;
GRANT R_GLPI_TECH, R_GLPI_READ  TO GLPI_TECH_CERGY;
GRANT R_GLPI_TECH, R_GLPI_READ  TO GLPI_TECH_PAU;
GRANT R_GLPI_READ               TO GLPI_READ;


-- =============================================================================
-- Bascule de session : on quitte SYSDBA et on se reconnecte en GLPI_OWNER
-- pour que les CREATE TABLE qui suivent appartiennent bien au schema
-- proprietaire (et non a SYS, ce qui serait une catastrophe).
-- =============================================================================
CONNECT GLPI_OWNER/Owner2026

-- =================================================================
-- 1. SUPPRESSION DES TABLES EXISTANTES (REMISE A ZERO)
-- =================================================================
DROP TABLE glpi_profilerights CASCADE CONSTRAINTS;
DROP TABLE glpi_datacenters CASCADE CONSTRAINTS;
DROP TABLE glpi_ipaddresses CASCADE CONSTRAINTS;
DROP TABLE glpi_printers CASCADE CONSTRAINTS;
DROP TABLE glpi_computers CASCADE CONSTRAINTS;
DROP TABLE glpi_networks CASCADE CONSTRAINTS;
DROP TABLE glpi_profiles_users CASCADE CONSTRAINTS;
DROP TABLE glpi_profiles CASCADE CONSTRAINTS;
DROP TABLE glpi_users CASCADE CONSTRAINTS;
DROP TABLE glpi_locations CASCADE CONSTRAINTS;
DROP TABLE glpi_entities CASCADE CONSTRAINTS;

-- =================================================================
-- 2. CREATION DES TABLES (Syntaxe Oracle)
-- =================================================================

-- ---- Referentiels partages -> TS_GLPI_REF -----------------------------------

CREATE TABLE glpi_entities (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  name VARCHAR2(255),
  entities_id NUMBER DEFAULT 0,
  lvl NUMBER DEFAULT 0 NOT NULL -- Renommé car 'level' est un mot réservé Oracle
)
TABLESPACE TS_GLPI_REF;

CREATE TABLE glpi_locations (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  entities_id NUMBER DEFAULT 0 NOT NULL,
  name VARCHAR2(255),
  locations_id NUMBER DEFAULT 0 NOT NULL,
  lvl NUMBER DEFAULT 0 NOT NULL, -- Renommé car 'level' est un mot réservé Oracle
  address VARCHAR2(4000),
  postcode VARCHAR2(255),
  town VARCHAR2(255)
)
TABLESPACE TS_GLPI_REF;

CREATE TABLE glpi_users (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  name VARCHAR2(255),
  realname VARCHAR2(255),
  firstname VARCHAR2(255),
  locations_id NUMBER DEFAULT 0 NOT NULL,
  is_active NUMBER(1) DEFAULT 1 NOT NULL,
  entities_id NUMBER DEFAULT 0
)
TABLESPACE TS_GLPI_REF;

CREATE TABLE glpi_profiles (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  name VARCHAR2(255),
  interface VARCHAR2(255) DEFAULT 'helpdesk'
)
TABLESPACE TS_GLPI_REF;

CREATE TABLE glpi_profiles_users (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  users_id NUMBER DEFAULT 0 NOT NULL,
  profiles_id NUMBER DEFAULT 0 NOT NULL,
  entities_id NUMBER DEFAULT 0 NOT NULL,
  is_recursive NUMBER(1) DEFAULT 1 NOT NULL
)
TABLESPACE TS_GLPI_REF;

CREATE TABLE glpi_networks (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  name VARCHAR2(255)
)
TABLESPACE TS_GLPI_REF;

CREATE TABLE glpi_profilerights (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  profiles_id NUMBER DEFAULT 0 NOT NULL,
  name VARCHAR2(255),
  rights NUMBER DEFAULT 0 NOT NULL
)
TABLESPACE TS_GLPI_REF;

-- ---- Tables d'actifs : partitionnees par site (entities_id) -----------------
-- PARTITION BY LIST(entities_id) :
--   1 -> partition p_cergy -> TS_GLPI_CERGY
--   2 -> partition p_pau   -> TS_GLPI_PAU
--   autre (0, NULL...) -> partition p_other -> TS_GLPI_REF
--
-- Bénéfices :
--   * separation PHYSIQUE des donnees Cergy / Pau (multi-sites reel),
--   * partition pruning : WHERE entities_id=1 ne lit que TS_GLPI_CERGY,
--   * prepare la BDDR (transport du tablespace Pau vers une autre instance).

CREATE TABLE glpi_computers (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  entities_id NUMBER DEFAULT 0 NOT NULL,
  name VARCHAR2(255),
  serial VARCHAR2(255),
  users_id_tech NUMBER DEFAULT 0 NOT NULL,
  locations_id NUMBER DEFAULT 0 NOT NULL,
  networks_id NUMBER DEFAULT 0 NOT NULL,
  users_id NUMBER DEFAULT 0 NOT NULL,
  states_id NUMBER DEFAULT 0 NOT NULL
)
PARTITION BY LIST (entities_id) (
  PARTITION p_cergy VALUES (1)       TABLESPACE TS_GLPI_CERGY,
  PARTITION p_pau   VALUES (2)       TABLESPACE TS_GLPI_PAU,
  PARTITION p_other VALUES (DEFAULT) TABLESPACE TS_GLPI_REF
);

CREATE TABLE glpi_printers (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  entities_id NUMBER DEFAULT 0 NOT NULL,
  name VARCHAR2(255),
  serial VARCHAR2(255),
  users_id_tech NUMBER DEFAULT 0 NOT NULL,
  locations_id NUMBER DEFAULT 0 NOT NULL,
  networks_id NUMBER DEFAULT 0 NOT NULL,
  users_id NUMBER DEFAULT 0 NOT NULL,
  states_id NUMBER DEFAULT 0 NOT NULL
)
PARTITION BY LIST (entities_id) (
  PARTITION p_cergy VALUES (1)       TABLESPACE TS_GLPI_CERGY,
  PARTITION p_pau   VALUES (2)       TABLESPACE TS_GLPI_PAU,
  PARTITION p_other VALUES (DEFAULT) TABLESPACE TS_GLPI_REF
);

CREATE TABLE glpi_ipaddresses (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  entities_id NUMBER DEFAULT 0 NOT NULL,
  items_id NUMBER DEFAULT 0 NOT NULL,
  itemtype VARCHAR2(100) NOT NULL,
  name VARCHAR2(255),
  mainitems_id NUMBER DEFAULT 0 NOT NULL,
  mainitemtype VARCHAR2(255)
)
PARTITION BY LIST (entities_id) (
  PARTITION p_cergy VALUES (1)       TABLESPACE TS_GLPI_CERGY,
  PARTITION p_pau   VALUES (2)       TABLESPACE TS_GLPI_PAU,
  PARTITION p_other VALUES (DEFAULT) TABLESPACE TS_GLPI_REF
);

CREATE TABLE glpi_datacenters (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  name VARCHAR2(255),
  entities_id NUMBER DEFAULT 0 NOT NULL,
  locations_id NUMBER DEFAULT 0 NOT NULL
)
PARTITION BY LIST (entities_id) (
  PARTITION p_cergy VALUES (1)       TABLESPACE TS_GLPI_CERGY,
  PARTITION p_pau   VALUES (2)       TABLESPACE TS_GLPI_PAU,
  PARTITION p_other VALUES (DEFAULT) TABLESPACE TS_GLPI_REF
);

-- =================================================================
-- 3. CREATION DES INDEX (Noms uniques pour Oracle)
-- =================================================================

-- Tous les index applicatifs vont dans TS_GLPI_INDX (separation data / index).
-- Sur les tables PARTITIONNEES (computers, printers, ipaddresses, datacenters)
-- on utilise LOCAL : un sous-index par partition, aligne sur le decoupage
-- Cergy / Pau -> profite du partition pruning et garde l'isolation IO.

-- Index Uniques --------------------------------------------------------------
CREATE UNIQUE INDEX uk_ent_id_name        ON glpi_entities      (entities_id, name) TABLESPACE TS_GLPI_INDX;
CREATE UNIQUE INDEX uk_loc_ent_loc_name   ON glpi_locations     (entities_id, locations_id, name) TABLESPACE TS_GLPI_INDX;
CREATE UNIQUE INDEX uk_profrights_prof_name ON glpi_profilerights (profiles_id, name) TABLESPACE TS_GLPI_INDX;

-- Index glpi_entities --------------------------------------------------------
CREATE INDEX idx_ent_lvl ON glpi_entities (lvl) TABLESPACE TS_GLPI_INDX;

-- Index glpi_locations -------------------------------------------------------
CREATE INDEX idx_loc_loc_id ON glpi_locations (locations_id) TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_loc_name   ON glpi_locations (name)         TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_loc_lvl    ON glpi_locations (lvl)          TABLESPACE TS_GLPI_INDX;

-- Index glpi_users -----------------------------------------------------------
CREATE INDEX idx_usr_realname  ON glpi_users (realname)    TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_usr_ent_id    ON glpi_users (entities_id) TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_usr_loc_id    ON glpi_users (locations_id) TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_usr_is_active ON glpi_users (is_active)   TABLESPACE TS_GLPI_INDX;

-- Index glpi_profiles --------------------------------------------------------
CREATE INDEX idx_prof_name ON glpi_profiles (name) TABLESPACE TS_GLPI_INDX;

-- Index glpi_profiles_users --------------------------------------------------
CREATE INDEX idx_pu_ent_id  ON glpi_profiles_users (entities_id) TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_pu_prof_id ON glpi_profiles_users (profiles_id) TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_pu_usr_id  ON glpi_profiles_users (users_id)    TABLESPACE TS_GLPI_INDX;

-- Index glpi_networks --------------------------------------------------------
CREATE INDEX idx_net_name ON glpi_networks (name) TABLESPACE TS_GLPI_INDX;

-- Index glpi_computers (table partitionnee -> LOCAL) -------------------------
CREATE INDEX idx_comp_name    ON glpi_computers (name)         LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_comp_ent_id  ON glpi_computers (entities_id)  LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_comp_serial  ON glpi_computers (serial)       LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_comp_loc_id  ON glpi_computers (locations_id) LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_comp_net_id  ON glpi_computers (networks_id)  LOCAL TABLESPACE TS_GLPI_INDX;

-- Index glpi_printers (table partitionnee -> LOCAL) --------------------------
CREATE INDEX idx_print_name    ON glpi_printers (name)         LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_print_ent_id  ON glpi_printers (entities_id)  LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_print_serial  ON glpi_printers (serial)       LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_print_loc_id  ON glpi_printers (locations_id) LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_print_net_id  ON glpi_printers (networks_id)  LOCAL TABLESPACE TS_GLPI_INDX;

-- Index glpi_ipaddresses (table partitionnee -> LOCAL) -----------------------
CREATE INDEX idx_ip_name     ON glpi_ipaddresses (name)        LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_ip_ent_id   ON glpi_ipaddresses (entities_id) LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_ip_item     ON glpi_ipaddresses (itemtype, items_id)         LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_ip_mainitem ON glpi_ipaddresses (mainitemtype, mainitems_id) LOCAL TABLESPACE TS_GLPI_INDX;

-- Index glpi_datacenters (table partitionnee -> LOCAL) -----------------------
CREATE INDEX idx_dc_name   ON glpi_datacenters (name)         LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_dc_ent_id ON glpi_datacenters (entities_id)  LOCAL TABLESPACE TS_GLPI_INDX;
CREATE INDEX idx_dc_loc_id ON glpi_datacenters (locations_id) LOCAL TABLESPACE TS_GLPI_INDX;

-- Index glpi_profilerights ---------------------------------------------------
CREATE INDEX idx_profright_name ON glpi_profilerights (name) TABLESPACE TS_GLPI_INDX;


-- =================================================================
-- 4. AJOUT DES CLES ETRANGERES (L'optimisation attendue par ton prof)
-- =================================================================

ALTER TABLE glpi_entities ADD CONSTRAINT fk_ent_parent FOREIGN KEY (entities_id) REFERENCES glpi_entities(id);

ALTER TABLE glpi_locations ADD CONSTRAINT fk_loc_entity FOREIGN KEY (entities_id) REFERENCES glpi_entities(id);
ALTER TABLE glpi_locations ADD CONSTRAINT fk_loc_parent FOREIGN KEY (locations_id) REFERENCES glpi_locations(id);

ALTER TABLE glpi_users ADD CONSTRAINT fk_usr_entity FOREIGN KEY (entities_id) REFERENCES glpi_entities(id);
ALTER TABLE glpi_users ADD CONSTRAINT fk_usr_location FOREIGN KEY (locations_id) REFERENCES glpi_locations(id);

ALTER TABLE glpi_profiles_users ADD CONSTRAINT fk_pu_user FOREIGN KEY (users_id) REFERENCES glpi_users(id);
ALTER TABLE glpi_profiles_users ADD CONSTRAINT fk_pu_profile FOREIGN KEY (profiles_id) REFERENCES glpi_profiles(id);
ALTER TABLE glpi_profiles_users ADD CONSTRAINT fk_pu_entity FOREIGN KEY (entities_id) REFERENCES glpi_entities(id);

ALTER TABLE glpi_computers ADD CONSTRAINT fk_comp_entity FOREIGN KEY (entities_id) REFERENCES glpi_entities(id);
ALTER TABLE glpi_computers ADD CONSTRAINT fk_comp_location FOREIGN KEY (locations_id) REFERENCES glpi_locations(id);
ALTER TABLE glpi_computers ADD CONSTRAINT fk_comp_network FOREIGN KEY (networks_id) REFERENCES glpi_networks(id);
ALTER TABLE glpi_computers ADD CONSTRAINT fk_comp_user FOREIGN KEY (users_id) REFERENCES glpi_users(id);
ALTER TABLE glpi_computers ADD CONSTRAINT fk_comp_tech FOREIGN KEY (users_id_tech) REFERENCES glpi_users(id);

ALTER TABLE glpi_printers ADD CONSTRAINT fk_print_entity FOREIGN KEY (entities_id) REFERENCES glpi_entities(id);
ALTER TABLE glpi_printers ADD CONSTRAINT fk_print_location FOREIGN KEY (locations_id) REFERENCES glpi_locations(id);
ALTER TABLE glpi_printers ADD CONSTRAINT fk_print_network FOREIGN KEY (networks_id) REFERENCES glpi_networks(id);
ALTER TABLE glpi_printers ADD CONSTRAINT fk_print_user FOREIGN KEY (users_id) REFERENCES glpi_users(id);

ALTER TABLE glpi_ipaddresses ADD CONSTRAINT fk_ip_entity FOREIGN KEY (entities_id) REFERENCES glpi_entities(id);

ALTER TABLE glpi_datacenters ADD CONSTRAINT fk_dc_entity FOREIGN KEY (entities_id) REFERENCES glpi_entities(id);
ALTER TABLE glpi_datacenters ADD CONSTRAINT fk_dc_location FOREIGN KEY (locations_id) REFERENCES glpi_locations(id);

ALTER TABLE glpi_profilerights ADD CONSTRAINT fk_profrights_profile FOREIGN KEY (profiles_id) REFERENCES glpi_profiles(id);

-- =============================================================================
-- 5. GRANTS sur les tables (droits OBJETS)
-- =============================================================================
-- Les roles ont ete crees plus haut avec uniquement le privilege SYSTEME
-- CREATE SESSION. Ils n ont donc pour l instant aucun droit sur les tables
-- (les tables n existaient pas encore au moment du CREATE ROLE).
--
-- Ce bloc, execute APRES la creation des tables, attribue aux roles les
-- droits OBJETS (SELECT, INSERT, UPDATE, DELETE) sur chaque table. Ces
-- droits cascade automatiquement aux comptes qui ont le role :
--
--   * GLPI_READ          recoit R_GLPI_READ  -> SELECT sur toutes les tables.
--   * GLPI_TECH_CERGY    recoit R_GLPI_TECH  -> DML sur les actifs.
--   * GLPI_TECH_PAU      idem.
--   * GLPI_ADMIN         recoit R_GLPI_ADMIN -> herite des deux precedents.
-- =============================================================================

-- ---- Lecture sur l ensemble des tables -> R_GLPI_READ -----------------------
-- Tout role lecteur peut consulter n importe quelle table, y compris les
-- tables de securite (profilerights) pour pouvoir auditer les droits.
GRANT SELECT ON glpi_entities       TO R_GLPI_READ;
GRANT SELECT ON glpi_locations      TO R_GLPI_READ;
GRANT SELECT ON glpi_users          TO R_GLPI_READ;
GRANT SELECT ON glpi_profiles       TO R_GLPI_READ;
GRANT SELECT ON glpi_profiles_users TO R_GLPI_READ;
GRANT SELECT ON glpi_networks       TO R_GLPI_READ;
GRANT SELECT ON glpi_computers      TO R_GLPI_READ;
GRANT SELECT ON glpi_printers       TO R_GLPI_READ;
GRANT SELECT ON glpi_ipaddresses    TO R_GLPI_READ;
GRANT SELECT ON glpi_datacenters    TO R_GLPI_READ;
GRANT SELECT ON glpi_profilerights  TO R_GLPI_READ;

-- ---- DML sur les actifs (parc materiel) -> R_GLPI_TECH ----------------------
-- Les techniciens peuvent ajouter / modifier / supprimer une machine, une
-- imprimante, une IP, un datacenter. Ils NE TOUCHENT PAS aux referentiels
-- partages (entities, locations, profiles, networks) qui restent geres par
-- l administrateur.
--
-- Limitation assumee : un technicien Cergy peut techniquement inserer avec
-- entities_id = 2 (donc cote Pau). Le cloisonnement strict viendra avec les
-- VUES filtrees (V_COMPUTERS_CERGY WHERE entities_id=1 WITH CHECK OPTION)
-- ou un TRIGGER de controle, prevus dans les etapes ulterieures du projet.
GRANT SELECT, INSERT, UPDATE, DELETE ON glpi_computers   TO R_GLPI_TECH;
GRANT SELECT, INSERT, UPDATE, DELETE ON glpi_printers    TO R_GLPI_TECH;
GRANT SELECT, INSERT, UPDATE, DELETE ON glpi_ipaddresses TO R_GLPI_TECH;
GRANT SELECT, INSERT, UPDATE, DELETE ON glpi_datacenters TO R_GLPI_TECH;

-- ---- R_GLPI_ADMIN = cumul des deux ------------------------------------------
-- Un role peut recevoir un autre role : R_GLPI_ADMIN herite ainsi de tous
-- les droits objets de R_GLPI_READ et R_GLPI_TECH, sans qu on ait a recopier
-- la liste des GRANTs. Si demain on ajoute une table et qu on grant au role
-- READ, l admin l aura aussi automatiquement.
GRANT R_GLPI_READ, R_GLPI_TECH TO R_GLPI_ADMIN;

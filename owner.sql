-- =============================================================================
-- GLPI CY Tech - Comptes Oracle
-- Fichier    : owner.sql
-- Connexion  : SYS AS SYSDBA  (ou SYSTEM)
-- Ordre exec : 2e fichier, apres infrastructure.sql
-- Contenu    : Creation de GLPI_OWNER + comptes generiques applicatifs
-- =============================================================================
-- Principe :
--   GLPI_OWNER : proprietaire de tous les objets du schema (tables, vues,
--                procedures, sequences, types). Il n est pas utilise pour
--                se connecter en production, uniquement pour les deploiements.
--   GLPI_READ  : compte partage des auditeurs (role R_GLPI_READ).
--   GLPI_HELP  : compte partage de l interface helpdesk (R_GLPI_TICKET_HELP).
--   Les comptes individuels (admins, techniciens) sont crees dynamiquement
--   par les procedures ajouter_admin et ajouter_technicien.
-- =============================================================================
-- SECURITE : changer les mots de passe avant toute mise en production.
-- =============================================================================


-- =============================================================================
-- 1. GLPI_OWNER : proprietaire du schema
-- =============================================================================

BEGIN EXECUTE IMMEDIATE 'DROP USER GLPI_OWNER CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE USER GLPI_OWNER
  IDENTIFIED BY "GlpiOwner#2024"
  DEFAULT TABLESPACE TS_GLPI_REF
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

-- Quotas sur chaque tablespace utilise
ALTER USER GLPI_OWNER QUOTA UNLIMITED ON TS_GLPI_REF;
ALTER USER GLPI_OWNER QUOTA UNLIMITED ON TS_GLPI_CERGY;
ALTER USER GLPI_OWNER QUOTA UNLIMITED ON TS_GLPI_PAU;
ALTER USER GLPI_OWNER QUOTA UNLIMITED ON TS_GLPI_INDX;

-- Privileges systeme necessaires au deploiement et a la gestion des comptes
GRANT CREATE SESSION        TO GLPI_OWNER;
GRANT CREATE TABLE          TO GLPI_OWNER;
GRANT CREATE VIEW           TO GLPI_OWNER;
GRANT CREATE SEQUENCE       TO GLPI_OWNER;
GRANT CREATE PROCEDURE      TO GLPI_OWNER;
GRANT CREATE TRIGGER        TO GLPI_OWNER;
GRANT CREATE MATERIALIZED VIEW TO GLPI_OWNER;
GRANT CREATE TYPE           TO GLPI_OWNER;
GRANT CREATE PUBLIC SYNONYM     TO GLPI_OWNER;
GRANT DROP PUBLIC SYNONYM       TO GLPI_OWNER;
GRANT CREATE PUBLIC DATABASE LINK TO GLPI_OWNER;
-- Necessaire pour CREATE USER / GRANT dans ajouter_admin et ajouter_technicien
GRANT CREATE USER           TO GLPI_OWNER;
GRANT ALTER USER            TO GLPI_OWNER;
GRANT GRANT ANY ROLE        TO GLPI_OWNER;


-- =============================================================================
-- 2. GLPI_READ : compte partage des auditeurs (lecture seule)
-- =============================================================================

BEGIN EXECUTE IMMEDIATE 'DROP USER GLPI_READ CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE USER GLPI_READ
  IDENTIFIED BY "GlpiRead#2024"
  DEFAULT TABLESPACE TS_GLPI_REF
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

GRANT R_GLPI_READ TO GLPI_READ;


-- =============================================================================
-- 3. GLPI_HELP : compte partage de l interface helpdesk
-- =============================================================================

BEGIN EXECUTE IMMEDIATE 'DROP USER GLPI_HELP CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE USER GLPI_HELP
  IDENTIFIED BY "GlpiHelp#2024"
  DEFAULT TABLESPACE TS_GLPI_REF
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

GRANT R_GLPI_TICKET_HELP TO GLPI_HELP;


-- =============================================================================
-- 4. Comptes de service BDDR (un par instance, minimal)
-- =============================================================================
-- GLPI_DBLINK_CERGY : cree sur l'instance CERGY, utilise par le dblink de PAU
--                     pour lire les donnees Cergy a distance.
-- GLPI_DBLINK_PAU   : cree sur l'instance PAU,   utilise par le dblink de CERGY
--                     pour lire les donnees Pau a distance.
-- Ces comptes sont independants des admins dynamiques (PSEUDO_SITE) : leur
-- existence ne depend pas des utilisateurs metier et ils ne peuvent pas etre
-- supprimes par les procedures ajouter_*/supprimer_*.
-- Les GRANT SELECT sur les tables sont dans acces.sql.
-- =============================================================================

BEGIN EXECUTE IMMEDIATE 'DROP USER GLPI_DBLINK_CERGY CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE USER GLPI_DBLINK_CERGY
  IDENTIFIED BY "DbCergy2026!"
  DEFAULT TABLESPACE TS_GLPI_REF
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

GRANT CREATE SESSION TO GLPI_DBLINK_CERGY;


BEGIN EXECUTE IMMEDIATE 'DROP USER GLPI_DBLINK_PAU CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE USER GLPI_DBLINK_PAU
  IDENTIFIED BY "DbPau2026!"
  DEFAULT TABLESPACE TS_GLPI_REF
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

GRANT CREATE SESSION TO GLPI_DBLINK_PAU;

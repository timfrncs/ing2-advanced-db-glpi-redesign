-- =============================================================================
-- GLPI CY Tech - Infrastructure Oracle
-- Fichier    : infrastructure.sql
-- Connexion  : SYS AS SYSDBA  (ou SYSTEM)
-- Ordre exec : 1er fichier a executer, avant owner.sql
-- Contenu    : Tablespaces + Roles Oracle
-- =============================================================================
-- Instance : Oracle 21c XE (Windows) — portable multi-machines
-- PDB cible : XEPDB1 (se connecter en SYSDBA sur XEPDB1 avant d executer)
-- Le chemin des datafiles est detecte automatiquement depuis v$datafile.
-- =============================================================================


-- =============================================================================
-- 1. TABLESPACES
-- =============================================================================
-- TS_GLPI_REF   : donnees de reference (entities, profiles, users, networks...)
--                 Lecture frequente, faible volumetrie, jamais partitionne.
-- TS_GLPI_CERGY : partitions Cergy  (equipements, tickets, localisations)
-- TS_GLPI_PAU   : partitions Pau    (equipements, tickets, localisations)
-- TS_GLPI_INDX  : tous les index    (separation data/index -> pas de contention IO)
-- =============================================================================

-- Suppression defensive (ignoree si le tablespace n'existe pas encore)
-- Ne pas executer DROP TABLESPACE en production sans sauvegarde !
BEGIN EXECUTE IMMEDIATE 'DROP TABLESPACE TS_GLPI_REF   INCLUDING CONTENTS AND DATAFILES'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLESPACE TS_GLPI_CERGY INCLUDING CONTENTS AND DATAFILES'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLESPACE TS_GLPI_PAU   INCLUDING CONTENTS AND DATAFILES'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLESPACE TS_GLPI_INDX  INCLUDING CONTENTS AND DATAFILES'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Detection automatique du repertoire datafiles de XEPDB1
-- Fonctionne sur toute machine Oracle XE 21c sans modification manuelle.
DECLARE
  v_dir VARCHAR2(512);

  PROCEDURE create_ts(p_name VARCHAR2, p_file VARCHAR2, p_size VARCHAR2,
                      p_next VARCHAR2, p_max VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE
      'CREATE TABLESPACE ' || p_name ||
      ' DATAFILE ''' || v_dir || p_file || '''' ||
      ' SIZE ' || p_size ||
      ' AUTOEXTEND ON NEXT ' || p_next || ' MAXSIZE ' || p_max ||
      ' EXTENT MANAGEMENT LOCAL AUTOALLOCATE' ||
      ' SEGMENT SPACE MANAGEMENT AUTO';
    DBMS_OUTPUT.PUT_LINE('Tablespace ' || p_name || ' cree dans ' || v_dir);
  END;

BEGIN
  -- Recupere le dossier du premier datafile de la PDB courante
  SELECT REGEXP_REPLACE(name, '[^\\/]+$', '')
  INTO   v_dir
  FROM   v$datafile
  WHERE  ROWNUM = 1;

  create_ts('TS_GLPI_REF',   'ts_glpi_ref01.dbf',   '50M',  '10M', '500M');
  create_ts('TS_GLPI_CERGY', 'ts_glpi_cergy01.dbf', '100M', '20M', '2G');
  create_ts('TS_GLPI_PAU',   'ts_glpi_pau01.dbf',   '100M', '20M', '2G');
  create_ts('TS_GLPI_INDX',  'ts_glpi_indx01.dbf',  '50M',  '10M', '1G');
END;
/


-- =============================================================================
-- 2. ROLES APPLICATIFS
-- =============================================================================
-- R_GLPI_READ        : auditeurs / lecture seule (rapports globaux)
-- R_GLPI_TECH        : techniciens (parc + tickets de leurs equipements)
-- R_GLPI_ADMIN       : administrateurs site (gestion users, parc, tickets)
-- R_GLPI_TICKET_HELP : interface helpdesk (creation ticket uniquement)
-- =============================================================================

BEGIN EXECUTE IMMEDIATE 'DROP ROLE R_GLPI_READ';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE R_GLPI_TECH';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE R_GLPI_ADMIN';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE R_GLPI_TICKET_HELP'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE ROLE R_GLPI_READ;
CREATE ROLE R_GLPI_TECH;
CREATE ROLE R_GLPI_ADMIN;
CREATE ROLE R_GLPI_TICKET_HELP;

-- Droit de connexion commun a tous les roles applicatifs
GRANT CREATE SESSION TO R_GLPI_READ, R_GLPI_TECH, R_GLPI_ADMIN, R_GLPI_TICKET_HELP;

-- =============================================================================
-- GLPI CY Tech - Nettoyage complet
-- Fichier    : cleanup.sql
-- Connexion  : SYS AS SYSDBA
-- Usage      : remet la base dans l etat avant infrastructure.sql
-- Ordre      : synonymes → database links → comptes → roles → tablespaces
-- =============================================================================

SET SERVEROUTPUT ON


-- =============================================================================
-- 1. SYNONYMES PUBLICS (avant DROP USER pour eviter les synonymes fantomes)
-- =============================================================================
BEGIN
  FOR s IN (
    SELECT synonym_name
    FROM   all_synonyms
    WHERE  owner       = 'PUBLIC'
    AND    table_owner = 'GLPI_OWNER'
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP PUBLIC SYNONYM ' || s.synonym_name;
      DBMS_OUTPUT.PUT_LINE('Synonyme supprime : ' || s.synonym_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Synonyme ignore  : ' || s.synonym_name || ' — ' || SQLERRM);
    END;
  END LOOP;
END;
/


-- =============================================================================
-- 2. DATABASE LINKS PUBLICS
-- =============================================================================
-- Les PUBLIC DATABASE LINKs ne sont pas des objets du schema GLPI_OWNER :
-- DROP USER GLPI_OWNER CASCADE ne les supprime pas. Il faut les supprimer
-- explicitement avant de supprimer les comptes.
-- =============================================================================
BEGIN EXECUTE IMMEDIATE 'DROP PUBLIC DATABASE LINK dblink_vers_pau';   EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('dblink_vers_pau absent');   END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PUBLIC DATABASE LINK dblink_vers_cergy'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('dblink_vers_cergy absent'); END;
/


-- =============================================================================
-- 3. COMPTES ORACLE
-- =============================================================================

-- Proprietaire du schema (CASCADE supprime tables, vues, procedures, sequences,
-- triggers, vues materialisees, types et database links prives)
BEGIN EXECUTE IMMEDIATE 'DROP USER GLPI_OWNER CASCADE'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('GLPI_OWNER absent'); END;
/

-- Comptes generiques applicatifs
BEGIN EXECUTE IMMEDIATE 'DROP USER GLPI_READ  CASCADE'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('GLPI_READ absent');  END;
/
BEGIN EXECUTE IMMEDIATE 'DROP USER GLPI_HELP  CASCADE'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('GLPI_HELP absent');  END;
/

-- Comptes de service BDDR
BEGIN EXECUTE IMMEDIATE 'DROP USER GLPI_DBLINK_CERGY CASCADE'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('GLPI_DBLINK_CERGY absent'); END;
/
BEGIN EXECUTE IMMEDIATE 'DROP USER GLPI_DBLINK_PAU   CASCADE'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('GLPI_DBLINK_PAU absent');   END;
/

-- Comptes individuels crees dynamiquement par ajouter_admin / ajouter_technicien
-- (pattern : PSEUDO_SITE, ex : JDUPONT_CERGY, MARTIN_PAU)
-- Note : GLPI_DBLINK_CERGY et GLPI_DBLINK_PAU correspondent aussi a ce pattern
-- mais sont deja supprimes ci-dessus.
BEGIN
  FOR u IN (
    SELECT username
    FROM   dba_users
    WHERE  (username LIKE '%\_CERGY' ESCAPE '\'
        OR  username LIKE '%\_PAU'   ESCAPE '\')
    AND    username NOT IN ('GLPI_DBLINK_CERGY', 'GLPI_DBLINK_PAU')
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
      DBMS_OUTPUT.PUT_LINE('Compte supprime : ' || u.username);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Compte ignore   : ' || u.username || ' — ' || SQLERRM);
    END;
  END LOOP;
END;
/


-- =============================================================================
-- 4. ROLES
-- =============================================================================
BEGIN EXECUTE IMMEDIATE 'DROP ROLE R_GLPI_READ';        EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('R_GLPI_READ absent');        END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE R_GLPI_TECH';        EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('R_GLPI_TECH absent');        END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE R_GLPI_ADMIN';       EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('R_GLPI_ADMIN absent');       END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE R_GLPI_TICKET_HELP'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('R_GLPI_TICKET_HELP absent'); END;
/


-- =============================================================================
-- 5. TABLESPACES (INCLUDING CONTENTS supprime les segments ;
--    AND DATAFILES supprime les fichiers .dbf sur le disque)
-- =============================================================================
BEGIN EXECUTE IMMEDIATE 'DROP TABLESPACE TS_GLPI_REF   INCLUDING CONTENTS AND DATAFILES'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('TS_GLPI_REF absent');   END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLESPACE TS_GLPI_CERGY INCLUDING CONTENTS AND DATAFILES'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('TS_GLPI_CERGY absent'); END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLESPACE TS_GLPI_PAU   INCLUDING CONTENTS AND DATAFILES'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('TS_GLPI_PAU absent');   END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLESPACE TS_GLPI_INDX  INCLUDING CONTENTS AND DATAFILES'; EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('TS_GLPI_INDX absent');  END;
/


-- =============================================================================
-- 6. VERIFICATION FINALE (toutes les lignes doivent afficher 0)
-- =============================================================================
SELECT 'Tablespaces restants'      AS check_name, COUNT(*) AS nb
FROM   dba_tablespaces
WHERE  tablespace_name LIKE 'TS_GLPI%'
UNION ALL
SELECT 'Roles restants',           COUNT(*)
FROM   dba_roles
WHERE  role LIKE 'R_GLPI%'
UNION ALL
SELECT 'Comptes fixes restants',   COUNT(*)
FROM   dba_users
WHERE  username IN ('GLPI_OWNER', 'GLPI_READ', 'GLPI_HELP',
                    'GLPI_DBLINK_CERGY', 'GLPI_DBLINK_PAU')
UNION ALL
SELECT 'Comptes PSEUDO_SITE restants', COUNT(*)
FROM   dba_users
WHERE  username LIKE '%\_CERGY' ESCAPE '\'
    OR username LIKE '%\_PAU'   ESCAPE '\'
UNION ALL
SELECT 'Database links restants',  COUNT(*)
FROM   dba_db_links
WHERE  db_link IN ('DBLINK_VERS_PAU', 'DBLINK_VERS_CERGY');

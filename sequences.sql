-- =============================================================================
-- GLPI CY Tech - Sequences
-- Fichier    : sequences.sql
-- Connexion  : GLPI_OWNER
-- Dependances: schema.sql execute avant
-- =============================================================================

-- Suppression defensive (ignoree si la sequence n'existe pas encore)
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_ticket_cergy';      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_ticket_pau';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_equip_cergy';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_equip_pau';         EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_hardware_serial';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_locations_name';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_ip_host_cergy';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_ip_host_pau';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_users_pseudo';      EXCEPTION WHEN OTHERS THEN NULL; END;
/


-- 1. TICKETS (plages distinctes pour eviter collision BDDR)
CREATE SEQUENCE seq_ticket_cergy
    START WITH 1000001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_ticket_pau
    START WITH 2000001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;


-- 2. EQUIPEMENTS (noms generes : EQ-10001, EQ-20001...)
CREATE SEQUENCE seq_equip_cergy
    START WITH 10001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_equip_pau
    START WITH 20001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;


-- 3. NUMEROS DE SERIE (secours si le matériel n'en a pas)
CREATE SEQUENCE seq_hardware_serial
    START WITH 550000
    INCREMENT BY 17
    NOCACHE
    NOCYCLE;


-- 4. LOCALISATIONS (LOC-1, LOC-2...)
CREATE SEQUENCE seq_locations_name
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;


-- 5. ADRESSES IP (partie hote : 10.1.0.X pour Cergy, 10.2.0.X pour Pau)
-- CYCLE : le /24 ne couvre que 254 hotes ; le cycle est intentionnel
CREATE SEQUENCE seq_ip_host_cergy
    START WITH 1
    INCREMENT BY 1
    MAXVALUE 254
    CYCLE
    NOCACHE;

CREATE SEQUENCE seq_ip_host_pau
    START WITH 1
    INCREMENT BY 1
    MAXVALUE 254
    CYCLE
    NOCACHE;


-- 6. PSEUDOS UTILISATEURS (secours homonymes)
CREATE SEQUENCE seq_users_pseudo
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

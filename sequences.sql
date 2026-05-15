-- =================================================================
-- PROJET : Inventaire Parc Informatique CY Tech
-- FICHIER : creation_sequences.sql
-- ROLE : Initialisation des compteurs pour le multi-sites (BDDR)
-- =================================================================

-- 1. TICKETS (Plages distinctes pour Cergy et Pau)
DROP SEQUENCE seq_ticket_cergy;
CREATE SEQUENCE seq_ticket_cergy 
    START WITH 1000001 
    INCREMENT BY 1 
    NOCACHE;

DROP SEQUENCE seq_ticket_pau;
CREATE SEQUENCE seq_ticket_pau 
    START WITH 2000001 
    INCREMENT BY 1 
    NOCACHE;

-- 2. ÉQUIPEMENTS (Noms d'hôtes PC/Printers)
DROP SEQUENCE seq_equip_cergy;
CREATE SEQUENCE seq_equip_cergy 
    START WITH 10001 
    INCREMENT BY 1 
    NOCACHE;

DROP SEQUENCE seq_equip_pau;
CREATE SEQUENCE seq_equip_pau 
    START WITH 20001 
    INCREMENT BY 1 
    NOCACHE;

-- 3. NUMÉROS DE SÉRIE (Global)
-- à voir si on genère plus tot des grands nombres avec des lettres ou pas...
DROP SEQUENCE seq_hardware_serial;
CREATE SEQUENCE seq_hardware_serial 
    START WITH 550000 
    INCREMENT BY 17 
    NOCACHE;

-- 4. LOCALISATIONS (Salles et Bureaux)
-- à compléter avec le niveau ( et site ? ) 
DROP SEQUENCE seq_locations_name;
CREATE SEQUENCE seq_locations_name 
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE;

-- 5. ADRESSES IP (Partie Hôte)
-- à compléter avec le nom du network ( 10.1.0.X pour cergy par exemple et 10.2.0.X pour pau ) 
DROP SEQUENCE seq_ip_host;
CREATE SEQUENCE seq_ip_host 
    START WITH 1 
    INCREMENT BY 1 
    MAXVALUE 254 
    CYCLE 
    NOCACHE;

-- 6. PSEUDOS UTILISATEURS (Séquence de secours pour homonymes)
-- au cas 2 personenes ont le même nom et prénom
DROP SEQUENCE seq_users_pseudo;
CREATE SEQUENCE seq_users_pseudo 
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE;

COMMIT;

DECLARE 
    -- 1. Déclaration du curseur (La requête SQL)
   CREATE OR REPLACE PROCEDURE rapport_utilisateurs_site (p_id_site IN NUMBER) IS 
    
    v_nom_site VARCHAR2(255);

    -- 1. Le Curseur Paramétré (Il attend un ID d'entité)
    CURSOR c_users_site (v_ent_id NUMBER) IS 
        SELECT u.realname, 
               u.firstname, 
               p.name AS profile_name, 
               e.itemtype, 
               e.name AS equip_name, 
               l.name AS location_name
        FROM glpi_users u
        LEFT JOIN glpi_profiles_users pu ON u.id = pu.users_id
        LEFT JOIN glpi_profiles p ON pu.profiles_id = p.id
        LEFT JOIN glpi_computers c ON u.id = c.users_id
        LEFT JOIN glpi_printers pr ON u.id = pr.users_id
        LEFT JOIN glpi_equipments e ON (e.id = c.id OR e.id = pr.id)
        LEFT JOIN glpi_locations l ON e.locations_id = l.id
        WHERE u.is_active = 1
          AND u.entities_id = v_ent_id; -- On filtre dynamiquement !

BEGIN 
    -- 2. Récupération du nom du site pour faire un beau titre
    BEGIN
        SELECT name INTO v_nom_site FROM glpi_entities WHERE id = p_id_site;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : L''entité N°' || p_id_site || ' n''existe pas.');
            RETURN; -- On arrête tout si le site n'existe pas
    END;

    -- 3. Affichage de l'en-tête dynamique
    DBMS_OUTPUT.PUT_LINE('===================================================');
    DBMS_OUTPUT.PUT_LINE('--- RAPPORT UTILISATEURS : SITE DE ' || UPPER(v_nom_site) || ' ---'); 
    DBMS_OUTPUT.PUT_LINE('===================================================');

    -- 4. La boucle (On passe le paramètre p_id_site au curseur !)
    FOR lign IN c_users_site(p_id_site) LOOP
        
        IF lign.profile_name IS NULL THEN 
            DBMS_OUTPUT.PUT('> Élève : ' || lign.realname || ' ' || lign.firstname);
        ELSE
            DBMS_OUTPUT.PUT('> ' || lign.profile_name || ' : ' || lign.realname || ' ' || lign.firstname);
        END IF;

        IF lign.equip_name IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE(' | Matériel : ' || lign.itemtype || ' (' || lign.equip_name || ') en ' || lign.location_name);
        ELSE
            DBMS_OUTPUT.PUT_LINE(' | Matériel : Aucun équipement assigné.');
        END IF;

    END LOOP; 
    
    DBMS_OUTPUT.PUT_LINE('===================================================');
END;
/


CREATE OR REPLACE PROCEDURE rapport_equipements_site (p_id_site IN NUMBER) IS 
    
    v_nom_site VARCHAR2(255);
    
    -- Compteurs globaux nettoyés
    v_tot_equip       NUMBER := 0;
    v_tot_pc          NUMBER := 0;
    v_tot_print       NUMBER := 0;
    v_tot_non_resolus NUMBER := 0;

    -- 1. Le Curseur Paramétré
    CURSOR c_parc (v_ent_id NUMBER) IS 
        SELECT e.itemtype, 
               e.name AS equip_name,
               l.name AS location_name,
               u_tech.realname AS tech_nom,
               CASE NVL(c.states_id, pr.states_id)
                   WHEN 1 THEN 'Opérationnel'
                   WHEN 2 THEN 'En maintenance'
                   WHEN 3 THEN 'En panne'
                   WHEN 4 THEN 'Au rebut'
                   ELSE 'Inconnu'
               END AS etat_materiel,
               -- Uniquement les tickets en attente d'action
               NVL(t.nb_non_resolus, 0) AS tickets_non_resolus
        FROM glpi_equipments e
        LEFT JOIN glpi_locations l ON e.locations_id = l.id
        LEFT JOIN glpi_computers c ON e.id = c.id
        LEFT JOIN glpi_printers pr ON e.id = pr.id
        LEFT JOIN glpi_users u_tech ON u_tech.id = NVL(c.users_id_tech, pr.users_id_tech)
        
        -- LA SOUS-REQUÊTE RADICALE : On ne regarde QUE les statuts 1, 2 et 3
        LEFT JOIN (
            SELECT equipment_id,
                   COUNT(id) AS nb_non_resolus
            FROM glpi_tickets
            WHERE status IN (1, 2, 3) -- On éjecte physiquement les 4 et 5 ici
            GROUP BY equipment_id
        ) t ON t.equipment_id = e.id
        
        WHERE e.entities_id = v_ent_id;

BEGIN 
    -- 2. Vérification de l'existence du site
    BEGIN
        SELECT name INTO v_nom_site FROM glpi_entities WHERE id = p_id_site;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : L''entité N°' || p_id_site || ' n''existe pas.');
            RETURN;
    END;

    -- 3. En-tête du rapport
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('   INVENTAIRE DU PARC MATÉRIEL : SITE DE ' || UPPER(v_nom_site)); 
    DBMS_OUTPUT.PUT_LINE('================================================================');

    -- 4. Lecture des données
    FOR r_equip IN c_parc(p_id_site) LOOP
        
        DBMS_OUTPUT.PUT_LINE('[' || UPPER(r_equip.itemtype) || '] ' || r_equip.equip_name 
                             || ' | Salle: ' || NVL(r_equip.location_name, 'Non assignée'));
        DBMS_OUTPUT.PUT_LINE('    -> État : ' || r_equip.etat_materiel 
                             || ' | Tech : ' || NVL(r_equip.tech_nom, 'Aucun'));
        
        -- On n'affiche les tickets QUE s'il y en a (plus propre visuellement)
        IF r_equip.tickets_non_resolus > 0 THEN
            DBMS_OUTPUT.PUT_LINE('    -> ⚠️ TICKETS EN COURS : ' || r_equip.tickets_non_resolus);
        ELSE
            DBMS_OUTPUT.PUT_LINE('    -> RAS (Aucun ticket en cours)');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('---');

        -- Incrémentation des compteurs
        v_tot_equip := v_tot_equip + 1;
        v_tot_non_resolus := v_tot_non_resolus + r_equip.tickets_non_resolus;
        
        IF r_equip.itemtype = 'Computer' THEN
            v_tot_pc := v_tot_pc + 1;
        ELSIF r_equip.itemtype = 'Printer' THEN
            v_tot_print := v_tot_print + 1;
        END IF;

    END LOOP; 
    
    -- 5. Le Bilan Final
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('                     BILAN STATISTIQUE                          ');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('Total des équipements : ' || v_tot_equip);
    DBMS_OUTPUT.PUT_LINE('  - Ordinateurs       : ' || v_tot_pc);
    DBMS_OUTPUT.PUT_LINE('  - Imprimantes       : ' || v_tot_print);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('TOTAL DES INCIDENTS EN COURS : ' || v_tot_non_resolus);
    DBMS_OUTPUT.PUT_LINE('================================================================');
END;
/

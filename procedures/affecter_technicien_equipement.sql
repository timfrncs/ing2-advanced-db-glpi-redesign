CREATE OR REPLACE PROCEDURE affecter_technicien_equipement(
    p_equip_name IN VARCHAR2,
    p_tech_pseudo IN VARCHAR2
) AS
    v_equip_id    NUMBER;
    v_tech_id     NUMBER;
    v_entities_id NUMBER;
    v_site        VARCHAR2(50);
    v_ent_site    NUMBER;
    v_itemtype    VARCHAR2(100);
BEGIN
    v_site := SUBSTR(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),
              INSTR(SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),'|')+1);

    SELECT id INTO v_ent_site FROM glpi_entities WHERE UPPER(name) = v_site;

    SELECT id, entities_id, itemtype INTO v_equip_id, v_entities_id, v_itemtype
    FROM glpi_equipments
    WHERE UPPER(name) = UPPER(p_equip_name) AND ROWNUM = 1;

    IF v_entities_id != v_ent_site THEN
        RAISE_APPLICATION_ERROR(-20070, 'Équipement hors de votre site.');
    END IF;

    SELECT u.id INTO v_tech_id FROM glpi_users u
    JOIN glpi_profiles_users pu ON pu.users_id = u.id
    JOIN glpi_profiles p ON p.id = pu.profiles_id
    WHERE UPPER(u.pseudo) = UPPER(p_tech_pseudo)
    AND UPPER(p.name) = 'TECHNICIEN' AND u.is_active = 1;

    IF v_itemtype = 'Computer' THEN
        UPDATE glpi_computers SET users_id_tech = v_tech_id WHERE id = v_equip_id;
    ELSE
        UPDATE glpi_printers SET users_id_tech = v_tech_id WHERE id = v_equip_id;
    END IF;

    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20071, 'Équipement ou technicien introuvable.');
END;
/

# ing2-advanced-db-glpi-redesign
Advanced DB mini-project — reverse engineering GLPI inventory schema and proposing a redesigned Oracle model for CY Tech IT assets with multi-campus (network, users, performance).


CONNECT / AS SYSDBA

ALTER SESSION SET CONTAINER = XEPDB1;

@[path_to_the_project]/ing2-advanced-db-glpi-redesign/cleanup.sql

@[path_to_the_project]/ing2-advanced-db-glpi-redesign/install.sql

@[path_to_the_project]/ing2-advanced-db-glpi-redesign/scenario.sql

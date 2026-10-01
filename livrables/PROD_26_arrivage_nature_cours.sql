-- =====================================================================
-- PROD étape 26 : demandes client sur l'Arrivage / la commande d'achat (écran GESCOM)
--   1. Nature : comme GESCOM, un arrivage « à embarquer » est un Flottant (badge + colonne « À embarquer »).
--      L'option de recherche « En cours de production (à embarquer) » disparaît : « Arrivage(s) Flottant(s) »
--      inclut les arrivages à embarquer (Arrivages et liste des achats fournisseurs).
--   2. Champs Cours / Couvert / Flottant / Réel (taux de change GESCOM) sur la commande d'achat et l'arrivage,
--      pour archivage seulement : ils n'entrent dans aucun calcul. Recopiés de la commande sur l'arrivage.
--   3. Équivalent en devise comptable (€) quand la devise d'achat est l'USD (taux officiel Axelor).
-- Relance des écrans PROD_8 (commande d'achat), PROD_9 (arrivages) et PROD_10 (listes) depuis leurs sources
-- mises à jour (ces scripts sont relançables et reprennent PROD_17, PROD_18 et PROD_21).
-- Code à déployer avec ce script (champs, nature « Flottant », recopie du cours).
-- À lancer depuis la racine du dépôt, AVANT le redémarrage d'Axelor.
-- =====================================================================
BEGIN;
ALTER TABLE stock_stock_move ADD COLUMN IF NOT EXISTS lvme_cours numeric(20,4);
ALTER TABLE stock_stock_move ADD COLUMN IF NOT EXISTS lvme_couvert numeric(20,4);
ALTER TABLE stock_stock_move ADD COLUMN IF NOT EXISTS lvme_flottant numeric(20,4);
ALTER TABLE stock_stock_move ADD COLUMN IF NOT EXISTS lvme_reel numeric(20,4);
ALTER TABLE purchase_purchase_order ADD COLUMN IF NOT EXISTS lvme_cours numeric(20,4);
ALTER TABLE purchase_purchase_order ADD COLUMN IF NOT EXISTS lvme_couvert numeric(20,4);
ALTER TABLE purchase_purchase_order ADD COLUMN IF NOT EXISTS lvme_flottant numeric(20,4);
ALTER TABLE purchase_purchase_order ADD COLUMN IF NOT EXISTS lvme_reel numeric(20,4);

-- options de recherche « En cours de production (à embarquer) » retirées
DELETE FROM meta_select_item
WHERE (value = '5' AND select_id = (SELECT id FROM meta_select WHERE name = 'lvme.arrivage.nature.select'))
   OR (value = '4' AND select_id = (SELECT id FROM meta_select WHERE name = 'lvme.achat.nature.select'));
COMMIT;

\i livrables/PROD_8_ui_commande_fournisseur.sql
\i livrables/PROD_9_arrivages.sql
\i livrables/PROD_10_listes_achats_commandes.sql

SELECT s.name, i.value, i.title FROM meta_select s JOIN meta_select_item i ON i.select_id = s.id
WHERE s.name IN ('lvme.arrivage.nature.select', 'lvme.achat.nature.select') ORDER BY s.name, i.order_seq;

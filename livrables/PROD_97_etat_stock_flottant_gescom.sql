-- =====================================================================
-- PROD étape 97 : État des stocks par lots — stock des lots flottants comme GESCOM (décision du 28/10/2026)
--   - lot d'un arrivage flottant (marchandise en mer, quel que soit le transport) : stock = entrées - sorties (ventes
--     et réservations déjà faites sur le lot), sorties affichées, commandes clients du lot comptées (disponible)
--   - la ligne de lot d'un flottant porte « moins les sorties » ; à la réception, la quantité reçue s'y ajoute et le
--     stock devient entrées - sorties en frigo ; lots réels : inchangés
--   - vue lvme_etat_stock_lot (sql/lvme_etat_stock_lot.sql), mêmes colonnes : pas de redémarrage nécessaire
-- À lancer depuis la racine du dépôt. Relançable.
-- =====================================================================
BEGIN;
\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_etat_stock_lot.sql
COMMIT;

SELECT nature_label AS nature, count(*) AS lots, round(sum(stock_qty)) AS stock, round(sum(stock_value)) AS valeur
FROM lvme_etat_stock_lot WHERE stock_qty <> 0 GROUP BY nature_label ORDER BY 1;

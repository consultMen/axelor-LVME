-- =====================================================================
-- PROD étape 16 : Historique Produit / Synthèse des Arrivages — arrivages repris de GESCOM
--   Les réceptions migrées n'ont que la date prévue (date réelle vide) : les deux vues prennent
--   désormais la date réelle, sinon la date prévue (comme « État des stocks par lots »).
-- Vues SQL seulement : pas de redémarrage nécessaire. À lancer depuis la racine du dépôt, après git pull.
-- Relançable.
-- =====================================================================
BEGIN;
\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_historique_produit.sql
\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_synthese_arrivage.sql
COMMIT;

SELECT 'synthese' AS vue, count(*) AS lignes, count(*) FILTER (WHERE date_arrivee IS NULL) AS sans_date,
       min(date_arrivee) AS du, max(date_arrivee) AS au FROM lvme_synthese_arrivage
UNION ALL
SELECT 'historique', count(*), count(*) FILTER (WHERE date_mvt IS NULL), min(date_mvt), max(date_mvt) FROM lvme_historique_produit;

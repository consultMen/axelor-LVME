-- =====================================================================
-- PROD étape 106 : « Rotation des stocks par lot » rapide (le 28/10/2026, recherche > 60 s : erreur 504)
--   Depuis la reprise des BL GESCOM (MIG_06, 154 575 lignes de sortie), la vue lvme_rotation_lot calculait la dernière
--   vente et la rotation lot par lot en relisant toutes les sorties : plusieurs minutes. Les sorties sont maintenant
--   lues une seule fois ; même calcul, mêmes colonnes (vérifié : 0 écart sur 300 lots vendus). Moins d'une seconde.
--   Pas de redémarrage nécessaire. À lancer depuis la racine du dépôt. Relançable.
-- =====================================================================
BEGIN;
\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_rotation_lot.sql
COMMIT;

\timing on
SELECT count(*) AS lots, count(last_sale_date) AS lots_vendus, max(last_sale_date) AS derniere_vente FROM lvme_rotation_lot;

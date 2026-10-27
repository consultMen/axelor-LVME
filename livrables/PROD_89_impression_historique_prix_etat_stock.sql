-- =====================================================================
-- PROD étape 89 : impression de l'Historique prix et de l'État des stocks par lots
--   - Historique prix (F1 de la ligne de commande client) : bouton « Imprimer » sous « Recherche », impression LVME
--     (logo, colonnes de l'écran, mêmes filtres client / produit / période, sommes colis, poids et montant)
--   - État des stocks par lots : bouton « Imprimer » sous « Archiver / Désarchiver », impression LVME (logo,
--     colonnes de la liste, mêmes filtres et options, sommes des colis, poids et montants)
-- Prérequis : code avec LvmeImpressionListesController.imprimerHistoriquePrix / imprimerEtatStock et
-- reports/LvmeHistoriquePrix.rptdesign, LvmeEtatStockLots.rptdesign (recompiler) ; PROD_79.
-- Sources : livrables/ui/historique-prix-form.xml, etat-stock-lot-search-form.xml. Relançable.
-- =====================================================================
\set histo `cat livrables/ui/historique-prix-form.xml`
SELECT set_config('lvme.histo_prix', :'histo', false) IS NOT NULL AS historique_prix_lu;
\set etat `cat livrables/ui/etat-stock-lot-search-form.xml`
SELECT set_config('lvme.etat_stock', :'etat', false) IS NOT NULL AS etat_stock_lu;

BEGIN;

DELETE FROM meta_action WHERE module IS NULL
  AND name IN ('action-lvme-historique-prix-imprimer', 'action-lvme-etat-stock-lot-imprimer');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-prix-imprimer', 'action-method', NULL,
'<action-method name="action-lvme-historique-prix-imprimer">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerHistoriquePrix"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-imprimer', 'action-method', NULL,
'<action-method name="action-lvme-etat-stock-lot-imprimer">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerEtatStock"/>
</action-method>', false, false, 0);

UPDATE meta_view SET xml = current_setting('lvme.histo_prix'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-historique-prix-form' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.etat_stock'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-etat-stock-lot-search-form' AND module IS NULL;

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND (
          (name = 'lvme-historique-prix-form' AND xml LIKE '%action-lvme-historique-prix-imprimer%')
          OR (name = 'lvme-etat-stock-lot-search-form' AND xml LIKE '%action-lvme-etat-stock-lot-imprimer%')))
       AS ecrans_modifies,
       (SELECT count(*) FROM meta_action WHERE module IS NULL
          AND name IN ('action-lvme-historique-prix-imprimer', 'action-lvme-etat-stock-lot-imprimer')) AS actions;

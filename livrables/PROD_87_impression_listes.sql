-- =====================================================================
-- PROD étape 87 : boutons d'impression des listes, comme GESCOM
--   - « Imprimer » (liste des achats fournisseurs), « Editer » (liste des arrivages), « Liste des Rotations »
--     (rotation des stocks par lot) : impressions LVME avec logo, colonnes de la liste, mêmes filtres que l'écran,
--     couleurs GESCOM, totaux (et totaux par produit pour les rotations)
-- Prérequis : code avec LvmeImpressionListesController et reports/LvmeListe*.rptdesign (recompiler) ; PROD_85.
-- Sources : livrables/ui/achat-search-form.xml, livrables/ui/arrivage-search-form.xml. Relançable.
-- =====================================================================
\set achats `cat livrables/ui/achat-search-form.xml`
SELECT set_config('lvme.ach_recherche', :'achats', false) IS NOT NULL AS achats_lu;
\set arrivages `cat livrables/ui/arrivage-search-form.xml`
SELECT set_config('lvme.arr_recherche', :'arrivages', false) IS NOT NULL AS arrivages_lu;

BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-achat-imprimer-liste',
  'action-lvme-arrivage-imprimer-liste', 'action-lvme-rotation-imprimer-liste');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-imprimer-liste', 'action-method', NULL,
'<action-method name="action-lvme-achat-imprimer-liste">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerAchats"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-imprimer-liste', 'action-method', NULL,
'<action-method name="action-lvme-arrivage-imprimer-liste">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerArrivages"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-imprimer-liste', 'action-method', NULL,
'<action-method name="action-lvme-rotation-imprimer-liste">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerRotations"/>
</action-method>', false, false, 0);

UPDATE meta_view SET xml = current_setting('lvme.ach_recherche'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-achat-search-form' AND module IS NULL;

UPDATE meta_view SET xml = current_setting('lvme.arr_recherche'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-arrivage-search-form' AND module IS NULL;

UPDATE meta_view SET xml = replace(xml,
  '<button name="recalculBtn" title="Recalculer les KPI" icon="arrow-repeat" onClick="action-lvme-rotation-stock-group-recalcul"/>',
  '<button name="recalculBtn" title="Recalculer les KPI" icon="arrow-repeat" onClick="action-lvme-rotation-stock-group-recalcul"/>
      <button name="listeRotationsBtn" title="Liste des Rotations" icon="printer" onClick="action-lvme-rotation-imprimer-liste"/>'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-rotation-stock-dashboard-form' AND module IS NULL AND xml NOT LIKE '%listeRotationsBtn%';

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND (
          (name = 'lvme-achat-search-form' AND xml LIKE '%imprimerListeBtn%')
          OR (name = 'lvme-arrivage-search-form' AND xml LIKE '%editerListeBtn%')
          OR (name = 'lvme-rotation-stock-dashboard-form' AND xml LIKE '%listeRotationsBtn%'))) AS boutons_ajoutes;

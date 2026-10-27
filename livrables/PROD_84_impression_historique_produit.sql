-- =====================================================================
-- PROD étape 84 : impression de l'écran « Historique Produit » (bouton « Imprimer » en bas à gauche, comme GESCOM)
--   - modèle LvmeHistoriqueProduit.rptdesign : logo LVME en haut à gauche, produit et période, mouvements dans les
--     colonnes de l'écran (lignes cyan clair / cyan), totaux dans des cases bleues ; mêmes filtres que l'écran
-- Prérequis : code avec LvmeHistoriqueProduitController.imprimer et reports/LvmeHistoriqueProduit.rptdesign
-- (recompiler) ; PROD_83. Source : livrables/ui/lvme-historique-produit-form.xml. Relançable.
-- =====================================================================
BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-historique-produit-imprimer';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-imprimer', 'action-method', NULL,
'<action-method name="action-lvme-historique-produit-imprimer">
  <!-- impression LVME de l''écran Historique Produit (mêmes filtres) -->
  <call class="com.axelor.apps.supplychain.web.LvmeHistoriqueProduitController" method="imprimer"/>
</action-method>', false, false, 0);

UPDATE meta_view SET xml = replace(xml, $q$  <panel name="totauxPanel" showTitle="false" colSpan="12">
    <field name="$totalColis" title="Total colis" type="decimal" readonly="true" colSpan="3" x-scale="0"/>
    <field name="$stockPeriode" title="Stock Période" type="decimal" readonly="true" colSpan="3" x-scale="3"/>
    <field name="$poidsEntrees" title="Poids Entrées" type="decimal" readonly="true" colSpan="3" x-scale="3"/>
    <field name="$poidsSorties" title="Poids Sorties" type="decimal" readonly="true" colSpan="3" x-scale="3"/>$q$, $q$  <panel name="totauxPanel" showTitle="false" colSpan="12">
    <!-- bouton « Imprimer » en bas à gauche comme GESCOM : impression LVME de l'historique (PROD_84) -->
    <button name="imprimerBtn" title="Imprimer" icon="printer" colSpan="2" onClick="action-lvme-historique-produit-imprimer"/>
    <field name="$totalColis" title="Total colis" type="decimal" readonly="true" colSpan="2" x-scale="0"/>
    <field name="$stockPeriode" title="Stock Période" type="decimal" readonly="true" colSpan="3" x-scale="3"/>
    <field name="$poidsEntrees" title="Poids Entrées" type="decimal" readonly="true" colSpan="3" x-scale="3"/>
    <field name="$poidsSorties" title="Poids Sorties" type="decimal" readonly="true" colSpan="2" x-scale="3"/>$q$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-historique-produit-form' AND module IS NULL AND xml NOT LIKE '%imprimerBtn%';

COMMIT;

SELECT xml LIKE '%imprimerBtn%' AS bouton_imprimer
FROM meta_view WHERE name = 'lvme-historique-produit-form' AND module IS NULL;

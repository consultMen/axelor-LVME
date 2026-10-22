-- =====================================================================
-- PROD étape 66 : Sélect Arrivage de la ligne de commande client = « Sélection Arrivage » GESCOM
--   - liste des arrivages / lots de l'article (Numero Arrivage, Fournisseur, Origine, Conditionnement, Frigo,
--     N° Lot, Date Arrivée, D.D.M, Unité Vente, Prix Revient, Poids Colis, Colis Stock, Colis Rsv, Poids Dispo,
--     Colis Dispo en jaune), lignes bleu clair / cyan
--   - le lot choisi est ajouté aux « Lots sélectionnés » de la ligne et les valeurs du lot (N° Lot, Arrivage,
--     Frigo, Marque…) se remplissent tout de suite ; conditionnement, nb unités / poids du colis, coef. et unité
--     repris de la ligne d'arrivage choisie, Prix Revient = PR/kg de l'arrivage ; mêmes calculs qu'un lot ajouté à la main (frais, P.R., marge)
--   - l'ancienne fenêtre « Ajouter un arrivage » (allocation sur commande d'achat) reste dans le panneau
--     Arrivages de la ligne
-- Source : livrables/ui/selection-arrivage-grid.xml ; le sélecteur est dans la fiche ligne (PROD_64).
-- Prérequis : code avec le champ EtatStockLot.nbColisDispo (recompiler), PROD_64. Depuis la racine du dépôt.
-- Relançable. Retour arrière : relancer PROD_64 avec l'ancienne fiche ligne (bouton Sélect Arrivage).
-- =====================================================================
\set grille `cat livrables/ui/selection-arrivage-grid.xml`
SELECT set_config('lvme.selection_arrivage', :'grille', false) IS NOT NULL AS grille_lue;

BEGIN;

DELETE FROM meta_view WHERE module IS NULL AND name = 'lvme-selection-arrivage-grid';
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-selection-arrivage-grid', 'Sélection Arrivage', 'grid',
 'com.axelor.apps.supplychain.db.EtatStockLot', 20, current_setting('lvme.selection_arrivage'), false, false);

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-ligne-cde-sel-arrivage-ajout',
  'action-lvme-ligne-cde-sel-arrivage-valeurs',
  'action-lvme-ligne-cde-sel-arrivage-vider', 'action-lvme-ligne-cde-group-sel-arrivage');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cde-sel-arrivage-ajout', 'action-attrs', NULL,
'<action-attrs name="action-lvme-ligne-cde-sel-arrivage-ajout">
  <!-- lot de l''arrivage choisi ajouté aux lots sélectionnés (s''il n''y est pas déjà) -->
  <attribute name="value" for="saleOrderLineLotList" expr="eval: def e = selArrivage?.id ? __repo__(com.axelor.apps.supplychain.db.EtatStockLot).find(selArrivage.id as Long) : null; def l = (saleOrderLineLotList ?: []).collect { it }; if (e?.trackingNumber &amp;&amp; !l.any { it.trackingNumber?.id == e.trackingNumber.id }) { l.add([trackingNumber: [id: e.trackingNumber.id, trackingNumberSeq: e.trackingNumber.trackingNumberSeq], qtyToShip: qty ?: 0, availableQty: e.dispoQty, perishableExpirationDate: e.dluo]) }; l"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cde-sel-arrivage-valeurs', 'action-attrs', NULL,
'<action-attrs name="action-lvme-ligne-cde-sel-arrivage-valeurs">
  <!-- valeurs de la ligne d''arrivage choisie reprises sur la ligne de commande (conditionnement, colis, unité) -->
  <attribute name="value" for="conditionnement" expr="eval: def e = selArrivage?.id ? __repo__(com.axelor.apps.supplychain.db.EtatStockLot).find(selArrivage.id as Long) : null; def a = e?.trackingNumber?.originStockMoveLine; a?.purchaseOrderLine?.conditionnement != null ? a.purchaseOrderLine?.conditionnement : conditionnement"/>
  <attribute name="value" for="nbUnitesParColis" expr="eval: def e = selArrivage?.id ? __repo__(com.axelor.apps.supplychain.db.EtatStockLot).find(selArrivage.id as Long) : null; def a = e?.trackingNumber?.originStockMoveLine; a?.nbUnitesParColis != null ? a.nbUnitesParColis : nbUnitesParColis"/>
  <attribute name="value" for="poidsParColis" expr="eval: def e = selArrivage?.id ? __repo__(com.axelor.apps.supplychain.db.EtatStockLot).find(selArrivage.id as Long) : null; def a = e?.trackingNumber?.originStockMoveLine; a?.poidsParColis != null ? a.poidsParColis : poidsParColis"/>
  <attribute name="value" for="coefPoidsNet" expr="eval: def e = selArrivage?.id ? __repo__(com.axelor.apps.supplychain.db.EtatStockLot).find(selArrivage.id as Long) : null; def a = e?.trackingNumber?.originStockMoveLine; a?.coefPoidsNet != null ? a.coefPoidsNet : coefPoidsNet"/>
  <attribute name="value" for="unit" expr="eval: def e = selArrivage?.id ? __repo__(com.axelor.apps.supplychain.db.EtatStockLot).find(selArrivage.id as Long) : null; def a = e?.trackingNumber?.originStockMoveLine; a?.unit != null ? a.unit : unit"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cde-sel-arrivage-vider', 'action-attrs', NULL,
'<action-attrs name="action-lvme-ligne-cde-sel-arrivage-vider">
  <attribute name="value" for="$selArrivage" expr="eval: null"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cde-group-sel-arrivage', 'action-group', NULL,
'<action-group name="action-lvme-ligne-cde-group-sel-arrivage">
  <action name="action-lvme-ligne-cde-sel-arrivage-ajout"/>
  <action name="action-lvme-ligne-cde-sel-arrivage-valeurs"/>
  <action name="action-sale-order-line-method-compute-packaging"/>
  <action name="action-method-sale-order-line-persist-lot-selection"/>
  <action name="action-method-sale-order-line-set-frais-congelation-from-lot"/>
  <action name="action-method-sale-order-line-set-pr-from-lot"/>
  <action name="action-method-sale-order-line-compute-pr-net"/>
  <action name="action-method-sale-order-line-recompute-marge-with-pr-net"/>
  <action name="action-method-sale-order-line-persist-calculs-lvme"/>
  <action name="action-lvme-ligne-cde-valeurs-lot"/>
  <action name="action-lvme-ligne-cde-sel-arrivage-vider"/>
</action-group>', false, false, 0);

COMMIT;

SELECT name FROM meta_view WHERE module IS NULL AND name = 'lvme-selection-arrivage-grid';
SELECT count(*) = 4 AS actions_ok FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-ligne-cde-%sel-arrivage%';

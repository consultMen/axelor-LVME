-- =====================================================================
-- PROD étape 57 : ligne « Somme » toujours juste (commande fournisseur et arrivage)
--   La somme était faite dans le navigateur, qui ne connaît en entier que les lignes modifiées : total
--   d'une seule ligne, ou 0 après une duplication. Elle est maintenant calculée par le serveur (toutes les
--   lignes, à l'ouverture et à chaque ajout / modification / suppression / duplication de ligne).
-- Sources : livrables/ui/commande-achat-form.xml, livrables/ui/arrivage-form.xml. Après PROD_56.
-- À lancer depuis la racine du dépôt. Relançable. Pas de redémarrage nécessaire.
-- =====================================================================
\set fiche_achat `cat livrables/ui/commande-achat-form.xml`
SELECT set_config('lvme.fiche_achat', :'fiche_achat', false) IS NOT NULL AS commande_lue;
\set fiche_arrivage `cat livrables/ui/arrivage-form.xml`
SELECT set_config('lvme.fiche_arrivage', :'fiche_arrivage', false) IS NOT NULL AS arrivage_lu;

BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-commande-achat-attrs-somme', 'action-lvme-arrivage-attrs-somme');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-commande-achat-attrs-somme', 'action-attrs', 'com.axelor.apps.purchase.db.PurchaseOrder',
'<action-attrs name="action-lvme-commande-achat-attrs-somme" model="com.axelor.apps.purchase.db.PurchaseOrder">
  <attribute name="value" for="$sommeColis" expr="eval: (purchaseOrderLineList ?: []).sum(0.0) { it.nbColis ?: 0.0 }"/>
  <attribute name="value" for="$sommeQte" expr="eval: (purchaseOrderLineList ?: []).sum(0.0) { it.qty ?: 0.0 }"/>
  <attribute name="value" for="$sommePoids" expr="eval: (purchaseOrderLineList ?: []).sum(0.0) { it.poidsTotalNet ?: 0.0 }"/>
  <attribute name="value" for="$sommeMontant" expr="eval: (purchaseOrderLineList ?: []).sum(0.0) { it.exTaxTotal ?: 0.0 }"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-attrs-somme', 'action-attrs', 'com.axelor.apps.stock.db.StockMove',
'<action-attrs name="action-lvme-arrivage-attrs-somme" model="com.axelor.apps.stock.db.StockMove">
  <attribute name="value" for="$sommeColis" expr="eval: (stockMoveLineList ?: []).sum(0.0) { it.nbColis ?: 0.0 }"/>
  <attribute name="value" for="$sommeQte" expr="eval: (stockMoveLineList ?: []).sum(0.0) { (statusSelect == 3 ? it.realQty : it.qty) ?: 0.0 }"/>
  <attribute name="value" for="$sommePoids" expr="eval: (stockMoveLineList ?: []).sum(0.0) { it.poidsTotalNet ?: 0.0 }"/>
  <attribute name="value" for="$sommeMontant" expr="eval: (stockMoveLineList ?: []).sum(0.0) { (it.unitPriceUntaxed ?: 0.0) * ((statusSelect == 3 ? it.realQty : it.qty) ?: 0.0) }"/>
</action-attrs>', false, false, 0);

DO $$
BEGIN
  UPDATE meta_view SET xml = current_setting('lvme.fiche_achat'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND priority = 30 AND name = 'purchase-order-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'purchase-order-form (admin) introuvable : arrêt'; END IF;
  UPDATE meta_view SET xml = current_setting('lvme.fiche_arrivage'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-arrivage-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-arrivage-form introuvable : arrêt'; END IF;
END $$;

COMMIT;

SELECT name, position('attrs-somme' IN xml) > 0 AS somme_serveur
FROM meta_view WHERE module IS NULL AND (name = 'lvme-arrivage-form' OR (name = 'purchase-order-form' AND priority = 30));

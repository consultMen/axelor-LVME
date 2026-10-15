-- =====================================================================
-- PROD étape 56 : retours client sur le détail des lignes
--   - commande fournisseur, détail : colonne « Prix Revient » = prix de revient saisi sur la ligne
--     (« Prix de revient U.V(€) »), au lieu du prix de revient réel calculé (resté à 0)
--   - fiche Arrivage : bouton « Flottant -> A Embarquer » (comme GESCOM), à côté de « A Embarquer -> flottant » :
--     l'arrivage repasse « à embarquer » et ses lots FL redeviennent AE
-- Sources : livrables/ui/purchase-order-line-purchase-order-grid.xml, livrables/ui/arrivage-form.xml.
-- Après PROD_55. À lancer depuis la racine du dépôt. Relançable. Pas de redémarrage nécessaire.
-- =====================================================================
\set grille `cat livrables/ui/purchase-order-line-purchase-order-grid.xml`
SELECT set_config('lvme.grille', :'grille', false) IS NOT NULL AS grille_lue;
\set fiche_arrivage `cat livrables/ui/arrivage-form.xml`
SELECT set_config('lvme.fiche_arrivage', :'fiche_arrivage', false) IS NOT NULL AS arrivage_lu;

BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-arrivage-record-a-embarquer';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-record-a-embarquer', 'action-record', 'com.axelor.apps.stock.db.StockMove',
'<action-record name="action-lvme-arrivage-record-a-embarquer" model="com.axelor.apps.stock.db.StockMove">
  <field name="nature" expr="eval: ''EN_COURS_DE_PRODUCTION''"/>
</action-record>', false, false, 0);

DO $$
BEGIN
  UPDATE meta_view SET xml = current_setting('lvme.grille'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND priority = 30 AND name = 'purchase-order-line-purchase-order-grid';
  IF NOT FOUND THEN RAISE EXCEPTION 'grille des lignes de commande (admin) introuvable : arrêt'; END IF;
  UPDATE meta_view SET xml = current_setting('lvme.fiche_arrivage'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-arrivage-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-arrivage-form introuvable : arrêt'; END IF;
END $$;

COMMIT;

SELECT position('name="prKg"' IN xml) > 0 AS colonne_prix_revient
FROM meta_view WHERE module IS NULL AND priority = 30 AND name = 'purchase-order-line-purchase-order-grid';
SELECT position('lvmeAEmbarquerBtn' IN xml) > 0 AS bouton_retour_a_embarquer
FROM meta_view WHERE module IS NULL AND name = 'lvme-arrivage-form';

-- =====================================================================
-- PROD étape 18 : commande fournisseur — ses réceptions s'ouvrent sur la fiche « Arrivage » (GESCOM)
--   - la liste des réceptions en bas de la commande ouvre lvme-arrivage-form (au lieu du mouvement de stock standard)
--   - le bouton « Générer réception » fait de même (code Java, livré avec le redéploiement)
-- Modifie la fiche commande fournisseur admin (priorité 30) en place ; déjà intégré dans PROD_8 pour ses relances.
-- À lancer depuis la racine du dépôt, puis redémarrer Axelor. Relançable.
-- =====================================================================
BEGIN;

DELETE FROM meta_action WHERE name = 'action-lvme-purchase-order-arrivages' AND module IS NULL;
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom)
VALUES (nextval('meta_action_seq'), 0, now(), 'action-lvme-purchase-order-arrivages', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-purchase-order-arrivages" model="com.axelor.apps.stock.db.StockMove" title="Arrivages">
  <view name="stock-move-grid" type="grid"/>
  <view name="lvme-arrivage-form" type="form"/>
  <domain>:purchaseOrder MEMBER OF self.purchaseOrderSet</domain>
  <context name="purchaseOrder" expr="eval: __this__.id"/>
</action-view>', false, false);

UPDATE meta_view
SET xml = replace(xml, 'action="action-purchase-order-view-stock-moves"', 'action="action-lvme-purchase-order-arrivages"'),
    version = version + 1, updated_on = now()
WHERE name = 'purchase-order-form' AND module IS NULL AND priority = 30
  AND xml LIKE '%action="action-purchase-order-view-stock-moves"%';

COMMIT;

SELECT name, priority, (xml LIKE '%action-lvme-purchase-order-arrivages%') AS arrivages_ok
FROM meta_view WHERE name = 'purchase-order-form' AND module IS NULL;

-- =====================================================================
-- PROD étape 98 : « Interrogation Produit », comme GESCOM (diapo Interrogation Produit)
--   - écran : Article du + désignation, OU Lot n°, Lot Fournisseur n°, Origine, Sélection (Lots dispo / Lots soldés /
--     Les deux), Lancer la recherche, Fermer(F12) ; liste des lots par frigo (colonnes GESCOM, sommes en bas) ;
--     boutons Historique produit et Cdes client/produit (commandes clients en cours du produit)
--   - lignes d'arrivage : colonnes gencode et obs (Gencode / Obs de la ligne GESCOM, remplies par MIG_05)
--   - vue lvme_interrogation_produit (sql/lvme_interrogation_produit.sql), construite sur lvme_etat_stock_lot
--   - menu Stocks > Interrogation Produit
-- Prérequis : PROD_92 (Lots Vérifiés : sélection lvme.lots.selection.select), PROD_97. À lancer depuis la racine du
-- dépôt, AVANT de démarrer le serveur avec le nouveau code (modèle InterrogationProduit, champs gencode / obs des
-- lignes de mouvement). Sources : livrables/ui/lvme-interrogation-produit-form.xml, -grid.xml. Relançable.
-- =====================================================================
\set fInterro `cat livrables/ui/lvme-interrogation-produit-form.xml`
SELECT set_config('lvme.fInterro', :'fInterro', false) IS NOT NULL AS vue_lue;
\set gInterro `cat livrables/ui/lvme-interrogation-produit-grid.xml`
SELECT set_config('lvme.gInterro', :'gInterro', false) IS NOT NULL AS liste_lue;

BEGIN;

ALTER TABLE stock_stock_move_line ADD COLUMN IF NOT EXISTS gencode varchar(255);
ALTER TABLE stock_stock_move_line ADD COLUMN IF NOT EXISTS obs varchar(255);
\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_interrogation_produit.sql

UPDATE meta_menu SET action = NULL WHERE action IN (SELECT id FROM meta_action WHERE module IS NULL
  AND name = 'action-lvme-interrogation-produit-open');
DELETE FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-interrogation-produit-%';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-interrogation-produit-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-interrogation-produit-open" title="Interrogation Produit" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-interrogation-produit-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-interrogation-produit-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-interrogation-produit-defaults">
  <attribute name="value" for="$selectionLots" expr="eval: 1"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-interrogation-produit-designation', 'action-attrs', NULL,
'<action-attrs name="action-lvme-interrogation-produit-designation">
  <attribute name="value" for="$designation" expr="eval: produit?.id ? __repo__(com.axelor.apps.base.db.Product).find(produit.id as Long)?.name : null"/>
  <attribute name="refresh" for="lotsDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-interrogation-produit-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-interrogation-produit-refresh">
  <attribute name="refresh" for="lotsDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-interrogation-produit-dashlet', 'action-view',
 'com.axelor.apps.supplychain.db.InterrogationProduit',
'<action-view name="action-lvme-interrogation-produit-dashlet" title="Lots" model="com.axelor.apps.supplychain.db.InterrogationProduit">
  <view type="grid" name="lvme-interrogation-produit-grid"/>
  <view-param name="popup" value="true"/>
  <domain>(:_prod = 0 OR self.product.id = :_prod)
    AND LOWER(COALESCE(self.lotNumber, &apos;&apos;)) LIKE :_lot
    AND LOWER(COALESCE(self.lotFournisseur, &apos;&apos;)) LIKE :_lotf
    AND (:_orig = &apos;&apos; OR self.origine = :_orig)
    AND ((:_sel = 1 AND self.stockQty &gt; 0) OR (:_sel = 2 AND self.stockQty &lt;= 0) OR :_sel = 3)</domain>
  <context name="_prod" expr="eval: (produit?.id ?: 0) as Long"/>
  <context name="_lot" expr="eval: numeroLot ? &apos;%&apos; + numeroLot.toString().trim().toLowerCase() + &apos;%&apos; : &apos;%&apos;"/>
  <context name="_lotf" expr="eval: lotFournisseur ? &apos;%&apos; + lotFournisseur.toString().trim().toLowerCase() + &apos;%&apos; : &apos;%&apos;"/>
  <context name="_orig" expr="eval: origine ? origine.toString() : &apos;&apos;"/>
  <context name="_sel" expr="eval: (selectionLots ?: 1) as Integer"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-interrogation-produit-historique', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-interrogation-produit-historique" title="Historique Produit" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-historique-produit-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_produitId" expr="eval: produit?.id"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-interrogation-produit-cdes', 'action-view',
 'com.axelor.apps.sale.db.SaleOrderLine',
'<action-view name="action-lvme-interrogation-produit-cdes" title="Cdes client / produit" model="com.axelor.apps.sale.db.SaleOrderLine">
  <view type="grid" name="lvme-cdes-client-lignes-grid"/>
  <view type="form" name="sale-order-line-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="forceReadonly" value="true"/>
  <domain>self.saleOrder.template = false AND self.saleOrder.statusSelect IN (1, 2, 3)
    AND (:_prod = 0 OR self.product.id = :_prod)</domain>
  <context name="_prod" expr="eval: (produit?.id ?: 0) as Long"/>
</action-view>', false, false, 0);

DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-interrogation-produit-form', 'lvme-interrogation-produit-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-interrogation-produit-form', 'Interrogation Produit', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fInterro'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-interrogation-produit-grid', 'Interrogation Produit', 'grid',
 'com.axelor.apps.supplychain.db.InterrogationProduit', 20, current_setting('lvme.gInterro'), false, false);

DELETE FROM meta_menu WHERE name = 'lvme-menu-interrogation-produit';
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, hidden, left_menu, mobile_menu, priority)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-interrogation-produit', 'Interrogation Produit',
  (SELECT id FROM meta_menu WHERE name = 'stock-root' ORDER BY id LIMIT 1),
  (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-interrogation-produit-open'),
  coalesce((SELECT order_seq + 1 FROM meta_menu WHERE name = 'lvme-menu-historique-produit'), 53), false, true, false, 0;

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND name LIKE 'lvme-interrogation-produit-%') AS vues,
       (SELECT count(*) FROM meta_menu WHERE name = 'lvme-menu-interrogation-produit' AND action IS NOT NULL) AS menu,
       (SELECT count(*) FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-interrogation-produit-%') AS actions,
       (SELECT count(*) FROM lvme_interrogation_produit WHERE stock_qty > 0) AS lots_en_stock;

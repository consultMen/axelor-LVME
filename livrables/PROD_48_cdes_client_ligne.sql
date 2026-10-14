-- =====================================================================
-- PROD étape 48 : fenêtres de ligne comme GESCOM « Lignes Arrivages »
--   - boutons « Cdes client / Lot » et « Cdes client / produit » sur la Ligne d'arrivage et la Ligne de
--     commande d'achat : ouvrent l'écran « Commandes Clients » GESCOM (période, client, produit,
--     commercial, n° lot + liste des lignes de commandes clients), rempli avec le lot ou l'article de la ligne
--   - fond bleu GESCOM sur les deux fenêtres de ligne (feuille de style css/lvme.css du code de ce lot)
--   Liste : toutes les commandes clients sauf annulées, depuis le 01/01/2000 par défaut (comme GESCOM).
-- Avec le code de ce lot (champs N° Lot / N° Arrivage des lignes de commande client, css).
-- Prérequis : PROD_42, PROD_45, PROD_46. À lancer depuis la racine du dépôt, avant le redémarrage. Relançable.
-- =====================================================================
\set grille `cat livrables/ui/cdes-client-lignes-grid.xml`
SELECT set_config('lvme.grille', :'grille', false) IS NOT NULL AS grille_lue;
\set fiche `cat livrables/ui/cdes-client-lignes-form.xml`
SELECT set_config('lvme.fiche', :'fiche', false) IS NOT NULL AS fiche_lue;
\set ligne `cat livrables/ui/arrivage-line-form.xml`
SELECT set_config('lvme.ligne', :'ligne', false) IS NOT NULL AS ligne_arrivage_lue;
\set ligne_achat `cat livrables/ui/commande-achat-line-form.xml`
SELECT set_config('lvme.ligne_achat', :'ligne_achat', false) IS NOT NULL AS ligne_achat_lue;

BEGIN;

-- ---------- écran « Commandes Clients » ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-cdes-client-lignes-grid', 'lvme-cdes-client-lignes-form');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-cdes-client-lignes-grid', 'Commandes Clients', 'grid',
 'com.axelor.apps.sale.db.SaleOrderLine', 20, current_setting('lvme.grille'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-cdes-client-lignes-form', 'Commandes Clients', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fiche'), false, false);

DELETE FROM meta_action WHERE module IS NULL AND name IN (
  'action-lvme-cdes-client-lignes-dashlet', 'action-lvme-cdes-client-lignes-refresh',
  'action-lvme-cdes-client-lignes-defaults', 'action-lvme-cdes-client-lignes-group-onnew',
  'action-lvme-ligne-cdes-client-lot', 'action-lvme-ligne-cdes-client-produit');

INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cdes-client-lignes-dashlet', 'action-view', 'com.axelor.apps.sale.db.SaleOrderLine',
'<action-view name="action-lvme-cdes-client-lignes-dashlet" title="Commandes clients" model="com.axelor.apps.sale.db.SaleOrderLine">
  <view type="grid" name="lvme-cdes-client-lignes-grid"/>
  <view type="form" name="sale-order-line-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="forceReadonly" value="true"/>
  <domain>self.saleOrder.template = false AND self.saleOrder.statusSelect != 5 AND self.product IS NOT NULL
    AND (:_produit = 0 OR self.product.id = :_produit)
    AND (:_client = 0 OR self.saleOrder.clientPartner.id = :_client)
    AND (:_commercial = 0 OR self.saleOrder.commercial.id = :_commercial)
    AND (:_lot = 0 OR self.id IN (SELECT l.saleOrderLine.id FROM SaleOrderLineLot l WHERE l.trackingNumber.id = :_lot))
    AND COALESCE(self.saleOrder.orderDate, self.saleOrder.creationDate) BETWEEN :_dateDu AND :_dateAu</domain>
  <context name="_produit" expr="eval: (produit?.id ?: 0) as Long"/>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_commercial" expr="eval: (commercialFiltre?.id ?: 0) as Long"/>
  <context name="_lot" expr="eval: (lot?.id ?: 0) as Long"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cdes-client-lignes-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cdes-client-lignes-refresh">
  <attribute name="refresh" for="lignesDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cdes-client-lignes-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cdes-client-lignes-defaults">
  <attribute name="value" for="$dateDu" expr="eval: java.time.LocalDate.of(2000, 1, 1)"/>
  <attribute name="value" for="$dateAu" expr="eval: __date__"/>
  <attribute name="value" for="$produit" expr="eval: _produitId ? __repo__(com.axelor.apps.base.db.Product).find(_produitId as Long) : null"/>
  <attribute name="value" for="$lot" expr="eval: _lotId ? __repo__(com.axelor.apps.stock.db.TrackingNumber).find(_lotId as Long) : null"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cdes-client-lignes-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-cdes-client-lignes-group-onnew">
  <action name="action-lvme-cdes-client-lignes-defaults"/>
  <action name="action-lvme-cdes-client-lignes-refresh"/>
</action-group>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cdes-client-lot', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-ligne-cdes-client-lot" title="Commandes Clients" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-cdes-client-lignes-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_lotId" expr="eval: trackingNumber?.id"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cdes-client-produit', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-ligne-cdes-client-produit" title="Commandes Clients" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-cdes-client-lignes-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_produitId" expr="eval: product?.id"/>
</action-view>', false, false, 0);

-- ---------- fenêtres de ligne (boutons + fond bleu) ----------
DO $$
BEGIN
  UPDATE meta_view SET xml = current_setting('lvme.ligne'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-arrivage-line-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-arrivage-line-form introuvable (PROD_42 passé ?) : arrêt'; END IF;
  UPDATE meta_view SET xml = current_setting('lvme.ligne_achat'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-commande-achat-line-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-commande-achat-line-form introuvable (PROD_45 passé ?) : arrêt'; END IF;
END $$;

COMMIT;

SELECT name, position('lvmeCdesClientLotBtn' IN xml) > 0 AS boutons_cdes_client
FROM meta_view WHERE module IS NULL AND name IN ('lvme-arrivage-line-form', 'lvme-commande-achat-line-form');
SELECT count(*) = 6 AS actions_ok FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-%cdes-client%';

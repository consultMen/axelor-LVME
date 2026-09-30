-- =====================================================================
-- PROD étape 10 : écrans de recherche GESCOM pour les listes
--   - Achats > Commandes fournisseurs : « liste des achats fournisseurs » (diapo 23)
--   - Ventes > Commandes clients      : « Listes Commandes Clients » (diapo 29)
--   + totaux Nb Colis / Nb unités / Tonnage des commandes fournisseurs existantes (somme des lignes,
--     même calcul que le code).
-- Le script crée lui-même les colonnes des totaux (déclarées aussi dans le code).
-- À lancer depuis la racine du dépôt, puis redémarrer Axelor. Relançable. Une seule transaction.
-- =====================================================================
\set achatForm `cat livrables/ui/achat-search-form.xml`
\set achatGrid `cat livrables/ui/achat-grid.xml`
\set cdeForm `cat livrables/ui/commande-client-search-form.xml`
\set cdeGrid `cat livrables/ui/commande-client-grid.xml`
SELECT set_config('lvme.achatForm', :'achatForm', false), set_config('lvme.achatGrid', :'achatGrid', false),
       set_config('lvme.cdeForm', :'cdeForm', false), set_config('lvme.cdeGrid', :'cdeGrid', false);

BEGIN;

-- ---------- Totaux des commandes fournisseurs ----------
ALTER TABLE purchase_purchase_order ADD COLUMN IF NOT EXISTS nb_colis_total numeric(20,3);
ALTER TABLE purchase_purchase_order ADD COLUMN IF NOT EXISTS qty_total numeric(20,3);
ALTER TABLE purchase_purchase_order ADD COLUMN IF NOT EXISTS poids_total numeric(20,3);
UPDATE purchase_purchase_order po
SET nb_colis_total = t.colis, qty_total = t.qty, poids_total = t.poids
FROM (SELECT purchase_order, SUM(COALESCE(nb_colis, 0)) AS colis, SUM(COALESCE(qty, 0)) AS qty,
             SUM(COALESCE(poids_total_net, 0)) AS poids
      FROM purchase_purchase_order_line WHERE COALESCE(is_title_line, false) = false
      GROUP BY purchase_order) t
WHERE t.purchase_order = po.id;

-- ---------- Listes de choix des filtres ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, v.name, 0, true
FROM (VALUES ('lvme.achat.nature.select'), ('lvme.commande.client.etat.select')) AS v(name)
WHERE NOT EXISTS (SELECT 1 FROM meta_select s WHERE s.name = v.name);
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('lvme.achat.nature.select', '1', 'Arrivages réels', 1),
             ('lvme.achat.nature.select', '2', 'Arrivages flottants', 2),
             ('lvme.achat.nature.select', '3', 'Tous', 3),
             ('lvme.commande.client.etat.select', '1', 'Commandes en cours', 1),
             ('lvme.commande.client.etat.select', '2', 'Commandes soldées', 2),
             ('lvme.commande.client.etat.select', '3', 'Toutes commandes', 3)) AS v(sel, value, title, seq)
  ON v.sel = s.name
WHERE NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- ---------- Actions ----------
UPDATE meta_menu SET action = NULL WHERE name IN ('sc-root-purchase-orders', 'sc-root-sale-orders')
  AND action IN (SELECT id FROM meta_action WHERE name IN ('action-lvme-achat-open', 'action-lvme-cde-client-open') AND module IS NULL);
DELETE FROM meta_action WHERE module IS NULL AND name IN (
  'action-lvme-achat-open', 'action-lvme-achat-dashlet', 'action-lvme-achat-refresh', 'action-lvme-achat-defaults',
  'action-lvme-achat-periode-date', 'action-lvme-achat-periode-arrivee', 'action-lvme-achat-new',
  'action-lvme-cde-client-open', 'action-lvme-cde-client-dashlet', 'action-lvme-cde-client-refresh',
  'action-lvme-cde-client-defaults', 'action-lvme-cde-client-periode-date', 'action-lvme-cde-client-periode-livraison',
  'action-lvme-cde-client-new');

INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-achat-open" title="Commandes fournisseurs" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-achat-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-dashlet', 'action-view', 'com.axelor.apps.purchase.db.PurchaseOrder',
'<action-view name="action-lvme-achat-dashlet" title="Achats fournisseurs" model="com.axelor.apps.purchase.db.PurchaseOrder">
  <view type="grid" name="lvme-achat-grid"/>
  <view type="form" name="purchase-order-form"/>
  <domain>self.statusSelect IN (3, 4)
    AND (:_dateFiltre = false OR self.orderDate BETWEEN :_dateDu AND :_dateAu)
    AND (:_arrFiltre = false OR self.estimatedReceiptDate BETWEEN :_arrDu AND :_arrAu)
    AND (:_fouDu = '''' OR self.supplierPartner.name &gt;= :_fouDu) AND (:_fouAu = '''' OR self.supplierPartner.name &lt;= :_fouAu)
    AND (:_transport = 0 OR self.shipmentMode.id = :_transport)
    AND ((:_nature = 1 AND self.receiptState = 3) OR (:_nature = 2 AND self.receiptState != 3) OR :_nature = 3)</domain>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_arrFiltre" expr="eval: arriveeDu != null || arriveeAu != null"/>
  <context name="_arrDu" expr="eval: arriveeDu ? java.time.LocalDate.parse(arriveeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_arrAu" expr="eval: arriveeAu ? java.time.LocalDate.parse(arriveeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_fouDu" expr="eval: fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.name ?: '''') : ''''"/>
  <context name="_fouAu" expr="eval: fournisseurAu?.id ? (__repo__(Partner).find(fournisseurAu.id as Long)?.name ?: '''') : (fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.name ?: '''') : '''')"/>
  <context name="_transport" expr="eval: (typeTransport?.id ?: 0) as Long"/>
  <context name="_nature" expr="eval: (natureAchat ?: 3) as Integer"/>
  <context name="_internalUser" expr="eval: __user__.id"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-achat-refresh">
  <attribute name="refresh" for="achatsDashlet" expr="eval: true"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-achat-defaults">
  <attribute name="value" for="$natureAchat" expr="eval: 3"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-periode-date', 'action-attrs', NULL,
'<action-attrs name="action-lvme-achat-periode-date">
  <attribute name="value" for="$dateDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][datePeriode as Integer]"/>
  <attribute name="value" for="$dateAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][datePeriode as Integer]"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-periode-arrivee', 'action-attrs', NULL,
'<action-attrs name="action-lvme-achat-periode-arrivee">
  <attribute name="value" for="$arriveeDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][arriveePeriode as Integer]"/>
  <attribute name="value" for="$arriveeAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][arriveePeriode as Integer]"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-new', 'action-view', 'com.axelor.apps.purchase.db.PurchaseOrder',
'<action-view name="action-lvme-achat-new" title="Commande fournisseur" model="com.axelor.apps.purchase.db.PurchaseOrder">
  <view type="form" name="purchase-order-form"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_internalUser" expr="eval: __user__.id"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-cde-client-open" title="Commandes clients" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-commande-client-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-dashlet', 'action-view', 'com.axelor.apps.sale.db.SaleOrder',
'<action-view name="action-lvme-cde-client-dashlet" title="Commandes clients" model="com.axelor.apps.sale.db.SaleOrder">
  <view type="grid" name="lvme-commande-client-grid"/>
  <view type="form" name="sale-order-form"/>
  <domain>self.template = false AND self.statusSelect IN (3, 4)
    AND ((:_etat = 1 AND self.statusSelect = 3 AND self.deliveryState != 3)
         OR (:_etat = 2 AND (self.statusSelect = 4 OR self.deliveryState = 3)) OR :_etat = 3)
    AND (:_client = 0 OR self.clientPartner.id = :_client)
    AND (:_commercial = 0 OR self.commercial.id = :_commercial)
    AND (:_dateFiltre = false OR COALESCE(self.orderDate, self.creationDate) BETWEEN :_dateDu AND :_dateAu)
    AND (:_livFiltre = false OR self.estimatedDeliveryDate BETWEEN :_livDu AND :_livAu)</domain>
  <context name="_etat" expr="eval: (etatCommande ?: 1) as Integer"/>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_commercial" expr="eval: (commercialFiltre?.id ?: 0) as Long"/>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_livFiltre" expr="eval: livraisonDu != null || livraisonAu != null"/>
  <context name="_livDu" expr="eval: livraisonDu ? java.time.LocalDate.parse(livraisonDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_livAu" expr="eval: livraisonAu ? java.time.LocalDate.parse(livraisonAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_internalUser" expr="eval: __user__.id"/>
  <context name="_template" expr="eval: false"/>
  <context name="todayDate" expr="eval: __config__.date"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-refresh">
  <attribute name="refresh" for="commandesDashlet" expr="eval: true"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-defaults">
  <attribute name="value" for="$etatCommande" expr="eval: 1"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-periode-date', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-periode-date">
  <attribute name="value" for="$dateDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][datePeriode as Integer]"/>
  <attribute name="value" for="$dateAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][datePeriode as Integer]"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-periode-livraison', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-periode-livraison">
  <attribute name="value" for="$livraisonDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][livraisonPeriode as Integer]"/>
  <attribute name="value" for="$livraisonAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][livraisonPeriode as Integer]"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-new', 'action-view', 'com.axelor.apps.sale.db.SaleOrder',
'<action-view name="action-lvme-cde-client-new" title="Commande client" model="com.axelor.apps.sale.db.SaleOrder">
  <view type="form" name="sale-order-form"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_internalUser" expr="eval: __user__.id"/>
  <context name="_template" expr="eval: false"/>
  <context name="todayDate" expr="eval: __config__.date"/>
</action-view>', false, false);

-- ---------- Vues ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-achat-search-form', 'lvme-achat-grid',
  'lvme-commande-client-search-form', 'lvme-commande-client-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-achat-search-form', 'liste des achats fournisseurs', 'form', 'com.axelor.utils.db.Wizard', 20,
 current_setting('lvme.achatForm'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-achat-grid', 'Achats fournisseurs', 'grid', 'com.axelor.apps.purchase.db.PurchaseOrder', 20,
 current_setting('lvme.achatGrid'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-commande-client-search-form', 'Listes Commandes Clients', 'form', 'com.axelor.utils.db.Wizard', 20,
 current_setting('lvme.cdeForm'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-commande-client-grid', 'Commandes clients', 'grid', 'com.axelor.apps.sale.db.SaleOrder', 20,
 current_setting('lvme.cdeGrid'), false, false);

-- ---------- Menus ----------
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE name = 'action-lvme-achat-open' AND module IS NULL)
WHERE name = 'sc-root-purchase-orders';
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE name = 'action-lvme-cde-client-open' AND module IS NULL)
WHERE name = 'sc-root-sale-orders';

COMMIT;

SELECT m.name, m.title, a.name AS action FROM meta_menu m LEFT JOIN meta_action a ON a.id = m.action
WHERE m.name IN ('sc-root-purchase-orders', 'sc-root-sale-orders');

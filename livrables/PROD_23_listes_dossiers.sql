-- =====================================================================
-- PROD étape 23 : REC-012 écran GESCOM « Listes Dossiers » (Ventes > Listes Dossiers)
--   - Type doc BL / BL retour : BL clients et retours clients, B.L. non facturés / facturés,
--     + filtre Transporteur et colonnes Transporteur / Point de livraison (vue transporteur du cahier)
--     + case « Détail produits » : une ligne par produit livré (colis, poids, quantité)
--   - Type doc Facture / Avoir : factures et avoirs clients validés ou ventilés
--   - boutons Quitter, Nouveau BL, Nouveau retour, Suppression (BL brouillons, suppression standard)
-- Les colonnes Date, Facture N°, Type, Ref Cde Client (BL) et Pré-facture N° (facture) sont des champs
-- calculés déclarés dans le code (StockMove / Invoice) : déployer le code avec ce script.
-- À lancer depuis la racine du dépôt, puis redémarrer Axelor. Relançable. Une seule transaction.
-- =====================================================================
\set form `cat livrables/ui/dossiers-search-form.xml`
\set blGrid `cat livrables/ui/dossiers-bl-grid.xml`
\set facGrid `cat livrables/ui/dossiers-facture-grid.xml`
\set ligGrid `cat livrables/ui/dossiers-ligne-grid.xml`
SELECT set_config('lvme.form', :'form', false), set_config('lvme.blGrid', :'blGrid', false),
       set_config('lvme.facGrid', :'facGrid', false), set_config('lvme.ligGrid', :'ligGrid', false);

BEGIN;

-- ---------- Listes de choix ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, v.name, 0, true
FROM (VALUES ('lvme.dossier.type.select'), ('lvme.dossier.facture.select')) AS v(name)
WHERE NOT EXISTS (SELECT 1 FROM meta_select s WHERE s.name = v.name);
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('lvme.dossier.type.select', '1', 'BL / BL retour', 1),
             ('lvme.dossier.type.select', '2', 'Facture / Avoir', 2),
             ('lvme.dossier.facture.select', '1', 'B.L. non facturés', 1),
             ('lvme.dossier.facture.select', '2', 'B.L. facturés', 2)) AS v(sel, value, title, seq)
  ON v.sel = s.name
WHERE NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- ---------- Actions ----------
UPDATE meta_menu SET action = NULL
WHERE action IN (SELECT id FROM meta_action WHERE name = 'action-lvme-dossiers-open' AND module IS NULL);
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-dossiers-open',
  'action-lvme-dossiers-bl-dashlet', 'action-lvme-dossiers-lignes-dashlet', 'action-lvme-dossiers-factures-dashlet',
  'action-lvme-dossiers-refresh', 'action-lvme-dossiers-defaults', 'action-lvme-dossiers-group-onnew',
  'action-lvme-dossiers-periode', 'action-lvme-dossiers-group-periode',
  'action-lvme-dossiers-nouveau-bl', 'action-lvme-dossiers-nouveau-retour', 'action-lvme-dossiers-suppression');

INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-dossiers-open" title="Listes Dossiers" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-dossiers-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-bl-dashlet', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-dossiers-bl-dashlet" title="Bon de livraison" model="com.axelor.apps.stock.db.StockMove">
  <view type="grid" name="lvme-dossiers-bl-grid"/>
  <view type="form" name="stock-move-form"/>
  <view-param name="forceTitle" value="true"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <domain>self.statusSelect IN (2, 3)
    AND ((self.typeSelect = 2 AND self.isReversion = false) OR (self.typeSelect = 3 AND self.isReversion = true))
    AND ((:_num != ''%'' AND LOWER(self.stockMoveSeq) LIKE :_num)
      OR (:_num = ''%''
        AND (:_client = 0 OR self.partner.id = :_client)
        AND (:_transporteur = 0 OR self.carrierPartner.id = :_transporteur)
        AND (:_dateFiltre = false OR self.lvmeDateLivraison BETWEEN :_du AND :_au)
        AND ((:_facture = 1 AND self.lvmeEstFacture = false) OR (:_facture = 2 AND self.lvmeEstFacture = true))))</domain>
  <context name="_num" expr="eval: numero ? ''%'' + numero.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_transporteur" expr="eval: (transporteur?.id ?: 0) as Long"/>
  <context name="_facture" expr="eval: (blFacture ?: 1) as Integer"/>
  <context name="_dateFiltre" expr="eval: livraisonDu != null || livraisonAu != null"/>
  <context name="_du" expr="eval: livraisonDu ? java.time.LocalDate.parse(livraisonDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_au" expr="eval: livraisonAu ? java.time.LocalDate.parse(livraisonAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-lignes-dashlet', 'action-view', 'com.axelor.apps.stock.db.StockMoveLine',
'<action-view name="action-lvme-dossiers-lignes-dashlet" title="Détail produits des BL" model="com.axelor.apps.stock.db.StockMoveLine">
  <view type="grid" name="lvme-dossiers-ligne-grid"/>
  <view type="form" name="stock-move-line-form"/>
  <view-param name="popup" value="true"/>
  <domain>self.stockMove.statusSelect IN (2, 3)
    AND ((self.stockMove.typeSelect = 2 AND self.stockMove.isReversion = false) OR (self.stockMove.typeSelect = 3 AND self.stockMove.isReversion = true))
    AND ((:_num != ''%'' AND LOWER(self.stockMove.stockMoveSeq) LIKE :_num)
      OR (:_num = ''%''
        AND (:_client = 0 OR self.stockMove.partner.id = :_client)
        AND (:_transporteur = 0 OR self.stockMove.carrierPartner.id = :_transporteur)
        AND (:_dateFiltre = false OR self.stockMove.lvmeDateLivraison BETWEEN :_du AND :_au)
        AND ((:_facture = 1 AND self.stockMove.lvmeEstFacture = false) OR (:_facture = 2 AND self.stockMove.lvmeEstFacture = true))))</domain>
  <context name="_num" expr="eval: numero ? ''%'' + numero.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_transporteur" expr="eval: (transporteur?.id ?: 0) as Long"/>
  <context name="_facture" expr="eval: (blFacture ?: 1) as Integer"/>
  <context name="_dateFiltre" expr="eval: livraisonDu != null || livraisonAu != null"/>
  <context name="_du" expr="eval: livraisonDu ? java.time.LocalDate.parse(livraisonDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_au" expr="eval: livraisonAu ? java.time.LocalDate.parse(livraisonAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-factures-dashlet', 'action-view', 'com.axelor.apps.account.db.Invoice',
'<action-view name="action-lvme-dossiers-factures-dashlet" title="Facture / Avoir" model="com.axelor.apps.account.db.Invoice">
  <view type="grid" name="lvme-dossiers-facture-grid"/>
  <view type="form" name="invoice-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <domain>self.operationTypeSelect IN (3, 4) AND self.statusSelect IN (2, 3)
    AND ((:_num != ''%'' AND LOWER(self.invoiceId) LIKE :_num)
      OR (:_num = ''%''
        AND (:_client = 0 OR self.partner.id = :_client)
        AND (:_dateFiltre = false OR self.invoiceDate BETWEEN :_du AND :_au)))</domain>
  <context name="_num" expr="eval: numero ? ''%'' + numero.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_dateFiltre" expr="eval: livraisonDu != null || livraisonAu != null"/>
  <context name="_du" expr="eval: livraisonDu ? java.time.LocalDate.parse(livraisonDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_au" expr="eval: livraisonAu ? java.time.LocalDate.parse(livraisonAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_operationTypeSelect" expr="eval: 3"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-dossiers-refresh">
  <attribute name="refresh" for="blDashlet" expr="eval: true"/>
  <attribute name="refresh" for="lignesDashlet" expr="eval: true"/>
  <attribute name="refresh" for="facturesDashlet" expr="eval: true"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-dossiers-defaults">
  <attribute name="value" for="$typeDoc" expr="eval: 1"/>
  <attribute name="value" for="$blFacture" expr="eval: 1"/>
  <attribute name="value" for="$livraisonDu" expr="eval: __date__.minusMonths(1)"/>
  <attribute name="value" for="$livraisonAu" expr="eval: __date__"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-dossiers-group-onnew">
  <action name="action-lvme-dossiers-defaults"/>
  <action name="action-lvme-dossiers-refresh"/>
</action-group>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-periode', 'action-attrs', NULL,
'<action-attrs name="action-lvme-dossiers-periode">
  <attribute name="value" for="$livraisonDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][livraisonPeriode as Integer]"/>
  <attribute name="value" for="$livraisonAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][livraisonPeriode as Integer]"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-group-periode', 'action-group', NULL,
'<action-group name="action-lvme-dossiers-group-periode">
  <action name="action-lvme-dossiers-periode"/>
  <action name="action-lvme-dossiers-refresh"/>
</action-group>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-nouveau-bl', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-dossiers-nouveau-bl" title="Nouveau BL" model="com.axelor.apps.stock.db.StockMove">
  <view type="form" name="stock-move-form"/>
  <view-param name="forceEdit" value="true"/>
  <view-param name="forceTitle" value="true"/>
  <context name="_typeSelect" expr="eval: __repo__(StockMove).TYPE_OUTGOING"/>
  <context name="_isReversion" expr="eval: false"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-nouveau-retour', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-dossiers-nouveau-retour" title="Nouveau retour" model="com.axelor.apps.stock.db.StockMove">
  <view type="form" name="stock-move-form"/>
  <view-param name="forceEdit" value="true"/>
  <view-param name="forceTitle" value="true"/>
  <context name="_typeSelect" expr="eval: __repo__(StockMove).TYPE_INCOMING"/>
  <context name="_isReversion" expr="eval: true"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-dossiers-suppression', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-dossiers-suppression" title="Suppression (BL brouillons)" model="com.axelor.apps.stock.db.StockMove">
  <view type="grid" name="stock-move-out-grid"/>
  <view type="form" name="stock-move-form"/>
  <domain>self.statusSelect = 1
    AND ((self.typeSelect = 2 AND self.isReversion = false) OR (self.typeSelect = 3 AND self.isReversion = true))</domain>
</action-view>', false, false);

-- ---------- Vues ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-dossiers-search-form', 'lvme-dossiers-bl-grid',
  'lvme-dossiers-facture-grid', 'lvme-dossiers-ligne-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-dossiers-search-form', 'Listes Dossiers', 'form', 'com.axelor.utils.db.Wizard', 20,
 current_setting('lvme.form'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-dossiers-bl-grid', 'BL / BL retour', 'grid', 'com.axelor.apps.stock.db.StockMove', 20,
 current_setting('lvme.blGrid'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-dossiers-facture-grid', 'Facture / Avoir', 'grid', 'com.axelor.apps.account.db.Invoice', 20,
 current_setting('lvme.facGrid'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-dossiers-ligne-grid', 'Détail produits des BL', 'grid', 'com.axelor.apps.stock.db.StockMoveLine', 20,
 current_setting('lvme.ligGrid'), false, false);

-- ---------- Menu Ventes > Listes Dossiers ----------
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, priority, hidden, left_menu, mobile_menu, tag_count)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-listes-dossiers', 'Listes Dossiers',
       (SELECT id FROM meta_menu WHERE name = 'sc-root-sale' ORDER BY priority DESC LIMIT 1), NULL, 650, 0, false, true, false, false
WHERE NOT EXISTS (SELECT 1 FROM meta_menu WHERE name = 'lvme-menu-listes-dossiers');
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE name = 'action-lvme-dossiers-open' AND module IS NULL)
WHERE name = 'lvme-menu-listes-dossiers';

COMMIT;

SELECT m.name, m.title, p.name AS parent, a.name AS action FROM meta_menu m
LEFT JOIN meta_menu p ON p.id = m.parent LEFT JOIN meta_action a ON a.id = m.action
WHERE m.name = 'lvme-menu-listes-dossiers';

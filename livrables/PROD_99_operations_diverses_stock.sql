-- =====================================================================
-- PROD étape 99 : « Opérations Diverses sur les Stocks / Lots », comme GESCOM
--   - écran : Référence Produit ou Lot n°, Entrées du / au, Sélection, Afficher Lots / Fermer ; liste des lots
--     (N° Lot … Poids Dispo, sommes) ; en bas N° Lot, Type Mouvement, Libellé Mvts, Entrée/Sortie, Date OD, Unité,
--     Poids (Kg), Valider / Annuler
--   - types de mouvement = types d'OD de GESCOM (table_base STKMVT, sens E / S hors achats et ventes)
--   - Valider : mouvement de stock interne réalisé à la date OD entre le frigo du lot et l'emplacement virtuel
--     « OPERATIONS DIVERSES » créé ici ; stock du lot mis à jour, négatif accepté comme GESCOM
--   - menu Stocks > Opérations Diverses sur les Stocks / Lots
-- Prérequis : PROD_92 (actions Lots Vérifiés), code avec LvmeOperationDiverseController (recompiler). À lancer
-- depuis la racine du dépôt. Sources : livrables/ui/lvme-od-stock-form.xml, -grid.xml. Relançable.
-- =====================================================================
\set fOd `cat livrables/ui/lvme-od-stock-form.xml`
SELECT set_config('lvme.fOd', :'fOd', false) IS NOT NULL AS vue_lue;
\set gOd `cat livrables/ui/lvme-od-stock-grid.xml`
SELECT set_config('lvme.gOd', :'gOd', false) IS NOT NULL AS liste_lue;

BEGIN;

-- emplacement virtuel des opérations diverses
INSERT INTO stock_stock_location (id, version, created_on, import_id, import_origin, name, company, type_select,
  is_valued, usable_on_purchase_order, usable_on_sale_order, usable_on_production, direct_order_location,
  include_out_of_stock, include_virtual_sub_location, is_not_in_calcul_stock, is_not_in_mrp, is_outsourcing_location,
  is_workshop, archived)
SELECT nextval('stock_stock_location_seq'), 0, now(), 'LVME-OD', 'LVME', 'OPERATIONS DIVERSES',
  (SELECT id FROM base_company ORDER BY id LIMIT 1), 3, false, false, false, false, false, false, false, true, true,
  false, false, false
WHERE NOT EXISTS (SELECT 1 FROM stock_stock_location WHERE import_id = 'LVME-OD');

-- types de mouvement (GESCOM STKMVT)
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.od.type.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.od.type.select');
DELETE FROM meta_select_item WHERE select_id = (SELECT id FROM meta_select WHERE name = 'lvme.od.type.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, (SELECT id FROM meta_select WHERE name = 'lvme.od.type.select'), v, t, o
FROM (VALUES ('ED', 'ENTREE DIVERSE', 1), ('RE', 'REGULARISATION ENTREE', 2), ('BU', 'PRELEVEMENT BUREAU', 3),
  ('CA', 'PRODUIT ABIME / CASSE', 4), ('DD', 'DLC DEPASSEE', 5), ('EC', 'ECHANTILLON', 6),
  ('JV', 'JET A LA VOIRIE', 7), ('LA', 'LABORATOIRE', 8), ('PE', 'PERTE', 9), ('PR', 'PRELEVEMENT', 10),
  ('RF', 'RETOUR FOURNISSEUR', 11), ('RS', 'REGULARISATION SORTIE', 12), ('VD', 'VIDANGE', 13)) x(v, t, o);

UPDATE meta_menu SET action = NULL WHERE action IN (SELECT id FROM meta_action WHERE module IS NULL
  AND name = 'action-lvme-od-stock-open');
DELETE FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-od-stock-%';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-od-stock-open" title="Opérations Diverses" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-od-stock-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-od-stock-defaults">
  <attribute name="value" for="$selectionLots" expr="eval: 1"/>
  <attribute name="value" for="$dateOd" expr="eval: __date__"/>
  <attribute name="value" for="$poidsOd" expr="eval: 0"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-od-stock-refresh">
  <attribute name="refresh" for="lotsDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-dashlet', 'action-view',
 'com.axelor.apps.supplychain.db.EtatStockLot',
'<action-view name="action-lvme-od-stock-dashlet" title="Lots" model="com.axelor.apps.supplychain.db.EtatStockLot">
  <view type="grid" name="lvme-od-stock-grid"/>
  <view type="form" name="lvme-etat-stock-lot-form"/>
  <view-param name="popup" value="true"/>
  <domain>(:_prod = 0 OR self.product.id = :_prod)
    AND LOWER(COALESCE(self.lotNumber, &apos;&apos;)) LIKE :_lot
    AND (:_entFiltre = false OR self.entryDate BETWEEN :_du AND :_au)
    AND ((:_sel = 1 AND self.dispoQty &gt; 0) OR (:_sel = 2 AND self.stockQty &lt;= 0) OR :_sel = 3)</domain>
  <context name="_prod" expr="eval: (produit?.id ?: 0) as Long"/>
  <context name="_lot" expr="eval: numeroLot ? &apos;%&apos; + numeroLot.toString().trim().toLowerCase() + &apos;%&apos; : &apos;%&apos;"/>
  <context name="_entFiltre" expr="eval: entreeDu != null || entreeAu != null"/>
  <context name="_du" expr="eval: entreeDu ? java.time.LocalDate.parse(entreeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_au" expr="eval: entreeAu ? java.time.LocalDate.parse(entreeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_sel" expr="eval: (selectionLots ?: 1) as Integer"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-lot', 'action-attrs', NULL,
'<action-attrs name="action-lvme-od-stock-lot">
  <attribute name="value" for="$uniteOd" expr="eval: lotOd?.id ? __repo__(com.axelor.apps.stock.db.TrackingNumber).find(lotOd.id as Long)?.product?.unit?.name : null"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-type', 'action-attrs', NULL,
'<action-attrs name="action-lvme-od-stock-type">
  <attribute name="value" for="$sensMvt" expr="eval: typeMouvement ? ([&apos;ED&apos;, &apos;RE&apos;].contains(typeMouvement) ? &apos;Entrée&apos; : &apos;Sortie&apos;) : null"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-valider', 'action-method', NULL,
'<action-method name="action-lvme-od-stock-valider">
  <call class="com.axelor.apps.supplychain.web.LvmeOperationDiverseController" method="valider"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-annuler', 'action-attrs', NULL,
'<action-attrs name="action-lvme-od-stock-annuler">
  <attribute name="value" for="$lotOd" expr="eval: null"/>
  <attribute name="value" for="$typeMouvement" expr="eval: null"/>
  <attribute name="value" for="$libelleMvt" expr="eval: null"/>
  <attribute name="value" for="$sensMvt" expr="eval: null"/>
  <attribute name="value" for="$uniteOd" expr="eval: null"/>
  <attribute name="value" for="$dateOd" expr="eval: __date__"/>
  <attribute name="value" for="$poidsOd" expr="eval: 0"/>
</action-attrs>', false, false, 0);

DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-od-stock-form', 'lvme-od-stock-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-od-stock-form', 'Opérations Diverses sur les Stocks / Lots', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fOd'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-od-stock-grid', 'Opérations Diverses sur les Stocks / Lots', 'grid',
 'com.axelor.apps.supplychain.db.EtatStockLot', 20, current_setting('lvme.gOd'), false, false);

DELETE FROM meta_menu WHERE name = 'lvme-menu-od-stock';
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, hidden, left_menu, mobile_menu, priority)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-od-stock', 'Opérations Diverses sur les Stocks / Lots',
  (SELECT id FROM meta_menu WHERE name = 'stock-root' ORDER BY id LIMIT 1),
  (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-od-stock-open'),
  coalesce((SELECT order_seq + 1 FROM meta_menu WHERE name = 'lvme-menu-lots-verifies'), 51), false, true, false, 0;

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND name LIKE 'lvme-od-stock-%') AS vues,
       (SELECT count(*) FROM meta_menu WHERE name = 'lvme-menu-od-stock' AND action IS NOT NULL) AS menu,
       (SELECT count(*) FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-od-stock-%') AS actions,
       (SELECT count(*) FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
         WHERE s.name = 'lvme.od.type.select') AS types_mouvement,
       (SELECT count(*) FROM stock_stock_location WHERE import_id = 'LVME-OD') AS emplacement_od;

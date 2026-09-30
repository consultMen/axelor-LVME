-- =====================================================================
-- PROD étape 13 : écran « Lots Vérifiés » de GESCOM (diapo 21) — menu Stocks > Lots Vérifiés
--   - colonne « Lot vérifié » sur le lot (déclarée aussi dans le code)
--   - vue SQL lvme_etat_stock_lot mise à jour (Date de congélation + Vérif, ajoutées en fin de vue)
--   - listes de choix, actions, écran de recherche, liste, menu
-- À lancer depuis la racine du dépôt, APRÈS le déploiement du code, puis redémarrer Axelor. Relançable.
-- =====================================================================
\set fLots `cat livrables/ui/lvme-lots-verifies-form.xml`
\set gLots `cat livrables/ui/lvme-lots-verifies-grid.xml`
SELECT set_config('lvme.fLots', :'fLots', false), set_config('lvme.gLots', :'gLots', false);

BEGIN;

ALTER TABLE stock_tracking_number ADD COLUMN IF NOT EXISTS lot_verifie boolean DEFAULT false;
\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_etat_stock_lot.sql

-- ---------- Listes de choix ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, v.name, 0, true
FROM (VALUES ('lvme.lots.selection.select'), ('lvme.lots.verification.select')) AS v(name)
WHERE NOT EXISTS (SELECT 1 FROM meta_select s WHERE s.name = v.name);
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('lvme.lots.selection.select', '1', 'Lots dispo', 1), ('lvme.lots.selection.select', '2', 'Lots Soldés', 2),
             ('lvme.lots.selection.select', '3', 'Les deux', 3),
             ('lvme.lots.verification.select', '1', 'Lot vérifié', 1), ('lvme.lots.verification.select', '2', 'Lot non vérifié', 2))
  AS v(sel, value, title, seq) ON v.sel = s.name
WHERE NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- ---------- Actions ----------
UPDATE meta_menu SET action = NULL WHERE name = 'lvme-menu-lots-verifies'
  AND action IN (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-lots-verifies-open');
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-lots-verifies-open', 'action-lvme-lots-verifies-dashlet',
  'action-lvme-lots-verifies-refresh', 'action-lvme-lots-verifies-defaults', 'action-lvme-lots-verifies-periode',
  'action-lvme-lots-verifies-valider');

INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-lots-verifies-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-lots-verifies-open" title="Lots Vérifiés" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-lots-verifies-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-lots-verifies-dashlet', 'action-view', 'com.axelor.apps.supplychain.db.EtatStockLot',
'<action-view name="action-lvme-lots-verifies-dashlet" title="Lots" model="com.axelor.apps.supplychain.db.EtatStockLot">
  <view type="grid" name="lvme-lots-verifies-grid"/>
  <view type="form" name="lvme-etat-stock-lot-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <domain>(:_prod = 0 OR self.product.id = :_prod)
    AND LOWER(COALESCE(self.lotNumber, '''')) LIKE :_lot
    AND (:_entFiltre = false OR self.entryDate BETWEEN :_du AND :_au)
    AND ((:_sel = 1 AND self.dispoQty &gt; 0) OR (:_sel = 2 AND self.stockQty &lt;= 0) OR :_sel = 3)</domain>
  <context name="_prod" expr="eval: (produit?.id ?: 0) as Long"/>
  <context name="_lot" expr="eval: numeroLot ? ''%'' + numeroLot.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_entFiltre" expr="eval: entreeDu != null || entreeAu != null"/>
  <context name="_du" expr="eval: entreeDu ? java.time.LocalDate.parse(entreeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_au" expr="eval: entreeAu ? java.time.LocalDate.parse(entreeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_sel" expr="eval: (selectionLots ?: 1) as Integer"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-lots-verifies-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-lots-verifies-refresh">
  <attribute name="refresh" for="lotsDashlet" expr="eval: true"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-lots-verifies-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-lots-verifies-defaults">
  <attribute name="value" for="$selectionLots" expr="eval: 1"/>
  <attribute name="value" for="$verification" expr="eval: 1"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-lots-verifies-periode', 'action-attrs', NULL,
'<action-attrs name="action-lvme-lots-verifies-periode">
  <attribute name="value" for="$entreeDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][entreePeriode as Integer]"/>
  <attribute name="value" for="$entreeAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][entreePeriode as Integer]"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-lots-verifies-valider', 'action-method', NULL,
'<action-method name="action-lvme-lots-verifies-valider">
  <call class="com.axelor.apps.supplychain.web.LvmeLotVerifieController" method="valider"/>
</action-method>', false, false);

-- ---------- Vues ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-lots-verifies-form', 'lvme-lots-verifies-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-lots-verifies-form', 'Lots Vérifiés', 'form', 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fLots'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-lots-verifies-grid', 'Lots Vérifiés', 'grid', 'com.axelor.apps.supplychain.db.EtatStockLot', 20, current_setting('lvme.gLots'), false, false);

-- ---------- Menu Stocks > Lots Vérifiés ----------
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, priority, hidden, left_menu, mobile_menu, tag_count)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-lots-verifies', 'Lots Vérifiés',
       (SELECT id FROM meta_menu WHERE name = 'stock-root' ORDER BY priority DESC LIMIT 1),
       (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-lots-verifies-open'), 51, 0, false, true, false, false
WHERE NOT EXISTS (SELECT 1 FROM meta_menu WHERE name = 'lvme-menu-lots-verifies');
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-lots-verifies-open')
WHERE name = 'lvme-menu-lots-verifies';

COMMIT;

SELECT count(*) AS lignes_vue, count(*) FILTER (WHERE lot_verifie) AS lots_verifies FROM lvme_etat_stock_lot;

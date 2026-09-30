-- =====================================================================
-- PROD étape 14 : écran « Historique Produit » de GESCOM (diapo 11) — menu Stocks > Historique Produit
--   - vue SQL lvme_historique_produit (modèle HistoriqueProduit, déclaré aussi dans le code)
--   - actions, écran de recherche, liste, menu
-- À lancer depuis la racine du dépôt, AVANT le redémarrage d'Axelor avec le nouveau code
-- (sinon Hibernate crée une table lvme_historique_produit à la place de la vue). Relançable.
-- =====================================================================
\set fHisto `cat livrables/ui/lvme-historique-produit-form.xml`
\set gHisto `cat livrables/ui/lvme-historique-produit-grid.xml`
\set dHisto `cat livrables/ui/lvme-historique-produit-detail-form.xml`
SELECT set_config('lvme.fHisto', :'fHisto', false), set_config('lvme.gHisto', :'gHisto', false),
       set_config('lvme.dHisto', :'dHisto', false);

BEGIN;

\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_historique_produit.sql

-- ---------- Actions ----------
UPDATE meta_menu SET action = NULL WHERE name = 'lvme-menu-historique-produit'
  AND action IN (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-historique-produit-open');
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-historique-produit-open',
  'action-lvme-historique-produit-dashlet', 'action-lvme-historique-produit-defaults',
  'action-lvme-historique-produit-periode', 'action-lvme-historique-produit-designation',
  'action-lvme-historique-produit-valider', 'action-lvme-historique-produit-ouvrir-mvt');

INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-historique-produit-open" title="Historique Produit" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-historique-produit-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-dashlet', 'action-view', 'com.axelor.apps.supplychain.db.HistoriqueProduit',
'<action-view name="action-lvme-historique-produit-dashlet" title="Historique Produit" model="com.axelor.apps.supplychain.db.HistoriqueProduit">
  <view type="grid" name="lvme-historique-produit-grid"/>
  <view type="form" name="lvme-historique-produit-detail-form"/>
  <domain>self.product.id = :_prod AND self.dateMvt BETWEEN :_du AND :_au</domain>
  <context name="_prod" expr="eval: (produit?.id ?: 0) as Long"/>
  <context name="_du" expr="eval: entreeDu ? java.time.LocalDate.parse(entreeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_au" expr="eval: entreeAu ? java.time.LocalDate.parse(entreeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-historique-produit-defaults">
  <attribute name="value" for="$entreeDu" expr="eval: __date__.minusYears(3)"/>
  <attribute name="value" for="$entreeAu" expr="eval: __date__"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-periode', 'action-attrs', NULL,
'<action-attrs name="action-lvme-historique-produit-periode">
  <attribute name="value" for="$entreeDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][entreePeriode as Integer]"/>
  <attribute name="value" for="$entreeAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][entreePeriode as Integer]"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-designation', 'action-attrs', NULL,
'<action-attrs name="action-lvme-historique-produit-designation">
  <attribute name="value" for="$designation" expr="eval: produit?.id ? __repo__(com.axelor.apps.base.db.Product).find(produit.id as Long)?.name : null"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-valider', 'action-method', NULL,
'<action-method name="action-lvme-historique-produit-valider">
  <call class="com.axelor.apps.supplychain.web.LvmeHistoriqueProduitController" method="valider"/>
</action-method>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-ouvrir-mvt', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-historique-produit-ouvrir-mvt" title="Mouvement" model="com.axelor.apps.stock.db.StockMove">
  <view type="form" name="stock-move-form"/>
  <view type="grid" name="stock-move-grid"/>
  <context name="_showRecord" expr="eval: stockMove?.id"/>
</action-view>', false, false);

-- ---------- Vues ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-historique-produit-form', 'lvme-historique-produit-grid',
  'lvme-historique-produit-detail-form');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-historique-produit-form', 'Historique Produit', 'form', 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fHisto'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-historique-produit-grid', 'Historique Produit', 'grid', 'com.axelor.apps.supplychain.db.HistoriqueProduit', 20, current_setting('lvme.gHisto'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-historique-produit-detail-form', 'Mouvement', 'form', 'com.axelor.apps.supplychain.db.HistoriqueProduit', 20, current_setting('lvme.dHisto'), false, false);

-- ---------- Menu Stocks > Historique Produit ----------
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, priority, hidden, left_menu, mobile_menu, tag_count)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-historique-produit', 'Historique Produit',
       (SELECT id FROM meta_menu WHERE name = 'stock-root' ORDER BY priority DESC LIMIT 1),
       (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-historique-produit-open'), 52, 0, false, true, false, false
WHERE NOT EXISTS (SELECT 1 FROM meta_menu WHERE name = 'lvme-menu-historique-produit');
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-historique-produit-open')
WHERE name = 'lvme-menu-historique-produit';

COMMIT;

SELECT type_mvt AS type, count(*) AS lignes FROM lvme_historique_produit GROUP BY type_mvt ORDER BY type_mvt;

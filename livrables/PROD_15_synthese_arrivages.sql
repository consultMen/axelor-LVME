-- =====================================================================
-- PROD étape 15 : écran « Synthèse des Arrivages » de GESCOM (diapo 24) — menu Stocks > Arrivages > Synthèse des Arrivages
--   - vue SQL lvme_synthese_arrivage (modèle SyntheseArrivage, déclaré aussi dans le code)
--   - actions, écran de recherche, liste regroupée par arrivage, fiche de détail, menu
-- À lancer depuis la racine du dépôt, AVANT le redémarrage d'Axelor avec le nouveau code
-- (sinon Hibernate crée une table lvme_synthese_arrivage à la place de la vue). Relançable.
-- =====================================================================
\set fSynth `cat livrables/ui/lvme-synthese-arrivage-form.xml`
\set gSynth `cat livrables/ui/lvme-synthese-arrivage-grid.xml`
\set dSynth `cat livrables/ui/lvme-synthese-arrivage-detail-form.xml`
SELECT set_config('lvme.fSynth', :'fSynth', false), set_config('lvme.gSynth', :'gSynth', false),
       set_config('lvme.dSynth', :'dSynth', false);

BEGIN;

\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_synthese_arrivage.sql

-- ---------- Actions ----------
UPDATE meta_menu SET action = NULL WHERE name = 'lvme-menu-synthese-arrivage'
  AND action IN (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-synthese-arrivage-open');
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-synthese-arrivage-open',
  'action-lvme-synthese-arrivage-dashlet', 'action-lvme-synthese-arrivage-defaults',
  'action-lvme-synthese-arrivage-periode', 'action-lvme-synthese-arrivage-refresh',
  'action-lvme-synthese-arrivage-ouvrir');

INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-synthese-arrivage-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-synthese-arrivage-open" title="Synthèse des Arrivages" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-synthese-arrivage-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-synthese-arrivage-dashlet', 'action-view', 'com.axelor.apps.supplychain.db.SyntheseArrivage',
'<action-view name="action-lvme-synthese-arrivage-dashlet" title="Synthèse des Arrivages" model="com.axelor.apps.supplychain.db.SyntheseArrivage">
  <view type="grid" name="lvme-synthese-arrivage-grid"/>
  <view type="form" name="lvme-synthese-arrivage-detail-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <domain>self.arrivage &gt;= :_numDu AND self.arrivage &lt;= :_numAu
    AND self.dateArrivee BETWEEN :_du AND :_au</domain>
  <context name="_numDu" expr="eval: arrivageDu ? arrivageDu.toString().trim() : ''''"/>
  <context name="_numAu" expr="eval: arrivageAu ? arrivageAu.toString().trim() : ''zzzzzzzzzzzz''"/>
  <context name="_du" expr="eval: arriveeDu ? java.time.LocalDate.parse(arriveeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_au" expr="eval: arriveeAu ? java.time.LocalDate.parse(arriveeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-synthese-arrivage-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-synthese-arrivage-refresh">
  <attribute name="refresh" for="syntheseDashlet" expr="eval: true"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-synthese-arrivage-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-synthese-arrivage-defaults">
  <attribute name="value" for="$arriveeDu" expr="eval: __date__.minusYears(3)"/>
  <attribute name="value" for="$arriveeAu" expr="eval: __date__"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-synthese-arrivage-periode', 'action-attrs', NULL,
'<action-attrs name="action-lvme-synthese-arrivage-periode">
  <attribute name="value" for="$arriveeDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][arriveePeriode as Integer]"/>
  <attribute name="value" for="$arriveeAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][arriveePeriode as Integer]"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-synthese-arrivage-ouvrir', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-synthese-arrivage-ouvrir" title="Arrivage" model="com.axelor.apps.stock.db.StockMove">
  <view type="form" name="lvme-arrivage-form"/>
  <view type="grid" name="lvme-arrivage-grid"/>
  <context name="_showRecord" expr="eval: stockMove?.id"/>
</action-view>', false, false);

-- ---------- Vues ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-synthese-arrivage-form', 'lvme-synthese-arrivage-grid',
  'lvme-synthese-arrivage-detail-form');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-synthese-arrivage-form', 'Synthèse des Arrivages', 'form', 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fSynth'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-synthese-arrivage-grid', 'Synthèse des Arrivages', 'grid', 'com.axelor.apps.supplychain.db.SyntheseArrivage', 20, current_setting('lvme.gSynth'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-synthese-arrivage-detail-form', 'Ligne d''arrivage', 'form', 'com.axelor.apps.supplychain.db.SyntheseArrivage', 20, current_setting('lvme.dSynth'), false, false);

-- ---------- Menu Stocks > Arrivages > Synthèse des Arrivages ----------
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, priority, hidden, left_menu, mobile_menu, tag_count)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-synthese-arrivage', 'Synthèse des Arrivages',
       (SELECT id FROM meta_menu WHERE name = 'stock-root-arrivals' ORDER BY priority DESC LIMIT 1),
       (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-synthese-arrivage-open'), 150, 0, false, true, false, false
WHERE NOT EXISTS (SELECT 1 FROM meta_menu WHERE name = 'lvme-menu-synthese-arrivage');
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-synthese-arrivage-open')
WHERE name = 'lvme-menu-synthese-arrivage';

COMMIT;

SELECT count(*) AS lignes, count(DISTINCT arrivage) AS arrivages FROM lvme_synthese_arrivage;

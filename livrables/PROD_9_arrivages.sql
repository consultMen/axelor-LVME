-- =====================================================================
-- PROD étape 9 : menu « Arrivages » = réceptions fournisseur, écran de recherche à la manière de GESCOM
--   - Nature renseignée sur les anciennes réceptions (même règle que le code : statut -> nature)
--   - Nb Colis / Poids Total des réceptions existantes (somme des lignes, comme le code)
--   - Liste de choix « Nature » du filtre, actions, écran de recherche, liste des arrivages,
--     fiche « Arrivage » dédiée (lvme-arrivage-form) et grille de ses lignes ; la fiche de réception
--     standard (stock-move-form, aussi utilisée par les BL) n'est pas modifiée
--   - Menu « Réceptions fournisseur » renommé « Arrivages » et ouvert sur l'écran de recherche
-- Le script crée lui-même les colonnes nb_colis_total / poids_total (déclarées aussi dans le code) ;
-- les tables des bateaux / containers et leurs liens sont créés par Axelor au redémarrage.
-- À lancer depuis la racine du dépôt, puis redémarrer Axelor. Relançable. Une seule transaction.
-- =====================================================================
\set grille `cat livrables/ui/arrivage-grid.xml`
\set recherche `cat livrables/ui/arrivage-search-form.xml`
\set fiche `cat livrables/ui/arrivage-form.xml`
\set lignes `cat livrables/ui/arrivage-line-grid.xml`
SELECT set_config('lvme.grille', :'grille', false), set_config('lvme.recherche', :'recherche', false),
       set_config('lvme.fiche', :'fiche', false), set_config('lvme.lignes', :'lignes', false);

BEGIN;

ALTER TABLE stock_stock_move ADD COLUMN IF NOT EXISTS nb_colis_total numeric(20,3);
ALTER TABLE stock_stock_move ADD COLUMN IF NOT EXISTS poids_total numeric(20,3);

-- ---------- Données ----------
UPDATE stock_stock_move SET nature = CASE status_select WHEN 1 THEN 0 WHEN 2 THEN 1 WHEN 3 THEN 3 WHEN 4 THEN 4 END
WHERE nature IS NULL AND type_select = 3;

UPDATE stock_stock_move sm
SET nb_colis_total = t.colis, poids_total = t.poids
FROM (SELECT stock_move, SUM(COALESCE(nb_colis, 0)) AS colis, SUM(COALESCE(poids_total_net, 0)) AS poids
      FROM stock_stock_move_line GROUP BY stock_move) t
WHERE t.stock_move = sm.id;

-- ---------- Liste de choix du filtre Nature ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.arrivage.nature.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.arrivage.nature.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
CROSS JOIN (VALUES ('1', 'Arrivages Flottant + Réel', 1), ('2', 'Arrivage Réel', 2), ('3', 'Arrivage Flottant', 3),
                   ('4', 'Arrivages Archivés', 5)) AS v(value, title, seq)
WHERE s.name = 'lvme.arrivage.nature.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- ---------- Actions ----------
-- (le menu est détaché le temps de recréer son action : script relançable)
UPDATE meta_menu SET action = NULL WHERE name = 'stock-root-suparrivals'
  AND action IN (SELECT id FROM meta_action WHERE name = 'action-lvme-arrivage-open' AND module IS NULL);
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-arrivage-open', 'action-lvme-arrivage-dashlet',
  'action-lvme-arrivage-refresh', 'action-lvme-arrivage-defaults', 'action-lvme-arrivage-periode-date',
  'action-lvme-arrivage-periode-arrivee', 'action-lvme-arrivage-new', 'action-lvme-arrivage-record-flottant',
  'action-lvme-arrivage-record-embarquer', 'action-lvme-arrivage-attrs-devise');

INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-arrivage-open" title="Arrivages" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-arrivage-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-dashlet', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-arrivage-dashlet" title="Arrivages" model="com.axelor.apps.stock.db.StockMove">
  <view type="grid" name="lvme-arrivage-grid"/>
  <view type="form" name="lvme-arrivage-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <domain>self.typeSelect = 3 AND self.isReversion = FALSE
    AND LOWER(COALESCE(self.stockMoveSeq, '''')) LIKE :_num
    AND (:_fou = 0 OR self.partner.id = :_fou)
    AND (:_dateFiltre = false OR self.createdOn BETWEEN :_dateDu AND :_dateAu)
    AND (:_arrFiltre = false OR (self.realDate BETWEEN :_arrDu AND :_arrAu)
         OR (self.realDate IS NULL AND self.estimatedDate BETWEEN :_arrDu AND :_arrAu))
    AND ((:_nature = 4 AND self.archived = true)
      OR (:_nature != 4 AND (self.archived IS NULL OR self.archived = false)
        AND ((:_nature = 1 AND self.nature IN (0, 1, 2, 3)) OR (:_nature = 2 AND self.nature = 3)
          OR (:_nature = 3 AND self.nature IN (1, 2)))))</domain>
  <context name="_num" expr="eval: numeroArrivage ? ''%'' + numeroArrivage.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_fou" expr="eval: (fournisseur?.id ?: 0) as Long"/>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)).atStartOfDay() : java.time.LocalDateTime.of(1900, 1, 1, 0, 0)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)).atTime(23, 59, 59) : java.time.LocalDateTime.of(2999, 12, 31, 0, 0)"/>
  <context name="_arrFiltre" expr="eval: arriveeDu != null || arriveeAu != null"/>
  <context name="_arrDu" expr="eval: arriveeDu ? java.time.LocalDate.parse(arriveeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_arrAu" expr="eval: arriveeAu ? java.time.LocalDate.parse(arriveeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_nature" expr="eval: (natureFiltre ?: 1) as Integer"/>
  <context name="_typeSelect" expr="eval: 3"/>
  <context name="_isReversion" expr="eval: false"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-arrivage-refresh">
  <attribute name="refresh" for="arrivagesDashlet" expr="eval: true"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-arrivage-defaults">
  <attribute name="value" for="$natureFiltre" expr="eval: 1"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-periode-date', 'action-attrs', NULL,
'<action-attrs name="action-lvme-arrivage-periode-date">
  <attribute name="value" for="$dateDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][datePeriode as Integer]"/>
  <attribute name="value" for="$dateAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][datePeriode as Integer]"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-periode-arrivee', 'action-attrs', NULL,
'<action-attrs name="action-lvme-arrivage-periode-arrivee">
  <attribute name="value" for="$arriveeDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][arriveePeriode as Integer]"/>
  <attribute name="value" for="$arriveeAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][arriveePeriode as Integer]"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-new', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-arrivage-new" title="Arrivage" model="com.axelor.apps.stock.db.StockMove">
  <view type="form" name="lvme-arrivage-form"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_typeSelect" expr="eval: __repo__(StockMove).TYPE_INCOMING"/>
  <context name="_newDate" expr="eval: __config__.date.plusWeeks(1)"/>
  <context name="_isReversion" expr="eval: false"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-record-flottant', 'action-record', 'com.axelor.apps.stock.db.StockMove',
'<action-record name="action-lvme-arrivage-record-flottant" model="com.axelor.apps.stock.db.StockMove">
  <field name="nature" expr="eval: ''FLOTTANT''"/>
</action-record>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-record-embarquer', 'action-record', 'com.axelor.apps.stock.db.StockMove',
'<action-record name="action-lvme-arrivage-record-embarquer" model="com.axelor.apps.stock.db.StockMove">
  <field name="nature" expr="eval: ''EN_COURS_DE_PRODUCTION''"/>
</action-record>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-attrs-devise', 'action-attrs', NULL,
'<action-attrs name="action-lvme-arrivage-attrs-devise">
  <attribute name="value" for="$deviseAchat"
    expr="eval: def sm = id ? __repo__(StockMove).find(id) : null; sm?.purchaseOrderSet?.find { true }?.currency?.code ?: (sm?.company?.currency?.code ?: '''')"/>
  <attribute name="value" for="$currencySymbol"
    expr="eval: def sm = id ? __repo__(StockMove).find(id) : null; sm?.purchaseOrderSet?.find { true }?.currency?.symbol ?: (sm?.company?.currency?.symbol ?: '''')"/>
  <attribute name="value" for="$deviseComptable"
    expr="eval: def sm = id ? __repo__(StockMove).find(id) : null; sm?.company?.currency?.code ?: ''''"/>
</action-attrs>', false, false);

-- ---------- Vues ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-arrivage-grid', 'lvme-arrivage-search-form', 'lvme-arrivage-form',
  'lvme-arrivage-line-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-arrivage-grid', 'Arrivages', 'grid', 'com.axelor.apps.stock.db.StockMove', 20,
 current_setting('lvme.grille'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-arrivage-search-form', 'Arrivages', 'form', 'com.axelor.utils.db.Wizard', 20,
 current_setting('lvme.recherche'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-arrivage-form', 'Arrivage', 'form', 'com.axelor.apps.stock.db.StockMove', 20,
 current_setting('lvme.fiche'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-arrivage-line-grid', 'Lignes Arrivages', 'grid', 'com.axelor.apps.stock.db.StockMoveLine', 20,
 current_setting('lvme.lignes'), false, false);

-- ---------- Référentiels des bateaux et des containers (Stocks > Configuration) ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-bateau-grid', 'lvme-bateau-form', 'lvme-container-grid',
  'lvme-container-form');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-bateau-grid', 'Bateaux', 'grid', 'com.axelor.apps.stock.db.Bateau', 20,
'<grid name="lvme-bateau-grid" title="Bateaux" model="com.axelor.apps.stock.db.Bateau" orderBy="name" editable="true">
  <field name="name"/>
</grid>', false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-bateau-form', 'Bateau', 'form', 'com.axelor.apps.stock.db.Bateau', 20,
'<form name="lvme-bateau-form" title="Bateau" model="com.axelor.apps.stock.db.Bateau">
  <panel name="mainPanel">
    <field name="name" colSpan="12"/>
  </panel>
</form>', false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-container-grid', 'Containers', 'grid', 'com.axelor.apps.stock.db.Container', 20,
'<grid name="lvme-container-grid" title="Containers" model="com.axelor.apps.stock.db.Container" orderBy="name" editable="true">
  <field name="name"/>
</grid>', false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-container-form', 'Container', 'form', 'com.axelor.apps.stock.db.Container', 20,
'<form name="lvme-container-form" title="Container" model="com.axelor.apps.stock.db.Container">
  <panel name="mainPanel">
    <field name="name" colSpan="12"/>
  </panel>
</form>', false, false);

UPDATE meta_menu SET action = NULL WHERE name IN ('lvme-menu-bateau', 'lvme-menu-container')
  AND action IN (SELECT id FROM meta_action WHERE name IN ('action-lvme-bateau', 'action-lvme-container') AND module IS NULL);
DELETE FROM meta_action WHERE name IN ('action-lvme-bateau', 'action-lvme-container') AND module IS NULL;
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-bateau', 'action-view', 'com.axelor.apps.stock.db.Bateau',
'<action-view name="action-lvme-bateau" title="Bateaux" model="com.axelor.apps.stock.db.Bateau">
  <view type="grid" name="lvme-bateau-grid"/>
  <view type="form" name="lvme-bateau-form"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-container', 'action-view', 'com.axelor.apps.stock.db.Container',
'<action-view name="action-lvme-container" title="Containers" model="com.axelor.apps.stock.db.Container">
  <view type="grid" name="lvme-container-grid"/>
  <view type="form" name="lvme-container-form"/>
</action-view>', false, false);

INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, priority, hidden, left_menu, mobile_menu, tag_count)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-bateau', 'Bateaux',
       (SELECT id FROM meta_menu WHERE name = 'stock-root-conf' ORDER BY priority DESC LIMIT 1),
       (SELECT id FROM meta_action WHERE name = 'action-lvme-bateau' AND module IS NULL), 100, 0, false, true, false, false
WHERE NOT EXISTS (SELECT 1 FROM meta_menu WHERE name = 'lvme-menu-bateau');
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE name = 'action-lvme-bateau' AND module IS NULL)
WHERE name = 'lvme-menu-bateau';
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, priority, hidden, left_menu, mobile_menu, tag_count)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-container', 'Containers',
       (SELECT id FROM meta_menu WHERE name = 'stock-root-conf' ORDER BY priority DESC LIMIT 1),
       (SELECT id FROM meta_action WHERE name = 'action-lvme-container' AND module IS NULL), 101, 0, false, true, false, false
WHERE NOT EXISTS (SELECT 1 FROM meta_menu WHERE name = 'lvme-menu-container');
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE name = 'action-lvme-container' AND module IS NULL)
WHERE name = 'lvme-menu-container';

-- ---------- Menu « Réceptions fournisseur » -> « Arrivages » ----------
UPDATE meta_menu SET title = 'Arrivages',
       action = (SELECT id FROM meta_action WHERE name = 'action-lvme-arrivage-open' AND module IS NULL)
WHERE name = 'stock-root-suparrivals';

COMMIT;

SELECT m.name, m.title, a.name AS action FROM meta_menu m LEFT JOIN meta_action a ON a.id = m.action
WHERE m.name = 'stock-root-suparrivals';
SELECT nature, count(*) FROM stock_stock_move WHERE type_select = 3 GROUP BY 1 ORDER BY 1;

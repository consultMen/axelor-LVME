-- =====================================================================
-- PROD étape 95 : RFA par produit, comme GESCOM
--   - règles RFA par produit (table RFA_ART de GESCOM) : % accordé à un client ou à un groupement, sur un article ou
--     une famille, du / au ; menu Ventes > Configuration > Règles RFA par produit
--   - écran « Liste des RFA par produit / facture » (menu Ventes) : Factures du / au, période prédéfinie, Lancer la
--     recherche, Imprimer ; une ligne par ligne de facture client validée qui a une règle (règle du client avant
--     celle du groupement, sur l'article avant celle sur la famille) ; montant de la remise = HT x % ; sommes
--   - table supplychain_rfa_article et vue lvme_rfa_facture (sql/lvme_rfa_facture.sql)
-- Prérequis : code avec RfaArticle, RfaFacture, LvmeImpressionListesController.imprimerRfa et
-- reports/LvmeListeRfa.rptdesign (recompiler). À lancer depuis la racine du dépôt, AVANT le redémarrage d'Axelor avec
-- le nouveau code (sinon Hibernate crée une table lvme_rfa_facture à la place de la vue). Relançable.
-- =====================================================================
\set gRegle `cat livrables/ui/lvme-rfa-article-grid.xml`
\set fRegle `cat livrables/ui/lvme-rfa-article-form.xml`
\set fRfa `cat livrables/ui/lvme-rfa-facture-form.xml`
\set gRfa `cat livrables/ui/lvme-rfa-facture-grid.xml`
SELECT set_config('lvme.gRegle', :'gRegle', false) IS NOT NULL AND set_config('lvme.fRegle', :'fRegle', false) IS NOT NULL
   AND set_config('lvme.fRfa', :'fRfa', false) IS NOT NULL AND set_config('lvme.gRfa', :'gRfa', false) IS NOT NULL
   AS vues_lues;

BEGIN;

\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_rfa_facture.sql

-- ---------- listes de choix ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, v.name, 0, true
FROM (VALUES ('lvme.rfa.type.client.select'), ('lvme.rfa.type.article.select')) AS v(name)
WHERE NOT EXISTS (SELECT 1 FROM meta_select s WHERE s.name = v.name);
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('lvme.rfa.type.client.select', '1', 'Client', 1), ('lvme.rfa.type.client.select', '2', 'Groupement', 2),
             ('lvme.rfa.type.article.select', '1', 'Article', 1), ('lvme.rfa.type.article.select', '2', 'Famille', 2))
  AS v(sel, value, title, seq) ON v.sel = s.name
WHERE NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- ---------- actions ----------
UPDATE meta_menu SET action = NULL WHERE action IN (SELECT id FROM meta_action WHERE module IS NULL
  AND name IN ('action-lvme-rfa-article-all', 'action-lvme-rfa-facture-open'));
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-rfa-article-all', 'action-lvme-rfa-article-defaults',
  'action-lvme-rfa-facture-open', 'action-lvme-rfa-facture-dashlet', 'action-lvme-rfa-facture-refresh',
  'action-lvme-rfa-facture-defaults', 'action-lvme-rfa-facture-periode', 'action-lvme-rfa-facture-group-onnew',
  'action-lvme-rfa-facture-imprimer');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rfa-article-all', 'action-view', 'com.axelor.apps.supplychain.db.RfaArticle',
'<action-view name="action-lvme-rfa-article-all" title="Règles RFA par produit" model="com.axelor.apps.supplychain.db.RfaArticle">
  <view type="grid" name="lvme-rfa-article-grid"/>
  <view type="form" name="lvme-rfa-article-form"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rfa-article-defaults', 'action-record', 'com.axelor.apps.supplychain.db.RfaArticle',
'<action-record name="action-lvme-rfa-article-defaults" model="com.axelor.apps.supplychain.db.RfaArticle">
  <field name="typeClient" expr="eval: 1"/>
  <field name="typeArticle" expr="eval: 1"/>
</action-record>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rfa-facture-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-rfa-facture-open" title="Liste des RFA par produit / facture" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-rfa-facture-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rfa-facture-dashlet', 'action-view', 'com.axelor.apps.supplychain.db.RfaFacture',
'<action-view name="action-lvme-rfa-facture-dashlet" title="RFA par produit / facture" model="com.axelor.apps.supplychain.db.RfaFacture">
  <view type="grid" name="lvme-rfa-facture-grid"/>
  <view-param name="popup" value="true"/>
  <domain>self.dateFacture BETWEEN :_du AND :_au</domain>
  <context name="_du" expr="eval: factureDu ? java.time.LocalDate.parse(factureDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_au" expr="eval: factureAu ? java.time.LocalDate.parse(factureAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rfa-facture-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-rfa-facture-refresh">
  <attribute name="refresh" for="rfaDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rfa-facture-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-rfa-facture-defaults">
  <attribute name="value" for="$factureDu" expr="eval: __date__.minusMonths(1).withDayOfMonth(1)"/>
  <attribute name="value" for="$factureAu" expr="eval: __date__.withDayOfMonth(1).minusDays(1)"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rfa-facture-periode', 'action-attrs', NULL,
'<action-attrs name="action-lvme-rfa-facture-periode">
  <attribute name="value" for="$factureDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][facturePeriode as Integer]"/>
  <attribute name="value" for="$factureAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][facturePeriode as Integer]"/>
  <attribute name="refresh" for="rfaDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rfa-facture-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-rfa-facture-group-onnew">
  <action name="action-lvme-rfa-facture-defaults"/>
  <action name="action-lvme-rfa-facture-refresh"/>
</action-group>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rfa-facture-imprimer', 'action-method', NULL,
'<action-method name="action-lvme-rfa-facture-imprimer">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerRfa"/>
</action-method>', false, false, 0);

-- ---------- vues ----------
DELETE FROM meta_view WHERE module IS NULL
  AND name IN ('lvme-rfa-article-grid', 'lvme-rfa-article-form', 'lvme-rfa-facture-form', 'lvme-rfa-facture-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-rfa-article-grid', 'Règles RFA par produit', 'grid',
 'com.axelor.apps.supplychain.db.RfaArticle', 20, current_setting('lvme.gRegle'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-rfa-article-form', 'Règle RFA par produit', 'form',
 'com.axelor.apps.supplychain.db.RfaArticle', 20, current_setting('lvme.fRegle'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-rfa-facture-form', 'Liste des RFA par produit / facture', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fRfa'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-rfa-facture-grid', 'RFA par produit / facture', 'grid',
 'com.axelor.apps.supplychain.db.RfaFacture', 20, current_setting('lvme.gRfa'), false, false);

-- ---------- menus ----------
DELETE FROM meta_menu WHERE name IN ('lvme-menu-rfa-article', 'lvme-menu-rfa-facture');
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, hidden, left_menu, mobile_menu, priority)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-rfa-article', 'Règles RFA par produit',
  (SELECT id FROM meta_menu WHERE name = 'sc-root-sale-conf' ORDER BY id LIMIT 1),
  (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-rfa-article-all'), 110, false, true, false, 0
UNION ALL
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-rfa-facture', 'Liste des RFA par produit / facture',
  (SELECT id FROM meta_menu WHERE name = 'sc-root-sale' ORDER BY id LIMIT 1),
  (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-rfa-facture-open'), 660, false, true, false, 0;
-- mêmes rôles que le menu Groupements / Listes Dossiers
INSERT INTO meta_menu_roles (menus, roles)
SELECT m.id, r.roles FROM meta_menu m
JOIN meta_menu_roles r ON r.menus = (SELECT id FROM meta_menu WHERE name = CASE m.name WHEN 'lvme-menu-rfa-article'
  THEN 'sale-menu-groupements' ELSE 'lvme-menu-listes-dossiers' END ORDER BY id LIMIT 1)
WHERE m.name IN ('lvme-menu-rfa-article', 'lvme-menu-rfa-facture');

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND name LIKE 'lvme-rfa-%') AS vues,
       (SELECT count(*) FROM meta_menu WHERE name IN ('lvme-menu-rfa-article', 'lvme-menu-rfa-facture') AND action IS NOT NULL)
         AS menus,
       (SELECT count(*) FROM pg_views WHERE viewname = 'lvme_rfa_facture') AS vue_sql,
       (SELECT count(*) FROM supplychain_rfa_article) AS regles;

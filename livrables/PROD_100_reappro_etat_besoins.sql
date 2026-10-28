-- =====================================================================
-- PROD étape 100 : « Aides aux Réapprovisionnements » et « Etat des besoins », comme GESCOM
--   - Aides aux Réapprovisionnements : période de réappro, période de statistiques, Fournisseur / Produit / Famille,
--     cases Tenir Compte (arrivages réels, flottants, commandes clients en cours, à commander négatif), Lancer
--     Traitement ; une ligne par produit (qtés et poids vendus, commandés, en stock réel / DLC courte / flottant, à
--     commander) calculée par LvmeReapproController
--   - Etat des besoins : Année N, Année N-1 (% d'évolution), Année N-1 période réappro, cadres Client / Produit ;
--     Valider = impression « Aides aux Réapprovisionnements » (LvmeEtatBesoins.rptdesign, logo LVME)
--   - menus Stocks > Aides aux Réapprovisionnements, Etat des besoins
-- Prérequis : PROD_98 ; code avec ReapproLigne, LvmeReapproController, imprimerEtatBesoins (recompiler). À lancer
-- depuis la racine du dépôt. Sources : livrables/ui/lvme-reappro-form.xml, lvme-reappro-grid.xml,
-- lvme-etat-besoins-form.xml. Relançable.
-- =====================================================================
\set fReappro `cat livrables/ui/lvme-reappro-form.xml`
SELECT set_config('lvme.fReappro', :'fReappro', false) IS NOT NULL AS vue_lue;
\set gReappro `cat livrables/ui/lvme-reappro-grid.xml`
SELECT set_config('lvme.gReappro', :'gReappro', false) IS NOT NULL AS liste_lue;
\set fBesoins `cat livrables/ui/lvme-etat-besoins-form.xml`
SELECT set_config('lvme.fBesoins', :'fBesoins', false) IS NOT NULL AS vue_besoins_lue;

BEGIN;

UPDATE meta_menu SET action = NULL WHERE action IN (SELECT id FROM meta_action WHERE module IS NULL
  AND name IN ('action-lvme-reappro-open', 'action-lvme-etat-besoins-open'));
DELETE FROM meta_action WHERE module IS NULL AND (name LIKE 'action-lvme-reappro-%' OR name LIKE 'action-lvme-etat-besoins-%');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reappro-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-reappro-open" title="Aides aux Réapprovisionnements" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-reappro-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reappro-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-reappro-defaults">
  <attribute name="value" for="$reapproDu" expr="eval: __date__"/>
  <attribute name="value" for="$reapproAu" expr="eval: __date__.plusMonths(1)"/>
  <attribute name="value" for="$statsDu" expr="eval: __date__.minusMonths(1)"/>
  <attribute name="value" for="$statsAu" expr="eval: __date__"/>
  <attribute name="value" for="$tenirReels" expr="eval: true"/>
  <attribute name="value" for="$tenirFlottants" expr="eval: true"/>
  <attribute name="value" for="$tenirCdes" expr="eval: true"/>
  <attribute name="value" for="$afficherNegatif" expr="eval: false"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reappro-periode-reappro', 'action-attrs', NULL,
'<action-attrs name="action-lvme-reappro-periode-reappro">
  <attribute name="value" for="$reapproDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][reapproPeriode as Integer]"/>
  <attribute name="value" for="$reapproAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][reapproPeriode as Integer]"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reappro-periode-stats', 'action-attrs', NULL,
'<action-attrs name="action-lvme-reappro-periode-stats">
  <attribute name="value" for="$statsDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][statsPeriode as Integer]"/>
  <attribute name="value" for="$statsAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][statsPeriode as Integer]"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reappro-lancer', 'action-method', NULL,
'<action-method name="action-lvme-reappro-lancer">
  <call class="com.axelor.apps.supplychain.web.LvmeReapproController" method="lancer"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reappro-dashlet', 'action-view',
 'com.axelor.apps.supplychain.db.ReapproLigne',
'<action-view name="action-lvme-reappro-dashlet" title="Réapprovisionnements" model="com.axelor.apps.supplychain.db.ReapproLigne">
  <view type="grid" name="lvme-reappro-grid"/>
  <view-param name="popup" value="true"/>
  <domain>self.utilisateur = :__user__</domain>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-besoins-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-etat-besoins-open" title="Etat des besoins" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-etat-besoins-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-besoins-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-etat-besoins-defaults">
  <attribute name="value" for="$dateDu" expr="eval: __date__.withDayOfYear(1)"/>
  <attribute name="value" for="$dateAu" expr="eval: __date__"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-besoins-periode-n', 'action-attrs', NULL,
'<action-attrs name="action-lvme-etat-besoins-periode-n">
  <attribute name="value" for="$dateDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][datePeriode as Integer]"/>
  <attribute name="value" for="$dateAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][datePeriode as Integer]"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-besoins-periode-n1', 'action-attrs', NULL,
'<action-attrs name="action-lvme-etat-besoins-periode-n1">
  <attribute name="value" for="$dateDuN1" expr="eval: [1: __date__.minusYears(1).withDayOfMonth(1), 2: __date__.minusYears(1).minusMonths(3), 3: __date__.minusYears(1).minusMonths(6), 4: __date__.minusYears(1).withDayOfYear(1), 5: __date__.minusYears(1).minusMonths(12)][periodeN1 as Integer]"/>
  <attribute name="value" for="$dateAuN1" expr="eval: [1: __date__.minusYears(1).withDayOfMonth(__date__.minusYears(1).lengthOfMonth()), 2: __date__.minusYears(1), 3: __date__.minusYears(1), 4: __date__.minusYears(1).withMonth(12).withDayOfMonth(31), 5: __date__.minusYears(1)][periodeN1 as Integer]"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-besoins-periode-reappro', 'action-attrs', NULL,
'<action-attrs name="action-lvme-etat-besoins-periode-reappro">
  <attribute name="value" for="$dateDuReappro" expr="eval: [1: __date__.minusYears(1).withDayOfMonth(1), 2: __date__.minusYears(1).minusMonths(3), 3: __date__.minusYears(1).minusMonths(6), 4: __date__.minusYears(1).withDayOfYear(1), 5: __date__.minusYears(1).minusMonths(12)][periodeReappro as Integer]"/>
  <attribute name="value" for="$dateAuReappro" expr="eval: [1: __date__.minusYears(1).withDayOfMonth(__date__.minusYears(1).lengthOfMonth()), 2: __date__.minusYears(1), 3: __date__.minusYears(1), 4: __date__.minusYears(1).withMonth(12).withDayOfMonth(31), 5: __date__.minusYears(1)][periodeReappro as Integer]"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-besoins-imprimer', 'action-method', NULL,
'<action-method name="action-lvme-etat-besoins-imprimer">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerEtatBesoins"/>
</action-method>', false, false, 0);

DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-reappro-form', 'lvme-reappro-grid', 'lvme-etat-besoins-form');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-reappro-form', 'Aides aux Réapprovisionnements', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fReappro'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-reappro-grid', 'Aides aux Réapprovisionnements', 'grid',
 'com.axelor.apps.supplychain.db.ReapproLigne', 20, current_setting('lvme.gReappro'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-etat-besoins-form', 'Etat des besoins', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fBesoins'), false, false);

DELETE FROM meta_menu WHERE name IN ('lvme-menu-reappro', 'lvme-menu-etat-besoins');
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, hidden, left_menu, mobile_menu, priority)
SELECT nextval('meta_menu_seq'), 0, now(), m.nom, m.titre,
  (SELECT id FROM meta_menu WHERE name = 'stock-root' ORDER BY id LIMIT 1),
  (SELECT id FROM meta_action WHERE module IS NULL AND name = m.action),
  coalesce((SELECT order_seq FROM meta_menu WHERE name = 'lvme-menu-interrogation-produit'), 53) + m.rang,
  false, true, false, 0
FROM (VALUES ('lvme-menu-reappro', 'Aides aux Réapprovisionnements', 'action-lvme-reappro-open', 1),
             ('lvme-menu-etat-besoins', 'Etat des besoins', 'action-lvme-etat-besoins-open', 2)) m(nom, titre, action, rang);

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL
          AND name IN ('lvme-reappro-form', 'lvme-reappro-grid', 'lvme-etat-besoins-form')) AS vues,
       (SELECT count(*) FROM meta_menu WHERE name IN ('lvme-menu-reappro', 'lvme-menu-etat-besoins')
          AND action IS NOT NULL) AS menus,
       (SELECT count(*) FROM meta_action WHERE module IS NULL
          AND (name LIKE 'action-lvme-reappro-%' OR name LIKE 'action-lvme-etat-besoins-%')) AS actions;

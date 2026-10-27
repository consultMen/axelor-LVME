-- =====================================================================
-- PROD étape 96 : « Palmarès Client / Produits par Tonnage pour établissement Prix », comme GESCOM (diapos 50-51)
--   - écran : Date du / au, période ; cadre Client (client, famille, commercial du / au, pays, groupement principal) ;
--     cadre Produit (produit, famille, fournisseur, origine, conditionnement) ; Valider
--   - Valider = impression « Palmarès Clients par Produits » : par client (classés par tonnage), ses produits classés
--     par tonnage avec Nb colis, Qtés en UV, Unité, Poids KG, C.A. HT, dernière date, prix à l'U.V., rangs, totaux ;
--     ventes = lignes des commandes clients confirmées ou terminées, à la date du BL (sinon de la commande)
--   - menu Ventes > Palmarès Client / Produits
-- Prérequis : code avec LvmeImpressionListesController.imprimerPalmaresClients et
-- reports/LvmePalmaresClientsProduits.rptdesign (recompiler). Source : livrables/ui/lvme-palmares-clients-form.xml.
-- Relançable.
-- =====================================================================
\set fPalm `cat livrables/ui/lvme-palmares-clients-form.xml`
SELECT set_config('lvme.fPalm', :'fPalm', false) IS NOT NULL AS vue_lue;

BEGIN;

UPDATE meta_menu SET action = NULL WHERE action IN (SELECT id FROM meta_action WHERE module IS NULL
  AND name = 'action-lvme-palmares-clients-open');
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-palmares-clients-open',
  'action-lvme-palmares-clients-defaults', 'action-lvme-palmares-clients-periode', 'action-lvme-palmares-clients-imprimer');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-palmares-clients-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-palmares-clients-open" title="Palmarès Client / Produits" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-palmares-clients-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-palmares-clients-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-palmares-clients-defaults">
  <attribute name="value" for="$dateDu" expr="eval: __date__.withDayOfMonth(1)"/>
  <attribute name="value" for="$dateAu" expr="eval: __date__"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-palmares-clients-periode', 'action-attrs', NULL,
'<action-attrs name="action-lvme-palmares-clients-periode">
  <attribute name="value" for="$dateDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][datePeriode as Integer]"/>
  <attribute name="value" for="$dateAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][datePeriode as Integer]"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-palmares-clients-imprimer', 'action-method', NULL,
'<action-method name="action-lvme-palmares-clients-imprimer">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerPalmaresClients"/>
</action-method>', false, false, 0);

DELETE FROM meta_view WHERE module IS NULL AND name = 'lvme-palmares-clients-form';
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-palmares-clients-form', 'Palmarès Client / Produits', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fPalm'), false, false);

DELETE FROM meta_menu WHERE name = 'lvme-menu-palmares-clients';
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, hidden, left_menu, mobile_menu, priority)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-palmares-clients', 'Palmarès Client / Produits',
  (SELECT id FROM meta_menu WHERE name = 'sc-root-sale' ORDER BY id LIMIT 1),
  (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-palmares-clients-open'),
  coalesce((SELECT order_seq + 1 FROM meta_menu WHERE name = 'lvme-menu-palmares-vente'), 670), false, true, false, 0;

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND name = 'lvme-palmares-clients-form') AS vue,
       (SELECT count(*) FROM meta_menu WHERE name = 'lvme-menu-palmares-clients' AND action IS NOT NULL) AS menu,
       (SELECT count(*) FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-palmares-clients-%') AS actions;

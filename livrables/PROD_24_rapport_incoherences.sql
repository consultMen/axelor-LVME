-- =====================================================================
-- PROD étape 24 : REC-012 « Rapport d'incohérences » (Ventes > Rapport d'incohérences)
--   Commandes VS Réceptions VS BL VS Facturé (cahier de recette REC-012 ; cahier des charges p. 6-7) :
--   1 Cde client commandé ≠ livré, 2 BL livré ≠ facturé, 3 Cde fournisseur commandé ≠ reçu
--   (quantité, colis, produit non commandé / différent), 4 Réception reçu ≠ facturé,
--   5 Prix facturé ≠ prix de la commande.
--   - vue SQL lvme_incoherence (modèle Incoherence, déclaré dans le code)
-- À lancer depuis la racine du dépôt, AVANT le redémarrage d'Axelor. Relançable. Une seule transaction.
-- =====================================================================
\set form `cat livrables/ui/incoherence-search-form.xml`
\set grille `cat livrables/ui/incoherence-grid.xml`
\set fiche `cat livrables/ui/incoherence-form.xml`
SELECT set_config('lvme.form', :'form', false), set_config('lvme.grille', :'grille', false),
       set_config('lvme.fiche', :'fiche', false);

BEGIN;

-- ---------- Vue SQL ----------
\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_incoherence.sql

-- ---------- Liste de choix « Type d'écart » ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.incoherence.type.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.incoherence.type.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('1', 'Cde client : commandé ≠ livré', 1),
             ('2', 'BL : livré ≠ facturé', 2),
             ('3', 'Cde fournisseur : commandé ≠ reçu', 3),
             ('4', 'Réception : reçu ≠ facturé', 4),
             ('5', 'Prix facturé ≠ prix de la commande', 5)) AS v(value, title, seq) ON true
WHERE s.name = 'lvme.incoherence.type.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- ---------- Actions ----------
UPDATE meta_menu SET action = NULL
WHERE action IN (SELECT id FROM meta_action WHERE name = 'action-lvme-incoherence-open' AND module IS NULL);
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-incoherence-open',
  'action-lvme-incoherence-dashlet', 'action-lvme-incoherence-refresh', 'action-lvme-incoherence-defaults',
  'action-lvme-incoherence-group-onnew', 'action-lvme-incoherence-periode', 'action-lvme-incoherence-group-periode');

INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-incoherence-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-incoherence-open" title="Rapport d''incohérences" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-incoherence-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-incoherence-dashlet', 'action-view', 'com.axelor.apps.supplychain.db.Incoherence',
'<action-view name="action-lvme-incoherence-dashlet" title="Incohérence" model="com.axelor.apps.supplychain.db.Incoherence">
  <view type="grid" name="lvme-incoherence-grid"/>
  <view type="form" name="lvme-incoherence-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="forceTitle" value="true"/>
  <domain>(:_type = 0 OR self.typeEcart = :_type)
    AND (:_tiers = 0 OR self.partner.id = :_tiers)
    AND (:_dateFiltre = false OR self.dateDoc BETWEEN :_du AND :_au)</domain>
  <context name="_type" expr="eval: (typeEcart ?: 0) as Integer"/>
  <context name="_tiers" expr="eval: (tiers?.id ?: 0) as Long"/>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_du" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_au" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-incoherence-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-incoherence-refresh">
  <attribute name="refresh" for="incoherencesDashlet" expr="eval: true"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-incoherence-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-incoherence-defaults">
  <attribute name="value" for="$dateDu" expr="eval: __date__.minusMonths(3)"/>
  <attribute name="value" for="$dateAu" expr="eval: __date__"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-incoherence-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-incoherence-group-onnew">
  <action name="action-lvme-incoherence-defaults"/>
  <action name="action-lvme-incoherence-refresh"/>
</action-group>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-incoherence-periode', 'action-attrs', NULL,
'<action-attrs name="action-lvme-incoherence-periode">
  <attribute name="value" for="$dateDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][datePeriode as Integer]"/>
  <attribute name="value" for="$dateAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][datePeriode as Integer]"/>
</action-attrs>', false, false),

(nextval('meta_action_seq'), 0, now(), 'action-lvme-incoherence-group-periode', 'action-group', NULL,
'<action-group name="action-lvme-incoherence-group-periode">
  <action name="action-lvme-incoherence-periode"/>
  <action name="action-lvme-incoherence-refresh"/>
</action-group>', false, false);

-- ---------- Vues ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-incoherence-search-form', 'lvme-incoherence-grid',
  'lvme-incoherence-form');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-incoherence-search-form', 'Rapport d''incohérences', 'form', 'com.axelor.utils.db.Wizard', 20,
 current_setting('lvme.form'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-incoherence-grid', 'Incohérences', 'grid', 'com.axelor.apps.supplychain.db.Incoherence', 20,
 current_setting('lvme.grille'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-incoherence-form', 'Incohérence', 'form', 'com.axelor.apps.supplychain.db.Incoherence', 20,
 current_setting('lvme.fiche'), false, false);

-- ---------- Menu Ventes > Rapport d'incohérences ----------
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, priority, hidden, left_menu, mobile_menu, tag_count)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-rapport-incoherences', 'Rapport d''incohérences',
       (SELECT id FROM meta_menu WHERE name = 'sc-root-sale' ORDER BY priority DESC LIMIT 1), NULL, 1030, 0, false, true, false, false
WHERE NOT EXISTS (SELECT 1 FROM meta_menu WHERE name = 'lvme-menu-rapport-incoherences');
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE name = 'action-lvme-incoherence-open' AND module IS NULL)
WHERE name = 'lvme-menu-rapport-incoherences';

COMMIT;

SELECT type_ecart, count(*) AS nb FROM lvme_incoherence GROUP BY type_ecart ORDER BY type_ecart;

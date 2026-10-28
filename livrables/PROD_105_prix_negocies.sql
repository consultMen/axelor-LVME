-- =====================================================================
-- PROD étape 105 : écran « Prix négociés » (PRIX_NEGOC / PRIX_NEGOCE_COUT de GESCOM, repris par MIG_08)
--   - filtres : client, produit, prix en vigueur à une date, période étudiée ; Lancer la recherche, Imprimer,
--     Fermer(F12) ; liste aux colonnes GESCOM (ventes de la période, prix négocié et sa période, coûts) ; fiche en
--     fenêtre modifiable ; nouvelle ligne possible
--   - impression « Prix négociés » par client (LvmePrixNegocies.rptdesign, logo LVME)
--   - menu Ventes > Prix négociés
--   Le prix négocié n'est pas encore proposé sur la ligne de commande client (décision du 28/10/2026).
-- Prérequis : code avec le modèle PrixNegocie, imprimerPrixNegocies et le modèle d'impression (recompiler).
-- À lancer depuis la racine du dépôt. Sources : livrables/ui/lvme-prix-negocie-search-form.xml, -grid.xml,
-- -form.xml. Relançable.
-- =====================================================================
\set fRech `cat livrables/ui/lvme-prix-negocie-search-form.xml`
SELECT set_config('lvme.fRechPN', :'fRech', false) IS NOT NULL AS vue_lue;
\set gPN `cat livrables/ui/lvme-prix-negocie-grid.xml`
SELECT set_config('lvme.gPN', :'gPN', false) IS NOT NULL AS liste_lue;
\set fPN `cat livrables/ui/lvme-prix-negocie-form.xml`
SELECT set_config('lvme.fPN', :'fPN', false) IS NOT NULL AS fiche_lue;

BEGIN;

UPDATE meta_menu SET action = NULL WHERE action IN (SELECT id FROM meta_action WHERE module IS NULL
  AND name = 'action-lvme-prix-negocie-open');
DELETE FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-prix-negocie-%';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-prix-negocie-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-prix-negocie-open" title="Prix négociés" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-prix-negocie-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-prix-negocie-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-prix-negocie-defaults">
  <attribute name="value" for="$enVigueur" expr="eval: false"/>
  <attribute name="value" for="$dateVigueur" expr="eval: __date__"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-prix-negocie-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-prix-negocie-refresh">
  <attribute name="refresh" for="prixNegocieDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-prix-negocie-dashlet', 'action-view',
 'com.axelor.apps.supplychain.db.PrixNegocie',
'<action-view name="action-lvme-prix-negocie-dashlet" title="Prix négociés" model="com.axelor.apps.supplychain.db.PrixNegocie">
  <view type="grid" name="lvme-prix-negocie-grid"/>
  <view type="form" name="lvme-prix-negocie-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <domain>(:_client = 0 OR self.client.id = :_client)
    AND (:_prod = 0 OR self.product.id = :_prod)
    AND (:_vig = false OR (self.prixNegocie IS NOT NULL
      AND (self.dateDebNeg IS NULL OR self.dateDebNeg &lt;= :_dv) AND (self.dateFinNeg IS NULL OR self.dateFinNeg &gt;= :_dv)))
    AND (:_sf = false OR (self.dateFinStats &gt;= :_du AND self.dateDebStats &lt;= :_au))</domain>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_prod" expr="eval: (produit?.id ?: 0) as Long"/>
  <context name="_vig" expr="eval: enVigueur == true"/>
  <context name="_dv" expr="eval: dateVigueur ? java.time.LocalDate.parse(dateVigueur.toString().substring(0, 10)) : __date__"/>
  <context name="_sf" expr="eval: statsDu != null || statsAu != null"/>
  <context name="_du" expr="eval: statsDu ? java.time.LocalDate.parse(statsDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_au" expr="eval: statsAu ? java.time.LocalDate.parse(statsAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-prix-negocie-imprimer', 'action-method', NULL,
'<action-method name="action-lvme-prix-negocie-imprimer">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerPrixNegocies"/>
</action-method>', false, false, 0);

DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-prix-negocie-search-form', 'lvme-prix-negocie-grid',
  'lvme-prix-negocie-form');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-prix-negocie-search-form', 'Prix négociés', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fRechPN'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-prix-negocie-grid', 'Prix négociés', 'grid',
 'com.axelor.apps.supplychain.db.PrixNegocie', 20, current_setting('lvme.gPN'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-prix-negocie-form', 'Prix négocié', 'form',
 'com.axelor.apps.supplychain.db.PrixNegocie', 20, current_setting('lvme.fPN'), false, false);

DELETE FROM meta_menu WHERE name = 'lvme-menu-prix-negocies';
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, hidden, left_menu, mobile_menu, priority)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-prix-negocies', 'Prix négociés',
  (SELECT id FROM meta_menu WHERE name = 'sc-root-sale' ORDER BY id LIMIT 1),
  (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-prix-negocie-open'),
  coalesce((SELECT order_seq + 1 FROM meta_menu WHERE name = 'lvme-menu-palmares-clients'), 1012), false, true, false, 0;

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND name LIKE 'lvme-prix-negocie-%') AS vues,
       (SELECT count(*) FROM meta_menu WHERE name = 'lvme-menu-prix-negocies' AND action IS NOT NULL) AS menu,
       (SELECT count(*) FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-prix-negocie-%') AS actions;

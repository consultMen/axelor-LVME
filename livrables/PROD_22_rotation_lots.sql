-- =====================================================================
-- PROD étape 22 : REC-012 « Rotation de Stock » par lot (écran GESCOM) + palmarès dans Ventes
--   - vue SQL lvme_rotation_lot (modèle RotationLot)
--   - écran Stock > Rotation des stocks : les 4 KPI restent en haut ; bascule
--     « Par lot » (colonnes GESCOM, Nbre jours rotation) / « Par produit » (tableau REC-003)
--   - filtres GESCOM : Article du/au, Fournisseur du/au, Fam. article, Origine, Frigo, Entrée du/au
--   - menus Palmarès des ventes / Palmarès par commercial : de Ventes > Configuration vers Ventes
-- Transforme la version ACTUELLE de l'écran (le panneau des 4 KPI n'est pas modifié).
-- À lancer depuis la racine du dépôt, AVANT le redémarrage d'Axelor. Relançable. Une seule transaction.
-- =====================================================================
\set lotGrid `cat livrables/ui/rotation-lot-grid.xml`
\set filtres `cat livrables/ui/rotation-stock-filtres.xml`
SELECT set_config('lvme.lotGrid', :'lotGrid', false), set_config('lvme.filtres', :'filtres', false);

BEGIN;

-- ---------- Vue SQL ----------
\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_rotation_lot.sql

-- ---------- Liste de choix « Affichage » ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.rotation.affichage.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.rotation.affichage.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('1', 'Par lot', 1), ('2', 'Par produit (indicateurs)', 2)) AS v(value, title, seq) ON true
WHERE s.name = 'lvme.rotation.affichage.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- ---------- Actions ----------
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-rotation-lot-dashlet',
  'action-lvme-rotation-lot-defaults', 'action-lvme-rotation-lot-group-periode-entree',
  'action-lvme-rotation-stock-refresh', 'action-lvme-rotation-stock-group-onnew');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-lot-dashlet', 'action-view', 'com.axelor.apps.supplychain.db.RotationLot',
'<action-view name="action-lvme-rotation-lot-dashlet" title="Rotation de stock par lot"
  model="com.axelor.apps.supplychain.db.RotationLot">
  <view type="grid" name="lvme-rotation-lot-grid"/>
  <domain>(:_artDu = '''' OR self.productCode &gt;= :_artDu) AND (:_artAu = '''' OR self.productCode &lt;= :_artAu)
    AND (:_fouDu = '''' OR self.supplierName &gt;= :_fouDu) AND (:_fouAu = '''' OR self.supplierName &lt;= :_fouAu)
    AND (:_famille = 0 OR self.productCategory.id = :_famille)
    AND (:_frigo = 0 OR self.stockLocation.id = :_frigo)
    AND (:_origine = '''' OR self.origine = :_origine)
    AND (:_entreeFiltre = false OR self.arrivalDate BETWEEN :_entreeDu AND :_entreeAu)</domain>
  <context name="_artDu" expr="eval: articleDu?.id ? (__repo__(Product).find(articleDu.id as Long)?.code ?: '''') : ''''"/>
  <context name="_artAu" expr="eval: articleAu?.id ? (__repo__(Product).find(articleAu.id as Long)?.code ?: '''') : (articleDu?.id ? (__repo__(Product).find(articleDu.id as Long)?.code ?: '''') : '''')"/>
  <context name="_fouDu" expr="eval: fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.fullName ?: '''') : ''''"/>
  <context name="_fouAu" expr="eval: fournisseurAu?.id ? (__repo__(Partner).find(fournisseurAu.id as Long)?.fullName ?: '''') : (fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.fullName ?: '''') : '''')"/>
  <context name="_famille" expr="eval: (famille?.id ?: 0) as Long"/>
  <context name="_frigo" expr="eval: (frigo?.id ?: 0) as Long"/>
  <context name="_origine" expr="eval: origine ? origine.toString() : ''''"/>
  <context name="_entreeFiltre" expr="eval: entreeDu != null || entreeAu != null"/>
  <context name="_entreeDu" expr="eval: entreeDu ? java.time.LocalDate.parse(entreeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_entreeAu" expr="eval: entreeAu ? java.time.LocalDate.parse(entreeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-lot-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-rotation-lot-defaults">
  <attribute name="value" for="$affichage" expr="eval: 1"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-lot-group-periode-entree', 'action-group', NULL,
'<action-group name="action-lvme-rotation-lot-group-periode-entree">
  <action name="action-lvme-etat-stock-lot-periode-entree"/>
  <action name="action-lvme-rotation-stock-refresh"/>
</action-group>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-stock-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-rotation-stock-refresh">
  <attribute name="refresh" for="rotationDashlet" expr="eval: true"/>
  <attribute name="refresh" for="rotationLotDashlet" expr="eval: true"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-stock-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-rotation-stock-group-onnew">
  <action name="action-lvme-rotation-lot-defaults"/>
  <action name="action-lvme-rotation-stock-kpi"/>
</action-group>', false, false);

-- ---------- Grille par lot ----------
DELETE FROM meta_view WHERE module IS NULL AND name = 'lvme-rotation-lot-grid';
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-rotation-lot-grid', 'Rotation de stock par lot', 'grid',
 'com.axelor.apps.supplychain.db.RotationLot', 20, current_setting('lvme.lotGrid'), false, false);

-- ---------- Écran : filtres + tableaux (le panneau des 4 KPI est conservé) ----------
DO $$
DECLARE v_id bigint; v_xml text; a int; n int;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'lvme-rotation-stock-dashboard-form' AND module IS NULL;
  IF v_id IS NULL THEN RAISE EXCEPTION 'lvme-rotation-stock-dashboard-form introuvable : arrêt'; END IF;
  IF position('kpiPanel' IN v_xml) = 0 THEN RAISE EXCEPTION 'panneau des KPI absent : arrêt, rien n''est modifié'; END IF;
  SELECT count(*) INTO n FROM regexp_matches(v_xml, '<panel name="filtresPanel"', 'g');
  IF n <> 1 THEN RAISE EXCEPTION 'panneau des filtres trouvé % fois (1 attendu) : arrêt', n; END IF;
  a := position('<panel name="filtresPanel"' IN v_xml);
  v_xml := substr(v_xml, 1, a - 1) || current_setting('lvme.filtres');
  UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  RAISE NOTICE 'Écran Rotation des stocks : affichage par lot ajouté, KPI conservés';
END $$;

-- ---------- Palmarès : dans le menu Ventes ----------
UPDATE meta_menu SET parent = (SELECT id FROM meta_menu WHERE name = 'sc-root-sale' ORDER BY priority DESC LIMIT 1), order_seq = 1010
WHERE name = 'lvme-menu-palmares-vente' AND EXISTS (SELECT 1 FROM meta_menu WHERE name = 'sc-root-sale');
UPDATE meta_menu SET parent = (SELECT id FROM meta_menu WHERE name = 'sc-root-sale' ORDER BY priority DESC LIMIT 1), order_seq = 1020
WHERE name = 'lvme-menu-palmares-commercial' AND EXISTS (SELECT 1 FROM meta_menu WHERE name = 'sc-root-sale');

COMMIT;

SELECT m.name, p.name AS parent, m.order_seq FROM meta_menu m LEFT JOIN meta_menu p ON p.id = m.parent
WHERE m.name LIKE 'lvme-menu-palmares%';
SELECT count(*) AS lots_rotation FROM lvme_rotation_lot;

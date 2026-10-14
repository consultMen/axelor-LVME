-- =====================================================================
-- PROD étape 44 : boutons de la fiche Ligne d'arrivage ouverts sur l'article de la ligne
--   - « Historique produit » : écran Historique Produit déjà rempli avec l'article de la ligne,
--     historique et totaux affichés
--   - « État des stocks par lots » : écran filtré sur l'article de la ligne (Article du / au)
--   Ouverts depuis le menu, les deux écrans restent vides comme avant.
-- Les boutons de la fiche ligne (PROD_42 / livrables/ui/arrivage-line-form.xml) appellent ces actions.
-- Avec le code de ce lot (LvmeHistoriqueProduitController). Relançable.
-- =====================================================================
BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name IN (
  'action-lvme-ligne-historique-produit', 'action-lvme-ligne-etat-stock-lot',
  'action-lvme-historique-produit-depuis-ligne', 'action-lvme-historique-produit-group-onnew',
  'action-lvme-etat-stock-lot-depuis-ligne');

INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-historique-produit', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-ligne-historique-produit" title="Historique Produit" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-historique-produit-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_produitId" expr="eval: product?.id"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-etat-stock-lot', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-ligne-etat-stock-lot" title="État des stocks par lots" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-etat-stock-lot-search-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_produitId" expr="eval: product?.id"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-depuis-ligne', 'action-attrs', NULL,
'<action-attrs name="action-lvme-historique-produit-depuis-ligne">
  <attribute name="value" for="$produit" expr="eval: __repo__(com.axelor.apps.base.db.Product).find(_produitId as Long)"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-historique-produit-group-onnew">
  <action name="action-lvme-historique-produit-defaults"/>
  <action name="action-lvme-historique-produit-depuis-ligne" if="_produitId"/>
  <action name="action-lvme-historique-produit-designation" if="_produitId"/>
  <action name="action-lvme-historique-produit-valider" if="_produitId"/>
</action-group>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-depuis-ligne', 'action-attrs', NULL,
'<action-attrs name="action-lvme-etat-stock-lot-depuis-ligne">
  <attribute name="value" for="$articleDu" expr="eval: __repo__(com.axelor.apps.base.db.Product).find(_produitId as Long)"/>
  <attribute name="value" for="$articleAu" expr="eval: __repo__(com.axelor.apps.base.db.Product).find(_produitId as Long)"/>
</action-attrs>', false, false, 0);

DO $$
DECLARE v_id bigint; v_xml text;
BEGIN
  -- Historique Produit : ouverture par le nouveau groupe (défauts + article de la ligne s'il y en a un)
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE module IS NULL AND name = 'lvme-historique-produit-form';
  IF v_id IS NULL THEN RAISE EXCEPTION 'lvme-historique-produit-form introuvable : arrêt'; END IF;
  IF position('action-lvme-historique-produit-group-onnew' IN v_xml) = 0 THEN
    IF position('onNew="action-lvme-historique-produit-defaults"' IN v_xml) = 0 THEN
      RAISE EXCEPTION 'onNew de l''Historique Produit non reconnu : arrêt';
    END IF;
    v_xml := replace(v_xml, 'onNew="action-lvme-historique-produit-defaults"', 'onNew="action-lvme-historique-produit-group-onnew"');
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  END IF;

  -- État des stocks par lots : article de la ligne en fin d'ouverture, puis rafraîchissement de la liste
  SELECT id, xml INTO v_id, v_xml FROM meta_action WHERE module IS NULL AND name = 'action-lvme-etat-stock-lot-group-onnew';
  IF v_id IS NULL THEN RAISE EXCEPTION 'action-lvme-etat-stock-lot-group-onnew introuvable : arrêt'; END IF;
  IF position('action-lvme-etat-stock-lot-depuis-ligne' IN v_xml) = 0 THEN
    v_xml := replace(v_xml, '</action-group>', '  <action name="action-lvme-etat-stock-lot-depuis-ligne" if="_produitId"/>
  <action name="action-lvme-etat-stock-lot-refresh" if="_produitId"/>
</action-group>');
    UPDATE meta_action SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  END IF;
END $$;

COMMIT;

SELECT name FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-ligne-%' ORDER BY name;

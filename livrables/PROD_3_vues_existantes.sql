-- =====================================================================
-- PROD étape 3 : modifications des 3 vues existantes (identiques à ce qui est testé en local)
--   1. stock-move-line-form : conditionnement de la commande client sur le BL + Marge HT / % Marge
--   2. sale-order-line-grid (vue calculée) : bouton « Dupliquer la ligne »
--   3. purchase-order-line-purchase-order-grid (vue calculée) : bouton « Dupliquer la ligne »
--   + 2 vues extension (admin) pour que le bouton survive à une mise à jour des modules.
-- Chaque modification n'est faite que si son point d'ancrage est trouvé une seule fois
-- et si elle n'a pas déjà été faite (relançable). Une seule transaction.
-- À lancer APRÈS PROD_2_ecrans_admin.sql (les actions du bouton doivent exister).
-- =====================================================================
BEGIN;

DO $$
DECLARE
  v_id bigint; v_xml text; n int;
  a_spacer constant text := '<spacer name="spacerPrices" colSpan="3"/>';
  a_cong constant text := '<field name="dateCongelation"';
BEGIN
  -- 1. stock-move-line-form (vue de base du module axelor-stock)
  SELECT id, xml INTO v_id, v_xml FROM meta_view
   WHERE name = 'stock-move-line-form' AND module = 'axelor-stock' AND COALESCE(computed, false) = false;
  IF v_id IS NULL THEN
    RAISE NOTICE '1. stock-move-line-form introuvable : rien fait';
  ELSIF v_xml LIKE '%margeHt%' THEN
    RAISE NOTICE '1. stock-move-line-form déjà modifiée : rien fait';
  ELSIF (length(v_xml) - length(replace(v_xml, a_spacer, ''))) / length(a_spacer) <> 1
     OR (length(v_xml) - length(replace(v_xml, a_cong, ''))) / length(a_cong) <> 1 THEN
    RAISE EXCEPTION '1. stock-move-line-form : points d''ancrage non trouvés une seule fois, arrêt';
  ELSE
    v_xml := replace(v_xml, a_cong,
      '<field name="saleOrderLine.conditionnement" title="Conditionnement" colSpan="3" readonly="true"'
      || ' showIf="saleOrderLine != null &amp;&amp; purchaseOrderLine == null"/>' || chr(10) || '      ' || a_cong);
    v_xml := replace(v_xml, a_spacer,
      '<field name="margeHt" title="Marge HT (€)" colSpan="3" readonly="true" x-scale="2" showIf="saleOrderLine != null"/>'
      || chr(10) || '      <field name="tauxMarge" title="% Marge" colSpan="3" readonly="true" x-scale="2" showIf="saleOrderLine != null"/>');
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
    RAISE NOTICE '1. stock-move-line-form modifiée (conditionnement + marge)';
  END IF;

  -- 2. sale-order-line-grid (vue calculée = celle servie à l'écran)
  FOR v_id, v_xml IN SELECT id, xml FROM meta_view WHERE name = 'sale-order-line-grid' AND computed = true LOOP
    IF v_xml LIKE '%lvmeDuplicateLineBtn%' THEN
      RAISE NOTICE '2. sale-order-line-grid (id %) déjà modifiée', v_id;
    ELSIF (length(v_xml) - length(replace(v_xml, '</grid>', ''))) / 7 <> 1 THEN
      RAISE EXCEPTION '2. sale-order-line-grid : balise </grid> non unique, arrêt';
    ELSE
      UPDATE meta_view SET xml = replace(v_xml, '</grid>',
        '  <button name="lvmeDuplicateLineBtn" title="Dupliquer la ligne" icon="fa-copy" readonlyIf="id == null || $get(''saleOrder.statusSelect'') &gt; 2" onClick="save,action-lvme-sale-order-line-method-duplicate"/>'
        || chr(10) || '</grid>'), updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
      RAISE NOTICE '2. sale-order-line-grid (id %) : bouton Dupliquer ajouté', v_id;
    END IF;
  END LOOP;

  -- 3. purchase-order-line-purchase-order-grid (vue calculée)
  FOR v_id, v_xml IN SELECT id, xml FROM meta_view WHERE name = 'purchase-order-line-purchase-order-grid' AND computed = true LOOP
    IF v_xml LIKE '%lvmeDuplicateLineBtn%' THEN
      RAISE NOTICE '3. purchase-order-line-purchase-order-grid (id %) déjà modifiée', v_id;
    ELSIF (length(v_xml) - length(replace(v_xml, '</grid>', ''))) / 7 <> 1 THEN
      RAISE EXCEPTION '3. purchase-order-line-purchase-order-grid : balise </grid> non unique, arrêt';
    ELSE
      UPDATE meta_view SET xml = replace(v_xml, '</grid>',
        '  <field name="purchaseOrder.statusSelect" hidden="true"/>' || chr(10)
        || '  <button name="lvmeDuplicateLineBtn" title="Dupliquer la ligne" icon="fa-copy" readonlyIf="id == null || $get(''purchaseOrder.statusSelect'') &gt; 2" onClick="save,action-lvme-purchase-order-line-method-duplicate"/>'
        || chr(10) || '</grid>'), updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
      RAISE NOTICE '3. purchase-order-line-purchase-order-grid (id %) : bouton Dupliquer ajouté', v_id;
    END IF;
  END LOOP;
END $$;

-- Vues extension (admin) : gardent le bouton lors d'un recalcul des vues
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed, xml_id)
SELECT nextval('meta_view_seq'), 0, now(), 'sale-order-line-grid', 'SO lines', 'grid', 'com.axelor.apps.sale.db.SaleOrderLine', 20,
'<grid name="sale-order-line-grid" id="lvme-sale-order-line-grid-duplicate" title="SO lines"
  model="com.axelor.apps.sale.db.SaleOrderLine" extension="true">
  <extend target="/">
    <insert position="inside">
      <button name="lvmeDuplicateLineBtn" title="Dupliquer la ligne" icon="fa-copy"
        readonlyIf="id == null || $get(''saleOrder.statusSelect'') &gt; 2"
        onClick="save,action-lvme-sale-order-line-method-duplicate"/>
    </insert>
  </extend>
</grid>', true, false, 'lvme-sale-order-line-grid-duplicate'
WHERE NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'sale-order-line-grid' AND module IS NULL);

INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed, xml_id)
SELECT nextval('meta_view_seq'), 0, now(), 'purchase-order-line-purchase-order-grid', 'PO lines', 'grid', 'com.axelor.apps.purchase.db.PurchaseOrderLine', 20,
'<grid name="purchase-order-line-purchase-order-grid" id="lvme-purchase-order-line-grid-duplicate"
  title="PO lines" model="com.axelor.apps.purchase.db.PurchaseOrderLine" extension="true">
  <extend target="/">
    <insert position="inside">
      <field name="purchaseOrder.statusSelect" hidden="true"/>
      <button name="lvmeDuplicateLineBtn" title="Dupliquer la ligne" icon="fa-copy"
        readonlyIf="id == null || $get(''purchaseOrder.statusSelect'') &gt; 2"
        onClick="save,action-lvme-purchase-order-line-method-duplicate"/>
    </insert>
  </extend>
</grid>', true, false, 'lvme-purchase-order-line-grid-duplicate'
WHERE NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'purchase-order-line-purchase-order-grid' AND module IS NULL);

COMMIT;

-- Vérification : 1 = modifiée
SELECT name, priority, COALESCE(module, 'admin') AS module,
       (xml LIKE '%margeHt%' OR xml LIKE '%lvmeDuplicateLineBtn%')::int AS modifiee
FROM meta_view
WHERE (name = 'stock-move-line-form' AND module = 'axelor-stock')
   OR (name IN ('sale-order-line-grid', 'purchase-order-line-purchase-order-grid') AND (computed = true OR module IS NULL))
ORDER BY name, priority;

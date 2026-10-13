-- =====================================================================
-- PROD étape 36 : retour client scénario 1, point 13 — n° de lot dès la commande fournisseur
--   - ligne de commande fournisseur : champ « N° Lot » (fiche + colonne de la liste des lignes)
--   - au choix du produit : si l'article génère ses lots à l'achat (configuration de suivi),
--     un nouveau lot est créé et proposé ; sinon l'utilisateur choisit / crée le lot
--   - modifiable ; plusieurs lignes peuvent avoir le même lot
--   - à la création de l'arrivage, la ligne d'arrivage reprend ce lot (Java)
-- À lancer avec le code de ce lot, AVANT le redémarrage. Relançable.
-- =====================================================================
BEGIN;

-- ---------- Colonne ----------
ALTER TABLE purchase_purchase_order_line ADD COLUMN IF NOT EXISTS tracking_number bigint;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_lvme_pol_tracking_number') THEN
    ALTER TABLE purchase_purchase_order_line ADD CONSTRAINT fk_lvme_pol_tracking_number
      FOREIGN KEY (tracking_number) REFERENCES stock_tracking_number(id);
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS purchase_purchase_order_line_tracking_number_idx
  ON purchase_purchase_order_line (tracking_number);

-- ---------- Action : proposer le lot au choix du produit ----------
DELETE FROM meta_action WHERE module IS NULL AND name IN (
  'action-lvme-ligne-achat-proposer-lot', 'action-budget-group-purchase-purchase-orderline-product-onchange');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority)
VALUES (nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-achat-proposer-lot', 'action-method', NULL,
'<action-method name="action-lvme-ligne-achat-proposer-lot">
  <call class="com.axelor.apps.supplychain.web.LvmeLotCommandeAchatController" method="proposerLot"/>
</action-method>', false, false, 0);

-- copie admin (priorité 30) de l'action standard du choix du produit, action LVME ajoutée en fin
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority)
SELECT nextval('meta_action_seq'), 0, now(), a.name, a.type, a.model,
       replace(a.xml, '</action-group>', '  <action name="action-lvme-ligne-achat-proposer-lot"/>
</action-group>'), false, false, 30
FROM meta_action a
WHERE a.name = 'action-budget-group-purchase-purchase-orderline-product-onchange' AND a.module = 'axelor-budget';

DO $$
DECLARE v_id bigint; v_xml text; n int;
  v_lot_form constant text := '<field name="trackingNumber" title="N° Lot" colSpan="3" domain="self.product = :product" form-view="tracking-number-form" grid-view="tracking-number-grid"/>';
BEGIN
  SELECT count(*) INTO n FROM meta_action WHERE module IS NULL AND priority = 30
     AND name = 'action-budget-group-purchase-purchase-orderline-product-onchange';
  IF n <> 1 THEN RAISE EXCEPTION 'action standard du choix du produit introuvable : arrêt'; END IF;

  -- ---------- Fiche de la ligne (version calculée en place) : N° Lot après le conditionnement ----------
  SELECT id, xml INTO v_id, v_xml FROM meta_view
   WHERE name = 'purchase-order-line-form' AND xml_id = 'purchase-order-line-form__computed__';
  IF v_id IS NULL THEN RAISE EXCEPTION 'fiche purchase-order-line-form calculée introuvable : arrêt'; END IF;
  IF position('name="trackingNumber"' IN v_xml) = 0 THEN
    SELECT count(*) INTO n FROM regexp_matches(v_xml, '<field name="conditionnement"[^>]*/>', 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'champ conditionnement trouvé % fois dans la fiche : arrêt', n; END IF;
    v_xml := regexp_replace(v_xml, '(<field name="conditionnement"[^>]*/>)', chr(92) || '1
        ' || v_lot_form);
    -- la ligne garde sa largeur : l'espace qui suivait le conditionnement est réduit d'autant
    v_xml := replace(v_xml, '<spacer name="spacerRow0" colSpan="6"/>', '<spacer name="spacerRow0" colSpan="3"/>');
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  END IF;

  -- ---------- Liste des lignes (admin) : colonne N° Lot après Conditionn. ----------
  SELECT id, xml INTO v_id, v_xml FROM meta_view
   WHERE name = 'purchase-order-line-purchase-order-grid' AND module IS NULL AND priority = 30;
  IF v_id IS NULL THEN RAISE EXCEPTION 'liste des lignes de commande fournisseur (admin) introuvable : arrêt'; END IF;
  IF position('name="trackingNumber"' IN v_xml) = 0 THEN
    SELECT count(*) INTO n FROM regexp_matches(v_xml, '<field name="conditionnement"[^>]*/>', 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'colonne conditionnement trouvée % fois dans la liste : arrêt', n; END IF;
    v_xml := regexp_replace(v_xml, '(<field name="conditionnement"[^>]*/>)', chr(92) || '1
  <field name="trackingNumber" title="N° Lot" width="110"/>');
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  END IF;
END $$;

COMMIT;

SELECT name, coalesce(module, 'admin') AS origine, priority, position('name="trackingNumber"' IN xml) > 0 AS lot
FROM meta_view
WHERE (name = 'purchase-order-line-form' AND xml_id = 'purchase-order-line-form__computed__')
   OR (name = 'purchase-order-line-purchase-order-grid' AND module IS NULL AND priority = 30);

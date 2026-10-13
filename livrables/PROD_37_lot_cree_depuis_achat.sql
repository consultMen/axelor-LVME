-- =====================================================================
-- PROD étape 37 : N° Lot de la ligne de commande fournisseur — créer un lot depuis l'achat
--   On tape un numéro qui n'existe pas dans « N° Lot » puis « Créer » : le lot est créé et
--   rattaché automatiquement au produit de la ligne (la création rapide ne remplit que le numéro).
-- À lancer avec le code de ce lot, avant le redémarrage. Relançable.
-- =====================================================================
BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-ligne-achat-rattacher-lot';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority)
VALUES (nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-achat-rattacher-lot', 'action-method', NULL,
'<action-method name="action-lvme-ligne-achat-rattacher-lot">
  <call class="com.axelor.apps.supplychain.web.LvmeLotCommandeAchatController" method="rattacherLot"/>
</action-method>', false, false, 0);

DO $$
DECLARE v_id bigint; v_xml text; n int;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view
   WHERE name = 'purchase-order-line-form' AND xml_id = 'purchase-order-line-form__computed__';
  IF v_id IS NULL THEN RAISE EXCEPTION 'fiche purchase-order-line-form calculée introuvable : arrêt'; END IF;
  SELECT count(*) INTO n FROM regexp_matches(v_xml, '<field name="trackingNumber" title="N° Lot"', 'g');
  IF n <> 1 THEN RAISE EXCEPTION 'champ N° Lot trouvé % fois (PROD_36 passé ?) : arrêt', n; END IF;
  IF position('action-lvme-ligne-achat-rattacher-lot' IN v_xml) = 0 THEN
    v_xml := replace(v_xml, '<field name="trackingNumber" title="N° Lot"',
      '<field name="trackingNumber" title="N° Lot" canNew="true" onChange="action-lvme-ligne-achat-rattacher-lot"');
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  END IF;
END $$;

COMMIT;

SELECT substring(xml FROM '<field name="trackingNumber"[^>]*/>') AS champ_lot
FROM meta_view WHERE name = 'purchase-order-line-form' AND xml_id = 'purchase-order-line-form__computed__';

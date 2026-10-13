-- =====================================================================
-- PROD étape 35 : retour client scénario 1, point 11 — intitulés de suivi de la commande fournisseur
--   Statuts : Brouillon / A embarquer / Flottant / En Stock / Annulée
--     (au lieu de Brouillon / Demandée / Validée / Terminée / Annulée)
--   Boutons : Demander -> A embarquer, Valider -> Flottant, Terminer la commande -> En Stock,
--             Retour à la commande validée -> Retour à Flottant
--   Libellés seulement : valeurs, boutons, réceptions et calculs inchangés.
--   Liste de statuts LVME (priorité 100) qui prime sur celle d'Axelor (priorité 20) :
--   la supprimer suffit à revenir aux libellés d'origine.
-- À lancer avant le redémarrage. Relançable.
-- =====================================================================
BEGIN;

-- ---------- Statuts ----------
DELETE FROM meta_select_item WHERE select_id IN
  (SELECT id FROM meta_select WHERE name = 'purchase.purchase.order.status.select' AND module IS NULL);
DELETE FROM meta_select WHERE name = 'purchase.purchase.order.status.select' AND module IS NULL;

INSERT INTO meta_select (id, version, name, priority, is_custom)
VALUES (nextval('meta_select_seq'), 0, 'purchase.purchase.order.status.select', 100, false);

INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
CROSS JOIN (VALUES ('1', 'Brouillon', 1), ('2', 'A embarquer', 2), ('3', 'Flottant', 3),
                   ('4', 'En Stock', 4), ('5', 'Annulée', 5)) AS v(value, title, seq)
WHERE s.name = 'purchase.purchase.order.status.select' AND s.module IS NULL;

-- ---------- Boutons de la fiche commande fournisseur ----------
DO $$
DECLARE v_id bigint; v_xml text; n int := 0;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view
   WHERE name = 'purchase-order-form' AND module IS NULL AND priority = 30;
  IF v_id IS NULL THEN RAISE EXCEPTION 'purchase-order-form (admin) introuvable : arrêt'; END IF;

  v_xml := regexp_replace(v_xml, '(<button [^>]*name="requestedBtn"[^>]*title=")[^"]*"', chr(92) || '1A embarquer"');
  v_xml := regexp_replace(v_xml, '(<button [^>]*name="validateBtn"[^>]*title=")[^"]*"', chr(92) || '1Flottant"');
  v_xml := regexp_replace(v_xml, '(<button [^>]*name="finishManuallyPurchaseOrderBtn"[^>]*title=")[^"]*"', chr(92) || '1En Stock"');
  v_xml := regexp_replace(v_xml, '(<button [^>]*name="backToValidatedBtn"[^>]*title=")[^"]*"', chr(92) || '1Retour à Flottant"');

  SELECT count(*) INTO n FROM regexp_matches(v_xml,
    '<button [^>]*name="(requestedBtn|validateBtn|finishManuallyPurchaseOrderBtn|backToValidatedBtn)"[^>]*title="(A embarquer|Flottant|En Stock|Retour à Flottant)"', 'g');
  IF n <> 4 THEN RAISE EXCEPTION 'boutons renommés : % sur 4, arrêt', n; END IF;

  UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
END $$;

COMMIT;

SELECT i.value, i.title FROM meta_select s JOIN meta_select_item i ON i.select_id = s.id
WHERE s.name = 'purchase.purchase.order.status.select' AND s.module IS NULL ORDER BY i.order_seq;

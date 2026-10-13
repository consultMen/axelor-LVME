-- =====================================================================
-- PROD étape 34 : icône « Dupliquer la ligne » en tête de ligne (à gauche, à côté de la poignée
-- de déplacement) au lieu de la dernière colonne, dans les lignes de commande fournisseur et
-- de commande client (demande client). Toujours visible sans faire défiler la liste.
-- Transforme en place les listes admin (priorité 30). À lancer avant le redémarrage. Relançable.
-- =====================================================================
BEGIN;

DO $$
DECLARE
  r record;
  v_btn text;
  v_xml text;
  v_anchor constant text := '<field name="$hasWarning" hidden="true"/>';
BEGIN
  FOR r IN SELECT id, name, xml FROM meta_view
           WHERE module IS NULL AND priority = 30
             AND name IN ('purchase-order-line-purchase-order-grid', 'sale-order-line-grid')
  LOOP
    v_xml := r.xml;
    v_btn := substring(v_xml FROM '<button name="lvmeDuplicateLineBtn"[^>]*/>');
    IF v_btn IS NULL THEN
      RAISE EXCEPTION '% : bouton Dupliquer introuvable, arrêt', r.name;
    END IF;
    IF position(v_anchor IN v_xml) = 0 THEN
      RAISE EXCEPTION '% : repère $hasWarning introuvable, arrêt', r.name;
    END IF;
    IF position(v_anchor || E'\n  ' || v_btn IN v_xml) > 0 THEN
      RAISE NOTICE '% : bouton déjà en tête', r.name;
      CONTINUE;
    END IF;
    -- retire le bouton de sa place actuelle (avec son retrait de ligne), puis le remet en tête
    v_xml := replace(v_xml, E'\n  ' || v_btn, '');
    v_xml := replace(v_xml, v_btn, '');
    v_xml := replace(v_xml, v_anchor, v_anchor || E'\n  ' || v_btn);
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = r.id;
    RAISE NOTICE '% : bouton Dupliquer placé en tête', r.name;
  END LOOP;
END $$;

COMMIT;

SELECT name, priority,
       position('<button name="lvmeDuplicateLineBtn"' IN xml) < position('name="product' IN xml) AS dupliquer_en_tete,
       (length(xml) - length(replace(xml, 'lvmeDuplicateLineBtn', ''))) / length('lvmeDuplicateLineBtn') AS nb_boutons
FROM meta_view
WHERE module IS NULL AND priority = 30 AND name IN ('purchase-order-line-purchase-order-grid', 'sale-order-line-grid');

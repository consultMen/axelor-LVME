-- =====================================================================
-- PROD étape 46 : « Réf. douanière » saisie sur l'article, comme dans GESCOM
--   - nouveau champ texte libre « Réf. douanière » sur la fiche article (ex. 03048990), à côté du
--     « Nom scientifique »
--   - fiches Ligne d'arrivage et Ligne de commande d'achat : la « Réf. douanière » affichée est
--     désormais ce champ (avant : le « Code douanier » Axelor, rempli seulement pour la DEB)
--   - le « Code douanier » Axelor (nomenclature, DEB) n'est pas modifié
-- Prérequis : PROD_42 (nom scientifique, fiche ligne d'arrivage), PROD_45 (fiche ligne d'achat).
-- Avec le code de ce lot (champ Product.refDouaniere). À lancer depuis la racine du dépôt,
-- avant le redémarrage. Relançable.
-- =====================================================================
\set ligne `cat livrables/ui/arrivage-line-form.xml`
SELECT set_config('lvme.ligne', :'ligne', false);
\set ligne_achat `cat livrables/ui/commande-achat-line-form.xml`
SELECT set_config('lvme.ligne_achat', :'ligne_achat', false);

BEGIN;

ALTER TABLE base_product ADD COLUMN IF NOT EXISTS ref_douaniere varchar(255);

-- fiche article : « Réf. douanière » juste après « Nom scientifique »
DO $$
DECLARE v_id bigint; v_xml text; n int;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'product-form' AND module IS NULL AND priority = 30;
  IF v_id IS NULL THEN RAISE EXCEPTION 'product-form (admin) introuvable : arrêt'; END IF;
  IF position('name="refDouaniere"' IN v_xml) = 0 THEN
    SELECT count(*) INTO n FROM regexp_matches(v_xml, '<field name="nomScientifique"[^>]*/>', 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'champ Nom scientifique trouvé % fois dans la fiche article (PROD_42 passé ?) : arrêt', n; END IF;
    v_xml := regexp_replace(v_xml, '(<field name="nomScientifique"[^>]*/>)',
      chr(92) || '1<field name="refDouaniere" title="Réf. douanière" colSpan="6"/>');
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  END IF;
END $$;

-- fiches de ligne : nouvelle version (product.refDouaniere au lieu du code douanier Axelor)
DO $$
BEGIN
  UPDATE meta_view SET xml = current_setting('lvme.ligne'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-arrivage-line-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-arrivage-line-form introuvable (PROD_42 passé ?) : arrêt'; END IF;
  UPDATE meta_view SET xml = current_setting('lvme.ligne_achat'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-commande-achat-line-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-commande-achat-line-form introuvable (PROD_45 passé ?) : arrêt'; END IF;
END $$;

COMMIT;

SELECT position('name="refDouaniere"' IN xml) > 0 AS fiche_article_ref_douaniere
FROM meta_view WHERE module IS NULL AND name = 'product-form' AND priority = 30;
SELECT name, position('product.refDouaniere' IN xml) > 0 AS ligne_ref_douaniere
FROM meta_view WHERE module IS NULL AND name IN ('lvme-arrivage-line-form', 'lvme-commande-achat-line-form');

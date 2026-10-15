-- =====================================================================
-- PROD étape 53 : fiche Produit, champs LVME remis en ordre
--   Gencode, Réf. fournisseur, Poids Colis, P.Vente TTC, Nom scientifique et Réf. douanière avaient été
--   insérés dans la zone « Code / Nom » d'Axelor (qui cache les libellés) : les champs se mélangeaient
--   (valeurs sans titre, Nom repoussé dessous). Ils sont sortis de cette zone et regroupés sur une ligne
--   « Informations article », avec leurs libellés, sous le code et le nom.
-- Relançable. Pas de redémarrage nécessaire.
-- =====================================================================
BEGIN;

DO $$
DECLARE v_id bigint; v_xml text; f text; n int;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'product-form' AND module IS NULL AND priority = 30;
  IF v_id IS NULL THEN RAISE EXCEPTION 'product-form (admin) introuvable : arrêt'; END IF;
  IF position('name="lvmeInfosArticlePanel"' IN v_xml) > 0 THEN
    RAISE NOTICE 'déjà passé';
    RETURN;
  END IF;
  -- retrait des 6 champs de la zone Code / Nom (chacun doit y être une seule fois)
  FOREACH f IN ARRAY ARRAY['gencode', 'refFournisseur', 'poidsColis', 'salePriceTtc', 'nomScientifique', 'refDouaniere'] LOOP
    SELECT count(*) INTO n FROM regexp_matches(v_xml, '<field name="' || f || '"[^>]*/>', 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'champ % trouvé % fois dans la fiche article : arrêt, rien n''est modifié', f, n; END IF;
    v_xml := regexp_replace(v_xml, '<field name="' || f || '"[^>]*/>', '');
  END LOOP;
  -- nouvelle ligne avant le bloc image / typologie
  SELECT count(*) INTO n FROM regexp_matches(v_xml, '<panel[^>]*?name="imagePanel"', 'g');
  IF n <> 1 THEN RAISE EXCEPTION 'bloc image trouvé % fois : arrêt, rien n''est modifié', n; END IF;
  v_xml := regexp_replace(v_xml, '(<panel[^>]*?name="imagePanel")',
    '<panel name="lvmeInfosArticlePanel" title="Informations article" colSpan="12" css="lvme-compact">
      <field name="gencode" title="Gencode" colSpan="2"/>
      <field name="refFournisseur" title="Réf. Fournisseur" colSpan="2"/>
      <field name="poidsColis" title="Poids Colis" colSpan="2"/>
      <field name="salePriceTtc" title="P.Vente TTC" colSpan="2" readonly="true"/>
      <field name="nomScientifique" title="Nom scientifique" colSpan="2"/>
      <field name="refDouaniere" title="Réf. douanière" colSpan="2"/>
    </panel>
    ' || chr(92) || '1');
  UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
END $$;

COMMIT;

SELECT position('name="lvmeInfosArticlePanel"' IN xml) > 0 AS ligne_infos_article,
       (length(xml) - length(replace(xml, 'name="gencode"', ''))) / length('name="gencode"') AS nb_gencode
FROM meta_view WHERE name = 'product-form' AND module IS NULL AND priority = 30;

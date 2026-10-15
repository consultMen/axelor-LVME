-- =====================================================================
-- PROD étape 52 : fiches Produit et Tiers (Fournisseur / Client) resserrées, étape 1
--   Chaque panneau des fiches admin product-form et partner-form reçoit la classe « lvme-compact »
--   (feuille de style css/lvme.css du code de ce lot) : moins d'espace entre les champs, cases moins
--   hautes, marges réduites. Aucun champ déplacé ni retiré. La fiche fournisseur (partner-supplier-form)
--   et la fiche client reprennent partner-form.
--   Les panneaux qui ont déjà une classe gardent la leur.
-- Avec le code de ce lot (css). Relançable. Pas de redémarrage nécessaire pour ce script.
-- =====================================================================
BEGIN;

DO $$
DECLARE r record; v_xml text;
BEGIN
  FOR r IN SELECT id, name, xml FROM meta_view
            WHERE module IS NULL AND priority = 30 AND name IN ('product-form', 'partner-form') LOOP
    -- <panel ...> et <panel-tabs ...> sans attribut css (les valeurs entre guillemets peuvent contenir « > »)
    v_xml := regexp_replace(r.xml, '<(panel|panel-tabs)(\s)(?!(?:(?:[^>"]|"[^"]*")*\s)?css=)',
                            '<\1 css="lvme-compact"\2', 'g');
    IF v_xml IS DISTINCT FROM r.xml THEN
      UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = r.id;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM meta_view WHERE module IS NULL AND priority = 30 AND name IN ('product-form', 'partner-form')) <> 2 THEN
    RAISE EXCEPTION 'fiches admin product-form / partner-form introuvables : arrêt';
  END IF;
END $$;

COMMIT;

SELECT name, (length(xml) - length(replace(xml, 'lvme-compact', ''))) / length('lvme-compact') AS panneaux_compacts
FROM meta_view WHERE module IS NULL AND priority = 30 AND name IN ('product-form', 'partner-form');

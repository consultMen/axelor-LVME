-- =====================================================================
-- PROD étape 83 : écran « Historique Produit » aux couleurs et tailles GESCOM, sur un seul écran
--   - classe lvme-ges-histo-produit posée sur le cadre Produit (repère de l'écran pour css/lvme.css)
--   - présentation dans css/lvme.css : haut lavande, en-têtes bleu-gris, lignes cyan clair / cyan, totaux dans
--     des cases bleues, liste sur toute la hauteur restante
-- Source : livrables/ui/lvme-historique-produit-form.xml. Relançable.
-- =====================================================================
BEGIN;

UPDATE meta_view SET xml = replace(xml, '<panel name="filtreProduitPanel" colSpan="5">',
  '<panel name="filtreProduitPanel" colSpan="5" css="lvme-ges-histo-produit">'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-historique-produit-form' AND module IS NULL AND xml NOT LIKE '%lvme-ges-histo-produit%';

COMMIT;

SELECT xml LIKE '%lvme-ges-histo-produit%' AS couleurs_branchees
FROM meta_view WHERE name = 'lvme-historique-produit-form' AND module IS NULL;

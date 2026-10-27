-- =====================================================================
-- PROD étape 85 : listes « Arrivages » et « Rotation des stocks » sur un seul écran comme GESCOM
--   - Arrivages : « Lancer la recherche » sous le fournisseur, boutons Suivi / Archiver / Nouveau Arrivage dans
--     une colonne à droite (comme GESCOM) ; repère lvme-ges-arr sur le cadre Nature
--   - Rotation des stocks : repères lvme-ges-rot (cadre Article) et lvme-ges-dates-jaune-rot (cadre Entrée)
--   - présentation (tailles, couleurs GESCOM, liste sur toute la hauteur) dans css/lvme.css, avec la liste des
--     achats fournisseurs
-- Source : livrables/ui/arrivage-search-form.xml. Depuis la racine du dépôt. Relançable.
-- =====================================================================
\set fiche `cat livrables/ui/arrivage-search-form.xml`
SELECT set_config('lvme.arr_recherche', :'fiche', false) IS NOT NULL AS fiche_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.arr_recherche'), updated_on = now(),
  version = COALESCE(version, 0) + 1
WHERE name = 'lvme-arrivage-search-form' AND module IS NULL;

UPDATE meta_view SET xml = replace(replace(xml,
  '<panel name="filtreArticlePanel" colSpan="3" itemSpan="12">',
  '<panel name="filtreArticlePanel" colSpan="3" itemSpan="12" css="lvme-ges-rot">'),
  '<panel name="filtreEntreePanel" colSpan="4" itemSpan="12"',
  '<panel name="filtreEntreePanel" colSpan="4" itemSpan="12" css="lvme-ges-dates-jaune-rot"'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-rotation-stock-dashboard-form' AND module IS NULL AND xml NOT LIKE '%lvme-ges-rot%';

COMMIT;

SELECT (SELECT xml LIKE '%filtreBoutonsPanel%' FROM meta_view WHERE name = 'lvme-arrivage-search-form' AND module IS NULL)
         AS arrivages_ranges,
       (SELECT xml LIKE '%lvme-ges-rot"%' AND xml LIKE '%lvme-ges-dates-jaune-rot%' FROM meta_view
          WHERE name = 'lvme-rotation-stock-dashboard-form' AND module IS NULL) AS rotation_reperee;

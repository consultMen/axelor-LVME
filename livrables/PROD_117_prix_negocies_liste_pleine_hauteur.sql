-- =====================================================================
-- PROD étape 117 : « Prix négociés » : la liste descend jusqu'en bas de l'écran, sans zone vide (29/10/2026)
--   L'écran partageait la hauteur de liste des écrans « Lots vérifiés / Interrogation… », dont les filtres sont plus
--   hauts : il restait un vide en bas. Repère lvme-prix-negocie sur le panneau des boutons, hauteur propre dans
--   css/lvme.css (déploiement du war). Tomcat arrêté, puis redémarrer (vues en cache). Relançable.
-- =====================================================================
BEGIN;

UPDATE meta_view SET xml = replace(xml,
    '<panel name="boutonsPrixNegociePanel" colSpan="2" itemSpan="12">',
    '<panel name="boutonsPrixNegociePanel" colSpan="2" itemSpan="12" css="lvme-prix-negocie">'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-prix-negocie-search-form' AND xml NOT LIKE '%lvme-prix-negocie"%';

COMMIT;

-- contrôle : t
SELECT xml LIKE '%css="lvme-prix-negocie"%' AS repere FROM meta_view
WHERE module IS NULL AND name = 'lvme-prix-negocie-search-form';

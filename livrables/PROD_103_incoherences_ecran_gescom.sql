-- =====================================================================
-- PROD étape 103 : « Rapport d'incohérences » présenté comme les écrans GESCOM, sur un seul écran
--   bande de filtres (type d'écart et tiers, dates, Lancer la recherche, Fermer(F12) à droite), cadres gris, liste
--   serrée blanc / gris sur toute la hauteur, colonnes aux libellés GESCOM, écart en rouge (css/lvme.css : repère
--   lvme-ges-lots-verif). Prérequis : PROD_24. Sources : livrables/ui/incoherence-search-form.xml,
--   incoherence-grid.xml. À lancer depuis la racine du dépôt. Relançable, sans redémarrage.
-- =====================================================================
\set fIncoh `cat livrables/ui/incoherence-search-form.xml`
SELECT set_config('lvme.fIncoh', :'fIncoh', false) IS NOT NULL AS vue_lue;
\set gIncoh `cat livrables/ui/incoherence-grid.xml`
SELECT set_config('lvme.gIncoh', :'gIncoh', false) IS NOT NULL AS liste_lue;

BEGIN;
UPDATE meta_view SET xml = current_setting('lvme.fIncoh'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-incoherence-search-form' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.gIncoh'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-incoherence-grid' AND module IS NULL;
COMMIT;

SELECT count(*) AS vues_modifiees FROM meta_view WHERE module IS NULL
  AND ((name = 'lvme-incoherence-search-form' AND xml LIKE '%lvme-ges-lots-verif%')
    OR (name = 'lvme-incoherence-grid' AND xml LIKE '%N° Pièce%'));

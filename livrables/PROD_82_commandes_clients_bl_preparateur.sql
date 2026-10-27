-- =====================================================================
-- PROD étape 82 : liste « Commandes clients » comme GESCOM
--   - colonnes « N° BL » (après Code : n° des livraisons non annulées de la commande) et « Préparateur » (après
--     Date livraison)
--   - couleurs GESCOM de l'écran (fond gris-bleu clair, en-têtes gris, lignes blanches, ligne Somme) : classe
--     lvme-ges-cdes posée sur le cadre des choix de commandes, couleurs dans css/lvme.css
-- Sources : livrables/ui/commande-client-grid.xml, livrables/ui/commande-client-search-form.xml.
-- Prérequis : code avec SaleOrder.lvmeNumeroBl (recompiler) ; PROD_81. Depuis la racine du dépôt. Relançable.
-- =====================================================================
\set grille `cat livrables/ui/commande-client-grid.xml`
SELECT set_config('lvme.cde_grille', :'grille', false) IS NOT NULL AS grille_lue;
\set fiche `cat livrables/ui/commande-client-search-form.xml`
SELECT set_config('lvme.cde_recherche', :'fiche', false) IS NOT NULL AS fiche_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.cde_grille'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-commande-client-grid' AND module IS NULL;

UPDATE meta_view SET xml = current_setting('lvme.cde_recherche'), updated_on = now(),
  version = COALESCE(version, 0) + 1
WHERE name = 'lvme-commande-client-search-form' AND module IS NULL;

COMMIT;

SELECT (SELECT xml LIKE '%lvmeNumeroBl%' AND xml LIKE '%lvmePreparateur.name%' FROM meta_view
          WHERE name = 'lvme-commande-client-grid' AND module IS NULL) AS colonnes_ajoutees,
       (SELECT xml LIKE '%lvme-ges-cdes%' FROM meta_view
          WHERE name = 'lvme-commande-client-search-form' AND module IS NULL) AS couleurs_branchees;

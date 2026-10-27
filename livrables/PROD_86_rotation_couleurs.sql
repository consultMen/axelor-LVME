-- =====================================================================
-- PROD étape 86 : rotation des stocks par lot aux couleurs GESCOM
--   - colonne « Nb colis Stock » en jaune (comme GESCOM) ; lignes de totaux par produit jaunes et lignes blanches
--     dans css/lvme.css
-- Source : livrables/ui/rotation-lot-grid.xml. Depuis la racine du dépôt. Relançable.
-- =====================================================================
\set grille `cat livrables/ui/rotation-lot-grid.xml`
SELECT set_config('lvme.rot_grille', :'grille', false) IS NOT NULL AS grille_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.rot_grille'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-rotation-lot-grid' AND module IS NULL;

COMMIT;

SELECT xml LIKE '%name="nbColisStock"%hilite background="yellow"%' AS stock_en_jaune
FROM meta_view WHERE name = 'lvme-rotation-lot-grid' AND module IS NULL;

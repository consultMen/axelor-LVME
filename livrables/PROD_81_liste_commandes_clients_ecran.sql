-- =====================================================================
-- PROD étape 81 : liste « Commandes clients » sur un seul écran comme GESCOM
--   - recherche sur une bande : choix des commandes | Client, Commercial | Date du / au | Livraison du / au +
--     Lancer la recherche ; boutons « Suivi des commandes clients » et « Nouvelle commande » à droite
--   - KPI moins hauts, filtres resserrés, liste sur toute la hauteur restante : dans css/lvme.css
-- Source : livrables/ui/commande-client-search-form.xml (après PROD_80). Depuis la racine du dépôt. Relançable.
-- =====================================================================
\set fiche `cat livrables/ui/commande-client-search-form.xml`
SELECT set_config('lvme.cde_recherche', :'fiche', false) IS NOT NULL AS fiche_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.cde_recherche'), updated_on = now(),
  version = COALESCE(version, 0) + 1
WHERE name = 'lvme-commande-client-search-form' AND module IS NULL;

COMMIT;

SELECT xml LIKE '%filtreBoutonsPanel%' AS boutons_a_droite
FROM meta_view WHERE name = 'lvme-commande-client-search-form' AND module IS NULL;

-- =====================================================================
-- PROD étape 51 : Ligne de commande d'achat et Ligne d'arrivage
--   - champs LVME vides tant qu'ils ne sont pas saisis / calculés (au lieu de 0) : Nb Colis, Nb unité/colis,
--     Unités Tot, Poids/Colis brut et net, Poids Total net, Durabilité, Frais d'approche, PA devise, PR
--     (code de ce lot : champs sans valeur par défaut) ; Poids Total brut à 0 par défaut au lieu de 1
--   - nombres affichés avec 3 décimales au plus (affichage seulement, calculs inchangés)
--   Les lignes déjà saisies gardent leurs valeurs.
-- Avec le code de ce lot. À lancer depuis la racine du dépôt, avant le redémarrage. Relançable.
-- =====================================================================
\set ligne `cat livrables/ui/arrivage-line-form.xml`
SELECT set_config('lvme.ligne', :'ligne', false) IS NOT NULL AS ligne_arrivage_lue;
\set ligne_achat `cat livrables/ui/commande-achat-line-form.xml`
SELECT set_config('lvme.ligne_achat', :'ligne_achat', false) IS NOT NULL AS ligne_achat_lue;

BEGIN;

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

SELECT name, position('x-scale="3"' IN xml) > 0 OR position('scale: 3' IN xml) > 0 AS trois_decimales
FROM meta_view WHERE module IS NULL AND name IN ('lvme-arrivage-line-form', 'lvme-commande-achat-line-form');

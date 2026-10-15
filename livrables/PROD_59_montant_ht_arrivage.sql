-- =====================================================================
-- PROD étape 59 : montant HT des lignes d'arrivage (était à 0)
--   La colonne « Montant ht » affichait le « montant réel » (au prix de revient réel des frais de stockage,
--   vide en général). Elle affiche maintenant Prix Achat x Nb unités ou poids (quantité prévue tant que
--   l'arrivage n'est pas réalisé, réelle ensuite), comme la ligne de commande fournisseur. Même calcul pour
--   le tableau Flottant / Réel de la fiche Ligne d'arrivage et pour le total sous les lignes (PROD_57).
--   Avec le code de ce lot (champ calculé StockMoveLine.lvmeMontantHt).
-- Sources : livrables/ui/arrivage-line-grid.xml, livrables/ui/arrivage-line-form.xml. Après PROD_58.
-- À lancer depuis la racine du dépôt, avant le redémarrage. Relançable.
-- =====================================================================
\set grille `cat livrables/ui/arrivage-line-grid.xml`
SELECT set_config('lvme.grille', :'grille', false) IS NOT NULL AS grille_lue;
\set ligne `cat livrables/ui/arrivage-line-form.xml`
SELECT set_config('lvme.ligne', :'ligne', false) IS NOT NULL AS ligne_lue;

BEGIN;

DO $$
BEGIN
  UPDATE meta_view SET xml = current_setting('lvme.grille'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-arrivage-line-grid';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-arrivage-line-grid introuvable : arrêt'; END IF;
  UPDATE meta_view SET xml = current_setting('lvme.ligne'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-arrivage-line-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-arrivage-line-form introuvable : arrêt'; END IF;
END $$;

COMMIT;

SELECT name, position('lvmeMontantHt' IN xml) > 0 OR position('unitPriceUntaxed || 0) * (+qty' IN xml) > 0 AS montant_ht
FROM meta_view WHERE module IS NULL AND name IN ('lvme-arrivage-line-grid', 'lvme-arrivage-line-form');

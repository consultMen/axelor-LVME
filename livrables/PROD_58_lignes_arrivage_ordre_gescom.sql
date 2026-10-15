-- =====================================================================
-- PROD étape 58 : lignes d'arrivage dans l'ordre GESCOM + ligne « Somme » en pied de liste
--   - colonnes des lignes d'arrivage : Produit, Désignation, Frigo, N° Lot, Origine, Conditionn., Prix Achat,
--     Prix Revient, Unité, Nb Colis, Nb unt ou Poids /Colis, Nb unités ou poids, Poids Kg, Montant ht,
--     D.L.C./D.L.U.O, Zone Pêche, puis les colonnes en plus (Flottant, Poids /Colis, N° Lot Fourn., Marque…)
--   - ligne « Somme » (commande fournisseur et arrivage) : une barre grise sous la liste, comme un pied de
--     tableau, libellé à côté de chaque total (plus de rangée de titres au-dessus)
-- Sources : livrables/ui/arrivage-line-grid.xml, commande-achat-form.xml, arrivage-form.xml (+ css du code).
-- Après PROD_57. À lancer depuis la racine du dépôt. Relançable.
-- =====================================================================
\set grille `cat livrables/ui/arrivage-line-grid.xml`
SELECT set_config('lvme.grille', :'grille', false) IS NOT NULL AS grille_lue;
\set fiche_achat `cat livrables/ui/commande-achat-form.xml`
SELECT set_config('lvme.fiche_achat', :'fiche_achat', false) IS NOT NULL AS commande_lue;
\set fiche_arrivage `cat livrables/ui/arrivage-form.xml`
SELECT set_config('lvme.fiche_arrivage', :'fiche_arrivage', false) IS NOT NULL AS arrivage_lu;

BEGIN;

DO $$
BEGIN
  UPDATE meta_view SET xml = current_setting('lvme.grille'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-arrivage-line-grid';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-arrivage-line-grid introuvable : arrêt'; END IF;
  UPDATE meta_view SET xml = current_setting('lvme.fiche_achat'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND priority = 30 AND name = 'purchase-order-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'purchase-order-form (admin) introuvable : arrêt'; END IF;
  UPDATE meta_view SET xml = current_setting('lvme.fiche_arrivage'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-arrivage-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-arrivage-form introuvable : arrêt'; END IF;
END $$;

COMMIT;

SELECT name, position('Nb unt ou Poids /Colis' IN xml) > 0 OR position('marginRight: "auto"' IN xml) > 0 AS a_jour
FROM meta_view WHERE module IS NULL AND (name IN ('lvme-arrivage-line-grid', 'lvme-arrivage-form') OR (name = 'purchase-order-form' AND priority = 30));

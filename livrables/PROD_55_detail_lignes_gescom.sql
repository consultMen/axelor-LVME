-- =====================================================================
-- PROD étape 55 : « Détail » des lignes comme GESCOM (retour client REC-001 : total cartons, montant HT,
-- poids… sous les lignes)
--   - commande fournisseur : colonnes aux intitulés GESCOM (N° Lot avant Origine), intitulés affichés en
--     entier (feuille de style du code de ce lot), ligne « Somme » sous le détail : Nb Colis, Nb unités ou
--     poids, Poids Kg, Montant ht
--   - fiche Arrivage : même ligne « Somme » sous les lignes d'arrivage (nb unités ou poids réel une fois
--     l'arrivage réalisé)
-- Sources : livrables/ui/purchase-order-line-purchase-order-grid.xml, commande-achat-form.xml, arrivage-form.xml.
-- Après PROD_41 et PROD_47. À lancer depuis la racine du dépôt. Relançable.
-- =====================================================================
\set grille `cat livrables/ui/purchase-order-line-purchase-order-grid.xml`
SELECT set_config('lvme.grille', :'grille', false) IS NOT NULL AS grille_lue;
\set fiche_achat `cat livrables/ui/commande-achat-form.xml`
SELECT set_config('lvme.fiche_achat', :'fiche_achat', false) IS NOT NULL AS commande_lue;
\set fiche_arrivage `cat livrables/ui/arrivage-form.xml`
SELECT set_config('lvme.fiche_arrivage', :'fiche_arrivage', false) IS NOT NULL AS arrivage_lu;

BEGIN;

DO $$
BEGIN
  UPDATE meta_view SET xml = current_setting('lvme.grille'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND priority = 30 AND name = 'purchase-order-line-purchase-order-grid';
  IF NOT FOUND THEN RAISE EXCEPTION 'grille des lignes de commande (admin) introuvable : arrêt'; END IF;
  UPDATE meta_view SET xml = current_setting('lvme.fiche_achat'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND priority = 30 AND name = 'purchase-order-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'purchase-order-form (admin) introuvable : arrêt'; END IF;
  UPDATE meta_view SET xml = current_setting('lvme.fiche_arrivage'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE module IS NULL AND name = 'lvme-arrivage-form';
  IF NOT FOUND THEN RAISE EXCEPTION 'lvme-arrivage-form introuvable : arrêt'; END IF;
END $$;

COMMIT;

SELECT name, position('lvmeSommeLignes' IN xml) > 0 AS ligne_somme
FROM meta_view WHERE module IS NULL AND name IN ('purchase-order-form', 'lvme-arrivage-form') AND (name <> 'purchase-order-form' OR priority = 30);

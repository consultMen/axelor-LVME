-- =====================================================================
-- PROD étape 60 : fiche Produit, haut de la fiche réorganisé
--   - 1re ligne : Code et Nom (comme Axelor)
--   - « Informations article » : Gencode, Réf. Fournisseur, Poids Colis, P.Vente TTC, Nom scientifique,
--     Réf. douanière, avec leurs libellés (ils étaient insérés dans la zone Code / Nom, qui cache les libellés :
--     valeurs sans titre, Nom repoussé dessous)
--   - Typologie (type, méthode d'approvisionnement) et Catégorisation (famille, catégorie) côte à côte,
--     image à droite, boutons de stock dessous
--   Onglets (Vente, Achat/Coûts, Comptabilité, Stock…) inchangés ; aucun champ retiré.
--   Remplace PROD_53 (ne plus le lancer). Sans rapport avec PROD_52 / PROD_54 (non déployés).
-- Source : livrables/ui/product-form.xml (fiche admin product-form, priorité 30).
-- À lancer depuis la racine du dépôt. Relançable. Pas de redémarrage nécessaire.
-- =====================================================================
\set fiche `cat livrables/ui/product-form.xml`
SELECT set_config('lvme.fiche_produit', :'fiche', false) IS NOT NULL AS fiche_lue;

BEGIN;

DO $$
DECLARE v_id bigint; v_xml text;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'product-form' AND module IS NULL AND priority = 30;
  IF v_id IS NULL THEN RAISE EXCEPTION 'product-form (admin) introuvable : arrêt'; END IF;
  IF position('name="productSpecificAttributes"' IN v_xml) = 0
     OR (position('name="namePanel"' IN v_xml) = 0 AND position('name="lvmeEntetePanel"' IN v_xml) = 0) THEN
    RAISE EXCEPTION 'fiche article non reconnue : arrêt, rien n''est modifié';
  END IF;
  UPDATE meta_view SET xml = current_setting('lvme.fiche_produit'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE id = v_id AND xml IS DISTINCT FROM current_setting('lvme.fiche_produit');
END $$;

COMMIT;

SELECT position('name="lvmeEntetePanel"' IN xml) > 0 AS fiche_organisee,
       (length(xml) - length(replace(xml, 'name="gencode"', ''))) / length('name="gencode"') AS nb_gencode
FROM meta_view WHERE name = 'product-form' AND module IS NULL AND priority = 30;

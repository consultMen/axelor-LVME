-- =====================================================================
-- PROD étape 8 : UI « Commande fournisseur » à la manière de la fiche « Arrivages » GESCOM
--   1. Grille des lignes (livrables/ui/purchase-order-line-purchase-order-grid.xml) : colonnes GESCOM,
--      colonnes jaunes Prix Achat / Nb Colis / Nb unités ou poids, bouton Dupliquer.
--   2. En-tête (livrables/ui/purchase-order-form-entete.xml) : ligne Société / Devise d'achat /
--      Devise comptable / Liste de prix ; bloc « Fournisseur » ; bloc « Arrivage » avec l'état
--      A Embarquer / Flottant / Réel ; paramètres techniques repliés. Onglets et colonne de droite conservés.
--      Construit à partir de la vue de module ACTUELLE de cette base (celle de la prod contient déjà
--      la devise comptable) ; seuls l'en-tête et les 8 champs remontés sont modifiés.
-- Vues admin de priorité 30 (durables), remplacent la copie faite par PROD_6. Relançable.
-- À lancer depuis la racine du dépôt, puis redémarrer Axelor.
-- Ne jamais réenregistrer ces vues depuis l'écran d'administration (Axelor régénérerait une vue calculée).
-- =====================================================================
\set grille `cat livrables/ui/purchase-order-line-purchase-order-grid.xml`
\set entete `cat livrables/ui/purchase-order-form-entete.xml`
SELECT set_config('lvme.grille', :'grille', false), set_config('lvme.entete', :'entete', false);

BEGIN;

DO $$
DECLARE
  src text; res text; a int; b int; n int; p text; f text;
  attr constant text := '(?:[^"/>]|"[^"]*")*';
  moved text[] := ARRAY['buyerUser', 'orderDate', 'estimatedReceiptDate', 'supplierShipmentDate',
                        'stockLocation', 'shipmentMode', 'paymentMode', 'paymentCondition'];
BEGIN
  -- ---------- 1. Grille des lignes ----------
  DELETE FROM meta_view WHERE name = 'purchase-order-line-purchase-order-grid' AND module IS NULL AND priority = 30;
  INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed)
  VALUES (nextval('meta_view_seq'), 0, now(), 'purchase-order-line-purchase-order-grid', 'Lignes arrivage', 'grid',
          'com.axelor.apps.purchase.db.PurchaseOrderLine', 30, current_setting('lvme.grille'), false, false);
  RAISE NOTICE '1. Grille des lignes installée';

  -- ---------- 2. Fiche commande fournisseur ----------
  SELECT xml INTO src FROM meta_view
   WHERE name = 'purchase-order-form' AND module IS NOT NULL AND COALESCE(extension, false) = false
     AND xml NOT LIKE '%lvmeFournisseurPanel%'
   ORDER BY priority DESC, COALESCE(computed, false) DESC LIMIT 1;
  IF src IS NULL THEN RAISE EXCEPTION 'purchase-order-form introuvable'; END IF;
  res := src;

  -- champs remontés dans l'en-tête : retirés de leur emplacement d'origine
  FOREACH f IN ARRAY moved LOOP
    p := '<field ' || attr || 'name="' || f || '"' || attr || '/>';
    SELECT count(*) INTO n FROM regexp_matches(res, p, 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'Champ % trouvé % fois (1 attendu) : arrêt, rien n''est modifié', f, n; END IF;
    res := regexp_replace(res, p, '');
  END LOOP;
  -- devise comptable : présente en prod (ajoutée à la main), absente ailleurs
  p := '<field ' || attr || 'name="company.currency"' || attr || '/>';
  SELECT count(*) INTO n FROM regexp_matches(res, p, 'g');
  IF n > 1 THEN RAISE EXCEPTION 'Devise comptable trouvée % fois : arrêt', n; END IF;
  res := regexp_replace(res, p, '');

  -- remplace le bloc d'en-tête (de la société jusqu'au message fournisseur)
  a := position('<field name="company" ' IN res);
  b := position('<field name="supplierPartner.purchaseOrderInformation"' IN res);
  IF a = 0 OR b = 0 OR b < a THEN RAISE EXCEPTION 'Bloc d''en-tête non trouvé : arrêt, rien n''est modifié'; END IF;
  res := substr(res, 1, a - 1) || current_setting('lvme.entete') || substr(res, b);

  DELETE FROM meta_view WHERE name = 'purchase-order-form' AND module IS NULL AND priority = 30;
  INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed)
  SELECT nextval('meta_view_seq'), 0, now(), name, title, type, model, 30, res, false, false
  FROM meta_view WHERE name = 'purchase-order-form' AND module IS NOT NULL AND COALESCE(extension, false) = false
    AND xml NOT LIKE '%lvmeFournisseurPanel%'
  ORDER BY priority DESC, COALESCE(computed, false) DESC LIMIT 1;
  RAISE NOTICE '2. Fiche commande fournisseur installée (en-tête Arrivage GESCOM)';
END $$;

COMMIT;

SELECT name, priority, COALESCE(module, 'admin') AS module, length(xml) AS taille
FROM meta_view WHERE name IN ('purchase-order-form', 'purchase-order-line-purchase-order-grid')
  AND module IS NULL AND priority = 30;

-- =====================================================================
-- PROD étape 7 : UI « Commande client » à la manière de la Fiche Commande client GESCOM
--   1. Grille des lignes (livrables/ui/sale-order-line-grid.xml) : colonnes et libellés GESCOM,
--      colonnes jaunes Colis Cdes / Nb unités ou Poids cdés / Prix Vente, bouton Dupliquer.
--   2. En-tête de la fiche (livrables/ui/sale-order-form-entete.xml) : bloc « Client » et bloc
--      « Commande » visibles d'un coup (règlement, échéance, opérateur, ref cde, dates, transporteur,
--      port payé, coût port/kg remontés des panneaux repliés), paramètres techniques repliés.
--      La fiche est construite à partir de la vue calculée ACTUELLE de cette base : seul le bloc
--      d'en-tête est remplacé et les 7 champs remontés sont retirés de leur ancien emplacement.
-- Les deux vues sont des vues admin de priorité 30 (durables). Relançable.
-- À lancer depuis la racine du dépôt :  psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_7_ui_commande_client.sql
-- Puis redémarrer Axelor (cache des vues).
-- =====================================================================
\set grille `cat livrables/ui/sale-order-line-grid.xml`
\set entete `cat livrables/ui/sale-order-form-entete.xml`
SELECT set_config('lvme.grille', :'grille', false), set_config('lvme.entete', :'entete', false);

BEGIN;

DO $$
DECLARE
  src text; res text; a int; b int; n int; p text; f text;
  moved text[] := ARRAY['estimatedDeliveryDate', 'carrierPartner', 'paymentMode', 'paymentCondition',
                        'externalReference', 'creationDate', 'salespersonUser'];
BEGIN
  -- ---------- 1. Grille des lignes ----------
  DELETE FROM meta_view WHERE name = 'sale-order-line-grid' AND module IS NULL AND priority = 30;
  INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed)
  VALUES (nextval('meta_view_seq'), 0, now(), 'sale-order-line-grid', 'Lignes commande', 'grid',
          'com.axelor.apps.sale.db.SaleOrderLine', 30, current_setting('lvme.grille'), false, false);
  RAISE NOTICE '1. Grille des lignes installée';

  -- ---------- 2. Fiche commande ----------
  SELECT xml INTO src FROM meta_view
   WHERE name = 'sale-order-form' AND module IS NOT NULL AND COALESCE(extension, false) = false
   ORDER BY priority DESC, COALESCE(computed, false) DESC LIMIT 1;
  IF src IS NULL THEN RAISE EXCEPTION 'sale-order-form introuvable'; END IF;

  -- retire les champs remontés dans l'en-tête de leur emplacement d'origine
  res := src;
  FOREACH f IN ARRAY moved LOOP
    p := '<field name="' || f || '"(?:[^"/>]|"[^"]*")*/>';
    SELECT count(*) INTO n FROM regexp_matches(res, p, 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'Champ % trouvé % fois (1 attendu) : arrêt, rien n''est modifié', f, n; END IF;
    res := regexp_replace(res, p, '');
  END LOOP;

  -- remplace le bloc d'en-tête (generalInfoPanel + addressPanel)
  a := position('<panel name="generalInfoPanel"' IN res);
  b := position('<field name="clientPartner.saleOrderInformation"' IN res);
  IF a = 0 OR b = 0 OR b < a THEN RAISE EXCEPTION 'Bloc d''en-tête non trouvé : arrêt, rien n''est modifié'; END IF;
  res := substr(res, 1, a - 1) || current_setting('lvme.entete') || substr(res, b);

  DELETE FROM meta_view WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30;
  INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed)
  SELECT nextval('meta_view_seq'), 0, now(), name, title, type, model, 30, res, false, false
  FROM meta_view WHERE name = 'sale-order-form' AND module IS NOT NULL AND COALESCE(extension, false) = false
  ORDER BY priority DESC, COALESCE(computed, false) DESC LIMIT 1;
  RAISE NOTICE '2. Fiche commande installée (en-tête GESCOM)';
END $$;

COMMIT;

SELECT name, priority, COALESCE(module, 'admin') AS module, length(xml) AS taille
FROM meta_view WHERE name IN ('sale-order-form', 'sale-order-line-grid') AND module IS NULL AND priority = 30;

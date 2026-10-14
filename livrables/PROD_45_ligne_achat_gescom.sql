-- =====================================================================
-- PROD étape 45 : fiche « Ligne de commande d'achat » copiée sur la fenêtre « Lignes Arrivages »
-- GESCOM (dans GESCOM la commande et l'arrivage partagent la même fenêtre de ligne)
--   - nouvelle fiche lvme-commande-achat-line-form (livrables/ui/commande-achat-line-form.xml),
--     ouverte depuis les lignes de la commande fournisseur
--   - onglet « Ligne » : article, désignation, nom scientifique, réf. douanière ; n° lot, congélation,
--     condit., coef., unité ; code produit, durabilité, DLUO, origine, marque ; TVA, zone / mode de pêche,
--     frais d'approche, colis/couche, colis/palette ; gencode, réf. fourn. ; tableau Flottant / Réel en
--     vrais champs de saisie (Nb Colis, prix… avec les mêmes calculs) ; boutons Historique produit /
--     État des stocks par lots (sur l'article de la ligne, PROD_44) ; Obs repliée
--   - autres onglets (historique des commandes, analytique, budget) inchangés
--   Mêmes champs, actions et calculs qu'avant : disposition seulement.
-- Prérequis : PROD_36, PROD_37 (n° de lot), PROD_42 (nom scientifique), PROD_44 (boutons).
-- À lancer depuis la racine du dépôt, avant le redémarrage. Relançable.
-- =====================================================================
\set ligne `cat livrables/ui/commande-achat-line-form.xml`
SELECT set_config('lvme.ligne_achat', :'ligne', false);

BEGIN;

DELETE FROM meta_view WHERE module IS NULL AND name = 'lvme-commande-achat-line-form';
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed)
VALUES (nextval('meta_view_seq'), 0, now(), 'lvme-commande-achat-line-form', 'Ligne de commande d''achat', 'form',
        'com.axelor.apps.purchase.db.PurchaseOrderLine', 20, current_setting('lvme.ligne_achat'), false, false);

DO $$
DECLARE v_id bigint; v_xml text; n int;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'purchase-order-form' AND module IS NULL AND priority = 30;
  IF v_id IS NULL THEN RAISE EXCEPTION 'purchase-order-form (admin) introuvable : arrêt'; END IF;
  IF position('form-view="lvme-commande-achat-line-form"' IN v_xml) = 0 THEN
    SELECT count(*) INTO n FROM regexp_matches(v_xml,
      '<panel-related[^>]*field="purchaseOrderLineList"[^>]*form-view="purchase-order-line-form"', 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'liste des lignes de la commande trouvée % fois : arrêt', n; END IF;
    v_xml := regexp_replace(v_xml,
      '(<panel-related[^>]*field="purchaseOrderLineList"[^>]*form-view=")purchase-order-line-form"',
      chr(92) || '1lvme-commande-achat-line-form"');
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  END IF;
END $$;

COMMIT;

SELECT name, priority FROM meta_view WHERE module IS NULL AND name = 'lvme-commande-achat-line-form';
SELECT position('form-view="lvme-commande-achat-line-form"' IN xml) > 0 AS commande_ouvre_nouvelle_ligne
FROM meta_view WHERE name = 'purchase-order-form' AND module IS NULL AND priority = 30;

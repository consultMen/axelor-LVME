-- =====================================================================
-- PROD étape 42 : fiche « Ligne d'arrivage » copiée sur la fenêtre « Lignes Arrivages » GESCOM
--   - nouvelle fiche lvme-arrivage-line-form (livrables/ui/arrivage-line-form.xml), ouverte depuis la
--     liste des lignes de la fiche Arrivage ; la fiche ligne standard (BL clients…) ne change pas
--   - mêmes champs, actions et calculs que la fiche standard, disposés comme GESCOM, sans défiler :
--     article, désignation, nom scientifique, réf. douanière ; n° lot, congélation, condit., unité ;
--     lot fourn., durabilité, DLUO, origine, marque ; frigo, TVA, zone / mode de pêche, frais d'approche ;
--     gencode, réf. fourn., colis/couche, colis/palette, qtés ; tableau Flottant / Réel (colis, unités,
--     poids, PA/Kg, PR devise, PR/Kg, montant HT) ; boutons Historique produit / État des stocks par lots
--   - article : nouveau champ « Nom scientifique » (colonne + fiche article)
-- Relance PROD_9 (fiche Arrivage qui ouvre la nouvelle fiche ligne).
-- À lancer depuis la racine du dépôt, avec le code de ce lot, AVANT le redémarrage. Relançable.
-- =====================================================================
\set ligne `cat livrables/ui/arrivage-line-form.xml`
SELECT set_config('lvme.ligne', :'ligne', false);

BEGIN;

ALTER TABLE base_product ADD COLUMN IF NOT EXISTS nom_scientifique varchar(255);

DELETE FROM meta_view WHERE module IS NULL AND name = 'lvme-arrivage-line-form';
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed)
VALUES (nextval('meta_view_seq'), 0, now(), 'lvme-arrivage-line-form', 'Ligne d''arrivage', 'form',
        'com.axelor.apps.stock.db.StockMoveLine', 20, current_setting('lvme.ligne'), false, false);

-- ---------- Fiche article : « Nom scientifique » après le P.Vente TTC ----------
DO $$
DECLARE v_id bigint; v_xml text; n int;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'product-form' AND module IS NULL AND priority = 30;
  IF v_id IS NULL THEN RAISE EXCEPTION 'product-form (admin) introuvable : arrêt'; END IF;
  IF position('name="nomScientifique"' IN v_xml) = 0 THEN
    SELECT count(*) INTO n FROM regexp_matches(v_xml, '<field name="salePriceTtc"[^>]*/>', 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'champ P.Vente TTC trouvé % fois dans la fiche article : arrêt', n; END IF;
    v_xml := regexp_replace(v_xml, '(<field name="salePriceTtc"[^>]*/>)',
      chr(92) || '1<field name="nomScientifique" title="Nom scientifique" colSpan="6"/>');
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  END IF;
END $$;

COMMIT;

\i livrables/PROD_9_arrivages.sql

SELECT name, priority FROM meta_view WHERE module IS NULL AND name = 'lvme-arrivage-line-form';
SELECT position('form-view="lvme-arrivage-line-form"' IN xml) > 0 AS arrivage_ouvre_nouvelle_ligne
FROM meta_view WHERE module IS NULL AND name = 'lvme-arrivage-form';
SELECT position('name="nomScientifique"' IN xml) > 0 AS fiche_article_nom_scientifique
FROM meta_view WHERE module IS NULL AND name = 'product-form' AND priority = 30;

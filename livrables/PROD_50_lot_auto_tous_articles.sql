-- =====================================================================
-- PROD étape 50 : lot automatique à l'achat pour tous les articles (articles repris de GESCOM)
--   Au choix de l'article sur une ligne de commande fournisseur, un lot AE + n° n'est proposé que si
--   l'article a une configuration de lot qui génère les lots à l'achat. Les articles repris n'en ont pas.
--   Ce script met LA configuration de lot automatique à l'achat sur tous les articles stockables
--   qui n'en ont pas, ou dont la configuration ne génère pas de lot à l'achat.
--   La configuration utilisée est celle qui est à la fois « suivi à l'achat » + « génération auto
--   à l'achat » + compteur (celle réglée par PROD_39). S'il n'y en a pas exactement une : arrêt, rien
--   n'est modifié, et la liste des configurations est affichée.
-- Pas de redémarrage nécessaire. Relançable (ne fait plus rien une fois passé).
-- =====================================================================

-- ---------- 1. État avant ----------
SELECT c.id, '[' || c.name || ']' AS configuration, c.is_purchase_tracking_managed AS suivi_achat,
       c.generate_purchase_auto_tracking_nbr AS lot_auto_achat, c.sequence AS compteur,
       (SELECT count(*) FROM base_product p WHERE p.tracking_number_configuration = c.id) AS nb_articles
FROM stock_tracking_number_configuration c ORDER BY c.id;

SELECT count(*) AS articles_stockables,
       count(*) FILTER (WHERE tracking_number_configuration IS NULL) AS sans_configuration
FROM base_product WHERE dtype = 'Product' AND product_type_select = 'storable';

BEGIN;

DO $$
DECLARE v_cfg bigint; n int;
BEGIN
  SELECT count(*) INTO n FROM stock_tracking_number_configuration
   WHERE is_purchase_tracking_managed AND generate_purchase_auto_tracking_nbr AND sequence IS NOT NULL;
  IF n <> 1 THEN
    RAISE EXCEPTION '% configuration(s) de lot automatique à l''achat (il en faut exactement 1) : arrêt, rien n''est modifié', n;
  END IF;
  SELECT id INTO v_cfg FROM stock_tracking_number_configuration
   WHERE is_purchase_tracking_managed AND generate_purchase_auto_tracking_nbr AND sequence IS NOT NULL;

  UPDATE base_product p
     SET tracking_number_configuration = v_cfg, updated_on = now(), version = COALESCE(p.version, 0) + 1
   WHERE p.dtype = 'Product' AND p.product_type_select = 'storable'
     AND (p.tracking_number_configuration IS NULL
          OR p.tracking_number_configuration IN (SELECT c.id FROM stock_tracking_number_configuration c
                                                  WHERE NOT (c.is_purchase_tracking_managed AND c.generate_purchase_auto_tracking_nbr)));
  GET DIAGNOSTICS n = ROW_COUNT;
  RAISE NOTICE '% article(s) passé(s) en lot automatique à l''achat', n;
END $$;

COMMIT;

-- ---------- 2. État après ----------
SELECT '[' || coalesce(c.name, '(aucune)') || ']' AS configuration, count(*) AS nb_articles_stockables
FROM base_product p LEFT JOIN stock_tracking_number_configuration c ON c.id = p.tracking_number_configuration
WHERE p.dtype = 'Product' AND p.product_type_select = 'storable'
GROUP BY 1 ORDER BY 2 DESC;

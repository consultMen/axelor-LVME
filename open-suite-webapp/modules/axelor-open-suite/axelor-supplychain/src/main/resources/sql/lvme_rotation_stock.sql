-- =====================================================================
-- REC-003 : vue lvme_rotation_stock (modèle Axelor RotationStock)
-- Une ligne par produit : stock, ventes, couverture, rotation, ancienneté.
--
-- Les 4 KPI de la rotation des stocks :
--   1. Couverture (jours de stock) = stock / vente moyenne par jour (90 j)
--   2. Taux de rotation (fois / an) = ventes 12 mois / stock actuel
--   3. Âge moyen du stock (j)       = âge des lots en stock, pondéré par la quantité
--   4. Stock dormant                = aucune vente depuis plus de 90 j (valeur immobilisée)
--
-- Historique :
--   v1 : créée manuellement dans pgAdmin.
--   v2 (28/09/2026) : correction du double comptage du stock.
--        Le CTE "stock" ne lit plus que les lignes d'emplacement
--        (details_stock_location IS NULL). Les lignes de lot ventilent
--        le même stock et ne doivent pas s'y ajouter.
--   v3 (29/09/2026) : 4 KPI.
--        La couverture est calculée dès qu'il y a une vente sur 90 j
--        (avant : seulement à partir de 10) ; le statut « A commander »
--        reste réservé aux produits aux ventes significatives (>= 10 / 90 j).
--        Colonnes ajoutées en fin de vue : ventes 12 mois, taux de rotation,
--        âge moyen pondéré, valeur dormante, jours depuis la dernière vente,
--        code / désignation / famille du produit (filtres et affichage).
--
-- Déploiement : exécuter AVANT le démarrage d'Axelor avec la version du
-- modèle RotationStock qui contient ces colonnes, sinon Hibernate tente de
-- les ajouter à une vue et échoue.
-- =====================================================================

CREATE OR REPLACE VIEW lvme_rotation_stock AS
WITH stock AS (
    -- Stock de référence : lignes d'emplacement uniquement (v2)
    SELECT l.product,
           SUM(l.current_qty)                            AS qty,
           SUM(l.current_qty * COALESCE(l.avg_price, 0)) AS valeur
    FROM stock_stock_location_line l
    JOIN stock_stock_location sl ON sl.id = l.stock_location
    WHERE l.details_stock_location IS NULL
      AND sl.type_select = 1
    GROUP BY l.product
),
ventes AS (
    SELECT sml.product,
           SUM(CASE WHEN sm.real_date >= CURRENT_DATE - 90
                    THEN sml.real_qty ELSE 0 END)        AS qty_90j,
           SUM(CASE WHEN sm.real_date >= CURRENT_DATE - 365
                    THEN sml.real_qty ELSE 0 END)        AS qty_365j,
           MAX(sm.real_date)                             AS derniere_vente
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    WHERE sm.type_select = 2
      AND sm.status_select = 3
    GROUP BY sml.product
),
lots AS (
    -- Ancienneté : lignes de lot en stock
    SELECT l.product,
           MIN(t.date_arrivage)                          AS plus_ancien,
           -- v3 : âge moyen pondéré par la quantité (date d'arrivage, sinon création du lot)
           ROUND(SUM(l.current_qty * (CURRENT_DATE - COALESCE(t.date_arrivage, t.created_on::date)))
                 / NULLIF(SUM(l.current_qty), 0))        AS age_moyen
    FROM stock_stock_location_line l
    JOIN stock_stock_location sl ON sl.id = COALESCE(l.details_stock_location, l.stock_location)
    JOIN stock_tracking_number t ON t.id = l.tracking_number
    WHERE l.current_qty > 0
      AND sl.type_select = 1
    GROUP BY l.product
),
calc AS (
    SELECT s.product,
           s.qty,
           s.valeur,
           COALESCE(v.qty_90j, 0)                        AS qty_90j,
           COALESCE(v.qty_365j, 0)                       AS qty_365j,
           ROUND(COALESCE(v.qty_90j, 0) / 90.0, 3)       AS moy_jour,
           -- v3 : couverture calculée dès la première vente sur 90 j
           CASE WHEN COALESCE(v.qty_90j, 0) > 0
                THEN ROUND(s.qty / (v.qty_90j / 90.0))
                ELSE NULL::numeric END                   AS jours_stock,
           (COALESCE(v.qty_90j, 0) >= 10)                AS significatif,
           v.derniere_vente,
           lo.plus_ancien,
           lo.age_moyen,
           CASE WHEN lo.plus_ancien IS NOT NULL
                THEN CURRENT_DATE - lo.plus_ancien
                ELSE NULL::integer END                   AS age_max,
           (v.derniere_vente IS NULL
            OR v.derniere_vente < CURRENT_DATE - 90)     AS dormant
    FROM stock s
    LEFT JOIN ventes v ON v.product = s.product
    LEFT JOIN lots  lo ON lo.product = s.product
    WHERE s.qty > 0
)
SELECT c.product                         AS id,
       0                                 AS version,
       false                             AS archived,
       NULL::bigint                      AS created_by,
       now()                             AS created_on,
       NULL::bigint                      AS updated_by,
       NULL::timestamp without time zone AS updated_on,
       NULL::character varying           AS import_id,
       NULL::character varying           AS import_origin,
       NULL::character varying           AS process_instance_id,
       NULL::jsonb                       AS attrs,
       c.product                         AS product_id,
       c.qty                             AS stock_qty,
       c.valeur                          AS stock_value,
       c.qty_90j                         AS sales_90d,
       c.moy_jour                        AS avg_daily_sales,
       c.jours_stock                     AS days_of_stock,
       c.derniere_vente                  AS last_sale_date,
       c.plus_ancien                     AS oldest_lot_date,
       c.age_max                         AS oldest_lot_age,
       c.dormant                         AS is_dormant,
       CASE
           WHEN c.significatif AND c.jours_stock < 60 THEN 'A commander'
           WHEN c.dormant                             THEN 'Dormant'
           WHEN c.age_max > 180                       THEN 'Lot ancien'
           WHEN NOT c.significatif                    THEN 'Ventes faibles'
           ELSE 'OK'
       END                               AS statut,
       -- ===== v3 : colonnes ajoutées (toujours en fin de vue) =====
       c.qty_365j                        AS sales_365d,
       ROUND(c.qty_365j / NULLIF(c.qty, 0), 2) AS rotation_rate,
       c.age_moyen::integer              AS avg_age_days,
       CASE WHEN c.dormant THEN c.valeur ELSE 0 END AS dormant_value,
       (CURRENT_DATE - c.derniere_vente)::integer AS days_since_last_sale,
       p.code                            AS product_code,
       p.name                            AS product_name,
       p.product_category                AS product_category_id
FROM calc c
JOIN base_product p ON p.id = c.product;

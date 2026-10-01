-- =====================================================================
-- REC-012 : vue lvme_rotation_lot (modèle Axelor RotationLot)
-- Reproduit l'écran GESCOM « Rotation de Stock » : une ligne par lot réel
-- et par frigo, avec le nombre de jours que le lot est resté en stock
-- avant sa sortie pour vente.
--
-- Règles :
--   Base                = lots réels de lvme_etat_stock_lot (même périmètre que l'état des stocks)
--   Poids entrées       = poids net des lignes de BR du lot, sinon colis x poids colis
--   Poids stock         = poids entrées au prorata du stock restant
--   Date dernière sortie = date du dernier BL client réalisé sur le lot / frigo
--   Jours en stock      = aujourd'hui - date d'arrivée, pour les lots encore en stock
--   Nbre jours rotation = moyenne, pondérée par les quantités livrées, des jours
--                         entre l'arrivée du lot et chaque BL client réalisé (0 sans vente)
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le
-- modèle RotationLot, sinon Hibernate crée une table du même nom.
-- Dépend de lvme_etat_stock_lot.
-- =====================================================================

CREATE OR REPLACE VIEW lvme_rotation_lot AS
WITH entrees AS (
    SELECT sml.tracking_number,
           COALESCE(sml.to_stock_location, sm.to_stock_location) AS frigo,
           MAX(sml.marque)                                        AS marque,
           MAX(COALESCE(sml.poids_par_colis, 0))                  AS poids_colis,
           SUM(COALESCE(sml.poids_total_net, 0))                  AS poids_net
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    WHERE sm.type_select = 3 AND sm.status_select = 3
      AND COALESCE(sm.is_reversion, false) = false
      AND sml.tracking_number IS NOT NULL
    GROUP BY sml.tracking_number, COALESCE(sml.to_stock_location, sm.to_stock_location)
),
sorties AS (
    SELECT sml.tracking_number,
           COALESCE(sml.from_stock_location, sm.from_stock_location) AS frigo,
           sm.real_date,
           SUM(COALESCE(sml.real_qty, 0)) AS qty
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    WHERE sm.type_select = 2 AND sm.status_select = 3
      AND COALESCE(sm.is_reversion, false) = false
      AND sml.tracking_number IS NOT NULL
      AND sm.real_date IS NOT NULL
    GROUP BY sml.tracking_number, COALESCE(sml.from_stock_location, sm.from_stock_location), sm.real_date
),
base AS (
    SELECT e.*,
           en.marque,
           COALESCE(en.poids_colis, 0)                                     AS poids_colis,
           CASE WHEN COALESCE(en.poids_net, 0) > 0 THEN en.poids_net
                ELSE e.nb_colis_in * COALESCE(en.poids_colis, 0) END       AS poids_entrees,
           (SELECT MAX(s.real_date) FROM sorties s
             WHERE s.tracking_number = e.tracking_number_id AND s.frigo = e.stock_location_id) AS last_sale_date,
           (SELECT SUM(s.qty * (s.real_date - e.arrival_date)) / NULLIF(SUM(s.qty), 0) FROM sorties s
             WHERE s.tracking_number = e.tracking_number_id AND s.frigo = e.stock_location_id
               AND s.real_date >= e.arrival_date)                            AS rotation_days
    FROM lvme_etat_stock_lot e
    LEFT JOIN entrees en ON en.tracking_number = e.tracking_number_id AND en.frigo = e.stock_location_id
    WHERE e.nature_arrivage = 1
)
SELECT b.id,
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
       b.product_id,
       b.product_code,
       b.product_name,
       b.product_category_id,
       b.supplier_id,
       b.supplier_name,
       b.stock_location_id,
       b.tracking_number_id,
       b.lot_number,
       b.arrival_number,
       b.origine,
       b.conditionnement,
       b.marque,
       p.gencode,
       b.entry_date,
       b.arrival_date,
       b.dluo,
       b.prix_revient,
       ROUND(b.poids_colis, 3)           AS poids_colis,
       ROUND(b.poids_entrees, 3)         AS poids_entrees,
       b.nb_colis_in,
       b.nb_colis_stock,
       ROUND(CASE WHEN b.entree_qty > 0 THEN b.poids_entrees * b.stock_qty / b.entree_qty
                  ELSE b.nb_colis_stock * b.poids_colis END, 3) AS poids_stock,
       b.stock_qty,
       b.stock_value,
       b.last_sale_date,
       COALESCE(ROUND(b.rotation_days), 0)::integer AS rotation_days,
       -- ajout en fin de vue (CREATE OR REPLACE VIEW) : âge des lots encore en stock
       CASE WHEN b.stock_qty > 0 AND b.arrival_date IS NOT NULL THEN CURRENT_DATE - b.arrival_date END AS stock_days
FROM base b
JOIN base_product p ON p.id = b.product_id;

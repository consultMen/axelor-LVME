-- =====================================================================
-- REC-003 : vue lvme_age_lot (modèle Axelor AgeLot)
-- Une ligne par lot et par frigo : quantité, valeur, âge, DLUO.
--
-- Historique :
--   v1 : créée manuellement dans pgAdmin.
--   v2 (28/09/2026) : correction de la valorisation.
--        Sur les lignes de lot, avg_price vaut 0 (et non NULL), donc
--        COALESCE(l.avg_price, ...) retenait 0. La valeur est désormais
--        calculée avec le prix moyen de la ligne d'emplacement
--        correspondante, même règle que lvme_rotation_stock : la somme
--        des lots est ainsi cohérente avec la valeur de la rotation.
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le
-- modèle AgeLot, sinon Hibernate crée une table du même nom.
-- =====================================================================

CREATE OR REPLACE VIEW lvme_age_lot AS
SELECT l.id,
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
       l.product                         AS product_id,
       l.tracking_number                 AS tracking_number_id,
       COALESCE(l.details_stock_location, l.stock_location) AS stock_location_id,
       l.current_qty                     AS qty,
       -- v2 : prix moyen de la ligne d'emplacement (le PMP n'est pas porté par les lignes de lot)
       l.current_qty * COALESCE(loc.avg_price, 0) AS stock_value,
       COALESCE(t.date_arrivage, t.created_on::date) AS arrival_date,
       CASE WHEN t.date_arrivage IS NOT NULL THEN 'Arrivage'
            ELSE 'Création (migration)' END AS date_source,
       CURRENT_DATE - COALESCE(t.date_arrivage, t.created_on::date) AS age_days,
       CASE
           WHEN CURRENT_DATE - COALESCE(t.date_arrivage, t.created_on::date) <= 30  THEN '0-30 j'
           WHEN CURRENT_DATE - COALESCE(t.date_arrivage, t.created_on::date) <= 90  THEN '30-90 j'
           WHEN CURRENT_DATE - COALESCE(t.date_arrivage, t.created_on::date) <= 180 THEN '90-180 j'
           ELSE '> 180 j'
       END                               AS age_bucket,
       t.perishable_expiration_date      AS dluo,
       t.perishable_expiration_date - CURRENT_DATE AS days_to_dluo,
       t.perishable_expiration_date < CURRENT_DATE AS is_expired
FROM stock_stock_location_line l
JOIN stock_stock_location sl ON sl.id = COALESCE(l.details_stock_location, l.stock_location)
JOIN stock_tracking_number t ON t.id = l.tracking_number
LEFT JOIN stock_stock_location_line loc
       ON loc.stock_location = l.details_stock_location
      AND loc.product = l.product
      AND loc.details_stock_location IS NULL
WHERE l.current_qty > 0
  AND sl.type_select = 1;

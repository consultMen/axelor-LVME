-- =====================================================================
-- LVME : vue lvme_reservation_ligne (modèle Axelor ReservationLigne), écran Ventes > Réservations.
-- Une ligne par ligne de commande de réservation : commande passée au nom d'un compte de réservation (GESCOM
-- CLIENT_RESERV, MIG_10) ou commande marquée « Réservation » (REC-009). Lot, frigo et D.D.M. calculés comme les
-- colonnes N° Lot / Frigo / D.D.M. de la ligne de commande, sans les colonnes de disponibilité (Colis Rsv / Dispo,
-- Qté Dispo) qui relisent l'état des stocks à chaque ligne et rendaient la liste très lente.
-- En cours : commande non terminée (Devis brouillon, Devis finalisé, Commande confirmée) et ligne non livrée.
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le modèle ReservationLigne, sinon Hibernate crée
-- une table du même nom. Prérequis : colonnes base_partner.lvme_est_compte_reservation (MIG_10).
-- =====================================================================

DROP VIEW IF EXISTS lvme_reservation_ligne;
CREATE VIEW lvme_reservation_ligne AS
SELECT l.id                                AS id,
       0                                   AS version,
       false                               AS archived,
       NULL::bigint                        AS created_by,
       now()                               AS created_on,
       NULL::bigint                        AS updated_by,
       NULL::timestamp without time zone   AS updated_on,
       NULL::character varying             AS import_id,
       NULL::character varying             AS import_origin,
       NULL::character varying             AS process_instance_id,
       NULL::jsonb                         AS attrs,
       l.id                                AS sale_order_line_id,
       s.id                                AS sale_order_id,
       s.sale_order_seq                    AS order_seq,
       COALESCE(s.order_date, s.creation_date) AS order_date,
       s.status_select                     AS status_select,
       s.client_partner                    AS compte_id,
       p.partner_seq                       AS compte_code,
       COALESCE(s.is_reservation, false)   AS is_reservation,
       l.product                           AS product_id,
       pr.code                             AS product_code,
       l.product_name                      AS product_name,
       lots.lots                           AS lots,
       lots.frigo                          AS frigo,
       lots.ddm                            AS ddm,
       l.nb_colis                          AS nb_colis,
       l.qty                               AS qty,
       l.ex_tax_total                      AS ex_tax_total,
       (s.status_select IN (1, 2, 3) AND COALESCE(l.delivery_state, 1) <> 3) AS en_cours
FROM sale_sale_order_line l
JOIN sale_sale_order s ON s.id = l.sale_order
LEFT JOIN base_partner p ON p.id = s.client_partner
LEFT JOIN base_product pr ON pr.id = l.product
LEFT JOIN LATERAL (
  SELECT string_agg(DISTINCT tn.tracking_number_seq, ', ') AS lots,
         string_agg(DISTINCT loc.name, ', ')               AS frigo,
         min(sml.dluo)                                     AS ddm
  FROM supplychain_sale_order_line_lot ll
  JOIN stock_tracking_number tn ON tn.id = ll.tracking_number
  LEFT JOIN stock_stock_move_line sml ON sml.id = tn.origin_stock_move_line
  LEFT JOIN stock_stock_location loc ON loc.id = sml.to_stock_location
  WHERE ll.sale_order_line = l.id
) lots ON true
WHERE s.template = false AND s.status_select <> 5 AND l.product IS NOT NULL
  AND (p.lvme_est_compte_reservation = true OR s.is_reservation = true);

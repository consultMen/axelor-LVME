-- =====================================================================
-- LVME : vue lvme_historique_prix_ligne (modèle Axelor HistoriquePrixLigne), écran « Historique prix » (F1 de la
-- ligne de commande client). Une ligne par ligne de commande client vendue (article, non annulée, hors modèle).
-- Pièce, date et origine calculées comme les colonnes Désignation (B.L. ou Cde), Date et Origine de la ligne de
-- commande, sans les colonnes de disponibilité (Colis Rsv / Dispo, Qté Dispo) qui relisent l'état des stocks à
-- chaque ligne : avec l'historique GESCOM (432 000 lignes), la liste mettait plus de 30 s à s'afficher.
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le modèle HistoriquePrixLigne, sinon Hibernate
-- crée une table du même nom.
-- =====================================================================

DROP VIEW IF EXISTS lvme_historique_prix_ligne;
CREATE VIEW lvme_historique_prix_ligne AS
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
       s.client_partner                    AS client_id,
       l.product                           AS product_id,
       pr.code                             AS product_code,
       COALESCE(s.order_date, s.creation_date) AS order_date,
       COALESCE(bl.piece, 'Cde N° ' || COALESCE(s.sale_order_seq, '') || ' Du '
                || to_char(COALESCE(s.order_date, s.creation_date), 'YYYYMMDD'))
         || '/' || COALESCE(p.partner_seq, '')  AS piece,
       COALESCE(bl.date_bl, s.order_date, s.creation_date) AS histo_date,
       ori.origine                         AS origine,
       l.conditionnement                   AS conditionnement_id,
       l.poids_par_colis                   AS poids_par_colis,
       l.nb_colis                          AS nb_colis,
       l.poids_total_net                   AS poids_total_net,
       l.price_discounted                  AS price_discounted,
       l.ex_tax_total                      AS ex_tax_total
FROM sale_sale_order_line l
JOIN sale_sale_order s ON s.id = l.sale_order
LEFT JOIN base_partner p ON p.id = s.client_partner
LEFT JOIN base_product pr ON pr.id = l.product
-- dernier B.L. non annulé de la ligne (comme lvmeHistoPiece / lvmeHistoDate)
LEFT JOIN LATERAL (
  SELECT 'B.L. N° ' || m.stock_move_seq || ' Du ' || to_char(COALESCE(m.real_date, m.estimated_date), 'YYYYMMDD') AS piece,
         COALESCE(m.real_date, m.estimated_date) AS date_bl
  FROM stock_stock_move m
  WHERE m.id = (SELECT max(ml.stock_move) FROM stock_stock_move_line ml JOIN stock_stock_move m2 ON m2.id = ml.stock_move
                WHERE ml.sale_order_line = l.id AND m2.status_select <> 4)
) bl ON true
-- origine des lots vendus (comme lvmeOrigine)
LEFT JOIN LATERAL (
  SELECT string_agg(DISTINCT sml.origine, ', ') AS origine
  FROM supplychain_sale_order_line_lot ll
  JOIN stock_tracking_number tn ON tn.id = ll.tracking_number
  JOIN stock_stock_move_line sml ON sml.id = tn.origin_stock_move_line
  WHERE ll.sale_order_line = l.id
) ori ON true
WHERE s.template = false AND s.status_select <> 5 AND l.product IS NOT NULL;

-- =====================================================================
-- LVME : vue lvme_historique_produit (modèle Axelor HistoriqueProduit)
-- Reproduit l'écran « Historique Produit » de GESCOM (diapo 11).
-- Une ligne par mouvement de stock réalisé et par sens (entrée / sortie) :
--   * sens E : la ligne arrive sur un emplacement interne (frigo)
--   * sens S : la ligne part d'un emplacement interne
--   un transfert entre deux frigos donne donc deux lignes (comme GESCOM).
--
-- Type : AR arrivage fournisseur, BL livraison client, RC retour client,
--        RF retour fournisseur, CE transfert interne, IN inventaire / correction
-- Arrivage : N° du BR fournisseur d'origine du lot
-- Poids   : quantité réelle de la ligne
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le
-- modèle HistoriqueProduit, sinon Hibernate crée une table du même nom.
-- =====================================================================

DROP VIEW IF EXISTS lvme_historique_produit;
CREATE VIEW lvme_historique_produit AS
WITH mvts AS (
    SELECT sml.id                                                AS sml_id,
           sml.product,
           sml.tracking_number,
           sm.id                                                 AS stock_move_id,
           sm.real_date,
           sm.stock_move_seq,
           sm.type_select,
           COALESCE(sm.is_reversion, false)                      AS is_reversion,
           sm.partner,
           fl.type_select                                        AS from_type,
           tl.type_select                                        AS to_type,
           sml.real_qty,
           sml.nb_colis,
           sml.poids_par_colis,
           sml.unit_price_untaxed,
           COALESCE(NULLIF(sml.prix_revient_reel, 0), NULLIF(tn.prix_revient_reel, 0), sml.wap_price) AS prix_revient,
           tn.tracking_number_seq
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    LEFT JOIN stock_stock_location fl ON fl.id = COALESCE(sml.from_stock_location, sm.from_stock_location)
    LEFT JOIN stock_stock_location tl ON tl.id = COALESCE(sml.to_stock_location, sm.to_stock_location)
    LEFT JOIN stock_tracking_number tn ON tn.id = sml.tracking_number
    WHERE sm.status_select = 3
      AND sml.product IS NOT NULL
      AND COALESCE(sml.real_qty, 0) <> 0
),
sens AS (
    SELECT m.*, 'E'::varchar AS sens FROM mvts m WHERE m.to_type = 1
    UNION ALL
    SELECT m.*, 'S'::varchar AS sens FROM mvts m WHERE m.from_type = 1
),
typed AS (
    SELECT s.*,
           CASE
             WHEN s.type_select = 3 AND NOT s.is_reversion THEN 'AR'
             WHEN s.type_select = 3 THEN 'RC'
             WHEN s.type_select = 2 AND NOT s.is_reversion THEN 'BL'
             WHEN s.type_select = 2 THEN 'RF'
             WHEN s.from_type = 3 OR s.to_type = 3 THEN 'IN'
             ELSE 'CE'
           END AS type_mvt,
           (SELECT sm2.stock_move_seq
              FROM stock_stock_move_line sml2
              JOIN stock_stock_move sm2 ON sm2.id = sml2.stock_move
             WHERE sml2.tracking_number = s.tracking_number
               AND sm2.type_select = 3 AND COALESCE(sm2.is_reversion, false) = false
               AND sm2.status_select IN (2, 3)
             ORDER BY sm2.status_select DESC, sm2.id
             LIMIT 1) AS arrivage,
           (SELECT MIN(i.invoice_id)
              FROM account_invoice_stock_move_set ism
              JOIN account_invoice i ON i.id = ism.invoice_set
             WHERE ism.stock_move_set = s.stock_move_id
               AND i.status_select <> 4) AS facture
    FROM sens s
)
SELECT (t.sml_id * 10 + CASE WHEN t.sens = 'E' THEN 1 ELSE 2 END)::bigint AS id,
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
       t.product                         AS product_id,
       t.sml_id                          AS stock_move_line_id,
       t.stock_move_id                   AS stock_move_id,
       t.tracking_number                 AS tracking_number_id,
       CASE WHEN t.type_mvt = 'AR' THEN t.stock_move_seq ELSE t.arrivage END AS arrivage,
       t.real_date                       AS date_mvt,
       t.tracking_number_seq             AS lot_number,
       CASE
         WHEN t.type_mvt = 'AR' THEN 'Arrivage ' || t.stock_move_seq || '/' || COALESCE(p.code, '')
                                     || COALESCE('/' || t.tracking_number_seq, '')
         ELSE COALESCE('FACT ' || t.facture, t.stock_move_seq) || COALESCE(' / ' || pa.partner_seq, '')
       END                               AS libelle,
       t.type_mvt                        AS type_mvt,
       pa.partner_seq                    AS ref_tiers,
       CASE WHEN t.type_mvt IN ('BL', 'RC') THEN t.unit_price_untaxed END AS prix_vente,
       t.prix_revient                    AS prix_revient,
       t.poids_par_colis                 AS poids_colis,
       t.nb_colis                        AS nb_colis,
       CASE WHEN t.sens = 'E' THEN t.real_qty END AS poids_entree,
       CASE WHEN t.sens = 'S' THEN t.real_qty END AS poids_sortie,
       t.sens                            AS sens
FROM typed t
JOIN base_product p ON p.id = t.product
LEFT JOIN base_partner pa ON pa.id = t.partner;

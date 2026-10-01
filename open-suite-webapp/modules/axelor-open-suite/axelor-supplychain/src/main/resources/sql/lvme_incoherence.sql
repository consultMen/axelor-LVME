-- =====================================================================
-- REC-012 : vue lvme_incoherence (modèle Axelor Incoherence)
-- « Rapport d'incohérences » : Commandes VS Réceptions VS BL VS Facturé
-- (cahier de recette REC-012 ; cahier des charges p. 6-7 « Gestion des livraisons frigo » :
--  comparer la réception avec la commande fournisseur — produit, quantité — et identifier les écarts).
--
-- Une ligne par écart :
--   1 Cde client : qté commandée ≠ qté livrée        (tous les BL de la commande réalisés)
--   2 BL : qté livrée ≠ qté facturée                  (ligne livrée, facturée ou non)
--   3 Cde fournisseur : qté / colis commandés ≠ reçus (toutes les réceptions de la commande réalisées)
--     + produit reçu non commandé / produit reçu différent du produit commandé
--   4 Réception : qté reçue ≠ qté facturée par le fournisseur (ligne reçue, facturée ou non)
--   5 Prix facturé ≠ prix de la commande              (factures validées ou ventilées)
-- Factures prises en compte : validées ou ventilées (statut 2, 3) ; avoirs déduits.
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le
-- modèle Incoherence, sinon Hibernate crée une table du même nom.
-- =====================================================================

CREATE OR REPLACE VIEW lvme_incoherence AS
WITH
-- quantités facturées par ligne de commande client (avoirs déduits)
fac_client AS (
    SELECT il.sale_order_line,
           SUM(CASE WHEN i.operation_type_select = 4 THEN -il.qty ELSE il.qty END) AS qty,
           STRING_AGG(DISTINCT i.invoice_id, ', ') AS numeros
    FROM account_invoice_line il
    JOIN account_invoice i ON i.id = il.invoice
    WHERE i.status_select IN (2, 3) AND i.operation_type_select IN (3, 4) AND il.sale_order_line IS NOT NULL
    GROUP BY il.sale_order_line
),
-- quantités facturées par ligne de commande fournisseur (avoirs déduits)
fac_fournisseur AS (
    SELECT il.purchase_order_line,
           SUM(CASE WHEN i.operation_type_select = 2 THEN -il.qty ELSE il.qty END) AS qty,
           STRING_AGG(DISTINCT COALESCE(NULLIF(i.supplier_invoice_nb, ''), i.invoice_id), ', ') AS numeros
    FROM account_invoice_line il
    JOIN account_invoice i ON i.id = il.invoice
    WHERE i.status_select IN (2, 3) AND i.operation_type_select IN (1, 2) AND il.purchase_order_line IS NOT NULL
    GROUP BY il.purchase_order_line
),
-- BL clients réalisés par ligne de commande client
bl AS (
    SELECT sml.sale_order_line, STRING_AGG(DISTINCT sm.stock_move_seq, ', ') AS numeros
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    WHERE sm.type_select = 2 AND sm.status_select = 3 AND sml.sale_order_line IS NOT NULL
    GROUP BY sml.sale_order_line
),
-- réceptions réalisées par ligne de commande fournisseur (colis reçus)
rec AS (
    SELECT sml.purchase_order_line,
           SUM(COALESCE(sml.nb_colis, 0)) AS colis,
           STRING_AGG(DISTINCT sm.stock_move_seq, ', ') AS numeros
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    WHERE sm.type_select = 3 AND sm.status_select = 3 AND COALESCE(sm.is_reversion, false) = false
      AND sml.purchase_order_line IS NOT NULL
    GROUP BY sml.purchase_order_line
),
-- commandes client dont tous les BL sont réalisés (au moins un)
so_livree AS (
    SELECT r.sale_order_set AS sale_order
    FROM stock_stock_move_sale_order_set r
    JOIN stock_stock_move sm ON sm.id = r.stock_stock_move
    WHERE sm.type_select = 2
    GROUP BY r.sale_order_set
    HAVING BOOL_OR(sm.status_select = 3) AND NOT BOOL_OR(sm.status_select IN (1, 2))
),
-- commandes fournisseur dont toutes les réceptions sont réalisées (au moins une)
po_recue AS (
    SELECT r.purchase_order_set AS purchase_order
    FROM stock_stock_move_purchase_order_set r
    JOIN stock_stock_move sm ON sm.id = r.stock_stock_move
    WHERE sm.type_select = 3 AND COALESCE(sm.is_reversion, false) = false
    GROUP BY r.purchase_order_set
    HAVING BOOL_OR(sm.status_select = 3) AND NOT BOOL_OR(sm.status_select IN (1, 2))
),
ecarts AS (
    -- 1. Cde client : qté commandée ≠ qté livrée
    SELECT 1000000000000 + sol.id AS id, 1 AS type_ecart, 'Cde client : commandé ≠ livré' AS type_label,
           so.client_partner AS partner_id, so.id AS sale_order_id, NULL::bigint AS purchase_order_id,
           so.sale_order_seq AS order_ref, COALESCE(so.order_date, so.creation_date) AS date_doc,
           sol.product AS product_id, sol.product_name,
           sol.qty AS qty_cde, COALESCE(sol.delivered_qty, 0) AS qty_mvt, fc.qty AS qty_facturee,
           COALESCE(sol.delivered_qty, 0) - sol.qty AS ecart,
           sol.nb_colis AS colis_cde, NULL::numeric AS colis_mvt,
           sol.price_discounted AS prix_cde, NULL::numeric AS prix_facture,
           bl.numeros AS mvt_numeros, fc.numeros AS facture_numeros
    FROM sale_sale_order_line sol
    JOIN sale_sale_order so ON so.id = sol.sale_order
    JOIN so_livree sl ON sl.sale_order = so.id
    LEFT JOIN bl ON bl.sale_order_line = sol.id
    LEFT JOIN fac_client fc ON fc.sale_order_line = sol.id
    WHERE so.status_select IN (3, 4) AND sol.product IS NOT NULL
      AND sol.qty <> COALESCE(sol.delivered_qty, 0)

    UNION ALL
    -- 2. BL : qté livrée ≠ qté facturée
    SELECT 2000000000000 + sol.id, 2, 'BL : livré ≠ facturé',
           so.client_partner, so.id, NULL::bigint,
           so.sale_order_seq, COALESCE(so.order_date, so.creation_date),
           sol.product, sol.product_name,
           sol.qty, sol.delivered_qty, COALESCE(fc.qty, 0),
           COALESCE(fc.qty, 0) - sol.delivered_qty,
           sol.nb_colis, NULL::numeric,
           sol.price_discounted, NULL::numeric,
           bl.numeros, fc.numeros
    FROM sale_sale_order_line sol
    JOIN sale_sale_order so ON so.id = sol.sale_order
    LEFT JOIN bl ON bl.sale_order_line = sol.id
    LEFT JOIN fac_client fc ON fc.sale_order_line = sol.id
    WHERE so.status_select IN (3, 4) AND sol.product IS NOT NULL
      AND COALESCE(sol.delivered_qty, 0) > 0
      AND COALESCE(fc.qty, 0) <> sol.delivered_qty

    UNION ALL
    -- 3. Cde fournisseur : qté ou colis commandés ≠ reçus
    SELECT 3000000000000 + pol.id, 3, 'Cde fournisseur : commandé ≠ reçu',
           po.supplier_partner, NULL::bigint, po.id,
           po.purchase_order_seq, po.order_date,
           pol.product, pol.product_name,
           pol.qty, COALESCE(pol.received_qty, 0), ff.qty,
           COALESCE(pol.received_qty, 0) - pol.qty,
           pol.nb_colis, COALESCE(rec.colis, 0),
           pol.price_discounted, NULL::numeric,
           rec.numeros, ff.numeros
    FROM purchase_purchase_order_line pol
    JOIN purchase_purchase_order po ON po.id = pol.purchase_order
    JOIN po_recue pr ON pr.purchase_order = po.id
    LEFT JOIN rec ON rec.purchase_order_line = pol.id
    LEFT JOIN fac_fournisseur ff ON ff.purchase_order_line = pol.id
    WHERE po.status_select IN (3, 4) AND pol.product IS NOT NULL
      AND (pol.qty <> COALESCE(pol.received_qty, 0)
        OR (COALESCE(pol.nb_colis, 0) > 0 AND COALESCE(pol.nb_colis, 0) <> COALESCE(rec.colis, 0)))

    UNION ALL
    -- 3 bis. Réception : produit reçu non commandé, ou différent du produit commandé
    SELECT 3500000000000 + sml.id, 3,
           CASE WHEN sml.purchase_order_line IS NULL THEN 'Réception : produit non commandé'
                ELSE 'Réception : produit ≠ commandé' END,
           po.supplier_partner, NULL::bigint, po.id,
           po.purchase_order_seq, po.order_date,
           sml.product, sml.product_name,
           pol.qty, sml.real_qty, NULL::numeric,
           sml.real_qty,
           pol.nb_colis, sml.nb_colis,
           pol.price_discounted, NULL::numeric,
           sm.stock_move_seq, NULL
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    JOIN stock_stock_move_purchase_order_set r ON r.stock_stock_move = sm.id
    JOIN purchase_purchase_order po ON po.id = r.purchase_order_set
    LEFT JOIN purchase_purchase_order_line pol ON pol.id = sml.purchase_order_line
    WHERE sm.type_select = 3 AND sm.status_select = 3 AND COALESCE(sm.is_reversion, false) = false
      AND sml.product IS NOT NULL AND COALESCE(sml.real_qty, 0) <> 0
      AND (sml.purchase_order_line IS NULL OR pol.product <> sml.product)

    UNION ALL
    -- 4. Réception : qté reçue ≠ qté facturée par le fournisseur
    SELECT 4000000000000 + pol.id, 4, 'Réception : reçu ≠ facturé',
           po.supplier_partner, NULL::bigint, po.id,
           po.purchase_order_seq, po.order_date,
           pol.product, pol.product_name,
           pol.qty, pol.received_qty, COALESCE(ff.qty, 0),
           COALESCE(ff.qty, 0) - pol.received_qty,
           pol.nb_colis, rec.colis,
           pol.price_discounted, NULL::numeric,
           rec.numeros, ff.numeros
    FROM purchase_purchase_order_line pol
    JOIN purchase_purchase_order po ON po.id = pol.purchase_order
    LEFT JOIN rec ON rec.purchase_order_line = pol.id
    LEFT JOIN fac_fournisseur ff ON ff.purchase_order_line = pol.id
    WHERE po.status_select IN (3, 4) AND pol.product IS NOT NULL
      AND COALESCE(pol.received_qty, 0) > 0
      AND COALESCE(ff.qty, 0) <> pol.received_qty

    UNION ALL
    -- 5. Prix facturé ≠ prix de la commande (client)
    SELECT 5000000000000 + il.id, 5, 'Prix facturé ≠ prix cde client',
           i.partner, so.id, NULL::bigint,
           so.sale_order_seq, i.invoice_date,
           il.product, il.product_name,
           sol.qty, NULL::numeric, il.qty,
           il.price_discounted - sol.price_discounted,
           NULL::numeric, NULL::numeric,
           sol.price_discounted, il.price_discounted,
           NULL, i.invoice_id
    FROM account_invoice_line il
    JOIN account_invoice i ON i.id = il.invoice
    JOIN sale_sale_order_line sol ON sol.id = il.sale_order_line
    JOIN sale_sale_order so ON so.id = sol.sale_order
    WHERE i.status_select IN (2, 3) AND i.operation_type_select = 3
      AND ROUND(il.price_discounted, 4) <> ROUND(sol.price_discounted, 4)

    UNION ALL
    -- 5. Prix facturé ≠ prix de la commande (fournisseur)
    SELECT 5500000000000 + il.id, 5, 'Prix facturé ≠ prix cde fournisseur',
           i.partner, NULL::bigint, po.id,
           po.purchase_order_seq, i.invoice_date,
           il.product, il.product_name,
           pol.qty, NULL::numeric, il.qty,
           il.price_discounted - pol.price_discounted,
           NULL::numeric, NULL::numeric,
           pol.price_discounted, il.price_discounted,
           NULL, COALESCE(NULLIF(i.supplier_invoice_nb, ''), i.invoice_id)
    FROM account_invoice_line il
    JOIN account_invoice i ON i.id = il.invoice
    JOIN purchase_purchase_order_line pol ON pol.id = il.purchase_order_line
    JOIN purchase_purchase_order po ON po.id = pol.purchase_order
    WHERE i.status_select IN (2, 3) AND i.operation_type_select = 1
      AND ROUND(il.price_discounted, 4) <> ROUND(pol.price_discounted, 4)
)
SELECT e.id,
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
       e.type_ecart,
       e.type_label,
       e.partner_id,
       e.sale_order_id,
       e.purchase_order_id,
       e.order_ref,
       e.date_doc,
       e.product_id,
       e.product_name,
       ROUND(e.qty_cde, 3)               AS qty_cde,
       ROUND(e.qty_mvt, 3)               AS qty_mvt,
       ROUND(e.qty_facturee, 3)          AS qty_facturee,
       ROUND(e.ecart, 3)                 AS ecart,
       ROUND(e.colis_cde, 3)             AS colis_cde,
       ROUND(e.colis_mvt, 3)             AS colis_mvt,
       ROUND(e.prix_cde, 4)              AS prix_cde,
       ROUND(e.prix_facture, 4)          AS prix_facture,
       e.mvt_numeros,
       e.facture_numeros
FROM ecarts e;

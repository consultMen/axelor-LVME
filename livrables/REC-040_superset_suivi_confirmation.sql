WITH lots AS (
    SELECT lot.sale_order_line,
           COUNT(*)                                                   AS nb_lots,
           STRING_AGG(t.tracking_number_seq, ', ' ORDER BY t.tracking_number_seq) AS lots_attribues,
           MIN(COALESCE(lot.perishable_expiration_date, t.perishable_expiration_date)) AS dluo_min
    FROM supplychain_sale_order_line_lot lot
    LEFT JOIN stock_tracking_number t ON t.id = lot.tracking_number
    GROUP BY lot.sale_order_line
),
arrivages AS (
    SELECT a.sale_order_line,
           COUNT(*)                                                   AS nb_arrivages,
           SUM(COALESCE(a.qty_allocated, 0))                          AS qty_arrivage,
           STRING_AGG(DISTINCT po.purchase_order_seq, ', ')           AS commandes_achat
    FROM supplychain_sale_order_line_arrivage a
    LEFT JOIN purchase_purchase_order_line pol ON pol.id = a.purchase_order_line
    LEFT JOIN purchase_purchase_order po ON po.id = pol.purchase_order
    GROUP BY a.sale_order_line
),
bons AS (
    SELECT sml.sale_order_line,
           COUNT(DISTINCT sm.id)                                      AS nb_bl,
           STRING_AGG(DISTINCT sm.stock_move_seq, ', ')               AS bl,
           STRING_AGG(DISTINCT fr.name, ', ')                         AS frigos,
           COUNT(DISTINCT COALESCE(sml.from_stock_location, sm.from_stock_location)) AS nb_frigos,
           STRING_AGG(DISTINCT CASE sm.status_select WHEN 1 THEN 'Brouillon' WHEN 2 THEN 'Planifié'
                                    WHEN 3 THEN 'Réalisé' ELSE 'Autre' END, ', ') AS statut_bl,
           MAX(sm.real_date)                                          AS date_livraison,
           STRING_AGG(DISTINCT tr.full_name, ', ')                    AS transporteur_bl
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    LEFT JOIN stock_stock_location fr ON fr.id = COALESCE(sml.from_stock_location, sm.from_stock_location)
    LEFT JOIN base_partner tr ON tr.id = sm.carrier_partner
    WHERE sm.type_select = 2
      AND sm.status_select <> 4
      AND sml.sale_order_line IS NOT NULL
    GROUP BY sml.sale_order_line
),
documents AS (
    SELECT f.related_id                                               AS sale_order,
           COUNT(*)                                                   AS nb_documents,
           STRING_AGG(f.file_name, ', ' ORDER BY f.file_name)         AS documents
    FROM dms_file f
    WHERE f.related_model = 'com.axelor.apps.sale.db.SaleOrder'
      AND COALESCE(f.is_directory, false) = false
    GROUP BY f.related_id
),
emails AS (
    SELECT r.related_to_select_id                                     AS sale_order,
           COUNT(DISTINCT m.id)                                       AS nb_emails,
           MAX(m.sent_datet)                                          AS dernier_email
    FROM message_multi_related r
    JOIN message_message m ON m.id = r.message
    WHERE r.related_to_select = 'com.axelor.apps.sale.db.SaleOrder'
      AND m.media_type_select = 2
      AND m.status_select = 3
    GROUP BY r.related_to_select_id
)
SELECT
    so.sale_order_seq                                                 AS commande,
    CASE so.status_select
        WHEN 1 THEN 'Devis brouillon'
        WHEN 2 THEN 'Devis finalisé (en attente)'
        WHEN 3 THEN 'Commande confirmée'
        WHEN 4 THEN 'Commande terminée'
    END                                                               AS statut_commande,
    so.creation_date                                                  AS date_creation,
    so.confirmation_date_time                                         AS date_confirmation,
    uc.name                                                           AS confirme_par,
    us.name                                                           AS commercial,
    so.external_reference                                             AS reference_client,
    cl.full_name                                                      AS client,
    fa.full_name                                                      AS entite_facturee,
    li.full_name                                                      AS entite_livree,
    CASE
        WHEN so.invoiced_partner IS NULL OR so.delivered_partner IS NULL THEN 'Non renseigné'
        WHEN so.invoiced_partner = so.delivered_partner THEN 'Livré = facturé'
        ELSE 'Livré ≠ facturé (groupement)'
    END                                                               AS cas_adresse,
    so.delivery_address_str                                           AS adresse_livraison,
    so.main_invoicing_address_str                                     AS adresse_facturation,
    sol.sequence                                                      AS num_ligne,
    p.code                                                            AS code_article,
    COALESCE(sol.product_name, p.name)                                AS article,
    sol.qty                                                           AS qte_commandee,
    COALESCE(sol.delivered_qty, 0)                                    AS qte_livree,
    sol.qty - COALESCE(sol.delivered_qty, 0)                          AS reste_a_livrer,
    sol.nb_colis                                                      AS nb_colis,
    sol.poids_total_net                                               AS poids_net_kg,
    sol.ex_tax_total                                                  AS montant_ht,
    CASE sol.delivery_state
        WHEN 1 THEN 'Non livré'
        WHEN 2 THEN 'Livraison partielle'
        WHEN 3 THEN 'Livré'
        ELSE 'Non livré'
    END                                                               AS etat_livraison,
    COALESCE(lo.nb_lots, 0)                                           AS nb_lots,
    CASE WHEN COALESCE(lo.nb_lots, 0) > 0 THEN 'Oui' ELSE 'Non' END   AS lots_attribues_oui_non,
    lo.lots_attribues,
    lo.dluo_min,
    CASE
        WHEN (COALESCE(sol.qty_from_arrivage, 0) > 0 OR COALESCE(ar.nb_arrivages, 0) > 0)
         AND COALESCE(sol.qty_from_stock, 0) > 0 THEN 'Mixte (stock + flottant)'
        WHEN COALESCE(sol.qty_from_arrivage, 0) > 0 OR COALESCE(ar.nb_arrivages, 0) > 0 THEN 'Flottant'
        ELSE 'Stock'
    END                                                               AS origine_marchandise,
    COALESCE(sol.qty_from_arrivage, ar.qty_arrivage, 0)               AS qte_flottant,
    ar.commandes_achat                                                AS commandes_achat_flottant,
    COALESCE(bo.nb_bl, 0)                                             AS nb_bl,
    CASE
        WHEN COALESCE(bo.nb_bl, 0) = 0 THEN 'Aucun BL'
        WHEN bo.nb_bl = 1 THEN 'Livraison unique'
        ELSE 'Livraisons multiples'
    END                                                               AS type_livraison,
    bo.bl                                                             AS bons_livraison,
    bo.statut_bl,
    bo.frigos,
    COALESCE(bo.nb_frigos, 0)                                         AS nb_bons_frigo,
    COALESCE(bo.transporteur_bl, ca.full_name)                        AS transporteur,
    bo.date_livraison,
    NULLIF(TRIM(REGEXP_REPLACE(REPLACE(COALESCE(so.delivery_comments, ''), '&nbsp;', ' '), '<[^>]+>', ' ', 'g')), '')
                                                                      AS note_livraison,
    COALESCE(dc.nb_documents, 0)                                      AS nb_documents_archives,
    dc.documents                                                      AS documents_archives,
    COALESCE(em.nb_emails, 0)                                         AS nb_emails_envoyes,
    em.dernier_email                                                  AS dernier_email_envoye
FROM sale_sale_order_line sol
JOIN sale_sale_order so ON so.id = sol.sale_order
LEFT JOIN base_product p   ON p.id  = sol.product
LEFT JOIN base_partner cl  ON cl.id = so.client_partner
LEFT JOIN base_partner fa  ON fa.id = so.invoiced_partner
LEFT JOIN base_partner li  ON li.id = so.delivered_partner
LEFT JOIN base_partner ca  ON ca.id = so.carrier_partner
LEFT JOIN auth_user uc     ON uc.id = so.confirmed_by_user
LEFT JOIN auth_user us     ON us.id = so.salesperson_user
LEFT JOIN lots lo          ON lo.sale_order_line = sol.id
LEFT JOIN arrivages ar     ON ar.sale_order_line = sol.id
LEFT JOIN bons bo          ON bo.sale_order_line = sol.id
LEFT JOIN documents dc     ON dc.sale_order = so.id
LEFT JOIN emails em        ON em.sale_order = so.id
WHERE so.status_select IN (1, 2, 3, 4)
  AND COALESCE(sol.type_select, 0) = 0
ORDER BY so.sale_order_seq, sol.sequence

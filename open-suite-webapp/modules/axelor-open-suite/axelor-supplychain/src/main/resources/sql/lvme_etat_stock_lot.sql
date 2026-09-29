-- =====================================================================
-- REC-038 : vue lvme_etat_stock_lot (modèle Axelor EtatStockLot)
-- Reproduit l'écran « État des stocks par lots » de l'ancien système.
-- Une ligne par lot et par frigo :
--   * arrivages réels   : BR fournisseur réalisés (entrées, sorties, stock)
--   * arrivages flottants : BR fournisseur planifiés (« ce qu'il aura »)
--   * lots en stock sans BR d'origine (reprise / inventaire)
--
-- Règles :
--   Entrées   = quantités reçues du lot sur ce frigo (BR réalisés)
--   Stock     = quantité actuelle de la ligne de lot du frigo
--   Sorties   = Entrées - Stock (réel) ; 0 pour un flottant
--   Commandes = lignes de livraison client planifiées sur ce lot / frigo
--   Colis     = quantité / (quantité par colis de l'arrivage)
--   Valeur    = montant réel d'entrée au prorata du stock, sinon stock x PR
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le
-- modèle EtatStockLot, sinon Hibernate crée une table du même nom.
-- =====================================================================

CREATE OR REPLACE VIEW lvme_etat_stock_lot AS
WITH arrivages AS (
    -- Lignes de BR fournisseur (hors retours), réalisées ou planifiées
    SELECT sml.tracking_number,
           COALESCE(sml.to_stock_location, sm.to_stock_location)          AS frigo,
           MAX(sml.product)                                                AS product,
           MAX(sm.partner)                                                 AS supplier,
           STRING_AGG(DISTINCT sm.stock_move_seq, ', ')                    AS arrival_number,
           MAX(sml.origine)                                                AS origine,
           MAX(COALESCE(NULLIF(cond.label, ''), cond.code))                  AS conditionnement,
           MAX(sml.dluo)                                                   AS dluo_ligne,
           MAX(sml.prix_revient_reel)                                      AS pr_ligne,
           MAX(sml.unit)                                                   AS unit,
           MIN(COALESCE(sm.real_date, sm.estimated_date))                  AS entry_date,
           (sm.status_select = 2)                                          AS is_flottant,
           SUM(CASE WHEN sm.status_select = 3 THEN sml.real_qty ELSE sml.qty END) AS entree_qty,
           SUM(COALESCE(sml.nb_colis, 0))                                  AS nb_colis_in,
           MAX(COALESCE(sml.poids_par_colis, 0))                           AS poids_par_colis,
           SUM(COALESCE(sml.montant_reel, 0))                              AS montant_in
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    LEFT JOIN purchase_purchase_order_line pol ON pol.id = sml.purchase_order_line
    LEFT JOIN purchase_conditionnement cond ON cond.id = pol.conditionnement
    WHERE sm.type_select = 3
      AND sm.status_select IN (2, 3)
      AND COALESCE(sm.is_reversion, false) = false
      AND sml.tracking_number IS NOT NULL
    GROUP BY sml.tracking_number, COALESCE(sml.to_stock_location, sm.to_stock_location), (sm.status_select = 2)
),
stock_lots AS (
    -- Stock actuel des lots, par frigo (lignes de lot)
    SELECT l.tracking_number,
           l.details_stock_location AS frigo,
           MAX(l.product)           AS product,
           SUM(l.current_qty)       AS stock_qty
    FROM stock_stock_location_line l
    JOIN stock_stock_location sl ON sl.id = l.details_stock_location
    WHERE l.tracking_number IS NOT NULL
      AND sl.type_select = 1
    GROUP BY l.tracking_number, l.details_stock_location
),
commandes AS (
    -- Livraisons clients planifiées (non réalisées) sur le lot / frigo
    SELECT sml.tracking_number,
           COALESCE(sml.from_stock_location, sm.from_stock_location) AS frigo,
           SUM(sml.qty) AS cdes_qty
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    WHERE sm.type_select = 2
      AND sm.status_select = 2
      AND sml.tracking_number IS NOT NULL
    GROUP BY sml.tracking_number, COALESCE(sml.from_stock_location, sm.from_stock_location)
),
base AS (
    SELECT COALESCE(a.tracking_number, s.tracking_number) AS tracking_number,
           COALESCE(a.frigo, s.frigo)                     AS frigo,
           COALESCE(a.product, s.product)                 AS product,
           a.supplier, a.arrival_number, a.origine, a.conditionnement,
           a.dluo_ligne, a.pr_ligne, a.unit, a.entry_date,
           COALESCE(a.is_flottant, false)                 AS is_flottant,
           COALESCE(a.entree_qty, 0)                      AS entree_qty,
           COALESCE(a.nb_colis_in, 0)                     AS nb_colis_in,
           COALESCE(a.poids_par_colis, 0)                 AS poids_par_colis,
           COALESCE(a.montant_in, 0)                      AS montant_in,
           COALESCE(s.stock_qty, 0)                       AS stock_lot_qty
    FROM arrivages a
    FULL OUTER JOIN stock_lots s
      ON s.tracking_number = a.tracking_number AND s.frigo = a.frigo AND a.is_flottant = false
),
calc AS (
    SELECT b.*,
           t.tracking_number_seq,
           COALESCE(t.perishable_expiration_date, b.dluo_ligne)            AS dluo,
           COALESCE(NULLIF(t.prix_revient_reel, 0), b.pr_ligne, 0)         AS prix_revient,
           COALESCE(t.date_arrivage, b.entry_date)                         AS arrival_date,
           COALESCE(b.supplier, t.supplier)                                AS supplier_id,
           -- Stock : réel = ligne de lot ; flottant = quantité attendue
           CASE WHEN b.is_flottant THEN b.entree_qty ELSE b.stock_lot_qty END AS stock_qty,
           CASE WHEN b.is_flottant THEN 0 ELSE b.entree_qty - b.stock_lot_qty END AS sortie_qty,
           COALESCE(c.cdes_qty, 0)                                         AS cdes_qty,
           -- Quantité par colis de l'arrivage
           CASE WHEN b.nb_colis_in > 0 AND b.entree_qty > 0 THEN b.entree_qty / b.nb_colis_in
                WHEN b.poids_par_colis > 0 THEN b.poids_par_colis
                ELSE NULL END                                              AS qty_per_colis
    FROM base b
    JOIN stock_tracking_number t ON t.id = b.tracking_number
    LEFT JOIN commandes c ON c.tracking_number = b.tracking_number AND c.frigo = b.frigo AND b.is_flottant = false
)
SELECT ((c.tracking_number * 1000000 + COALESCE(c.frigo, 0)) * 10 + CASE WHEN c.is_flottant THEN 2 ELSE 1 END)::bigint AS id,
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
       p.code                            AS product_code,
       p.name                            AS product_name,
       p.product_category                AS product_category_id,
       c.supplier_id                     AS supplier_id,
       pa.full_name                      AS supplier_name,
       c.frigo                           AS stock_location_id,
       c.tracking_number                 AS tracking_number_id,
       c.tracking_number_seq             AS lot_number,
       c.arrival_number                  AS arrival_number,
       c.origine                         AS origine,
       c.entry_date                      AS entry_date,
       c.arrival_date                    AS arrival_date,
       c.conditionnement                 AS conditionnement,
       c.dluo                            AS dluo,
       c.prix_revient                    AS prix_revient,
       COALESCE(c.unit, p.unit)          AS unit_id,
       CASE WHEN c.is_flottant THEN 2 ELSE 1 END AS nature_arrivage,
       CASE WHEN c.is_flottant THEN 'Flottant' ELSE 'Réel' END AS nature_label,
       ROUND(c.qty_per_colis, 3)         AS qty_per_colis,
       c.nb_colis_in                     AS nb_colis_in,
       ROUND(COALESCE(c.sortie_qty / c.qty_per_colis, 0), 3) AS nb_colis_out,
       ROUND(COALESCE(c.cdes_qty  / c.qty_per_colis, 0), 3) AS nb_colis_cdes,
       ROUND(COALESCE(c.stock_qty / c.qty_per_colis, 0), 3) AS nb_colis_stock,
       c.entree_qty                      AS entree_qty,
       c.sortie_qty                      AS sortie_qty,
       c.cdes_qty                        AS cdes_qty,
       c.stock_qty                       AS stock_qty,
       c.stock_qty - c.cdes_qty          AS dispo_qty,
       ROUND(CASE WHEN c.montant_in > 0 AND c.entree_qty > 0
                  THEN c.montant_in * c.stock_qty / c.entree_qty
                  ELSE c.stock_qty * c.prix_revient END, 2) AS stock_value
FROM calc c
JOIN base_product p ON p.id = c.product
LEFT JOIN base_partner pa ON pa.id = c.supplier_id;

-- =====================================================================
-- LVME : vue lvme_interrogation_produit (modèle Axelor InterrogationProduit)
-- Écran « Interrogation Produit » de GESCOM : une ligne par lot et par frigo, reprise de l'état des stocks par lots
-- (lvme_etat_stock_lot : mêmes règles réel / flottant) complétée de la ligne d'arrivage du lot :
--   Marque, Gencode (de la ligne, sinon de l'article), Obs, Devise et Cours devise de l'arrivage
--   (cours réel, sinon cours flottant), Lot fournisseur, Jours de stock (jours depuis la livraison, 0 si à venir).
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le modèle InterrogationProduit, sinon Hibernate
-- crée une table du même nom.
-- =====================================================================

CREATE OR REPLACE VIEW lvme_interrogation_produit AS
SELECT e.id,
       e.version,
       e.archived,
       e.created_by,
       e.created_on,
       e.updated_by,
       e.updated_on,
       e.import_id,
       e.import_origin,
       e.process_instance_id,
       e.attrs,
       e.product_id,
       e.product_code,
       e.product_name,
       e.product_category_id,
       e.supplier_id,
       e.supplier_name,
       e.stock_location_id,
       e.tracking_number_id,
       e.lot_number,
       e.arrival_number,
       e.origine,
       e.arrival_date,
       e.conditionnement,
       e.dluo,
       e.prix_revient,
       e.nature_arrivage,
       e.qty_per_colis,
       e.nb_colis_in,
       e.nb_colis_out,
       e.nb_colis_cdes,
       e.nb_colis_stock,
       e.nb_colis_stock - e.nb_colis_cdes                     AS nb_colis_dispo,
       e.stock_qty,
       e.dispo_qty,
       e.stock_value,
       e.date_congelation,
       a.marque                                               AS marque,
       COALESCE(a.gencode, p.gencode)                         AS gencode,
       a.obs                                                  AS obs,
       a.devise                                               AS devise,
       a.cours                                                AS cours_devise,
       lf.supplier_lot_number                                 AS lot_fournisseur,
       CASE WHEN e.arrival_date IS NULL THEN 0
            ELSE GREATEST(0, CURRENT_DATE - e.arrival_date) END AS jours_stock
FROM lvme_etat_stock_lot e
JOIN base_product p ON p.id = e.product_id
JOIN stock_tracking_number t ON t.id = e.tracking_number_id
LEFT JOIN stock_lot_fournisseur lf ON lf.id = t.lot_fournisseur
LEFT JOIN LATERAL (
    -- dernière ligne d'arrivage du lot
    SELECT sml.marque, sml.gencode, sml.obs, c.code AS devise,
           COALESCE(NULLIF(sm.lvme_reel, 0), sm.lvme_flottant) AS cours
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    LEFT JOIN purchase_purchase_order_line pol ON pol.id = sml.purchase_order_line
    LEFT JOIN purchase_purchase_order po ON po.id = pol.purchase_order
    LEFT JOIN base_currency c ON c.id = po.currency
    WHERE sml.tracking_number = e.tracking_number_id
      AND sm.type_select = 3
      AND sm.status_select IN (2, 3)
    ORDER BY sm.id DESC
    LIMIT 1
) a ON true;

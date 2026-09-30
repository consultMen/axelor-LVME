-- =====================================================================
-- LVME : vue lvme_synthese_arrivage (modèle Axelor SyntheseArrivage)
-- Reproduit l'écran « Synthèse des Arrivages » de GESCOM (diapo 24).
-- Une ligne par ligne d'arrivage réel (réception fournisseur réalisée, hors retours).
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le
-- modèle SyntheseArrivage, sinon Hibernate crée une table du même nom.
-- =====================================================================

DROP VIEW IF EXISTS lvme_synthese_arrivage;
CREATE VIEW lvme_synthese_arrivage AS
SELECT sml.id                            AS id,
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
       sm.id                             AS stock_move_id,
       sml.id                            AS stock_move_line_id,
       sm.stock_move_seq::varchar        AS arrivage,
       (sm.stock_move_seq || '   ' || COALESCE(pa.name, '') || '   ' || COALESCE(pa.partner_seq, '')
          || COALESCE('   Embarq. ' || to_char(sm.supplier_shipment_date, 'DD/MM/YYYY'), '')
          || COALESCE('   Arrivée ' || to_char(sm.real_date, 'DD/MM/YYYY'), ''))::varchar AS entete,
       pa.id                             AS supplier_id,
       pa.name::varchar                  AS fournisseur,
       pa.partner_seq::varchar           AS code_fournisseur,
       sm.supplier_shipment_date         AS date_embarquement,
       sm.real_date                      AS date_arrivee,
       sml.product                       AS product_id,
       p.code::varchar                   AS product_code,
       COALESCE(sml.product_name, p.name)::varchar AS designation,
       sml.origine::varchar              AS origine,
       COALESCE(NULLIF(cond.label, ''), cond.code)::varchar AS conditionnement,
       fr.name::varchar                  AS frigo,
       sml.tracking_number               AS tracking_number_id,
       tn.tracking_number_seq::varchar   AS lot_number,
       sml.dluo                          AS dlc,
       u.name::varchar                   AS unite,
       sml.nb_colis                      AS nb_colis,
       sml.poids_par_colis               AS poids_colis,
       sml.real_qty                      AS poids_total,
       sml.unit_price_untaxed            AS pa
FROM stock_stock_move_line sml
JOIN stock_stock_move sm ON sm.id = sml.stock_move
JOIN base_product p ON p.id = sml.product
LEFT JOIN base_partner pa ON pa.id = sm.partner
LEFT JOIN stock_stock_location fr ON fr.id = COALESCE(sml.to_stock_location, sm.to_stock_location)
LEFT JOIN stock_tracking_number tn ON tn.id = sml.tracking_number
LEFT JOIN base_unit u ON u.id = sml.unit
LEFT JOIN purchase_purchase_order_line pol ON pol.id = sml.purchase_order_line
LEFT JOIN purchase_conditionnement cond ON cond.id = pol.conditionnement
WHERE sm.type_select = 3
  AND sm.status_select = 3
  AND COALESCE(sm.is_reversion, false) = false;

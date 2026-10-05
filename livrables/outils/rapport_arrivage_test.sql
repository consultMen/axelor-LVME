
SELECT
  sm.stock_move_seq AS numero,
  '<div style="font-weight:bold;border-bottom:1px solid #999;margin-bottom:2px">Fournisseur</div><table style="font-size:8pt">' || '<tr><td style="color:#666;padding-right:6px">Fournisseur</td><td><b>' || replace(replace(replace(COALESCE((p.full_name)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Code</td><td><b>' || replace(replace(replace(COALESCE((p.partner_seq)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Adresse</td><td><b>' || replace(replace(replace(COALESCE((replace(COALESCE(sm.from_address_str, ''), chr(10), ' '))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Contact</td><td><b>' || replace(replace(replace(COALESCE((ct.full_name)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Tél.</td><td><b>' || replace(replace(replace(COALESCE((p.fixed_phone)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Email</td><td><b>' || replace(replace(replace(COALESCE((em.address)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Règlement</td><td><b>' || replace(replace(replace(COALESCE((pm.name)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Échéance</td><td><b>' || replace(replace(replace(COALESCE((pc.name)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '</table>' AS bloc1,
  '<div style="font-weight:bold;border-bottom:1px solid #999;margin-bottom:2px">Arrivage</div><table style="font-size:8pt">' || '<tr><td style="color:#666;padding-right:6px">Opérateur</td><td><b>' || replace(replace(replace(COALESCE((bu.full_name)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Arrivage N°</td><td><b>' || replace(replace(replace(COALESCE((sm.stock_move_seq)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Du</td><td><b>' || replace(replace(replace(COALESCE((to_char(sm.created_on, 'DD/MM/YYYY'))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Nature</td><td><b>' || replace(replace(replace(COALESCE((CASE sm.nature WHEN 1 THEN 'Flottant - à embarquer' WHEN 2 THEN 'Flottant' WHEN 3 THEN 'Réel' WHEN 4 THEN 'Annulé' ELSE 'Brouillon' END)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Commande</td><td><b>' || replace(replace(replace(COALESCE((po.purchase_order_seq)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Date Départ</td><td><b>' || replace(replace(replace(COALESCE((to_char(sm.supplier_shipment_date, 'DD/MM/YYYY'))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Arrivée</td><td><b>' || replace(replace(replace(COALESCE((to_char(COALESCE(sm.real_date, sm.estimated_date), 'DD/MM/YYYY'))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Type transport</td><td><b>' || replace(replace(replace(COALESCE((shm.name)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Bateau</td><td><b>' || replace(replace(replace(COALESCE((bt.name)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Containers</td><td><b>' || replace(replace(replace(COALESCE(((SELECT string_agg(c.name, ', ') FROM stock_stock_move_container_set cs JOIN stock_container c ON c.id = cs.container_set WHERE cs.stock_stock_move = sm.id))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Transitaire</td><td><b>' || replace(replace(replace(COALESCE((fw.full_name)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Frigo</td><td><b>' || replace(replace(replace(COALESCE((fr.name)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '</table>' AS bloc2,
  '<div style="font-weight:bold;border-bottom:1px solid #999;margin-bottom:2px">Devise</div><table style="font-size:8pt">' || '<tr><td style="color:#666;padding-right:6px">Devise</td><td><b>' || replace(replace(replace(COALESCE((cur.code)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Cours</td><td><b>' || replace(replace(replace(COALESCE((replace(replace(to_char(sm.lvme_cours, 'FM999,999,999,990.0000'), ',', ' '), '.', ','))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Couvert</td><td><b>' || replace(replace(replace(COALESCE((replace(replace(to_char(sm.lvme_couvert, 'FM999,999,999,990.0000'), ',', ' '), '.', ','))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Flottant</td><td><b>' || replace(replace(replace(COALESCE((replace(replace(to_char(sm.lvme_flottant, 'FM999,999,999,990.0000'), ',', ' '), '.', ','))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Réel</td><td><b>' || replace(replace(replace(COALESCE((replace(replace(to_char(sm.lvme_reel, 'FM999,999,999,990.0000'), ',', ' '), '.', ','))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Mt Achat HT</td><td><b>' || replace(replace(replace(COALESCE((replace(replace(to_char(sm.ex_tax_total, 'FM999,999,999,990.00'), ',', ' '), '.', ',') || ' ' || COALESCE(cur.code, ''))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Équivalent</td><td><b>' || replace(replace(replace(COALESCE((CASE WHEN cur.id IS DISTINCT FROM co.currency THEN replace(replace(to_char((SELECT SUM(CASE WHEN sm.status_select = 3 THEN l.real_qty ELSE l.qty END * COALESCE(l.company_unit_price_untaxed, 0)) FROM stock_stock_move_line l WHERE l.stock_move = sm.id), 'FM999,999,999,990.00'), ',', ' '), '.', ',') || ' ' || COALESCE(ccur.code, '') END)::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Nb Colis</td><td><b>' || replace(replace(replace(COALESCE((replace(replace(to_char(sm.nb_colis_total, 'FM999,999,999,990'), ',', ' '), '.', ','))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '<tr><td style="color:#666;padding-right:6px">Poids Total</td><td><b>' || replace(replace(replace(COALESCE((replace(replace(to_char(sm.poids_total, 'FM999,999,999,990.000'), ',', ' '), '.', ','))::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') || '</b></td></tr>' || '</table>' AS bloc3
FROM stock_stock_move sm
LEFT JOIN base_partner p ON p.id = sm.partner
LEFT JOIN message_email_address em ON em.id = p.email_address
LEFT JOIN stock_stock_move_purchase_order_set r ON r.stock_stock_move = sm.id
LEFT JOIN purchase_purchase_order po ON po.id = r.purchase_order_set
LEFT JOIN base_partner ct ON ct.id = po.contact_partner
LEFT JOIN base_company co ON co.id = sm.company
LEFT JOIN base_currency cur ON cur.id = COALESCE(po.currency, co.currency)
LEFT JOIN base_currency ccur ON ccur.id = co.currency
LEFT JOIN account_payment_mode pm ON pm.id = po.payment_mode
LEFT JOIN account_payment_condition pc ON pc.id = po.payment_condition
LEFT JOIN auth_user bu ON bu.id = po.buyer_user
LEFT JOIN stock_shipment_mode shm ON shm.id = sm.shipment_mode
LEFT JOIN stock_bateau bt ON bt.id = sm.bateau
LEFT JOIN base_partner fw ON fw.id = sm.forwarder_partner
LEFT JOIN stock_stock_location fr ON fr.id = sm.to_stock_location
WHERE sm.id = 33
LIMIT 1
;
SELECT * FROM (
SELECT 0 AS ordre, l.sequence AS seq, '0' AS is_total,
  (pr.code)::text AS produit,
  (l.product_name)::text AS designation,
  (fr.name)::text AS frigo,
  (tn.tracking_number_seq)::text AS lot,
  (l.origine)::text AS origine,
  (COALESCE(NULLIF(cd.label, ''), cd.code))::text AS cond,
  (replace(replace(to_char(l.unit_price_untaxed, 'FM999,999,999,990.00'), ',', ' '), '.', ','))::text AS pa,
  (replace(replace(to_char(l.pr_kg, 'FM999,999,999,990.00'), ',', ' '), '.', ','))::text AS pr,
  (u.name)::text AS unite,
  (replace(replace(to_char(l.nb_colis, 'FM999,999,999,990'), ',', ' '), '.', ','))::text AS colis,
  (replace(replace(to_char(COALESCE(NULLIF(l.nb_unites_par_colis, 0), l.poids_par_colis), 'FM999,999,999,990'), ',', ' '), '.', ','))::text AS parcolis,
  (replace(replace(to_char(CASE WHEN sm.status_select = 3 THEN l.real_qty ELSE l.qty END, 'FM999,999,999,990'), ',', ' '), '.', ','))::text AS qte,
  (replace(replace(to_char(l.poids_total_net, 'FM999,999,999,990'), ',', ' '), '.', ','))::text AS poids,
  (replace(replace(to_char(COALESCE(NULLIF(l.montant_reel, 0), (CASE WHEN sm.status_select = 3 THEN l.real_qty ELSE l.qty END) * l.unit_price_untaxed), 'FM999,999,999,990.00'), ',', ' '), '.', ','))::text AS montant,
  (to_char(l.dluo, 'DD/MM/YYYY'))::text AS dluo,
  (l.zone_peche)::text AS zone
FROM stock_stock_move_line l
JOIN stock_stock_move sm ON sm.id = l.stock_move
LEFT JOIN base_product pr ON pr.id = l.product
LEFT JOIN stock_stock_location fr ON fr.id = COALESCE(l.to_stock_location, sm.to_stock_location)
LEFT JOIN stock_tracking_number tn ON tn.id = l.tracking_number
LEFT JOIN purchase_purchase_order_line pol ON pol.id = l.purchase_order_line
LEFT JOIN purchase_conditionnement cd ON cd.id = pol.conditionnement
LEFT JOIN base_unit u ON u.id = l.unit
WHERE l.stock_move = 33
UNION ALL
SELECT 1, 0, '1',
  'Somme' AS produit,
  NULL::text AS designation,
  NULL::text AS frigo,
  NULL::text AS lot,
  NULL::text AS origine,
  NULL::text AS cond,
  NULL::text AS pa,
  NULL::text AS pr,
  NULL::text AS unite,
  (replace(replace(to_char(SUM(l.nb_colis), 'FM999,999,999,990'), ',', ' '), '.', ','))::text AS colis,
  NULL::text AS parcolis,
  (replace(replace(to_char(SUM(CASE WHEN sm.status_select = 3 THEN l.real_qty ELSE l.qty END), 'FM999,999,999,990'), ',', ' '), '.', ','))::text AS qte,
  (replace(replace(to_char(SUM(l.poids_total_net), 'FM999,999,999,990'), ',', ' '), '.', ','))::text AS poids,
  (replace(replace(to_char(SUM(COALESCE(NULLIF(l.montant_reel, 0), (CASE WHEN sm.status_select = 3 THEN l.real_qty ELSE l.qty END) * l.unit_price_untaxed)), 'FM999,999,999,990.00'), ',', ' '), '.', ','))::text AS montant,
  NULL::text AS dluo,
  NULL::text AS zone
FROM stock_stock_move_line l
JOIN stock_stock_move sm ON sm.id = l.stock_move
LEFT JOIN base_product pr ON pr.id = l.product
LEFT JOIN stock_stock_location fr ON fr.id = COALESCE(l.to_stock_location, sm.to_stock_location)
LEFT JOIN stock_tracking_number tn ON tn.id = l.tracking_number
LEFT JOIN purchase_purchase_order_line pol ON pol.id = l.purchase_order_line
LEFT JOIN purchase_conditionnement cd ON cd.id = pol.conditionnement
LEFT JOIN base_unit u ON u.id = l.unit
WHERE l.stock_move = 33
) x ORDER BY ordre, seq;

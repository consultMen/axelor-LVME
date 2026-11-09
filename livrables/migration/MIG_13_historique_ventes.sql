-- =====================================================================
-- MIGRATION GESCOM — étape 13 : historique des ventes (table HIS_VTE, 2013-2021)
--   HIS_VTE : une ligne par article vendu, 2013 à 2026 (client, article, date, prix de vente, prix de revient,
--   poids, colis, lot, n° d'arrivage, origine, conditionnement). Les lignes reliées à une ligne de commande CCD
--   (ID_CCD) sont déjà dans LVME (MIG_06), ou en sont d'anciennes versions : seules les lignes sans ID_CCD sont
--   reprises (249 218 lignes, 2013-2021).
--   Reprise :
--   - une commande client « Terminée » par client et par jour (HIS_VTE n'a ni n° de commande ni n° de BL) :
--     n° « HV-<code client>-<aaaammjj> », livrée, facturée dans GESCOM (aucune facture Axelor) ; aucun BL, aucun
--     mouvement de stock, aucune écriture comptable : historique consultable (Historique prix, Lignes commandes
--     clients, Palmarès, listes) ;
--   - une ligne par vente : article, désignation, poids (quantité, kg), colis, poids colis, prix de vente, montant HT,
--     TVA 5,5 % (taux de tous les articles GESCOM), prix de revient GESCOM ; lot vendu si le lot existe dans LVME,
--     sinon lot / arrivage / origine / conditionnement en description ;
--   - marge avec la formule LVME inchangée (comme MIG_06) : montant HT - prix de revient x poids.
--   Dates : 26 dates aberrantes (2001, 2002, 2012, 2033) corrigées avec l'année du n° d'arrivage (AAMM…).
-- Prérequis : MIG_00 (archive avec HIS_VTE), MIG_01 à MIG_06. Relançable : commandes HV-… et lignes déjà reprises
-- (même clé GESCOM) non recréées.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE mig_def ON COMMIT DROP AS
SELECT (SELECT id FROM base_company ORDER BY id LIMIT 1) AS societe,
       (SELECT id FROM base_currency WHERE codeiso = 'EUR' LIMIT 1) AS euro,
       (SELECT id FROM base_unit WHERE upper(btrim(name)) IN ('KG', 'KILOGRAMME') ORDER BY id LIMIT 1) AS kg,
       (SELECT tl.id FROM account_tax_line tl JOIN account_tax t ON t.id = tl.tax WHERE t.code = 'R2_C' ORDER BY tl.id LIMIT 1) AS tva55;

-- ---------- correspondances ----------
CREATE TEMP TABLE mig_article ON COMMIT DROP AS
SELECT DISTINCT ON (upper(code)) upper(code) AS ref, id, unit, name FROM base_product
WHERE code IS NOT NULL ORDER BY upper(code), (import_origin = 'GESCOM') DESC, id;
CREATE INDEX ON mig_article (ref);
CREATE TEMP TABLE mig_client_code ON COMMIT DROP AS
SELECT DISTINCT ON (upper(partner_seq)) upper(partner_seq) AS code, id, main_address FROM base_partner
WHERE is_customer AND partner_seq IS NOT NULL ORDER BY upper(partner_seq), archived NULLS FIRST, id;
CREATE INDEX ON mig_client_code (code);
CREATE TEMP TABLE mig_lot ON COMMIT DROP AS
SELECT t.id, upper(btrim(t.lvme_numero_base)) AS lot, t.product, m.stock_move_seq AS arrivage, t.lot_fournisseur,
  t.perishable_expiration_date AS dlc
FROM stock_tracking_number t
LEFT JOIN stock_stock_move_line ml ON ml.id = t.origin_stock_move_line
LEFT JOIN stock_stock_move m ON m.id = ml.stock_move
WHERE t.import_id LIKE 'GESCOM-LOT-%' AND t.lvme_numero_base IS NOT NULL;
CREATE INDEX ON mig_lot (lot, product);

-- ---------- lignes à reprendre : sans lien vers une ligne CCD déjà reprise ----------
CREATE TEMP TABLE mig_hv ON COMMIT DROP AS
SELECT h.*, a.id AS article, coalesce(a.unit, (SELECT kg FROM mig_def)) AS unite_id, a.name AS nom_article,
  c.id AS client, c.main_address, upper(btrim(h.ref_client)) AS code_client,
  gescom.dt(h.date_creation) AS date_brute,
  coalesce(gescom.num(h.poids), 0) AS qte, coalesce(gescom.num(h.px_vente), 0) AS prix,
  NULLIF(gescom.num(h.px_revient), 0) AS prix_revient,
  regexp_replace(coalesce(h.num_arrivage, ''), '\D', '', 'g') AS arr
FROM gescom.his_vte h
JOIN mig_client_code c ON c.code = upper(btrim(h.ref_client))
LEFT JOIN mig_article a ON a.ref = upper(btrim(h.ref_articles))
-- les 318 lignes dont l'ID_CCD ne correspond plus à aucune ligne CCD sont d'anciennes versions de lignes de commandes
-- reprises (279 dans une commande existante, 205 avec le même article) : non reprises (doublons)
WHERE coalesce(btrim(h.id_ccd), '0') IN ('', '0');
-- date : aberrante (avant 2013 ou dans le futur) -> année du n° d'arrivage (AAMMNN ou AMMNN), jour et mois gardés
ALTER TABLE mig_hv ADD COLUMN date_vte date;
UPDATE mig_hv SET date_vte = CASE
    WHEN date_brute IS NOT NULL AND date_brute BETWEEN DATE '2013-01-01' AND current_date THEN date_brute
    WHEN date_brute IS NOT NULL AND length(arr) IN (5, 6) THEN make_date(
      2000 + CASE WHEN length(arr) = 6 THEN left(arr, 2)::int ELSE left(arr, 1)::int END,
      extract(month FROM date_brute)::int, least(extract(day FROM date_brute)::int, 28))
    ELSE date_brute END;
DELETE FROM mig_hv WHERE date_vte IS NULL;
CREATE INDEX ON mig_hv (client, date_vte);

-- ---------- commandes : une par client et par jour ----------
CREATE TEMP TABLE mig_cde ON COMMIT DROP AS
SELECT client, date_vte, min(code_client) AS code_client, min(main_address) AS adresse,
  'HV-' || min(code_client) || '-' || to_char(date_vte, 'YYYYMMDD') AS num,
  round(sum(round(qte * prix, 2)), 2) AS montant
FROM mig_hv GROUP BY client, date_vte;
ALTER TABLE mig_cde ADD COLUMN id bigint, ADD COLUMN nouveau boolean;
UPDATE mig_cde m SET id = s.id FROM sale_sale_order s WHERE s.import_id = 'GESCOM-HVC-' || m.num;
UPDATE mig_cde SET nouveau = (id IS NULL);
UPDATE mig_cde SET id = nextval('sale_sale_order_seq') WHERE id IS NULL;
CREATE INDEX ON mig_cde (client, date_vte);

INSERT INTO sale_sale_order (id, version, created_on, import_id, import_origin, sale_order_seq, full_name, company,
  client_partner, invoiced_partner, delivered_partner, currency, status_select, sale_order_type_select, creation_date,
  order_date, confirmation_date_time, estimated_delivery_date, ex_tax_total, company_ex_tax_total, tax_total,
  in_tax_total, invoice_comments, description, delivery_state, invoicing_state, template, in_ati, version_number,
  amount_invoiced, advance_total, discount_amount, price_before_global_discount, oneoff_sale, order_being_edited,
  manual_unblock, number_of_periods, main_invoicing_address)
SELECT m.id, 0, now(), 'GESCOM-HVC-' || m.num, 'GESCOM', m.num,
  m.num || ' - ' || coalesce((SELECT name FROM base_partner WHERE id = m.client), ''),
  d.societe, m.client, m.client, m.client, d.euro, 4, 1, m.date_vte, m.date_vte, m.date_vte::timestamp, m.date_vte,
  m.montant, m.montant, round(m.montant * 0.055, 2), m.montant + round(m.montant * 0.055, 2),
  'Historique GESCOM (HIS_VTE) : facturé dans GESCOM', 'Historique des ventes GESCOM', 3, 3, false, false, 1,
  m.montant, 0, 0, m.montant, false, false, false, 1, m.adresse
FROM mig_cde m CROSS JOIN mig_def d
WHERE m.nouveau;

-- ---------- lignes ----------
CREATE TEMP TABLE mig_ligne ON COMMIT DROP AS
SELECT h.*, m.id AS commande,
  row_number() OVER (PARTITION BY m.id ORDER BY gescom.num(h.idhis_vte)) AS rang,
  nextval('sale_sale_order_line_seq') AS ligne_id,
  round(h.qte * h.prix, 2) AS montant
FROM mig_hv h JOIN mig_cde m ON m.client = h.client AND m.date_vte = h.date_vte
WHERE NOT EXISTS (SELECT 1 FROM sale_sale_order_line l WHERE l.import_id = 'GESCOM-HVL-' || btrim(h.idhis_vte));
CREATE INDEX ON mig_ligne (commande);
ALTER TABLE mig_ligne ADD COLUMN lot_id bigint;
UPDATE mig_ligne g SET lot_id = x.id
FROM (SELECT DISTINCT ON (g2.ligne_id) g2.ligne_id, t.id
      FROM mig_ligne g2 JOIN mig_lot t ON t.lot = upper(btrim(g2.lot)) AND t.product = g2.article
      WHERE g2.article IS NOT NULL AND gescom.txt(g2.lot) IS NOT NULL
      ORDER BY g2.ligne_id, (t.arrivage = btrim(g2.num_arrivage)) DESC NULLS LAST, t.id) x
WHERE g.ligne_id = x.ligne_id;

ANALYZE sale_sale_order;
INSERT INTO sale_sale_order_line (id, version, created_on, import_id, import_origin, sale_order, sequence, type_select,
  product, product_name, unit, qty, delivered_qty, price, price_discounted, in_tax_price, ex_tax_total,
  company_ex_tax_total, in_tax_total, company_in_tax_total, discount_type_select, discount_amount, nb_colis,
  poids_par_colis, prix_revient, prix_revient_net, delivery_state, invoicing_state, invoiced, amount_invoiced,
  estimated_delivery_date, full_name, description)
SELECT g.ligne_id, 0, now(), 'GESCOM-HVL-' || btrim(g.idhis_vte), 'GESCOM', g.commande, g.rang, 0, g.article,
  coalesce(g.nom_article, gescom.txt(g.des1), gescom.txt(g.ref_articles), 'Ligne'),
  g.unite_id, g.qte, g.qte, g.prix, g.prix, round(g.prix * 1.055, 4), g.montant, g.montant,
  round(g.montant * 1.055, 2), round(g.montant * 1.055, 2), 0, 0,
  NULLIF(gescom.num(g.colis), 0), NULLIF(gescom.num(g.poids_unt), 0), g.prix_revient, g.prix_revient, 3, 3, true,
  g.montant, g.date_vte,
  left(g.rang || ' - ' || coalesce(g.nom_article, gescom.txt(g.des1), gescom.txt(g.ref_articles), ''), 255),
  NULLIF(concat_ws(' - ', CASE WHEN g.lot_id IS NULL THEN 'Lot ' || gescom.txt(g.lot) END,
    'Arrivage ' || gescom.txt(g.num_arrivage), 'Origine ' || gescom.txt(g.origine),
    'Cond. ' || gescom.txt(g.condit),
    CASE WHEN g.article IS NULL THEN 'Article GESCOM ' || gescom.txt(g.ref_articles) END), '')
FROM mig_ligne g;

INSERT INTO sale_sale_order_line_tax_line_set (sale_sale_order_line, tax_line_set)
SELECT g.ligne_id, d.tva55 FROM mig_ligne g CROSS JOIN mig_def d WHERE d.tva55 IS NOT NULL;

-- lot vendu (s'il existe dans LVME)
ANALYZE sale_sale_order_line;
INSERT INTO supplychain_sale_order_line_lot (id, version, created_on, import_id, import_origin, sale_order_line,
  tracking_number, lot_fournisseur, qty_to_ship, available_qty, perishable_expiration_date)
SELECT nextval('supplychain_sale_order_line_lot_seq'), 0, now(), 'GESCOM-HVLOT-' || btrim(g.idhis_vte), 'GESCOM',
  g.ligne_id, g.lot_id, t.lot_fournisseur, g.qte, 0, t.perishable_expiration_date
FROM mig_ligne g JOIN stock_tracking_number t ON t.id = g.lot_id;

-- poids total de la ligne (colonne « Poids » de l'Historique prix) = poids vendu (tout est en kg)
UPDATE sale_sale_order_line SET poids_total_net = qty, version = version + 1
WHERE import_id LIKE 'GESCOM-HVL-%' AND poids_total_net IS NULL;

-- ---------- marge : formule LVME inchangée (comme MIG_06) ----------
UPDATE sale_sale_order_line l SET sub_total_cost_price = x.cout, sub_total_gross_margin = x.marge,
  sub_margin_rate = CASE WHEN coalesce(l.ex_tax_total, 0) <> 0 THEN round(x.marge * 100 / l.ex_tax_total, 2) ELSE 0 END,
  sub_total_markup = CASE WHEN x.cout <> 0 THEN round(x.marge * 100 / x.cout, 2) ELSE 0 END
FROM (SELECT id, round(coalesce(prix_revient_net, 0) * coalesce(qty, 0), 2) AS cout,
             round(coalesce(ex_tax_total, 0) - round(coalesce(prix_revient_net, 0) * coalesce(qty, 0), 2), 2) AS marge
      FROM sale_sale_order_line WHERE import_id LIKE 'GESCOM-HVL-%') x
WHERE l.id = x.id AND l.sub_total_gross_margin IS DISTINCT FROM x.marge;
UPDATE sale_sale_order s SET accounted_revenue = x.ca, total_cost_price = x.cout, total_gross_margin = x.marge,
  margin_rate = CASE WHEN x.ca <> 0 THEN round(x.marge * 100 / x.ca, 2) ELSE 0 END,
  markup = CASE WHEN x.cout <> 0 THEN round(x.marge * 100 / x.cout, 2) ELSE 0 END
FROM (SELECT sale_order, sum(coalesce(company_ex_tax_total, 0)) AS ca,
             sum(round(coalesce(prix_revient_net, 0) * coalesce(qty, 0), 2)) AS cout,
             sum(coalesce(sub_total_gross_margin, 0)) AS marge
      FROM sale_sale_order_line WHERE import_id LIKE 'GESCOM-HVL-%' GROUP BY sale_order) x
WHERE s.id = x.sale_order AND s.import_id LIKE 'GESCOM-HVC-%' AND s.total_gross_margin IS DISTINCT FROM x.marge;

ANALYZE sale_sale_order;
ANALYZE sale_sale_order_line;

COMMIT;

-- ---------- contrôle ----------
SELECT (SELECT count(*) FROM gescom.his_vte) AS lignes_his_vte,
  (SELECT count(*) FROM gescom.his_vte h WHERE coalesce(btrim(h.id_ccd), '0') NOT IN ('', '0')) AS deja_dans_lvme,
  (SELECT count(*) FROM sale_sale_order_line WHERE import_id LIKE 'GESCOM-HVL-%') AS lignes_reprises,
  (SELECT count(*) FROM sale_sale_order WHERE import_id LIKE 'GESCOM-HVC-%') AS commandes,
  (SELECT count(*) FROM supplychain_sale_order_line_lot WHERE import_id LIKE 'GESCOM-HVLOT-%') AS lignes_avec_lot,
  (SELECT round(sum(ex_tax_total)) FROM sale_sale_order WHERE import_id LIKE 'GESCOM-HVC-%') AS ca_repris;
SELECT extract(year FROM order_date)::int AS annee, count(*) AS commandes, round(sum(ex_tax_total)) AS ca_ht,
  round(sum(total_gross_margin)) AS marge
FROM sale_sale_order WHERE import_id LIKE 'GESCOM-HVC-%' GROUP BY 1 ORDER BY 1;

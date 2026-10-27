-- =====================================================================
-- MIGRATION GESCOM — étape 05 : arrivages (commandes fournisseurs + réceptions), lots et stock
--   Source : archive gescom.arr_entete, arr_ligne, articles_lot (MIG_00). Prérequis : MIG_01 à MIG_04.
--   Décisions du 27/10/2026 : historique complet ; lots en stock négatif gardés négatifs.
--   - lots fournisseur (fournisseur + article + n° de lot fournisseur) ;
--   - lots (ARTICLES_LOT, clé « référence article,n° lot ») : n° interne, lot fournisseur, DLC, prix de revient,
--     fournisseur, lot vérifié
--   - articles qui n'existent plus dans ARTICLES (supprimés dans GESCOM) : créés archivés ;
--   - arrivages (ARR_ENTETE) : une commande fournisseur (n° = n° d'arrivage GESCOM) et un arrivage ; Réel (réceptionné)
--     si au moins une ligne a un lot réel, sinon Flottant (prévu) ; fournisseur, dates (départ, arrivée,
--     livraison), devise, taux flottant / réel / couvert, frais d'approche, mode de transport (type d'arrivage :
--     camion / bateau / avion), bateau, containers,
--     transitaire / gestionnaire en note, montant, colis, poids
--   - lignes (ARR_LIGNE) : article, lot, frigo (FRIGO si GESCOM n'en a pas), quantité (quantité entrée du lot, sinon colis x poids colis), colis,
--     poids colis, prix d'achat, prix de revient, montant, conditionnement, origine, zone de pêche, marque, mode de
--     pêche, DLC, date de congélation, lot fournisseur
--   - stock : pour chaque lot, entrées - sorties GESCOM (QENT - QSOR) dans son frigo (négatif gardé) ; lot d'un
--     arrivage flottant (en mer) : « moins les sorties », l'écran affiche entrées - sorties comme GESCOM ; ligne de
--     stock par lot et par article / frigo
--   - articles sans prix d'achat / de revient / poids colis : complétés avec leur dernier arrivage
-- Relançable : ce qui existe déjà (même clé GESCOM) n'est pas recréé.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE mig_def ON COMMIT DROP AS
SELECT (SELECT id FROM base_company ORDER BY id LIMIT 1) AS societe,
       (SELECT id FROM base_currency WHERE codeiso = 'EUR' LIMIT 1) AS euro,
       (SELECT id FROM stock_stock_location WHERE type_select <> 1 AND upper(name) LIKE 'RECEPTION%' ORDER BY id LIMIT 1)
         AS reception,
       (SELECT id FROM stock_shipment_mode WHERE upper(name) = 'CAMION' LIMIT 1) AS camion,
       (SELECT id FROM stock_shipment_mode WHERE upper(name) = 'BATEAU' LIMIT 1) AS mode_bateau,
       (SELECT id FROM base_unit WHERE upper(name) = 'KG' ORDER BY id LIMIT 1) AS kg,
       (SELECT id FROM stock_stock_location WHERE type_select = 1 AND upper(name) = 'FRIGO' ORDER BY id LIMIT 1) AS frigo_defaut;

-- mode de transport Avion (type d'arrivage GESCOM 381), la liste ne connaît que Bateau et Camion
INSERT INTO stock_shipment_mode (id, version, created_on, name, has_carriage_paid_possibility, import_id, import_origin)
SELECT nextval('stock_shipment_mode_seq'), 0, now(), 'Avion', false, 'GESCOM-TRANSPORT-AVION', 'GESCOM'
WHERE NOT EXISTS (SELECT 1 FROM stock_shipment_mode WHERE upper(name) = 'AVION');

-- articles des arrivages / lots qui n'existent plus dans ARTICLES (supprimés dans GESCOM) : créés archivés
INSERT INTO base_product (id, version, created_on, dtype, import_id, import_origin, code, name, full_name, unit, sales_unit,
  purchases_unit, product_type_select, product_sub_type_select, procurement_method_select, sellable, purchasable,
  stock_managed, product_family, tracking_number_configuration, sale_currency, purchase_currency, sale_price, purchase_price,
  cost_price, cost_type_select, manag_price_coef, real_or_estimated_price_select, sale_supply_select,
  bom_comp_valu_method_select, manuf_order_comp_valu_method_select, avg_price, attrs, product_attrs,
  allow_to_force_purchase_qty, allow_to_force_sale_qty, auto_update_sale_price, block_expense_tax, control_on_receipt,
  deduct_lunch_voucher, def_ship_coef_by_partner, exclude_from_mrp, expense, in_ati, is_activity, is_analytic_capture,
  is_model, is_prototype, is_shipping_costs_product, is_unrenewed, manage_variant_price, personal_expense,
  unavailable_to_users, used_indeb, archived)
SELECT nextval('base_product_seq'), 0, now(), 'Product', 'GESCOM-ART-SUPPR-' || x.ref, 'GESCOM', x.ref,
  x.nom || ' (supprimé dans GESCOM)', '[' || x.ref || '] ' || x.nom || ' (supprimé dans GESCOM)', k.id, k.id, k.id,
  'storable', 0, 'buy', true, true, true,
  (SELECT id FROM base_product_family ORDER BY (code = 'PR-SURG') DESC, id LIMIT 1),
  (SELECT id FROM stock_tracking_number_configuration WHERE generate_purchase_auto_tracking_nbr = true ORDER BY id LIMIT 1),
  d.euro, d.euro, 0, 0, 0, 1, 1, 1, 1, 2, 1, 0, '{}'::jsonb, '{}'::jsonb,
  false, false, false, false, false, false, false, false, false, false, false, false,
  false, false, false, false, false, false, false, false, true
FROM (SELECT upper(btrim(r.ref)) AS ref, coalesce(max(gescom.txt(r.desi)), upper(btrim(r.ref))) AS nom
      FROM (SELECT ref, desi FROM gescom.arr_ligne UNION ALL SELECT ref, NULL FROM gescom.articles_lot) r
      WHERE gescom.txt(r.ref) IS NOT NULL GROUP BY upper(btrim(r.ref))) x
CROSS JOIN mig_def d
LEFT JOIN base_unit k ON k.id = d.kg
WHERE NOT EXISTS (SELECT 1 FROM base_product p WHERE upper(p.code) = x.ref);

-- ---------- correspondances ----------
CREATE TEMP TABLE mig_article ON COMMIT DROP AS
SELECT upper(code) AS ref, id, unit FROM base_product WHERE import_origin = 'GESCOM' AND code IS NOT NULL;
CREATE TEMP TABLE mig_frigo ON COMMIT DROP AS
SELECT DISTINCT ON (upper(btrim(f.code))) upper(btrim(f.code)) AS code, l.id
FROM gescom.frigo f JOIN stock_stock_location l ON l.import_id = 'GESCOM-FRIGO-' || btrim(f.idfrigo)
WHERE gescom.txt(f.code) IS NOT NULL ORDER BY upper(btrim(f.code)), l.id;
CREATE TEMP TABLE mig_fournisseur ON COMMIT DROP AS
SELECT DISTINCT ON (upper(btrim(f.refcpt))) upper(btrim(f.refcpt)) AS code, p.id
FROM gescom.fou f JOIN base_partner p ON p.import_id = 'GESCOM-FOU-' || btrim(f.focleunik)
WHERE gescom.txt(f.refcpt) IS NOT NULL ORDER BY upper(btrim(f.refcpt)), p.id;
CREATE TEMP TABLE mig_fournisseur_id ON COMMIT DROP AS
SELECT btrim(f.focleunik) AS cle, p.id FROM gescom.fou f JOIN base_partner p ON p.import_id = 'GESCOM-FOU-' || btrim(f.focleunik);
CREATE TEMP TABLE mig_cond ON COMMIT DROP AS SELECT upper(code) AS code, id FROM purchase_conditionnement;
CREATE TEMP TABLE mig_unite ON COMMIT DROP AS
SELECT DISTINCT ON (upper(btrim(name))) upper(btrim(name)) AS code, id FROM base_unit ORDER BY upper(btrim(name)), id;
CREATE TEMP TABLE mig_libelle ON COMMIT DROP AS
SELECT 'ORI' AS liste, upper(btrim(code)) AS code, btrim(libelle) AS libelle FROM gescom.origine WHERE gescom.txt(code) IS NOT NULL
UNION ALL SELECT 'ZON', upper(btrim(code)), btrim(libelle) FROM gescom.zone_peche WHERE gescom.txt(code) IS NOT NULL
UNION ALL SELECT 'MAR', upper(btrim(code)), btrim(desi) FROM gescom.marque WHERE gescom.txt(code) IS NOT NULL
UNION ALL SELECT 'MOD', upper(btrim(code)), btrim(libelle) FROM gescom.modepeche WHERE gescom.txt(code) IS NOT NULL;
CREATE INDEX ON mig_libelle (liste, code);

-- fournisseur des arrivages sans fournisseur connu
INSERT INTO base_partner (id, version, created_on, import_id, import_origin, partner_type_select, partner_seq, name, full_name,
  simple_full_name, is_supplier, is_customer, is_carrier, is_contact, is_prospect, is_employee, currency)
SELECT nextval('base_partner_seq'), 0, now(), 'GESCOM-FOU-INCONNU', 'GESCOM', 1, 'GESCOM-INCONNU',
  'FOURNISSEUR INCONNU (GESCOM)', 'GESCOM-INCONNU - FOURNISSEUR INCONNU (GESCOM)', 'FOURNISSEUR INCONNU (GESCOM)',
  true, false, false, false, false, false, d.euro
FROM mig_def d WHERE NOT EXISTS (SELECT 1 FROM base_partner WHERE import_id = 'GESCOM-FOU-INCONNU');

-- ---------- bateaux et containers ----------
INSERT INTO stock_bateau (id, version, created_on, name, import_id, import_origin)
SELECT nextval('stock_bateau_seq'), 0, now(), b.nom, 'GESCOM-BATEAU-' || md5(upper(b.nom)), 'GESCOM'
FROM (SELECT DISTINCT ON (upper(btrim(bateau))) btrim(bateau) AS nom FROM gescom.arr_entete
      WHERE gescom.txt(bateau) IS NOT NULL AND upper(btrim(bateau)) NOT IN ('CAMION', 'DIRECT')
      ORDER BY upper(btrim(bateau)), btrim(bateau)) b
WHERE NOT EXISTS (SELECT 1 FROM stock_bateau s WHERE upper(s.name) = upper(b.nom));
INSERT INTO stock_container (id, version, created_on, name, import_id, import_origin)
SELECT nextval('stock_container_seq'), 0, now(), c.nom, 'GESCOM-CONT-' || md5(upper(c.nom)), 'GESCOM'
FROM (SELECT DISTINCT ON (upper(btrim(container))) btrim(container) AS nom FROM gescom.arr_entete
      WHERE gescom.txt(container) IS NOT NULL AND upper(btrim(container)) <> 'CAMION'
      ORDER BY upper(btrim(container)), btrim(container)) c
WHERE NOT EXISTS (SELECT 1 FROM stock_container s WHERE upper(s.name) = upper(c.nom));

-- ---------- arrivages : en-têtes ----------
CREATE TEMP TABLE mig_arr_reel ON COMMIT DROP AS
SELECT DISTINCT btrim(arrivage) AS num FROM gescom.arr_ligne WHERE gescom.txt(lot_reel) IS NOT NULL;
CREATE INDEX ON mig_arr_reel (num);
CREATE TEMP TABLE mig_arr ON COMMIT DROP AS
SELECT btrim(e.arrivage) AS num, e.*,
  coalesce(f.id, (SELECT id FROM base_partner WHERE import_id = 'GESCOM-FOU-INCONNU')) AS fournisseur,
  EXISTS (SELECT 1 FROM mig_arr_reel r WHERE r.num = btrim(e.arrivage)) AS reel,
  coalesce((SELECT c.id FROM base_currency c WHERE c.codeiso = CASE upper(btrim(e.devise)) WHEN 'US' THEN 'USD'
     WHEN 'USB' THEN 'USD' WHEN 'DKR' THEN 'DKK' WHEN '2UR' THEN 'EUR' ELSE upper(btrim(e.devise)) END LIMIT 1),
    (SELECT euro FROM mig_def)) AS devise_id,
  NULL::bigint AS commande, NULL::bigint AS arrivage_id
FROM gescom.arr_entete e
LEFT JOIN mig_fournisseur f ON f.code = upper(btrim(e.code_fou))
WHERE gescom.txt(e.arrivage) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM stock_stock_move m WHERE m.import_id = 'GESCOM-ARR-' || btrim(e.arrivage));
UPDATE mig_arr SET commande = nextval('purchase_purchase_order_seq'), arrivage_id = nextval('stock_stock_move_seq');
CREATE INDEX ON mig_arr (num);

-- ---------- lots ----------
CREATE TEMP TABLE mig_lot ON COMMIT DROP AS
SELECT upper(btrim(l.cle_artlot)) AS cle,
  row_number() OVER (PARTITION BY upper(btrim(l.cle_artlot)) ORDER BY gescom.num(l.idarticles_lot)) AS rang_lot,
  l.*, a.id AS article, a.unit AS unite_article,
  coalesce(gescom.num(l.qent), 0) - coalesce(gescom.num(l.qsor), 0) AS stock,
  (SELECT t.id FROM stock_tracking_number t WHERE t.import_id = 'GESCOM-LOT-' || btrim(l.idarticles_lot)) AS id
FROM gescom.articles_lot l JOIN mig_article a ON a.ref = upper(btrim(l.ref))
WHERE gescom.txt(l.cle_artlot) IS NOT NULL AND gescom.txt(l.nlot_interne) IS NOT NULL;
CREATE INDEX ON mig_lot (cle);
CREATE INDEX ON mig_lot (id);
ALTER TABLE mig_lot ADD COLUMN nouveau boolean;
UPDATE mig_lot SET nouveau = (id IS NULL);
UPDATE mig_lot SET id = nextval('stock_tracking_number_seq') WHERE id IS NULL;

-- lots fournisseur (fournisseur + article + n° de lot fournisseur)
CREATE TEMP TABLE mig_lotf ON COMMIT DROP AS
SELECT DISTINCT ON (fi.id, l.article, upper(btrim(l.nlot_fournisseur))) fi.id AS fournisseur, l.article,
  btrim(l.nlot_fournisseur) AS numero, upper(btrim(l.nlot_fournisseur)) AS cle,
  (SELECT x.id FROM stock_lot_fournisseur x WHERE x.product = l.article AND x.supplier IS NOT DISTINCT FROM fi.id
     AND upper(x.supplier_lot_number) = upper(btrim(l.nlot_fournisseur)) LIMIT 1) AS id
FROM mig_lot l LEFT JOIN mig_fournisseur_id fi ON fi.cle = btrim(split_part(l.focleunik, ',', 1))
WHERE gescom.txt(l.nlot_fournisseur) IS NOT NULL
ORDER BY fi.id, l.article, upper(btrim(l.nlot_fournisseur));
ALTER TABLE mig_lotf ADD COLUMN nouveau boolean;
UPDATE mig_lotf SET nouveau = (id IS NULL);
CREATE INDEX ON mig_lotf (article, cle);
UPDATE mig_lotf SET id = nextval('stock_lot_fournisseur_seq') WHERE id IS NULL;
INSERT INTO stock_lot_fournisseur (id, version, created_on, import_id, import_origin, supplier, product, supplier_lot_number)
SELECT id, 0, now(), 'GESCOM-LOTF-' || id, 'GESCOM', fournisseur, article, numero FROM mig_lotf WHERE nouveau;

INSERT INTO stock_tracking_number (id, version, created_on, import_id, import_origin, tracking_number_seq, lvme_numero_base,
  product, supplier, lot_fournisseur, perishable_expiration_date, is_perishable, prix_revient_reel, lot_verifie,
  origin_move_type_select, check_expiration_date_at_stock_move_realization, has_warranty)
SELECT l.id, 0, now(), 'GESCOM-LOT-' || btrim(l.idarticles_lot), 'GESCOM',
  btrim(l.nlot_interne) || CASE WHEN l.rang_lot > 1 THEN ' (' || l.rang_lot || ')' ELSE '' END, btrim(l.nlot_interne),
  l.article, fi.id, lf.id, gescom.dt(l.date_limite_conso), gescom.dt(l.date_limite_conso) IS NOT NULL,
  gescom.num(l.pxrevt), coalesce(btrim(l.verif), '') = '1', 4, false, false
FROM mig_lot l LEFT JOIN mig_fournisseur_id fi ON fi.cle = btrim(split_part(l.focleunik, ',', 1))
LEFT JOIN mig_lotf lf ON lf.article = l.article AND lf.fournisseur IS NOT DISTINCT FROM fi.id
  AND lf.cle = upper(btrim(l.nlot_fournisseur))
WHERE l.nouveau;

-- ---------- lignes ----------
CREATE TEMP TABLE mig_ligne ON COMMIT DROP AS
SELECT r.*, a.num, a.commande, a.arrivage_id, a.reel, art.id AS article,
  coalesce(u.id, art.unit, (SELECT kg FROM mig_def)) AS unite_id,
  lo.id AS lot_id, lo.stock AS stock_lot, NULLIF(gescom.num(lo.qent), 0) AS qent_lot,
  coalesce(fr.id, (SELECT frigo_defaut FROM mig_def)) AS frigo_id, co.id AS cond_id,
  CASE WHEN gescom.txt(r.lot_reel) IS NOT NULL THEN gescom.num(r.colis_reel) ELSE gescom.num(r.colis_fl) END AS colis,
  CASE WHEN gescom.txt(r.lot_reel) IS NOT NULL THEN gescom.num(r.poids_colis_r) ELSE gescom.num(r.poids_colis_fl) END AS poids_colis,
  coalesce(NULLIF(gescom.num(r.prix_ach_r), 0), gescom.num(r.prix_ach_fl), 0) AS prix_achat,
  coalesce(NULLIF(gescom.num(r.prix_rev_r), 0), gescom.num(r.prix_rev_fl), 0) AS prix_revient,
  coalesce(NULLIF(gescom.num(r.total_ht_reel), 0), gescom.num(r.total_ht_fl), 0) AS montant,
  (SELECT libelle FROM mig_libelle WHERE liste = 'ORI' AND code = upper(btrim(r.origine)) LIMIT 1) AS origine_lib,
  (SELECT libelle FROM mig_libelle WHERE liste = 'ZON' AND code = upper(btrim(r.zpeche)) LIMIT 1) AS zone_lib,
  (SELECT libelle FROM mig_libelle WHERE liste = 'MAR' AND code = upper(btrim(r.marque)) LIMIT 1) AS marque_lib,
  (SELECT libelle FROM mig_libelle WHERE liste = 'MOD' AND code = upper(btrim(r.libre1)) LIMIT 1) AS mode_lib,
  row_number() OVER (PARTITION BY a.num ORDER BY gescom.num(r.idarr_ligne)) AS rang,
  nextval('purchase_purchase_order_line_seq') AS ligne_commande, nextval('stock_stock_move_line_seq') AS ligne_arrivage
FROM gescom.arr_ligne r
JOIN mig_arr a ON a.num = btrim(r.arrivage)
JOIN mig_article art ON art.ref = upper(btrim(r.ref))
LEFT JOIN mig_unite u ON u.code = upper(btrim(r.unite))
LEFT JOIN mig_lot lo ON lo.cle = upper(btrim(r.reflot)) AND lo.rang_lot = 1
LEFT JOIN mig_frigo fr ON fr.code = upper(btrim(r.frigo))
LEFT JOIN mig_cond co ON co.code = upper(btrim(r.cond));
ALTER TABLE mig_ligne ADD COLUMN qte numeric;
UPDATE mig_ligne SET qte = coalesce(qent_lot, coalesce(colis, 0) * coalesce(poids_colis, 0));
CREATE INDEX ON mig_ligne (num);
CREATE INDEX ON mig_ligne (lot_id);
CREATE TEMP TABLE mig_arr_frigo ON COMMIT DROP AS SELECT num, min(frigo_id) AS frigo FROM mig_ligne GROUP BY num;
CREATE INDEX ON mig_arr_frigo (num);

-- ---------- commandes fournisseurs ----------
INSERT INTO purchase_purchase_order (id, version, created_on, import_id, import_origin, purchase_order_seq, full_name,
  company, supplier_partner, currency, status_select, receipt_state, type_select, order_date, estimated_receipt_date,
  supplier_shipment_date, validation_date_time, version_number, ex_tax_total, company_ex_tax_total, tax_total, in_tax_total,
  nb_colis_total, poids_total, nature, lvme_flottant, lvme_reel, lvme_couvert, stock_location, from_stock_location,
  shipment_mode, notes, advance_total, amount_invoiced, amount_to_be_spread_over_the_timetable, budget_distribution_generated,
  created_by_interco, display_price_on_quotation_request, gap_amt, group_products_on_printings, in_ati, interco,
  is_purchase_parent, outsourcing_order, unassigned_amt)
SELECT a.commande, 0, now(), 'GESCOM-ARR-' || a.num, 'GESCOM', a.num,
  a.num || '-' || coalesce((SELECT name FROM base_partner WHERE id = a.fournisseur), ''),
  d.societe, a.fournisseur, a.devise_id, CASE WHEN a.reel THEN 4 ELSE 3 END, CASE WHEN a.reel THEN 3 ELSE 1 END, 1,
  coalesce(gescom.dt(a.date_depart), gescom.dt(a.date_arrivage), gescom.dt(a.date_liv)),
  coalesce(gescom.dt(a.date_arrivage), gescom.dt(a.date_liv)), gescom.dt(a.date_depart),
  coalesce(gescom.dt(a.date_depart), gescom.dt(a.date_arrivage), gescom.dt(a.date_liv))::timestamp, 1,
  coalesce(gescom.num(a.mt_ht), 0), coalesce(gescom.num(a.mt_ht), 0), round(coalesce(gescom.num(a.mt_ht), 0) * 0.055, 2),
  round(coalesce(gescom.num(a.mt_ht), 0) * 1.055, 2), gescom.num(a.colis), gescom.num(a.poids_total),
  CASE WHEN a.reel THEN 3 ELSE 2 END, gescom.num(a.taux_flot), gescom.num(a.taux_reel), gescom.num(a.taux_couv),
  (SELECT f.frigo FROM mig_arr_frigo f WHERE f.num = a.num), d.reception,
  CASE btrim(coalesce(a.typ_arrivage, '')) WHEN '379' THEN d.camion WHEN '380' THEN d.mode_bateau
    WHEN '381' THEN (SELECT id FROM stock_shipment_mode WHERE upper(name) = 'AVION' LIMIT 1)
    ELSE CASE WHEN upper(btrim(coalesce(a.bateau, ''))) IN ('CAMION', 'DIRECT') THEN d.camion
              WHEN gescom.txt(a.bateau) IS NOT NULL THEN d.mode_bateau END END,
  NULLIF(concat_ws(E'\n', 'Transitaire : ' || gescom.txt(a.transitaire), 'Gestionnaire : ' || gescom.txt(a.gestionnaire),
    gescom.txt(a.comm1), gescom.txt(a.comm2)), ''),
  0, 0, 0, false, false, false, 0, false, false, false, false, false, 0
FROM mig_arr a CROSS JOIN mig_def d;

INSERT INTO purchase_purchase_order_line (id, version, created_on, import_id, import_origin, purchase_order, sequence, product,
  product_name, product_code, unit, qty, received_qty, price, price_discounted, ex_tax_total, company_ex_tax_total,
  in_tax_price, in_tax_total, company_in_tax_total, nb_colis, poids_par_colis, poids_total_net, pa_devise, prix_revient_reel,
  montant_reel, conditionnement, origine, zone_peche, marque, mode_peche, dluo, date_congelation, frais_approche_kg,
  tracking_number, stock_location, receipt_state, desired_receipt_date, estimated_receipt_date, full_name,
  amount_invoiced, discount_amount, discount_type_select, fixed_assets, invoiced, is_ordered, is_title_line,
  qty_allocated_to_sales, qty_available_to_promise, to_invoice, unassigned_amt)
SELECT l.ligne_commande, 0, now(), 'GESCOM-ARRL-' || btrim(l.idarr_ligne), 'GESCOM', l.commande, l.rang, l.article,
  coalesce(gescom.txt(l.desi), (SELECT name FROM base_product WHERE id = l.article)), upper(btrim(l.ref)), l.unite_id,
  l.qte, CASE WHEN l.reel THEN l.qte ELSE 0 END, l.prix_achat, l.prix_achat, l.montant, l.montant,
  round(l.prix_achat * 1.055, 4), round(l.montant * 1.055, 2), round(l.montant * 1.055, 2),
  l.colis, l.poids_colis, CASE WHEN l.colis IS NOT NULL AND l.poids_colis IS NOT NULL THEN l.colis * l.poids_colis END,
  l.prix_achat, l.prix_revient, l.montant, l.cond_id, l.origine_lib, l.zone_lib, l.marque_lib, l.mode_lib,
  gescom.dt(l.dlc), gescom.dt(l.dat_cong), gescom.num(a.frais_appr), l.lot_id, l.frigo_id,
  CASE WHEN l.reel THEN 3 ELSE 1 END, gescom.dt(a.date_arrivage), gescom.dt(a.date_arrivage),
  l.num || '-' || coalesce(gescom.txt(l.desi), ''),
  0, 0, 0, false, false, false, false, 0, 0, false, 0
FROM mig_ligne l JOIN mig_arr a ON a.num = l.num;

-- ---------- arrivages (réceptions) ----------
INSERT INTO stock_stock_move (id, version, created_on, import_id, import_origin, stock_move_seq, name, origin, company,
  partner, type_select, status_select, nature, estimated_date, real_date, supplier_shipment_date, from_stock_location,
  to_stock_location, shipment_mode, bateau, ex_tax_total, nb_colis_total, poids_total, lvme_flottant, lvme_reel, lvme_couvert,
  note, filter_on_available_products, availability_request, cut_off_move_generated, fully_spread_over_logistical_forms_flag,
  group_products_on_printings, invoice_blocking, is_cession, is_conformity_certif_signed, is_ispm_required,
  is_needing_conformity_certificate, is_reversion, is_with_backorder, is_with_return_surplus, lvme_bl_flottant,
  picking_is_edited, planned_stock_move_automatic_mail, real_stock_move_automatic_mail)
SELECT a.arrivage_id, 0, now(), 'GESCOM-ARR-' || a.num, 'GESCOM', a.num,
  a.num || ' - ' || coalesce((SELECT partner_seq || ' - ' || name FROM base_partner WHERE id = a.fournisseur), ''),
  a.num, d.societe, a.fournisseur, 3, CASE WHEN a.reel THEN 3 ELSE 2 END, CASE WHEN a.reel THEN 3 ELSE 2 END,
  coalesce(gescom.dt(a.date_arrivage), gescom.dt(a.date_liv)),
  CASE WHEN a.reel THEN coalesce(gescom.dt(a.date_liv), gescom.dt(a.date_arrivage)) END, gescom.dt(a.date_depart),
  d.reception, coalesce((SELECT f.frigo FROM mig_arr_frigo f WHERE f.num = a.num), d.reception),
  CASE btrim(coalesce(a.typ_arrivage, '')) WHEN '379' THEN d.camion WHEN '380' THEN d.mode_bateau
    WHEN '381' THEN (SELECT id FROM stock_shipment_mode WHERE upper(name) = 'AVION' LIMIT 1)
    ELSE CASE WHEN upper(btrim(coalesce(a.bateau, ''))) IN ('CAMION', 'DIRECT') THEN d.camion
              WHEN gescom.txt(a.bateau) IS NOT NULL THEN d.mode_bateau END END,
  (SELECT id FROM stock_bateau WHERE upper(name) = upper(btrim(a.bateau)) LIMIT 1),
  coalesce(gescom.num(a.mt_ht), 0), gescom.num(a.colis), gescom.num(a.poids_total),
  gescom.num(a.taux_flot), gescom.num(a.taux_reel), gescom.num(a.taux_couv),
  NULLIF(concat_ws(E'\n', 'Transitaire : ' || gescom.txt(a.transitaire), 'Gestionnaire : ' || gescom.txt(a.gestionnaire),
    gescom.txt(a.comm1), gescom.txt(a.comm2)), ''),
  true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false
FROM mig_arr a CROSS JOIN mig_def d;
INSERT INTO stock_stock_move_purchase_order_set (stock_stock_move, purchase_order_set)
SELECT arrivage_id, commande FROM mig_arr;
INSERT INTO stock_stock_move_container_set (stock_stock_move, container_set)
SELECT DISTINCT a.arrivage_id, (SELECT min(c.id) FROM stock_container c WHERE upper(c.name) = upper(btrim(a.container)))
FROM mig_arr a
WHERE gescom.txt(a.container) IS NOT NULL
  AND EXISTS (SELECT 1 FROM stock_container c WHERE upper(c.name) = upper(btrim(a.container)));

INSERT INTO stock_stock_move_line (id, version, created_on, import_id, import_origin, stock_move, sequence, name, product,
  product_name, product_type_select, unit, qty, real_qty, unit_price_untaxed, unit_price_taxed, company_unit_price_untaxed,
  company_purchase_price, pa_devise, prix_revient_reel, montant_reel, nb_colis, poids_par_colis, poids_total_net,
  tracking_number, from_stock_location, to_stock_location, purchase_order_line, origine, zone_peche, marque, mode_peche,
  dluo, date_congelation, lot_fournisseur, frais_approche_kg, conformity_select, is_qty_requested,
  is_real_qty_modified_by_user, line_type_select, qty_invoiced, requested_reserved_qty, reserved_qty, shipped_qty)
SELECT l.ligne_arrivage, 0, now(), 'GESCOM-ARRL-' || btrim(l.idarr_ligne), 'GESCOM', l.arrivage_id, l.rang,
  l.num || '-' || l.rang, l.article, coalesce(gescom.txt(l.desi), (SELECT name FROM base_product WHERE id = l.article)),
  'storable', l.unite_id, l.qte, CASE WHEN l.reel THEN l.qte ELSE 0 END, l.prix_achat, round(l.prix_achat * 1.055, 4),
  l.prix_achat, l.prix_achat, l.prix_achat, l.prix_revient, l.montant, l.colis, l.poids_colis,
  CASE WHEN l.colis IS NOT NULL AND l.poids_colis IS NOT NULL THEN l.colis * l.poids_colis END,
  l.lot_id, d.reception, coalesce(l.frigo_id, d.reception), l.ligne_commande, l.origine_lib, l.zone_lib, l.marque_lib,
  l.mode_lib, gescom.dt(l.dlc), gescom.dt(l.dat_cong), (SELECT t.lot_fournisseur FROM stock_tracking_number t WHERE t.id = l.lot_id),
  gescom.num(a.frais_appr),
  0, false, false, 1, 0, 0, 0, 0
FROM mig_ligne l JOIN mig_arr a ON a.num = l.num CROSS JOIN mig_def d;

-- origine des lots (première ligne d'arrivage du lot)
UPDATE stock_tracking_number t SET origin_stock_move_line = x.ligne_arrivage, origin_purchase_order_line = x.ligne_commande
FROM (SELECT DISTINCT ON (lot_id) lot_id, ligne_arrivage, ligne_commande FROM mig_ligne WHERE lot_id IS NOT NULL
      ORDER BY lot_id, ligne_arrivage) x
WHERE t.id = x.lot_id AND t.origin_stock_move_line IS NULL;

-- ---------- stock : entrées - sorties GESCOM par lot, dans le frigo de son arrivage ----------
-- lot d'un arrivage flottant (marchandise en mer) : la ligne de lot porte (entrées - sorties GESCOM) - quantité de
-- l'arrivage ; l'écran État des stocks (quantité en mer + ligne de lot) affiche ainsi entrées - sorties comme GESCOM,
-- et la réception ajoutera la quantité reçue. Lot sans ligne d'arrivage : frigo de son arrivage GESCOM, sinon FRIGO
CREATE TEMP TABLE mig_stock ON COMMIT DROP AS
SELECT DISTINCT ON (lo.id) lo.id AS lot_id, lo.article,
  CASE WHEN l.lot_id IS NOT NULL AND NOT l.reel THEN lo.stock - coalesce(l.qte, 0) ELSE lo.stock END AS stock,
  coalesce(l.frigo_id, (SELECT f.frigo FROM mig_arr_frigo f WHERE f.num = btrim(lo.num_arrivage)), d.frigo_defaut) AS frigo,
  coalesce(l.unite_id, lo.unite_article, (SELECT kg FROM mig_def)) AS unite
FROM mig_lot lo LEFT JOIN mig_ligne l ON l.lot_id = lo.id CROSS JOIN mig_def d
WHERE lo.nouveau
ORDER BY lo.id, l.ligne_arrivage;
DELETE FROM mig_stock WHERE stock = 0;
INSERT INTO stock_stock_location_line (id, version, created_on, import_id, import_origin, details_stock_location, product,
  tracking_number, unit, current_qty, future_qty, avg_price, last_inventory_real_qty, requested_reserved_qty, reserved_qty)
SELECT nextval('stock_stock_location_line_seq'), 0, now(), 'GESCOM-STKL-' || s.lot_id, 'GESCOM', s.frigo, s.article,
  s.lot_id, s.unite, s.stock, s.stock, coalesce((SELECT prix_revient_reel FROM stock_tracking_number WHERE id = s.lot_id), 0),
  0, 0, 0
FROM mig_stock s;

-- totaux des arrivages et commandes : GESCOM ne les remplit pas pour un flottant (MT_HT, COLIS, POIDS à 0) ; somme
-- des lignes quand le total GESCOM est vide ou nul (comme Axelor à l'enregistrement d'un arrivage)
UPDATE stock_stock_move m SET nb_colis_total = x.colis, poids_total = x.poids, ex_tax_total = x.montant,
  version = m.version + 1
FROM (SELECT l.stock_move, sum(coalesce(l.nb_colis, 0)) AS colis, sum(coalesce(l.poids_total_net, l.qty, 0)) AS poids,
             sum(coalesce(l.montant_reel, 0)) AS montant
      FROM stock_stock_move_line l WHERE l.import_id LIKE 'GESCOM-ARRL-%' GROUP BY l.stock_move) x
WHERE m.id = x.stock_move AND m.import_id LIKE 'GESCOM-ARR-%'
  AND coalesce(m.nb_colis_total, 0) = 0 AND coalesce(m.poids_total, 0) = 0 AND coalesce(m.ex_tax_total, 0) = 0
  AND (x.colis <> 0 OR x.poids <> 0 OR x.montant <> 0);
UPDATE purchase_purchase_order o SET nb_colis_total = m.nb_colis_total, poids_total = m.poids_total,
  ex_tax_total = m.ex_tax_total, company_ex_tax_total = m.ex_tax_total, tax_total = round(m.ex_tax_total * 0.055, 2),
  in_tax_total = round(m.ex_tax_total * 1.055, 2), version = o.version + 1
FROM stock_stock_move m
WHERE m.import_id = o.import_id AND o.import_id LIKE 'GESCOM-ARR-%' AND coalesce(o.ex_tax_total, 0) = 0
  AND coalesce(o.nb_colis_total, 0) = 0 AND (coalesce(m.ex_tax_total, 0) <> 0 OR coalesce(m.nb_colis_total, 0) <> 0);

-- correction des lignes déjà migrées sans frigo GESCOM (parties dans l'emplacement virtuel de réception) : FRIGO
UPDATE stock_stock_move_line SET to_stock_location = (SELECT frigo_defaut FROM mig_def), version = version + 1
WHERE import_id LIKE 'GESCOM-ARRL-%' AND to_stock_location = (SELECT reception FROM mig_def);
UPDATE stock_stock_move SET to_stock_location = (SELECT frigo_defaut FROM mig_def), version = version + 1
WHERE import_id LIKE 'GESCOM-ARR-%' AND to_stock_location = (SELECT reception FROM mig_def);
UPDATE purchase_purchase_order_line SET stock_location = (SELECT frigo_defaut FROM mig_def), version = version + 1
WHERE import_id LIKE 'GESCOM-ARRL-%' AND stock_location IS NULL;

-- correction des lots déjà migrés : lots flottants (même règle) et lots sans ligne d'arrivage placés dans un emplacement
-- virtuel (frigo de leur arrivage GESCOM, sinon FRIGO)
UPDATE stock_stock_location_line l SET details_stock_location = coalesce(
    (SELECT min(ml.to_stock_location) FROM stock_stock_move_line ml JOIN stock_stock_move m ON m.id = ml.stock_move
      WHERE m.import_id = 'GESCOM-ARR-' || btrim(g.num_arrivage)), (SELECT frigo_defaut FROM mig_def)),
  version = l.version + 1
FROM stock_tracking_number t
JOIN gescom.articles_lot g ON t.import_id = 'GESCOM-LOT-' || btrim(g.idarticles_lot)
JOIN stock_stock_location v ON v.type_select <> 1
WHERE l.import_id LIKE 'GESCOM-STKL-%' AND l.tracking_number = t.id AND l.details_stock_location = v.id;
UPDATE stock_stock_location_line l SET current_qty = x.cible, future_qty = x.cible, version = l.version + 1
FROM (SELECT t.id AS lot, (coalesce(gescom.num(g.qent), 0) - coalesce(gescom.num(g.qsor), 0))
             - sum(ml.qty) AS cible
      FROM stock_tracking_number t
      JOIN gescom.articles_lot g ON t.import_id = 'GESCOM-LOT-' || btrim(g.idarticles_lot)
      JOIN stock_stock_move_line ml ON ml.tracking_number = t.id
      JOIN stock_stock_move m ON m.id = ml.stock_move AND m.type_select = 3 AND m.status_select = 2
      WHERE t.import_id LIKE 'GESCOM-LOT-%'
      GROUP BY t.id, g.qent, g.qsor) x
WHERE l.import_id LIKE 'GESCOM-STKL-%' AND l.tracking_number = x.lot AND l.current_qty IS DISTINCT FROM x.cible;
-- lots flottants sans ligne de lot (stock GESCOM nul) : ligne de lot « - quantité de l'arrivage » pour afficher 0
INSERT INTO stock_stock_location_line (id, version, created_on, import_id, import_origin, details_stock_location, product,
  tracking_number, unit, current_qty, future_qty, avg_price, last_inventory_real_qty, requested_reserved_qty, reserved_qty)
SELECT nextval('stock_stock_location_line_seq'), 0, now(), 'GESCOM-STKL-' || x.lot, 'GESCOM', x.frigo, x.product, x.lot,
  x.unit, x.cible, x.cible, 0, 0, 0, 0
FROM (SELECT t.id AS lot, min(ml.to_stock_location) AS frigo, min(t.product) AS product, min(ml.unit) AS unit,
             (coalesce(gescom.num(g.qent), 0) - coalesce(gescom.num(g.qsor), 0)) - sum(ml.qty) AS cible
      FROM stock_tracking_number t
      JOIN gescom.articles_lot g ON t.import_id = 'GESCOM-LOT-' || btrim(g.idarticles_lot)
      JOIN stock_stock_move_line ml ON ml.tracking_number = t.id
      JOIN stock_stock_move m ON m.id = ml.stock_move AND m.type_select = 3 AND m.status_select = 2
      WHERE t.import_id LIKE 'GESCOM-LOT-%'
      GROUP BY t.id, g.qent, g.qsor) x
WHERE x.cible <> 0
  AND NOT EXISTS (SELECT 1 FROM stock_stock_location_line l WHERE l.tracking_number = x.lot AND l.details_stock_location IS NOT NULL);
-- lignes de stock par article / frigo = somme des lignes de lot
DELETE FROM stock_stock_location_line WHERE import_id LIKE 'GESCOM-STK-%';
INSERT INTO stock_stock_location_line (id, version, created_on, import_id, import_origin, stock_location, product, unit,
  current_qty, future_qty, avg_price, last_inventory_real_qty, requested_reserved_qty, reserved_qty)
SELECT nextval('stock_stock_location_line_seq'), 0, now(), 'GESCOM-STK-' || x.frigo || '-' || x.product, 'GESCOM', x.frigo,
  x.product, x.unit, x.qte, x.qte, 0, 0, 0, 0
FROM (SELECT details_stock_location AS frigo, product, min(unit) AS unit, sum(current_qty) AS qte
      FROM stock_stock_location_line WHERE import_id LIKE 'GESCOM-STKL-%' GROUP BY details_stock_location, product) x
WHERE NOT EXISTS (SELECT 1 FROM stock_stock_location_line y WHERE y.stock_location = x.frigo AND y.product = x.product
                  AND y.tracking_number IS NULL);

-- ---------- articles sans prix / poids : dernier arrivage ----------
UPDATE base_product p SET
  purchase_price = CASE WHEN coalesce(p.purchase_price, 0) = 0 THEN coalesce(x.prix_achat, 0) ELSE p.purchase_price END,
  cost_price = CASE WHEN coalesce(p.cost_price, 0) = 0 THEN coalesce(x.prix_revient, 0) ELSE p.cost_price END,
  poids_colis = coalesce(p.poids_colis, x.poids_colis)
FROM (SELECT DISTINCT ON (article) article, NULLIF(prix_achat, 0) AS prix_achat, NULLIF(prix_revient, 0) AS prix_revient,
             NULLIF(poids_colis, 0) AS poids_colis
      FROM mig_ligne WHERE reel ORDER BY article, num::text DESC, rang DESC) x
WHERE p.id = x.article AND (coalesce(p.purchase_price, 0) = 0 OR coalesce(p.cost_price, 0) = 0 OR p.poids_colis IS NULL);

COMMIT;

-- ---------- contrôle ----------
SELECT (SELECT count(*) FROM gescom.arr_entete) AS arrivages_gescom,
       (SELECT count(*) FROM stock_stock_move WHERE import_id LIKE 'GESCOM-ARR-%') AS arrivages_axelor,
       (SELECT count(*) FROM stock_stock_move WHERE import_id LIKE 'GESCOM-ARR-%' AND status_select = 3) AS reels,
       (SELECT count(*) FROM gescom.arr_ligne) AS lignes_gescom,
       (SELECT count(*) FROM stock_stock_move_line WHERE import_id LIKE 'GESCOM-ARRL-%') AS lignes_axelor,
       (SELECT count(*) FROM gescom.articles_lot) AS lots_gescom,
       (SELECT count(*) FROM stock_tracking_number WHERE import_id LIKE 'GESCOM-LOT-%') AS lots_axelor,
       (SELECT count(*) FROM stock_stock_location_line WHERE import_id LIKE 'GESCOM-STKL-%') AS lots_en_stock,
       (SELECT count(*) FROM stock_stock_location_line WHERE import_id LIKE 'GESCOM-STKL-%' AND current_qty < 0) AS lots_negatifs,
       (SELECT round(sum(l.current_qty * coalesce(t.prix_revient_reel, 0))) FROM stock_stock_location_line l
         JOIN stock_tracking_number t ON t.id = l.tracking_number WHERE l.import_id LIKE 'GESCOM-STKL-%' AND l.current_qty > 0)
         AS valeur_stock;

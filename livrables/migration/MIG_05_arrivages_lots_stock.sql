-- =====================================================================
-- MIGRATION GESCOM — étape 05 : arrivages (commandes fournisseurs + réceptions), lots et stock
--   Source : archive gescom.arr_entete, arr_ligne, articles_lot (MIG_00). Prérequis : MIG_01 à MIG_04.
--   Décisions du 27/10/2026 : historique complet ; lots en stock négatif gardés négatifs.
--   - lots fournisseur (fournisseur + article + n° de lot fournisseur) ;
--   - lots (ARTICLES_LOT, clé « référence article,n° lot ») : n° interne, lot fournisseur, DLC, prix de revient,
--     fournisseur, lot vérifié
--   - arrivages (ARR_ENTETE) : une commande fournisseur (n° = n° d'arrivage GESCOM) et un arrivage ; Réel (réceptionné)
--     si au moins une ligne a un lot réel, sinon Flottant (prévu) ; fournisseur, dates (départ, arrivée,
--     livraison), devise, taux flottant / réel / couvert, frais d'approche, bateau (camion ou navire), containers,
--     transitaire / gestionnaire en note, montant, colis, poids
--   - lignes (ARR_LIGNE) : article, lot, frigo, quantité (quantité entrée du lot, sinon colis x poids colis), colis,
--     poids colis, prix d'achat, prix de revient, montant, conditionnement, origine, zone de pêche, marque, mode de
--     pêche, DLC, date de congélation, lot fournisseur
--   - stock : pour chaque lot, entrées - sorties GESCOM (QENT - QSOR) dans son frigo (négatif gardé) ; ligne de
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
       (SELECT id FROM base_unit WHERE upper(name) = 'KG' ORDER BY id LIMIT 1) AS kg;

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
SELECT DISTINCT ON (upper(btrim(l.cle_artlot))) upper(btrim(l.cle_artlot)) AS cle, l.*, a.id AS article, a.unit AS unite_article,
  coalesce(gescom.num(l.qent), 0) - coalesce(gescom.num(l.qsor), 0) AS stock,
  (SELECT t.id FROM stock_tracking_number t WHERE t.import_id = 'GESCOM-LOT-' || btrim(l.idarticles_lot)) AS id
FROM gescom.articles_lot l JOIN mig_article a ON a.ref = upper(btrim(l.ref))
WHERE gescom.txt(l.cle_artlot) IS NOT NULL AND gescom.txt(l.nlot_interne) IS NOT NULL
ORDER BY upper(btrim(l.cle_artlot)), gescom.num(l.idarticles_lot) DESC;
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
SELECT l.id, 0, now(), 'GESCOM-LOT-' || btrim(l.idarticles_lot), 'GESCOM', btrim(l.nlot_interne), btrim(l.nlot_interne),
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
  fr.id AS frigo_id, co.id AS cond_id,
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
LEFT JOIN mig_lot lo ON lo.cle = upper(btrim(r.reflot))
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
  CASE WHEN upper(btrim(coalesce(a.bateau, ''))) IN ('CAMION', 'DIRECT') THEN d.camion
       WHEN gescom.txt(a.bateau) IS NOT NULL THEN d.mode_bateau END,
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
  CASE WHEN upper(btrim(coalesce(a.bateau, ''))) IN ('CAMION', 'DIRECT') THEN d.camion
       WHEN gescom.txt(a.bateau) IS NOT NULL THEN d.mode_bateau END,
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
CREATE TEMP TABLE mig_stock ON COMMIT DROP AS
SELECT DISTINCT ON (lo.id) lo.id AS lot_id, lo.article, lo.stock, coalesce(l.frigo_id, (SELECT reception FROM mig_def)) AS frigo,
  coalesce(l.unite_id, lo.unite_article, (SELECT kg FROM mig_def)) AS unite
FROM mig_lot lo LEFT JOIN mig_ligne l ON l.lot_id = lo.id
WHERE lo.stock <> 0 AND lo.nouveau
ORDER BY lo.id, l.ligne_arrivage;
INSERT INTO stock_stock_location_line (id, version, created_on, import_id, import_origin, details_stock_location, product,
  tracking_number, unit, current_qty, future_qty, avg_price, last_inventory_real_qty, requested_reserved_qty, reserved_qty)
SELECT nextval('stock_stock_location_line_seq'), 0, now(), 'GESCOM-STKL-' || s.lot_id, 'GESCOM', s.frigo, s.article,
  s.lot_id, s.unite, s.stock, s.stock, coalesce((SELECT prix_revient_reel FROM stock_tracking_number WHERE id = s.lot_id), 0),
  0, 0, 0
FROM mig_stock s;
INSERT INTO stock_stock_location_line (id, version, created_on, import_id, import_origin, stock_location, product, unit,
  current_qty, future_qty, avg_price, last_inventory_real_qty, requested_reserved_qty, reserved_qty)
SELECT nextval('stock_stock_location_line_seq'), 0, now(), 'GESCOM-STK-' || s.frigo || '-' || s.article, 'GESCOM', s.frigo,
  s.article, min(s.unite), sum(s.stock), sum(s.stock), 0, 0, 0, 0
FROM mig_stock s
WHERE NOT EXISTS (SELECT 1 FROM stock_stock_location_line x WHERE x.stock_location = s.frigo AND x.product = s.article
                  AND x.tracking_number IS NULL)
GROUP BY s.frigo, s.article;

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

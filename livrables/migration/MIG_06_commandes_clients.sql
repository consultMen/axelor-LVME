-- =====================================================================
-- MIGRATION GESCOM — étape 06 : commandes clients (historique complet), BL et numéros de facture
--   Source : archive gescom.cce (en-têtes), gescom.ccd (lignes) (MIG_00). Prérequis : MIG_01 à MIG_05.
--   Décisions du 28/10/2026 : tout l'historique ; factures (option b) non recréées en factures Axelor.
--   GESCOM enregistre chaque vente deux fois dans CCE / CCD :
--     - TYPE_FACTURE 2 : la commande / le BL (n° de BL = n° de commande), IDPOSITION = sa facture ;
--     - TYPE_FACTURE 3 : la facture (NUMFACTURE, date, échéance), qui regroupe les lignes de ses commandes.
--   Reprise :
--   - une commande client Axelor « Terminée » par commande GESCOM (type 2, et les 2 de type 1) : n° GESCOM, client,
--     commercial, dates, référence client (REFCDE), montant HT, adresse de livraison ; « Avoir » si montant négatif ;
--     n° / date / échéance de la facture GESCOM dans les commentaires de facturation ;
--   - conditions et mode de paiement, transporteur, % RFA, % commission, coût du port au kg, % frais de congélation,
--     remise ; note interne : contact, téléphone, e-mail, zone (France / Corse / étranger), saisie par, affacturage,
--     bordereau, colis, poids brut, escompte, acompte, port ;
--   - ses lignes : produit (P, D), texte (T, ligne de titre), correction manuelle (M, sans produit) ; quantité, colis,
--     poids colis, prix, prix net, remise, montant HT et TTC, TVA, prix de revient, taux commission / RFA,
--     fournisseur, coefficient de poids net ; lot vendu ;
--   - un BL réalisé par commande (n° « BL » + n° de commande GESCOM : les n° d'arrivage occupent déjà les mêmes numéros) avec ses lignes de produit et leur lot, du frigo du lot
--     vers LIVRAISON CLIENT : historique produit (sorties), n° BL de la liste des commandes. Le stock N'EST PAS
--     modifié (il est déjà celui de GESCOM, MIG_05).
--   Les factures (type 3) et CLIENT_RESERV restent dans l'archive gescom.
-- Relançable : ce qui existe déjà (même clé GESCOM) n'est pas recréé.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE mig_def ON COMMIT DROP AS
SELECT (SELECT id FROM base_company ORDER BY id LIMIT 1) AS societe,
       (SELECT id FROM base_currency WHERE codeiso = 'EUR' LIMIT 1) AS euro,
       (SELECT customer_virtual_stock_location FROM stock_stock_config ORDER BY id LIMIT 1) AS client_loc,
       (SELECT id FROM stock_stock_location WHERE type_select = 1 AND upper(name) = 'FRIGO' ORDER BY id LIMIT 1) AS frigo_defaut,
       (SELECT tl.id FROM account_tax_line tl JOIN account_tax t ON t.id = tl.tax WHERE t.code = 'R2_C' ORDER BY tl.id LIMIT 1) AS tva55,
       (SELECT tl.id FROM account_tax_line tl JOIN account_tax t ON t.id = tl.tax WHERE t.code = 'U_C' ORDER BY tl.id LIMIT 1) AS tva21,
       (SELECT tl.id FROM account_tax_line tl JOIN account_tax t ON t.id = tl.tax WHERE t.code = 'N_C' AND tl.end_date IS NULL ORDER BY tl.id LIMIT 1) AS tva20,
       (SELECT tl.id FROM account_tax_line tl JOIN account_tax t ON t.id = tl.tax WHERE t.code = 'X_C' ORDER BY tl.id LIMIT 1) AS tva0;

-- ---------- correspondances ----------
CREATE TEMP TABLE mig_article ON COMMIT DROP AS
SELECT DISTINCT ON (upper(code)) upper(code) AS ref, id, unit, name FROM base_product
WHERE code IS NOT NULL ORDER BY upper(code), (import_origin = 'GESCOM') DESC, id;
CREATE INDEX ON mig_article (ref);
CREATE TEMP TABLE mig_unite ON COMMIT DROP AS
SELECT DISTINCT ON (upper(btrim(name))) upper(btrim(name)) AS code, id FROM base_unit ORDER BY upper(btrim(name)), id;
CREATE TEMP TABLE mig_client ON COMMIT DROP AS
SELECT substr(import_id, 12) AS cle, id, name, partner_seq FROM base_partner WHERE import_id LIKE 'GESCOM-CLI-%';
CREATE INDEX ON mig_client (cle);
CREATE TEMP TABLE mig_client_code ON COMMIT DROP AS
SELECT DISTINCT ON (upper(partner_seq)) upper(partner_seq) AS code, id FROM base_partner
WHERE is_customer AND partner_seq IS NOT NULL ORDER BY upper(partner_seq), id;
CREATE TEMP TABLE mig_commercial ON COMMIT DROP AS
SELECT substr(import_id, 12) AS code, id FROM auth_user WHERE import_id LIKE 'GESCOM-COM-%';
-- conditions (MODREGT) et modes (REGL1) de paiement, transporteur, fournisseur des lignes : comme MIG_02 / MIG_05
CREATE TEMP TABLE mig_condition ON COMMIT DROP AS
SELECT btrim(t.idtable) AS idtable, c.id
FROM gescom.table_base t JOIN account_payment_condition c ON c.code = btrim(t.codtab)
WHERE btrim(t.codtab) ~ '^RGT';
CREATE TEMP TABLE mig_mode ON COMMIT DROP AS
SELECT btrim(t.idtable) AS idtable,
  (SELECT id FROM account_payment_mode WHERE code = 'ENC_' || CASE btrim(t.codtab) WHEN 'MODRGTVIR' THEN 'VIR'
     WHEN 'MODRGTCHQ' THEN 'CHQ' WHEN 'MODRGTESP' THEN 'ESP' WHEN 'MODRGTCB' THEN 'CB' WHEN 'MODRGTTRT' THEN 'LCR'
     WHEN 'MODRGTTRD' THEN 'LCR' WHEN 'MODRGTBO' THEN 'LCR' ELSE 'OTH' END) AS encaissement
FROM gescom.table_base t
WHERE btrim(t.codtab) ~ '^MODRGT';
CREATE TEMP TABLE mig_transporteur ON COMMIT DROP AS
SELECT substr(import_id, 12) AS cle, id FROM base_partner WHERE import_id LIKE 'GESCOM-TRA-%';
CREATE TEMP TABLE mig_fournisseur ON COMMIT DROP AS
SELECT DISTINCT ON (upper(btrim(f.refcpt))) upper(btrim(f.refcpt)) AS code, p.id
FROM gescom.fou f JOIN base_partner p ON p.import_id = 'GESCOM-FOU-' || btrim(f.focleunik)
WHERE gescom.txt(f.refcpt) IS NOT NULL ORDER BY upper(btrim(f.refcpt)), p.id;
CREATE INDEX ON mig_fournisseur (code);
-- lots : n° de lot GESCOM + n° de l'arrivage d'origine
CREATE TEMP TABLE mig_lot ON COMMIT DROP AS
SELECT t.id, upper(btrim(t.lvme_numero_base)) AS lot, t.product, m.stock_move_seq AS arrivage, t.lot_fournisseur,
  t.perishable_expiration_date AS dlc,
  coalesce((SELECT l.details_stock_location FROM stock_stock_location_line l JOIN stock_stock_location s
             ON s.id = l.details_stock_location AND s.type_select = 1
            WHERE l.tracking_number = t.id ORDER BY abs(l.current_qty) DESC LIMIT 1), ml.to_stock_location) AS frigo
FROM stock_tracking_number t
LEFT JOIN stock_stock_move_line ml ON ml.id = t.origin_stock_move_line
LEFT JOIN stock_stock_move m ON m.id = ml.stock_move
WHERE t.import_id LIKE 'GESCOM-LOT-%' AND t.lvme_numero_base IS NOT NULL;
CREATE INDEX ON mig_lot (lot, product);

-- ---------- commandes (type 2) et leur facture (type 3) ----------
CREATE TEMP TABLE mig_cde ON COMMIT DROP AS
SELECT btrim(c.ncde) AS num, c.*,
  coalesce(cl.id, cc.id) AS client, co.id AS commercial_id, cnd.id AS condition_id, md.encaissement AS mode_id,
  tr.id AS transporteur_id,
  -- autres informations GESCOM de la commande (note interne)
  NULLIF(concat_ws(E'\n',
    'Contact : ' || gescom.txt(c.nomresp), 'Tél. : ' || gescom.txt(c.tel), 'E-mail : ' || gescom.txt(c.ademail),
    'Zone : ' || CASE btrim(c.position) WHEN '1' THEN 'France' WHEN '2' THEN 'Corse' WHEN '5' THEN 'Étranger' END,
    'Saisie par : ' || gescom.txt(c.codp_a),
    CASE WHEN btrim(c.affacturage) = '1' THEN 'Affacturage' END,
    'Bordereau : ' || gescom.txt(c.bordereau),
    'Colis : ' || NULLIF(gescom.num(c.nb_colis), 0), 'Poids brut : ' || NULLIF(gescom.num(c.poidsb), 0),
    'Escompte : ' || NULLIF(gescom.num(c.escompte), 0) || ' %', 'Acompte : ' || NULLIF(gescom.num(c.acompte), 0),
    'Port : ' || NULLIF(gescom.num(c.port), 0)), '') AS note_interne,
  coalesce(gescom.dt(c.dcre), DATE '2021-01-01') AS date_cde,
  coalesce(gescom.num(c.montht), 0) AS montant,
  gescom.txt(f.numfacture) AS facture, gescom.dt(f.dcre) AS date_facture, gescom.dt(f.deche) AS echeance,
  (SELECT s.id FROM sale_sale_order s WHERE s.import_id = 'GESCOM-CDE-' || btrim(c.ncde)) AS id,
  NULL::bigint AS bl_id
FROM gescom.cce c
LEFT JOIN gescom.cce f ON btrim(f.ncde) = btrim(c.idposition) AND btrim(f.type_facture) = '3'
  AND btrim(c.idposition) <> btrim(c.ncde)
LEFT JOIN mig_client cl ON cl.cle = btrim(c.clcleunik)
LEFT JOIN mig_client_code cc ON cc.code = upper(btrim(c.refcpt))
LEFT JOIN mig_commercial co ON co.code = btrim(c.comm)
LEFT JOIN mig_condition cnd ON cnd.idtable = btrim(c.modregt)
LEFT JOIN mig_mode md ON md.idtable = btrim(c.regl1)
LEFT JOIN mig_transporteur tr ON tr.cle = btrim(c.notransporteur)
WHERE btrim(coalesce(c.type_facture, '')) <> '3';
CREATE INDEX ON mig_cde (num);
ALTER TABLE mig_cde ADD COLUMN nouveau boolean;
UPDATE mig_cde SET nouveau = (id IS NULL);
UPDATE mig_cde SET id = nextval('sale_sale_order_seq') WHERE id IS NULL;

-- client absent de CLIENTS (supprimé dans GESCOM) : un client « inconnu » par code GESCOM, archivé
INSERT INTO base_partner (id, version, created_on, import_id, import_origin, partner_type_select, partner_seq, name,
  full_name, simple_full_name, is_supplier, is_customer, is_carrier, is_contact, is_prospect, is_employee, currency,
  archived)
SELECT nextval('base_partner_seq'), 0, now(), 'GESCOM-CLI-CDE-' || x.code, 'GESCOM', 1, x.code, x.nom,
  x.code || ' - ' || x.nom, x.nom, false, true, false, false, false, false, (SELECT euro FROM mig_def), true
FROM (SELECT DISTINCT ON (coalesce(gescom.txt(refcpt), 'C' || btrim(clcleunik)))
        coalesce(gescom.txt(refcpt), 'C' || btrim(clcleunik)) AS code, coalesce(gescom.txt(nom), 'CLIENT INCONNU') AS nom
      FROM mig_cde WHERE client IS NULL
      ORDER BY coalesce(gescom.txt(refcpt), 'C' || btrim(clcleunik)), gescom.num(cecleunik) DESC) x
WHERE NOT EXISTS (SELECT 1 FROM base_partner p WHERE p.import_id = 'GESCOM-CLI-CDE-' || x.code);
UPDATE mig_cde m SET client = p.id
FROM base_partner p
WHERE m.client IS NULL AND p.import_id = 'GESCOM-CLI-CDE-' || coalesce(gescom.txt(m.refcpt), 'C' || btrim(m.clcleunik));

-- ---------- lignes ----------
CREATE TEMP TABLE mig_ligne ON COMMIT DROP AS
SELECT l.*, m.id AS commande, m.date_cde, m.nouveau,
  btrim(l.typm) AS genre,
  CASE WHEN btrim(l.typm) IN ('P', 'D') THEN a.id END AS article,
  coalesce(u.id, a.unit) AS unite_id,
  coalesce(gescom.num(l.qsor), 0) AS qte,
  coalesce(gescom.num(l.prixvte), 0) AS prix_brut,
  coalesce(NULLIF(gescom.num(l.pedi), 0), gescom.num(l.prixvte), 0) AS prix_net,
  coalesce(gescom.num(l.montv), 0) AS montant,
  coalesce(gescom.num(l.ttvad), 0) AS taux_tva, fo.id AS fournisseur_id,
  row_number() OVER (PARTITION BY m.id ORDER BY gescom.num(l.no_ligne), gescom.num(l.cdcleunik)) AS rang,
  nextval('sale_sale_order_line_seq') AS ligne_id
FROM gescom.ccd l
JOIN mig_cde m ON m.num = btrim(l.ncde)
LEFT JOIN mig_article a ON a.ref = upper(btrim(l.ref))
LEFT JOIN mig_unite u ON u.code = upper(btrim(l.unite))
LEFT JOIN mig_fournisseur fo ON fo.code = upper(btrim(l.fou_cod))
WHERE m.nouveau;
CREATE INDEX ON mig_ligne (commande);
-- lot vendu : n° de lot + article, l'arrivage d'origine départage les lots du même nom
ALTER TABLE mig_ligne ADD COLUMN lot_id bigint, ADD COLUMN frigo bigint;
UPDATE mig_ligne g SET lot_id = x.id, frigo = x.frigo
FROM (SELECT DISTINCT ON (g2.ligne_id) g2.ligne_id, t.id, t.frigo
      FROM mig_ligne g2 JOIN mig_lot t ON t.lot = upper(btrim(g2.lot)) AND t.product = g2.article
      WHERE g2.article IS NOT NULL AND gescom.txt(g2.lot) IS NOT NULL
      ORDER BY g2.ligne_id, (t.arrivage = btrim(g2.arr_num)) DESC NULLS LAST, t.id) x
WHERE g.ligne_id = x.ligne_id;

-- statistiques à jour avant les insertions liées (base purgée : sinon contrôle des liens par lecture complète)
ANALYZE base_partner;
ANALYZE stock_tracking_number;

-- ---------- commandes clients ----------
INSERT INTO sale_sale_order (id, version, created_on, import_id, import_origin, sale_order_seq, full_name, company,
  client_partner, invoiced_partner, delivered_partner, currency, status_select, sale_order_type_select, creation_date,
  order_date, confirmation_date_time, estimated_delivery_date, ex_tax_total, company_ex_tax_total, tax_total,
  in_tax_total, external_reference, invoice_comments, description, delivery_address_str, commercial, delivery_state,
  invoicing_state, template, in_ati, version_number, amount_invoiced, advance_total, discount_amount,
  price_before_global_discount, oneoff_sale, order_being_edited, manual_unblock, payment_condition, payment_mode,
  carrier_partner, tauxrfa, taux_commission, cout_port_kg, lvme_frais_congelation, remise_facture, internal_note)
SELECT m.id, 0, now(), 'GESCOM-CDE-' || m.num, 'GESCOM', m.num, m.num || ' - ' || coalesce(gescom.txt(m.nom), ''),
  d.societe, m.client, m.client, m.client, d.euro, 4, 1, m.date_cde, m.date_cde, m.date_cde::timestamp, m.date_cde,
  m.montant, m.montant,
  coalesce((SELECT round(sum(g.montant * g.taux_tva / 100), 2) FROM mig_ligne g WHERE g.commande = m.id), 0),
  m.montant + coalesce((SELECT round(sum(g.montant * g.taux_tva / 100), 2) FROM mig_ligne g WHERE g.commande = m.id), 0),
  gescom.txt(m.refcde),
  CASE WHEN m.facture IS NOT NULL THEN 'Facture GESCOM n° ' || m.facture
    || coalesce(' du ' || to_char(m.date_facture, 'DD/MM/YYYY'), '')
    || coalesce(', échéance ' || to_char(m.echeance, 'DD/MM/YYYY'), '') END,
  CASE WHEN m.montant < 0 THEN 'Avoir' END,
  NULLIF(concat_ws(E'\n', gescom.txt(m.nom), gescom.txt(m.adr1), gescom.txt(m.adr2), gescom.txt(m.adr3),
    NULLIF(concat_ws(' ', gescom.txt(m.codp), gescom.txt(m.vil)), ''), gescom.txt(m.pays)), ''),
  m.commercial_id, 3, CASE WHEN m.facture IS NOT NULL THEN 3 ELSE 1 END, false, false, 1,
  CASE WHEN m.facture IS NOT NULL THEN m.montant ELSE 0 END, 0, 0, m.montant, false, false, false,
  m.condition_id, m.mode_id, m.transporteur_id, NULLIF(gescom.num(m.rfa), 0), NULLIF(gescom.num(m.pourc_comm), 0),
  NULLIF(gescom.num(m.cout_port), 0), NULLIF(gescom.num(m.pourc_cong), 0), NULLIF(gescom.num(m.remmax), 0),
  m.note_interne
FROM mig_cde m CROSS JOIN mig_def d
WHERE m.nouveau;

ANALYZE sale_sale_order;
INSERT INTO sale_sale_order_line (id, version, created_on, import_id, import_origin, sale_order, sequence, type_select,
  product, product_name, unit, qty, delivered_qty, price, price_discounted, in_tax_price, ex_tax_total,
  company_ex_tax_total, in_tax_total, company_in_tax_total, discount_type_select, discount_amount, nb_colis,
  poids_par_colis, poids_total_net, prix_revient, taux_commission, tauxrfa, delivery_state, invoicing_state, invoiced,
  amount_invoiced, estimated_delivery_date, full_name, supplier_partner, coef_poids_net)
SELECT g.ligne_id, 0, now(), 'GESCOM-CDL-' || btrim(g.cdcleunik), 'GESCOM', g.commande, g.rang,
  CASE WHEN g.genre = 'T' THEN 1 ELSE 0 END, g.article,
  coalesce(gescom.txt(g.tit), (SELECT name FROM base_product WHERE id = g.article), gescom.txt(g.ref), 'Ligne'),
  g.unite_id, g.qte, CASE WHEN g.article IS NOT NULL THEN g.qte ELSE 0 END, g.prix_brut, g.prix_net,
  coalesce(NULLIF(gescom.num(g.pedi_ttc), 0), round(g.prix_net * (1 + g.taux_tva / 100), 4)), g.montant, g.montant,
  coalesce(NULLIF(gescom.num(g.montv_ttc), 0), round(g.montant * (1 + g.taux_tva / 100), 2)),
  coalesce(NULLIF(gescom.num(g.montv_ttc), 0), round(g.montant * (1 + g.taux_tva / 100), 2)),
  CASE WHEN coalesce(gescom.num(g.remmax), 0) <> 0 THEN 1 ELSE 0 END, coalesce(gescom.num(g.remmax), 0),
  gescom.num(g.nbcolis), gescom.num(g.pdscolis), gescom.num(g.poidsb),
  -- prix de revient : celui de l'arrivage, sinon PRIX (prix de revient du lot au moment de la vente)
  coalesce(NULLIF(gescom.num(g.pr_arr), 0), NULLIF(gescom.num(g.prix), 0)),
  gescom.num(g.taux_comm), gescom.num(g.remise_rfa), CASE WHEN g.article IS NOT NULL THEN 3 END,
  CASE WHEN g.article IS NOT NULL THEN 3 END, g.article IS NOT NULL,
  CASE WHEN g.article IS NOT NULL THEN g.montant ELSE 0 END, g.date_cde,
  left(g.rang || ' - ' || coalesce(gescom.txt(g.tit), gescom.txt(g.ref), ''), 255), g.fournisseur_id,
  NULLIF(gescom.num(g.coeff_cond), 0)
FROM mig_ligne g;

INSERT INTO sale_sale_order_line_tax_line_set (sale_sale_order_line, tax_line_set)
SELECT g.ligne_id, CASE WHEN g.taux_tva = 5.5 THEN d.tva55 WHEN g.taux_tva = 2.1 THEN d.tva21
                        WHEN g.taux_tva = 20 THEN d.tva20 ELSE d.tva0 END
FROM mig_ligne g CROSS JOIN mig_def d
WHERE g.genre <> 'T'
  AND CASE WHEN g.taux_tva = 5.5 THEN d.tva55 WHEN g.taux_tva = 2.1 THEN d.tva21
           WHEN g.taux_tva = 20 THEN d.tva20 ELSE d.tva0 END IS NOT NULL;

-- lot vendu sur la ligne de commande
ANALYZE sale_sale_order_line;
INSERT INTO supplychain_sale_order_line_lot (id, version, created_on, import_id, import_origin, sale_order_line,
  tracking_number, lot_fournisseur, qty_to_ship, available_qty, perishable_expiration_date)
SELECT nextval('supplychain_sale_order_line_lot_seq'), 0, now(), 'GESCOM-CDLOT-' || btrim(g.cdcleunik), 'GESCOM',
  g.ligne_id, g.lot_id, t.lot_fournisseur, g.qte, 0, t.perishable_expiration_date
FROM mig_ligne g JOIN stock_tracking_number t ON t.id = g.lot_id;

-- ---------- BL réalisés (sans mouvement de stock : le stock est déjà celui de GESCOM) ----------
UPDATE mig_cde m SET bl_id = nextval('stock_stock_move_seq')
WHERE m.nouveau AND EXISTS (SELECT 1 FROM mig_ligne g WHERE g.commande = m.id AND g.article IS NOT NULL AND g.qte <> 0);
INSERT INTO stock_stock_move (id, version, created_on, import_id, import_origin, stock_move_seq, name, origin, company,
  partner, type_select, status_select, estimated_date, real_date, from_stock_location, to_stock_location, ex_tax_total,
  nb_colis_total, poids_total, note, filter_on_available_products, availability_request, cut_off_move_generated,
  fully_spread_over_logistical_forms_flag, group_products_on_printings, invoice_blocking, is_cession,
  is_conformity_certif_signed, is_ispm_required, is_needing_conformity_certificate, is_reversion, is_with_backorder,
  is_with_return_surplus, lvme_bl_flottant, picking_is_edited, planned_stock_move_automatic_mail,
  real_stock_move_automatic_mail)
SELECT m.bl_id, 0, now(), 'GESCOM-BL-' || m.num, 'GESCOM', 'BL' || m.num,
  'BL' || m.num || ' - ' || coalesce((SELECT partner_seq || ' - ' || name FROM base_partner WHERE id = m.client), ''), m.num,
  d.societe, m.client, 2, 3, m.date_cde, m.date_cde,
  coalesce((SELECT g.frigo FROM mig_ligne g WHERE g.commande = m.id AND g.frigo IS NOT NULL ORDER BY g.rang LIMIT 1),
           d.frigo_defaut), d.client_loc, m.montant,
  (SELECT sum(coalesce(gescom.num(g.nbcolis), 0)) FROM mig_ligne g WHERE g.commande = m.id AND g.article IS NOT NULL),
  (SELECT sum(g.qte) FROM mig_ligne g WHERE g.commande = m.id AND g.article IS NOT NULL),
  'BL repris de GESCOM (historique, sans mouvement de stock)',
  true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false
FROM mig_cde m CROSS JOIN mig_def d
WHERE m.bl_id IS NOT NULL;
INSERT INTO stock_stock_move_sale_order_set (stock_stock_move, sale_order_set)
SELECT bl_id, id FROM mig_cde WHERE bl_id IS NOT NULL;

ANALYZE stock_stock_move;
INSERT INTO stock_stock_move_line (id, version, created_on, import_id, import_origin, stock_move, sequence, name, product,
  product_name, product_type_select, unit, qty, real_qty, unit_price_untaxed, unit_price_taxed,
  company_unit_price_untaxed, tracking_number, from_stock_location, to_stock_location, sale_order_line, nb_colis,
  poids_par_colis, poids_total_net, conformity_select, is_qty_requested, is_real_qty_modified_by_user, line_type_select,
  qty_invoiced, requested_reserved_qty, reserved_qty, shipped_qty)
SELECT nextval('stock_stock_move_line_seq'), 0, now(), 'GESCOM-BLL-' || btrim(g.cdcleunik), 'GESCOM', m.bl_id, g.rang,
  m.num || '-' || g.rang, g.article, (SELECT name FROM base_product WHERE id = g.article), 'storable', g.unite_id,
  g.qte, g.qte, g.prix_net, round(g.prix_net * (1 + g.taux_tva / 100), 4), g.prix_net, g.lot_id,
  coalesce(g.frigo, d.frigo_defaut), d.client_loc, g.ligne_id, gescom.num(g.nbcolis), gescom.num(g.pdscolis),
  gescom.num(g.poidsb), 0, false, false, 0, 0, 0, 0, 0
FROM mig_ligne g JOIN mig_cde m ON m.id = g.commande CROSS JOIN mig_def d
WHERE m.bl_id IS NOT NULL AND g.article IS NOT NULL AND g.qte <> 0;

-- ---------- commandes déjà reprises : informations ajoutées ensuite (paiement, transporteur, taux, note ; lignes :
-- TTC GESCOM, fournisseur, coefficient de poids net, prix de revient) ----------
UPDATE sale_sale_order s SET payment_condition = m.condition_id, payment_mode = m.mode_id,
  carrier_partner = m.transporteur_id, tauxrfa = NULLIF(gescom.num(m.rfa), 0),
  taux_commission = NULLIF(gescom.num(m.pourc_comm), 0), cout_port_kg = NULLIF(gescom.num(m.cout_port), 0),
  lvme_frais_congelation = NULLIF(gescom.num(m.pourc_cong), 0), remise_facture = NULLIF(gescom.num(m.remmax), 0),
  internal_note = m.note_interne, version = s.version + 1
FROM mig_cde m
WHERE s.id = m.id AND NOT m.nouveau AND s.internal_note IS NULL AND s.payment_condition IS NULL
  AND s.carrier_partner IS NULL;
UPDATE sale_sale_order_line l SET supplier_partner = fo.id, coef_poids_net = NULLIF(gescom.num(c.coeff_cond), 0),
  in_tax_price = coalesce(NULLIF(gescom.num(c.pedi_ttc), 0), l.in_tax_price),
  in_tax_total = coalesce(NULLIF(gescom.num(c.montv_ttc), 0), l.in_tax_total),
  company_in_tax_total = coalesce(NULLIF(gescom.num(c.montv_ttc), 0), l.company_in_tax_total),
  prix_revient = coalesce(NULLIF(gescom.num(c.pr_arr), 0), NULLIF(gescom.num(c.prix), 0)), version = l.version + 1
FROM gescom.ccd c LEFT JOIN mig_fournisseur fo ON fo.code = upper(btrim(c.fou_cod))
WHERE l.import_id = 'GESCOM-CDL-' || btrim(c.cdcleunik) AND l.supplier_partner IS NULL AND l.coef_poids_net IS NULL
  AND (fo.id IS NOT NULL OR NULLIF(gescom.num(c.coeff_cond), 0) IS NOT NULL);

COMMIT;

-- ---------- contrôle ----------
SELECT (SELECT count(*) FROM gescom.cce WHERE btrim(coalesce(type_facture, '')) <> '3') AS commandes_gescom,
       (SELECT count(*) FROM sale_sale_order WHERE import_id LIKE 'GESCOM-CDE-%') AS commandes_axelor,
       (SELECT count(*) FROM gescom.cce WHERE btrim(type_facture) = '3') AS factures_gescom,
       (SELECT count(*) FROM sale_sale_order WHERE import_id LIKE 'GESCOM-CDE-%' AND invoice_comments IS NOT NULL)
         AS commandes_avec_facture,
       (SELECT count(*) FROM gescom.ccd l JOIN gescom.cce c ON btrim(c.ncde) = btrim(l.ncde)
         WHERE btrim(coalesce(c.type_facture, '')) <> '3') AS lignes_gescom,
       (SELECT count(*) FROM sale_sale_order_line WHERE import_id LIKE 'GESCOM-CDL-%') AS lignes_axelor,
       (SELECT count(*) FROM supplychain_sale_order_line_lot WHERE import_id LIKE 'GESCOM-CDLOT-%') AS lignes_avec_lot,
       (SELECT count(*) FROM stock_stock_move WHERE import_id LIKE 'GESCOM-BL-%') AS bl,
       (SELECT round(sum(gescom.num(montht))) FROM gescom.cce WHERE btrim(coalesce(type_facture, '')) <> '3') AS ca_gescom,
       (SELECT round(sum(ex_tax_total)) FROM sale_sale_order WHERE import_id LIKE 'GESCOM-CDE-%') AS ca_axelor;

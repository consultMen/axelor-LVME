-- =====================================================================
-- MIGRATION GESCOM — étape 01 : unités, familles et articles
--   Source : archive gescom.* (MIG_00_archive_gescom.sql, export GESCOM d'octobre 2026)
--   - unités : la liste Axelor est complétée avec les unités de GESCOM (UNITE_VENTE) ; une unité qui existe déjà
--     (même nom, ex. « Sac » = SAC) est réutilisée
--   - familles : FAMILLE_ARTICLES -> catégories d'articles (code, libellé) ; famille existante réutilisée
--   - articles : ARTICLES -> articles Axelor, mêmes réglages qu'un article créé à l'écran (stockable, vendable,
--     achetable, lot automatique à l'achat, famille comptable « Produit surgelé », euro) ; code = REF,
--     désignation = DESI, nom complet = [REF] DESI ; clé GESCOM gardée (import_id GESCOM-ART-<ARCLEUNIK>)
--   Ce qui n'a pas de champ dans la fiche article (marque, origine, zone de pêche, conditionnement, durabilité,
--   stock mini, promos, cdv…) reste dans gescom.articles.
--   Unité : unité de vente GESCOM, sinon unité d'achat, sinon KG (1 132 anciens articles sans unité dans GESCOM).
--   Fournisseur habituel (FOCLEUNIK) : relié à l'étape des tiers.
-- Relançable : ce qui existe déjà (même clé GESCOM ou même code) n'est pas recréé.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

-- ---------- unités ----------
INSERT INTO base_unit (id, version, created_on, name, label_to_printing, import_id, import_origin)
SELECT nextval('base_unit_seq'), 0, now(), u.code, u.libelle, 'GESCOM-UVE-' || u.code, 'GESCOM'
FROM (SELECT DISTINCT ON (upper(btrim(uve))) upper(btrim(uve)) AS code, gescom.txt(libelle) AS libelle
      FROM gescom.unite_vente WHERE gescom.txt(uve) IS NOT NULL ORDER BY upper(btrim(uve)), gescom.num(n_enr)) u
WHERE NOT EXISTS (SELECT 1 FROM base_unit b WHERE upper(btrim(b.name)) = u.code OR b.import_id = 'GESCOM-UVE-' || u.code);

CREATE TEMP TABLE mig_unite ON COMMIT DROP AS
SELECT DISTINCT ON (code) code, id FROM (
  SELECT upper(btrim(b.name)) AS code, b.id, 1 AS rang FROM base_unit b
  UNION ALL
  SELECT substr(b.import_id, 12), b.id, 0 FROM base_unit b WHERE b.import_id LIKE 'GESCOM-UVE-%') x
ORDER BY code, rang;

-- ---------- familles ----------
INSERT INTO base_product_category (id, version, created_on, code, name, import_id, import_origin)
SELECT nextval('base_product_category_seq'), 0, now(), gescom.txt(f.code), btrim(f.libelle),
       'GESCOM-FAM-' || btrim(f.idfamart), 'GESCOM'
FROM gescom.famille_articles f
WHERE gescom.txt(f.idfamart) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_product_category c
                  WHERE c.import_id = 'GESCOM-FAM-' || btrim(f.idfamart)
                     OR upper(c.code) = upper(btrim(f.code)) OR upper(c.name) = upper(btrim(f.libelle)));

CREATE TEMP TABLE mig_famille ON COMMIT DROP AS
SELECT DISTINCT ON (btrim(f.idfamart)) btrim(f.idfamart) AS idfamart, c.id
FROM gescom.famille_articles f
JOIN base_product_category c ON c.import_id = 'GESCOM-FAM-' || btrim(f.idfamart)
   OR upper(c.code) = upper(btrim(f.code)) OR upper(c.name) = upper(btrim(f.libelle))
ORDER BY btrim(f.idfamart), (c.import_id = 'GESCOM-FAM-' || btrim(f.idfamart)) DESC;

-- ---------- articles ----------
CREATE TEMP TABLE mig_defauts ON COMMIT DROP AS
SELECT (SELECT id FROM base_product_family ORDER BY (code = 'PR-SURG') DESC, id LIMIT 1) AS famille_comptable,
       (SELECT id FROM stock_tracking_number_configuration WHERE generate_purchase_auto_tracking_nbr = true
        ORDER BY id LIMIT 1) AS config_lot,
       (SELECT id FROM base_currency WHERE codeiso = 'EUR' LIMIT 1) AS euro;

INSERT INTO base_product (id, version, created_on, dtype, import_id, import_origin, code, name, full_name,
  product_category, unit, sales_unit, purchases_unit, sale_price, sale_price_ttc, purchase_price, cost_price,
  poids_colis, gencode, ref_douaniere, ref_fournisseur, nom_scientifique,
  product_type_select, product_sub_type_select, procurement_method_select, sellable, purchasable, stock_managed,
  product_family, tracking_number_configuration, sale_currency, purchase_currency, start_date,
  cost_type_select, manag_price_coef, real_or_estimated_price_select, sale_supply_select,
  bom_comp_valu_method_select, manuf_order_comp_valu_method_select, avg_price, attrs, product_attrs,
  allow_to_force_purchase_qty, allow_to_force_sale_qty, auto_update_sale_price, block_expense_tax, control_on_receipt,
  deduct_lunch_voucher, def_ship_coef_by_partner, exclude_from_mrp, expense, in_ati, is_activity, is_analytic_capture,
  is_model, is_prototype, is_shipping_costs_product, is_unrenewed, manage_variant_price, personal_expense,
  unavailable_to_users, used_indeb, archived)
SELECT nextval('base_product_seq'), 0, now(), 'Product', 'GESCOM-ART-' || btrim(a.arcleunik), 'GESCOM',
  btrim(a.ref), btrim(a.desi), '[' || btrim(a.ref) || '] ' || btrim(a.desi),
  fa.id, coalesce(uv.id, ua.id, kg.id), coalesce(uv.id, ua.id, kg.id), coalesce(ua.id, uv.id, kg.id),
  coalesce(gescom.num(a.pvente), 0), coalesce(gescom.num(a.pvente_ttc), 0), coalesce(gescom.num(a.pachat), 0),
  coalesce(gescom.num(a.pxrevt), 0),
  NULLIF(coalesce(gescom.num(a.pdscolis), gescom.num(a.poi)), 0),
  NULLIF(regexp_replace(coalesce(a.gencod, ''), '^0+$', ''), ''), gescom.txt(a.refdouane), gescom.txt(a.reffou),
  gescom.txt(a.nom_scien),
  'storable', 0, 'buy', true, true, true,
  d.famille_comptable, d.config_lot, d.euro, d.euro, current_date,
  1, 1, 1, 1, 2, 1, 0, '{}'::jsonb, '{}'::jsonb,
  false, false, false, false, false, false, false, false, false, false, false, false,
  false, false, false, false, false, false, false, false, coalesce(gescom.num(a.retire), 0) <> 0
FROM gescom.articles a
CROSS JOIN mig_defauts d
LEFT JOIN mig_famille fa ON fa.idfamart = btrim(a.idfamart)
LEFT JOIN mig_unite uv ON uv.code = upper(btrim(a.uve))
LEFT JOIN mig_unite ua ON ua.code = upper(btrim(a.uva))
LEFT JOIN mig_unite kg ON kg.code = 'KG'
WHERE gescom.txt(a.ref) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM base_product p
                  WHERE p.import_id = 'GESCOM-ART-' || btrim(a.arcleunik) OR p.code = btrim(a.ref));

COMMIT;

-- ---------- contrôle ----------
SELECT (SELECT count(*) FROM gescom.articles) AS articles_gescom,
       (SELECT count(*) FROM base_product WHERE import_origin = 'GESCOM') AS articles_axelor,
       (SELECT count(*) FROM base_product WHERE import_origin = 'GESCOM' AND product_category IS NULL) AS sans_famille,
       (SELECT count(*) FROM base_product WHERE import_origin = 'GESCOM' AND unit IS NULL) AS sans_unite,
       (SELECT count(*) FROM base_product_category WHERE import_origin = 'GESCOM') AS familles_creees,
       (SELECT count(*) FROM base_unit WHERE import_origin = 'GESCOM') AS unites_creees;

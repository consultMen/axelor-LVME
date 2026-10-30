-- =====================================================================
-- MIG_09 : catalogue fournisseurs GESCOM (table FOUART) -> catalogue fournisseurs Axelor (purchase_supplier_catalog)
--   Une ligne par fournisseur et article (2 785) : prix d'achat et devise (devise d'achat du fournisseur), unité, prix de revient, réf. fournisseur, date de
--   dernière commande, origine, zone de pêche, conditionnement, poids colis, marque, gencode.
--   Fournisseur : code GESCOM (REFCPT de FOU, comme les arrivages) ; 9 lignes sans code fournisseur dans GESCOM
--   (2014-2015) sont rattachées au « FOURNISSEUR INCONNU (GESCOM) » (précisé en description). Les lignes
--   sans code article dans GESCOM (2) ne sont pas reprises : listées par le contrôle. Origine, zone et marque : libellé
--   GESCOM, ou le code brut quand il n'a pas de libellé dans les tables de référence.
--   Consultation : écran « Catalogue fournisseurs » (menu Achats, PROD_118). L'option Axelor « gérer le catalogue
--   fournisseur » reste désactivée : la saisie des commandes d'achat ne change pas.
-- Prérequis : MIG_00 (archive GESCOM avec FOUART), MIG_01 (articles), MIG_02 (tiers), MIG_05 (fournisseur inconnu).
-- Colonnes LVME créées si besoin (avant le premier démarrage du code). Tomcat arrêté. Relançable.
-- =====================================================================
BEGIN;

ALTER TABLE purchase_supplier_catalog
  ADD COLUMN IF NOT EXISTS currency bigint,
  ADD COLUMN IF NOT EXISTS prix_revient numeric(20, 4),
  ADD COLUMN IF NOT EXISTS conditionnement bigint,
  ADD COLUMN IF NOT EXISTS poids_colis numeric(20, 3),
  ADD COLUMN IF NOT EXISTS origine varchar(255),
  ADD COLUMN IF NOT EXISTS zone_peche varchar(255),
  ADD COLUMN IF NOT EXISTS marque varchar(255),
  ADD COLUMN IF NOT EXISTS gencode varchar(255);

CREATE TEMP TABLE mig_fournisseur ON COMMIT DROP AS
SELECT DISTINCT ON (upper(btrim(f.refcpt))) upper(btrim(f.refcpt)) AS code, p.id,
  -- devise d'achat du fournisseur dans GESCOM (TABLE_BASE : 65 = euro, 66 = dollar US)
  (SELECT c.id FROM base_currency c WHERE c.codeiso = CASE btrim(f.devise_achat) WHEN '66' THEN 'USD' ELSE 'EUR' END
   LIMIT 1) AS devise
FROM gescom.fou f JOIN base_partner p ON p.import_id = 'GESCOM-FOU-' || btrim(f.focleunik)
WHERE gescom.txt(f.refcpt) IS NOT NULL ORDER BY upper(btrim(f.refcpt)), p.id;
CREATE TEMP TABLE mig_libelle ON COMMIT DROP AS
SELECT 'ORI' AS liste, upper(btrim(code)) AS code, btrim(libelle) AS libelle FROM gescom.origine WHERE gescom.txt(code) IS NOT NULL
UNION ALL SELECT 'ZON', upper(btrim(code)), btrim(libelle) FROM gescom.zone_peche WHERE gescom.txt(code) IS NOT NULL
UNION ALL SELECT 'MAR', upper(btrim(code)), btrim(desi) FROM gescom.marque WHERE gescom.txt(code) IS NOT NULL;
CREATE TEMP TABLE mig_unite ON COMMIT DROP AS
SELECT DISTINCT ON (upper(btrim(name))) upper(btrim(name)) AS code, id FROM base_unit ORDER BY upper(btrim(name)), id;

-- relançable : les lignes du catalogue reprises de GESCOM sont recréées
DELETE FROM purchase_supplier_catalog WHERE import_id LIKE 'GESCOM-FOUART-%';

INSERT INTO purchase_supplier_catalog (id, version, created_on, import_id, import_origin, product, supplier_partner,
  product_supplier_code, price, currency, unit, update_date, prix_revient, conditionnement, poids_colis, origine, zone_peche,
  marque, gencode, description, is_take_product_multiple_qty, is_taking_product_purchase_price, min_qty)
SELECT nextval('purchase_supplier_catalog_seq'), 0, now(), 'GESCOM-FOUART-' || btrim(f.idfouart), 'GESCOM', p.id,
  coalesce(fo.id, (SELECT id FROM base_partner WHERE import_id = 'GESCOM-FOU-INCONNU')),
  gescom.txt(f.ref_fou), gescom.num(f.prx_ach),
  coalesce(fo.devise, (SELECT id FROM base_currency WHERE codeiso = 'EUR' LIMIT 1)), coalesce(u.id, p.unit), gescom.dt(f.dat_dern_cdf),
  NULLIF(gescom.num(f.prx_rev), 0), co.id, NULLIF(gescom.num(f.pdscolis), 0),
  coalesce((SELECT libelle FROM mig_libelle WHERE liste = 'ORI' AND code = upper(btrim(f.origine)) LIMIT 1), gescom.txt(f.origine)),
  coalesce((SELECT libelle FROM mig_libelle WHERE liste = 'ZON' AND code = upper(btrim(f.zpeche)) LIMIT 1), gescom.txt(f.zpeche)),
  coalesce((SELECT libelle FROM mig_libelle WHERE liste = 'MAR' AND code = upper(btrim(f.marque)) LIMIT 1), gescom.txt(f.marque)),
  gescom.txt(f.gencod),
  CASE WHEN fo.id IS NULL THEN coalesce('Fournisseur GESCOM ' || gescom.txt(f.ref_cpt) || ' absent de GESCOM',
    'Sans fournisseur dans GESCOM (FOUART n° ' || btrim(f.idfouart) || ')') END,
  false, false, 1
FROM gescom.fouart f
JOIN base_product p ON upper(p.code) = upper(btrim(f.ref_art))
LEFT JOIN mig_fournisseur fo ON fo.code = upper(btrim(f.ref_cpt))
LEFT JOIN mig_unite u ON u.code = upper(btrim(f.uva))
LEFT JOIN purchase_conditionnement co ON upper(co.code) = upper(btrim(f.cond));

ANALYZE purchase_supplier_catalog;

COMMIT;

-- contrôles
SELECT (SELECT count(*) FROM gescom.fouart) AS fouart_gescom,
  (SELECT count(*) FROM purchase_supplier_catalog WHERE import_id LIKE 'GESCOM-FOUART-%') AS catalogue_lvme,
  (SELECT count(*) FROM purchase_supplier_catalog c JOIN base_partner p ON p.id = c.supplier_partner
   WHERE c.import_id LIKE 'GESCOM-FOUART-%' AND p.import_id = 'GESCOM-FOU-INCONNU') AS fournisseur_inconnu,
  (SELECT count(*) FROM purchase_supplier_catalog WHERE import_id LIKE 'GESCOM-FOUART-%' AND price > 0) AS avec_prix_achat,
  (SELECT count(*) FROM purchase_supplier_catalog WHERE import_id LIKE 'GESCOM-FOUART-%' AND conditionnement IS NOT NULL) AS avec_cond,
  (SELECT count(*) FROM purchase_supplier_catalog c JOIN base_currency d ON d.id = c.currency
   WHERE c.import_id LIKE 'GESCOM-FOUART-%' AND d.codeiso = 'USD') AS en_dollars;
-- lignes GESCOM non reprises (article absent)
SELECT btrim(f.ref_cpt) AS fournisseur, btrim(f.ref_art) AS article, f.prx_ach FROM gescom.fouart f
WHERE NOT EXISTS (SELECT 1 FROM base_product p WHERE upper(p.code) = upper(btrim(f.ref_art)));

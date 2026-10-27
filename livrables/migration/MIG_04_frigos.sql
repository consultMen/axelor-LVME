-- =====================================================================
-- MIGRATION GESCOM — étape 04 : frigos (FRIGO) -> emplacements de stock
--   Source : archive gescom.frigo (MIG_00). Décision du 27/10/2026 : tous les frigos GESCOM deviennent des
--   emplacements de stock internes de la société LVME, réglés comme FRIPACK (valorisés, utilisables en achat et en
--   vente) ; code GESCOM = n° de l'emplacement ; adresse reprise quand GESCOM en a une (contact, téléphone et
--   observations dans l'adresse). Frigo sans nom : son code sert de nom. Un emplacement qui existe déjà sous le même nom (ex. FRIPACK) est réutilisé et
--   reçoit la clé GESCOM. Relançable.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE mig_frigo ON COMMIT DROP AS
SELECT DISTINCT ON (btrim(f.idfrigo)) btrim(f.idfrigo) AS idfrigo, gescom.txt(f.code) AS code,
  coalesce(gescom.txt(f.nom), gescom.txt(f.code), 'Frigo ' || btrim(f.idfrigo)) AS nom,
  gescom.txt(f.adr_1) AS adr1, NULLIF(concat_ws(' ', gescom.txt(f.adr_2), gescom.txt(f.adr_3)), '') AS adr2,
  gescom.txt(f.codpost) AS cp, gescom.txt(f.ville) AS ville, upper(btrim(f.pays)) AS pays,
  NULLIF(concat_ws(' ', 'Contact : ' || gescom.txt(f.contact), 'Tél. : ' || gescom.txt(f.tel),
    'Portable : ' || gescom.txt(f.portable), 'E-mail : ' || gescom.txt(f.email), gescom.txt(f.obs)), '') AS infos,
  (SELECT l.id FROM stock_stock_location l
    WHERE l.import_id = 'GESCOM-FRIGO-' || btrim(f.idfrigo)
       OR (l.import_id IS NULL AND upper(btrim(l.name)) = upper(btrim(f.nom)))
    ORDER BY (l.import_id = 'GESCOM-FRIGO-' || btrim(f.idfrigo)) DESC NULLS LAST, l.id LIMIT 1) AS id,
  NULL::bigint AS adresse
FROM gescom.frigo f
WHERE gescom.txt(f.idfrigo) IS NOT NULL
ORDER BY btrim(f.idfrigo), gescom.num(f.n_enr);

-- adresse des nouveaux frigos quand GESCOM en a une
UPDATE mig_frigo SET adresse = nextval('base_address_seq')
WHERE id IS NULL AND (adr1 IS NOT NULL OR cp IS NOT NULL OR ville IS NOT NULL);
INSERT INTO base_address (id, version, created_on, import_id, import_origin, addressl2, addressl4, addressl5, addressl6,
  zip, town_name, country, full_name, formatted_full_name)
SELECT m.adresse, 0, now(), 'GESCOM-ADRF-' || m.idfrigo, 'GESCOM', left(m.infos, 255), m.adr1, m.adr2,
  NULLIF(concat_ws(' ', m.cp, m.ville), ''), m.cp, m.ville,
  coalesce((SELECT c.id FROM gescom.pays p JOIN base_country c ON upper(c.alpha2code) = upper(btrim(p.iso))
            WHERE upper(btrim(p.code)) = m.pays LIMIT 1),
           (SELECT id FROM base_country WHERE alpha2code = 'FR' LIMIT 1)),
  concat_ws(' ', m.adr1, m.adr2, m.cp, m.ville),
  concat_ws(E'\n', m.adr1, m.adr2, NULLIF(concat_ws(' ', m.cp, m.ville), ''))
FROM mig_frigo m WHERE m.adresse IS NOT NULL;

-- emplacements existants (même nom) : clé GESCOM
UPDATE stock_stock_location l SET import_id = 'GESCOM-FRIGO-' || m.idfrigo, import_origin = 'GESCOM',
  serial_number = coalesce(l.serial_number, m.code)
FROM mig_frigo m
WHERE l.id = m.id AND l.import_id IS NULL
  AND NOT EXISTS (SELECT 1 FROM stock_stock_location x WHERE x.import_id = 'GESCOM-FRIGO-' || m.idfrigo);

-- nouveaux emplacements, réglés comme FRIPACK
INSERT INTO stock_stock_location (id, version, created_on, import_id, import_origin, name, serial_number, company,
  type_select, address, is_valued, usable_on_purchase_order, usable_on_sale_order, usable_on_production,
  direct_order_location, include_out_of_stock, include_virtual_sub_location, is_not_in_calcul_stock, is_not_in_mrp,
  is_outsourcing_location, is_workshop, archived)
SELECT nextval('stock_stock_location_seq'), 0, now(), 'GESCOM-FRIGO-' || m.idfrigo, 'GESCOM', m.nom, m.code,
  (SELECT id FROM base_company ORDER BY id LIMIT 1), 1, m.adresse, true, true, true, false,
  false, false, false, false, false, false, false, false
FROM mig_frigo m WHERE m.id IS NULL;

COMMIT;

SELECT (SELECT count(*) FROM gescom.frigo) AS frigos_gescom,
       (SELECT count(*) FROM stock_stock_location WHERE import_id LIKE 'GESCOM-FRIGO-%') AS frigos_axelor,
       (SELECT count(*) FROM stock_stock_location) AS emplacements_total,
       (SELECT count(*) FROM stock_stock_location WHERE import_id LIKE 'GESCOM-FRIGO-%' AND address IS NOT NULL)
         AS avec_adresse;

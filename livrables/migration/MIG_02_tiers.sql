-- =====================================================================
-- MIGRATION GESCOM — étape 02 : tiers (transporteurs, fournisseurs, clients) et leurs listes
--   Source : archive gescom.* (MIG_00). Prérequis : MIG_01 (articles).
--   Listes complétées (rien de supprimé, pas de doublon) : pays (PAYS), secteurs (SECTEUR), catégories de clients
--   (FAMILLES_CLIENTS), groupements (GROUPEMENT), conditions de paiement (table_base RGT…) ; commerciaux
--   (COMMERCIAL) -> utilisateurs Axelor bloqués, sans mot de passe utilisable.
--   Tiers : clé GESCOM gardée (import_id GESCOM-CLI-<CLCLEUNIK>, GESCOM-FOU-<FOCLEUNIK>, GESCOM-TRA-<ID>) ;
--   code client / fournisseur = REFCPT ; adresse, téléphones, e-mail, SIRET, TVA intracom., secteur, catégorie,
--   groupement, % RFA / commission / remise facture, client comptant (règlement COMPTANT), condition et mode de
--   paiement, transporteur, commercial, port payé, code Coditour, horaires / notes, archivé (RETIRE) ;
--   contact responsable (NOMRESP) ; adresses de livraison (CLIENTAD) ; société et comptes client / fournisseur
--   (configuration comptable de la société) ; fournisseur habituel des articles (FOCLEUNIK).
--   Le reste (encours, plafond, client payeur, RIB, tournée, tarif, périodicité…) reste dans l'archive.
-- Relançable : ce qui existe déjà (même clé GESCOM) n'est pas recréé.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE mig_def ON COMMIT DROP AS
SELECT (SELECT id FROM base_company ORDER BY id LIMIT 1) AS societe,
       (SELECT id FROM base_currency WHERE codeiso = 'EUR' LIMIT 1) AS euro,
       (SELECT id FROM base_currency WHERE codeiso = 'USD' LIMIT 1) AS dollar,
       (SELECT id FROM base_localization WHERE name ILIKE 'French%' ORDER BY id LIMIT 1) AS langue,
       (SELECT id FROM base_country WHERE alpha2code = 'FR' LIMIT 1) AS france,
       (SELECT address_template FROM base_country WHERE alpha2code = 'FR' LIMIT 1) AS modele_adresse,
       (SELECT customer_account FROM account_account_config c
         WHERE c.company = (SELECT id FROM base_company ORDER BY id LIMIT 1) LIMIT 1) AS compte_client,
       (SELECT supplier_account FROM account_account_config c
         WHERE c.company = (SELECT id FROM base_company ORDER BY id LIMIT 1) LIMIT 1) AS compte_fournisseur;

-- ---------- pays ----------
INSERT INTO base_country (id, version, created_on, name, alpha2code, address_template, import_id, import_origin)
SELECT nextval('base_country_seq'), 0, now(), p.nom, p.iso, d.modele_adresse, 'GESCOM-PAYS-' || p.iso, 'GESCOM'
FROM (SELECT DISTINCT ON (upper(btrim(iso))) upper(btrim(iso)) AS iso, btrim(libpay) AS nom
      FROM gescom.pays WHERE gescom.txt(iso) IS NOT NULL ORDER BY upper(btrim(iso)), gescom.num(n_enr)) p
CROSS JOIN mig_def d
WHERE NOT EXISTS (SELECT 1 FROM base_country c WHERE upper(c.alpha2code) = p.iso);

CREATE TEMP TABLE mig_pays ON COMMIT DROP AS
SELECT DISTINCT ON (upper(btrim(p.code))) upper(btrim(p.code)) AS code, c.id
FROM gescom.pays p JOIN base_country c ON upper(c.alpha2code) = upper(btrim(p.iso))
ORDER BY upper(btrim(p.code)), c.id;
INSERT INTO mig_pays SELECT upper(alpha2code), id FROM base_country c
WHERE alpha2code IS NOT NULL AND NOT EXISTS (SELECT 1 FROM mig_pays m WHERE m.code = upper(c.alpha2code));

-- ---------- secteurs, catégories de clients, groupements ----------
INSERT INTO base_industry_sector (id, version, created_on, name, import_id, import_origin)
SELECT nextval('base_industry_sector_seq'), 0, now(), s.nom, 'GESCOM-SEC-' || s.code, 'GESCOM'
FROM (SELECT DISTINCT ON (upper(btrim(nom))) btrim(secteur) AS code, btrim(nom) AS nom
      FROM gescom.secteur WHERE gescom.txt(secteur) IS NOT NULL AND gescom.txt(nom) IS NOT NULL
      ORDER BY upper(btrim(nom)), gescom.num(n_enr)) s
WHERE NOT EXISTS (SELECT 1 FROM base_industry_sector i
                  WHERE upper(i.name) = upper(s.nom) OR i.import_id = 'GESCOM-SEC-' || s.code);
CREATE TEMP TABLE mig_secteur ON COMMIT DROP AS
SELECT DISTINCT ON (btrim(s.secteur)) btrim(s.secteur) AS code, i.id
FROM gescom.secteur s JOIN base_industry_sector i ON upper(i.name) = upper(btrim(s.nom))
ORDER BY btrim(s.secteur), i.id;

INSERT INTO base_partner_category (id, version, created_on, code, name, import_id, import_origin)
SELECT nextval('base_partner_category_seq'), 0, now(), f.code, f.nom, 'GESCOM-FAMCLI-' || f.code, 'GESCOM'
FROM (SELECT DISTINCT ON (btrim(familleclt)) btrim(familleclt) AS code, btrim(libelle) AS nom
      FROM gescom.familles_clients WHERE gescom.txt(familleclt) IS NOT NULL AND gescom.txt(libelle) IS NOT NULL
      ORDER BY btrim(familleclt), gescom.num(n_enr)) f
WHERE NOT EXISTS (SELECT 1 FROM base_partner_category c WHERE upper(c.code) = upper(f.code));
CREATE TEMP TABLE mig_categorie ON COMMIT DROP AS
SELECT DISTINCT ON (upper(code)) upper(code) AS code, id FROM base_partner_category ORDER BY upper(code), id;

INSERT INTO sale_groupement (id, version, created_on, code, name, pourc_rfa, fixed_phone, mobile_phone, fax, obs,
  actif, import_id, import_origin)
SELECT nextval('sale_groupement_seq'), 0, now(), g.code, coalesce(gescom.txt(g.nom), g.code),
  coalesce(gescom.num(g.pourc_rfa), 0), gescom.txt(g.tel), gescom.txt(g.portable), gescom.txt(g.fax),
  NULLIF(concat_ws(E'\n', gescom.txt(g.contact), gescom.txt(g.adr_1), gescom.txt(g.adr_2), gescom.txt(g.adr_3),
    nullif(concat_ws(' ', gescom.txt(g.codpost), gescom.txt(g.ville)), ''), gescom.txt(g.email), gescom.txt(g.obs)), ''),
  true, 'GESCOM-GRP-' || g.code, 'GESCOM'
FROM (SELECT DISTINCT ON (btrim(code)) *, btrim(code) AS code_g FROM gescom.groupement
      WHERE gescom.txt(code) IS NOT NULL ORDER BY btrim(code), gescom.num(n_enr)) g0
CROSS JOIN LATERAL (SELECT g0.code_g AS code, g0.nom, g0.pourc_rfa, g0.tel, g0.portable, g0.fax, g0.contact,
  g0.adr_1, g0.adr_2, g0.adr_3, g0.codpost, g0.ville, g0.email, g0.obs) g
WHERE NOT EXISTS (SELECT 1 FROM sale_groupement s WHERE upper(s.code) = upper(g.code));
CREATE TEMP TABLE mig_groupement ON COMMIT DROP AS
SELECT DISTINCT ON (upper(code)) upper(code) AS code, id FROM sale_groupement ORDER BY upper(code), id;

-- ---------- conditions et modes de paiement ----------
INSERT INTO account_payment_condition (id, version, created_on, code, name, import_id, import_origin)
SELECT nextval('account_payment_condition_seq'), 0, now(), btrim(t.codtab), btrim(t.codlib),
  'GESCOM-RGT-' || btrim(t.idtable), 'GESCOM'
FROM gescom.table_base t
WHERE btrim(t.codtab) ~ '^RGT' AND gescom.txt(t.codlib) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM account_payment_condition c WHERE c.code = btrim(t.codtab));
-- échéance : n jours date de facture (DF) ou fin de mois (FM), jour d'échéance éventuel (« le 10 ») ; 100 %
INSERT INTO account_payment_condition_line (id, version, created_on, payment_condition, sequence, payment_percentage,
  payment_time, period_type_select, type_select, day_select, is_holdback, import_id, import_origin)
SELECT nextval('account_payment_condition_line_seq'), 0, now(), c.id, 1, 100,
  coalesce(gescom.num(t.param1), 0)::int, 1,
  CASE WHEN btrim(t.param2) = 'FM' THEN 2 ELSE 1 END,
  CASE WHEN substr(btrim(t.codtab), 9) ~ '^[0-9]+$' THEN substr(btrim(t.codtab), 9)::int ELSE 0 END,
  false, c.import_id, 'GESCOM'
FROM account_payment_condition c JOIN gescom.table_base t ON c.import_id = 'GESCOM-RGT-' || btrim(t.idtable)
WHERE NOT EXISTS (SELECT 1 FROM account_payment_condition_line l WHERE l.payment_condition = c.id);

CREATE TEMP TABLE mig_condition ON COMMIT DROP AS
SELECT btrim(t.idtable) AS idtable, c.id, (btrim(t.codtab) = 'RGT00DF00') AS comptant
FROM gescom.table_base t JOIN account_payment_condition c ON c.code = btrim(t.codtab)
WHERE btrim(t.codtab) ~ '^RGT';

CREATE TEMP TABLE mig_mode ON COMMIT DROP AS
SELECT btrim(t.idtable) AS idtable,
  (SELECT id FROM account_payment_mode WHERE code = 'ENC_' || m.suffixe) AS encaissement,
  (SELECT id FROM account_payment_mode WHERE code = 'DEC_' || m.suffixe) AS decaissement
FROM gescom.table_base t
CROSS JOIN LATERAL (SELECT CASE btrim(t.codtab) WHEN 'MODRGTVIR' THEN 'VIR' WHEN 'MODRGTCHQ' THEN 'CHQ'
  WHEN 'MODRGTESP' THEN 'ESP' WHEN 'MODRGTCB' THEN 'CB' WHEN 'MODRGTTRT' THEN 'LCR' WHEN 'MODRGTTRD' THEN 'LCR'
  WHEN 'MODRGTBO' THEN 'LCR' ELSE 'OTH' END AS suffixe) m
WHERE btrim(t.codtab) ~ '^MODRGT';
UPDATE mig_mode SET decaissement = (SELECT id FROM account_payment_mode WHERE code = 'DEC_OTH') WHERE decaissement IS NULL;

-- ---------- commerciaux -> utilisateurs (bloqués, mot de passe inutilisable) ----------
INSERT INTO auth_user (id, version, created_on, code, name, password, blocked, force_password_change, email,
  language, active_company, import_id, import_origin)
SELECT nextval('auth_user_seq'), 0, now(), 'com' || c.code, coalesce(gescom.txt(c.nom), 'Commercial ' || c.code),
  'MIGRATION-GESCOM-SANS-MOT-DE-PASSE', true, true,
  CASE WHEN c.rang = 1 AND NOT EXISTS (SELECT 1 FROM auth_user u WHERE lower(u.email) = c.email) THEN c.email END,
  'fr', d.societe, 'GESCOM-COM-' || c.code, 'GESCOM'
FROM (SELECT btrim(code) AS code, nom, lower(gescom.txt(email)) AS email,
             row_number() OVER (PARTITION BY lower(gescom.txt(email)) ORDER BY gescom.num(n_enr)) AS rang
      FROM gescom.commercial WHERE gescom.txt(code) IS NOT NULL) c
CROSS JOIN mig_def d
WHERE NOT EXISTS (SELECT 1 FROM auth_user u WHERE u.import_id = 'GESCOM-COM-' || c.code OR u.code = 'com' || c.code);
CREATE TEMP TABLE mig_commercial ON COMMIT DROP AS
SELECT substr(import_id, 12) AS code, id FROM auth_user WHERE import_id LIKE 'GESCOM-COM-%';

-- ---------- tiers : clés et identifiants ----------
CREATE TEMP TABLE mig_tiers (cle text PRIMARY KEY, genre text, ref text, id bigint, nouveau boolean) ON COMMIT DROP;
INSERT INTO mig_tiers
SELECT 'GESCOM-TRA-' || btrim(idtransporteur), 'TRA', btrim(idtransporteur), NULL::bigint, NULL::boolean
FROM gescom.transporteur WHERE gescom.txt(idtransporteur) IS NOT NULL
UNION ALL
SELECT 'GESCOM-FOU-' || btrim(focleunik), 'FOU', btrim(focleunik), NULL, NULL
FROM gescom.fou WHERE gescom.txt(focleunik) IS NOT NULL
UNION ALL
SELECT 'GESCOM-CLI-' || btrim(clcleunik), 'CLI', btrim(clcleunik), NULL, NULL
FROM gescom.clients WHERE gescom.txt(clcleunik) IS NOT NULL
ON CONFLICT DO NOTHING;
UPDATE mig_tiers m SET id = p.id, nouveau = false FROM base_partner p WHERE p.import_id = m.cle;
UPDATE mig_tiers SET id = nextval('base_partner_seq'), nouveau = true WHERE id IS NULL;

-- code tiers (REFCPT) : unique ; un code déjà pris (client et fournisseur de même code) devient F-<code> / F<n>-<code>
CREATE TEMP TABLE mig_code ON COMMIT DROP AS
SELECT m.cle, x.code, row_number() OVER (PARTITION BY upper(x.code) ORDER BY (m.genre = 'CLI') DESC, m.ref::numeric) AS rang
FROM mig_tiers m
JOIN LATERAL (SELECT gescom.txt(c.refcpt) AS code FROM gescom.clients c WHERE m.genre = 'CLI' AND btrim(c.clcleunik) = m.ref
              UNION ALL
              SELECT gescom.txt(f.refcpt) FROM gescom.fou f WHERE m.genre = 'FOU' AND btrim(f.focleunik) = m.ref) x ON true
WHERE m.nouveau AND x.code IS NOT NULL;
UPDATE mig_code SET code = CASE WHEN rang = 2 THEN 'F-' || code ELSE 'F' || (rang - 1) || '-' || code END WHERE rang > 1;
DELETE FROM mig_code m WHERE EXISTS (SELECT 1 FROM base_partner p WHERE upper(p.partner_seq) = upper(m.code));

-- ---------- e-mails ----------
CREATE TEMP TABLE mig_email (cle text PRIMARY KEY, id bigint, adresse text) ON COMMIT DROP;
INSERT INTO mig_email
SELECT m.cle, nextval('message_email_address_seq'), x.email
FROM mig_tiers m
JOIN LATERAL (SELECT gescom.txt(c.ademail) AS email FROM gescom.clients c WHERE m.genre = 'CLI' AND btrim(c.clcleunik) = m.ref
              UNION ALL SELECT gescom.txt(f.ademail) FROM gescom.fou f WHERE m.genre = 'FOU' AND btrim(f.focleunik) = m.ref
              UNION ALL SELECT gescom.txt(t.email) FROM gescom.transporteur t
                        WHERE m.genre = 'TRA' AND btrim(t.idtransporteur) = m.ref) x ON true
WHERE m.nouveau AND x.email IS NOT NULL;
INSERT INTO message_email_address (id, version, created_on, name, address, import_id, import_origin)
SELECT id, 0, now(), adresse, adresse, 'GESCOM-MAIL-' || substr(cle, 8), 'GESCOM' FROM mig_email;

-- ---------- transporteurs ----------
INSERT INTO base_partner (id, version, created_on, import_id, import_origin, partner_type_select, name, full_name,
  simple_full_name, is_carrier, is_customer, is_supplier, is_contact, is_prospect, is_employee, fixed_phone,
  mobile_phone, email_address, description, currency, localization, archived)
SELECT m.id, 0, now(), m.cle, 'GESCOM', 1, coalesce(gescom.txt(t.nom), gescom.txt(t.code), 'Transporteur ' || m.ref),
  coalesce(gescom.txt(t.nom), gescom.txt(t.code), 'Transporteur ' || m.ref),
  coalesce(gescom.txt(t.nom), gescom.txt(t.code), 'Transporteur ' || m.ref),
  true, false, false, false, false, false, gescom.txt(t.tel), gescom.txt(t.portable), e.id,
  NULLIF(concat_ws(E'\n', 'Contact : ' || gescom.txt(t.contact), 'Fax : ' || gescom.txt(t.fax), gescom.txt(t.obs)), ''),
  d.euro, d.langue, false
FROM mig_tiers m JOIN gescom.transporteur t ON m.genre = 'TRA' AND btrim(t.idtransporteur) = m.ref
LEFT JOIN mig_email e ON e.cle = m.cle CROSS JOIN mig_def d
WHERE m.nouveau;

-- EN_ACTIVITE vaut 0 pour tous les transporteurs GESCOM (champ non utilisé, GXO sert à 557 clients) : jamais archivés
UPDATE base_partner SET archived = false WHERE import_id LIKE 'GESCOM-TRA-%' AND archived;

-- ---------- fournisseurs ----------
INSERT INTO base_partner (id, version, created_on, import_id, import_origin, partner_type_select, partner_seq, name,
  full_name, simple_full_name, is_supplier, is_customer, is_carrier, is_contact, is_prospect, is_employee, fixed_phone,
  mobile_phone, email_address, registration_code, tax_nbr, out_payment_condition, out_payment_mode, description,
  currency, localization, archived)
SELECT m.id, 0, now(), m.cle, 'GESCOM', 1, k.code, coalesce(gescom.txt(f.nom), 'Fournisseur ' || m.ref),
  CASE WHEN k.code IS NULL THEN '' ELSE k.code || ' - ' END || coalesce(gescom.txt(f.nom), 'Fournisseur ' || m.ref),
  coalesce(gescom.txt(f.nom), 'Fournisseur ' || m.ref),
  true, false, false, false, false, false, gescom.txt(f.tel), gescom.txt(f.portable), e.id,
  gescom.txt(f.siret), gescom.txt(f.tvaintra), co.id, mo.decaissement,
  NULLIF(concat_ws(E'\n', 'Contact : ' || gescom.txt(f.contact), 'Contact commercial : ' || gescom.txt(f.contact_cial),
    'Tél. commercial : ' || gescom.txt(f.tel_cial), 'E-mail commercial : ' || gescom.txt(f.email_cial),
    'Fax : ' || gescom.txt(f.fax), gescom.txt(f.notes)), ''),
  CASE WHEN btrim(f.devise_achat) = '66' THEN d.dollar ELSE d.euro END, d.langue, false
FROM mig_tiers m JOIN gescom.fou f ON m.genre = 'FOU' AND btrim(f.focleunik) = m.ref
LEFT JOIN mig_code k ON k.cle = m.cle LEFT JOIN mig_email e ON e.cle = m.cle
LEFT JOIN mig_condition co ON co.idtable = btrim(f.modregt) LEFT JOIN mig_mode mo ON mo.idtable = btrim(f.regl1)
CROSS JOIN mig_def d
WHERE m.nouveau;

-- ---------- clients ----------
INSERT INTO base_partner (id, version, created_on, import_id, import_origin, partner_type_select, partner_seq, name,
  full_name, simple_full_name, is_customer, is_supplier, is_carrier, is_contact, is_prospect, is_employee, fixed_phone,
  mobile_phone, email_address, registration_code, tax_nbr, industry_sector, partner_category, groupement, tauxrfa,
  taux_commission, remise_facture, lvme_client_comptant, payment_condition, in_payment_mode, carrier_partner,
  commercial, user_id, port_paye, code_coditour, delivery_comments, description, currency, localization, archived)
SELECT m.id, 0, now(), m.cle, 'GESCOM', 1, k.code, coalesce(gescom.txt(c.libelle), 'Client ' || m.ref),
  CASE WHEN k.code IS NULL THEN '' ELSE k.code || ' - ' END || coalesce(gescom.txt(c.libelle), 'Client ' || m.ref),
  coalesce(gescom.txt(c.libelle), 'Client ' || m.ref),
  true, false, false, false, false, false, gescom.txt(c.tel), gescom.txt(c.portable), e.id,
  NULLIF(regexp_replace(coalesce(c.siret, ''), '^0+$', ''), ''), gescom.txt(c.tvaintra), se.id, ca.id, gr.id,
  NULLIF(gescom.num(c.rfa), 0), NULLIF(gescom.num(c.pourc_comm), 0), NULLIF(gescom.num(c.remmax), 0),
  coalesce(co.comptant, false), co.id, mo.encaissement, tr.id, cm.id, cm.id, btrim(c.port_paye) = '1',
  (SELECT gescom.txt(x.code_coditour) FROM gescom.clientcoditour x
    WHERE upper(btrim(x.ref_client)) = upper(btrim(c.refcpt)) ORDER BY gescom.num(x.n_enr) LIMIT 1),
  gescom.txt(c.horaire),
  NULLIF(concat_ws(E'\n', 'Fax : ' || gescom.txt(c.fax), gescom.txt(c.notes), 'NAF : ' || gescom.txt(c.code_naf)), ''),
  CASE WHEN btrim(c.dev) = '66' THEN d.dollar ELSE d.euro END, d.langue, btrim(c.retire) = '1'
FROM mig_tiers m JOIN gescom.clients c ON m.genre = 'CLI' AND btrim(c.clcleunik) = m.ref
LEFT JOIN mig_code k ON k.cle = m.cle LEFT JOIN mig_email e ON e.cle = m.cle
LEFT JOIN mig_secteur se ON se.code = btrim(c.secteur)
LEFT JOIN mig_categorie ca ON ca.code = upper(btrim(c.familleclt))
LEFT JOIN mig_groupement gr ON gr.code = upper(btrim(c.group_1))
LEFT JOIN mig_condition co ON co.idtable = btrim(c.modregt)
LEFT JOIN mig_mode mo ON mo.idtable = btrim(c.regl1)
LEFT JOIN mig_tiers tr ON tr.cle = 'GESCOM-TRA-' || btrim(c.transporteur)
LEFT JOIN mig_commercial cm ON cm.code = btrim(c.commercial)
CROSS JOIN mig_def d
WHERE m.nouveau;

-- ---------- contacts (responsable) ----------
CREATE TEMP TABLE mig_contact ON COMMIT DROP AS
SELECT m.id AS client, nextval('base_partner_seq') AS id, gescom.txt(c.nomresp) AS nom, m.cle
FROM mig_tiers m JOIN gescom.clients c ON m.genre = 'CLI' AND btrim(c.clcleunik) = m.ref
WHERE m.nouveau AND gescom.txt(c.nomresp) IS NOT NULL;
INSERT INTO base_partner (id, version, created_on, import_id, import_origin, partner_type_select, name, full_name,
  simple_full_name, is_contact, is_customer, is_supplier, is_carrier, is_prospect, is_employee, main_partner, localization)
SELECT k.id, 0, now(), 'GESCOM-CTC-' || substr(k.cle, 12), 'GESCOM', 2, k.nom, k.nom, k.nom,
  true, false, false, false, false, false, k.client, d.langue
FROM mig_contact k CROSS JOIN mig_def d;
INSERT INTO base_partner_contact_partner_set (base_partner, contact_partner_set) SELECT client, id FROM mig_contact;

-- ---------- adresses (principale + livraison) ----------
CREATE TEMP TABLE mig_adresse ON COMMIT DROP AS
SELECT m.id AS tiers, x.l2, x.l4, x.l5, x.cp, x.ville, coalesce(pa.id, d.france) AS pays, x.cle, x.livraison_seule
FROM mig_tiers m
JOIN LATERAL (
  SELECT NULL::text AS l2, gescom.txt(c.adr1) AS l4, NULLIF(concat_ws(' ', gescom.txt(c.adr2), gescom.txt(c.adr3)), '') AS l5,
         gescom.txt(c.codp) AS cp, gescom.txt(c.ville) AS ville, upper(btrim(c.codpay)) AS codpay,
         'GESCOM-ADR-' || substr(m.cle, 8) AS cle, false AS livraison_seule
  FROM gescom.clients c WHERE m.genre = 'CLI' AND btrim(c.clcleunik) = m.ref
  UNION ALL
  SELECT NULL, gescom.txt(f.adr1), gescom.txt(f.adr2), gescom.txt(f.codp), gescom.txt(f.vil), upper(btrim(f.pays)),
         'GESCOM-ADR-' || substr(m.cle, 8), false
  FROM gescom.fou f WHERE m.genre = 'FOU' AND btrim(f.focleunik) = m.ref
  UNION ALL
  SELECT NULL, gescom.txt(t.adr1), NULLIF(concat_ws(' ', gescom.txt(t.adr2), gescom.txt(t.adr3)), ''),
         gescom.txt(t.code_postal), gescom.txt(t.ville), 'FR', 'GESCOM-ADR-' || substr(m.cle, 8), false
  FROM gescom.transporteur t WHERE m.genre = 'TRA' AND btrim(t.idtransporteur) = m.ref
  UNION ALL
  SELECT gescom.txt(a.libelle), gescom.txt(a.adr1), NULLIF(concat_ws(' ', gescom.txt(a.adr2), gescom.txt(a.adr3)), ''),
         gescom.txt(a.codp), gescom.txt(a.ville), upper(btrim(a.codpay)), 'GESCOM-ADRL-' || btrim(a.c1cleunik), true
  FROM gescom.clientad a WHERE m.genre = 'CLI' AND btrim(a.clcleunik) = m.ref) x ON true
LEFT JOIN mig_pays pa ON pa.code = x.codpay
CROSS JOIN mig_def d
WHERE m.nouveau AND (x.l4 IS NOT NULL OR x.l5 IS NOT NULL OR x.cp IS NOT NULL OR x.ville IS NOT NULL);
ALTER TABLE mig_adresse ADD COLUMN id bigint;
UPDATE mig_adresse SET id = nextval('base_address_seq');

INSERT INTO base_address (id, version, created_on, import_id, import_origin, addressl2, addressl4, addressl5, addressl6,
  zip, town_name, country, full_name, formatted_full_name)
SELECT a.id, 0, now(), a.cle, 'GESCOM', a.l2, a.l4, a.l5, NULLIF(concat_ws(' ', a.cp, a.ville), ''), a.cp, a.ville, a.pays,
  concat_ws(' ', a.l2, a.l4, a.l5, a.cp, a.ville),
  concat_ws(E'\n', a.l2, a.l4, a.l5, NULLIF(concat_ws(' ', a.cp, a.ville), ''), (SELECT name FROM base_country WHERE id = a.pays))
FROM mig_adresse a;

INSERT INTO base_partner_address (id, version, created_on, partner, address, is_default_addr, is_invoicing_addr,
  is_delivery_addr, is_business_addr, is_other_addr, import_id, import_origin)
SELECT nextval('base_partner_address_seq'), 0, now(), a.tiers, a.id, NOT a.livraison_seule, NOT a.livraison_seule, true,
  false, false, a.cle, 'GESCOM'
FROM mig_adresse a;
UPDATE base_partner p SET main_address = a.id FROM mig_adresse a WHERE a.tiers = p.id AND NOT a.livraison_seule;

-- ---------- villes : la liste Axelor des villes est complétée et reliée aux adresses GESCOM (listes Clients /
-- Fournisseurs, recherche par ville, impressions) ----------
CREATE TEMP TABLE mig_ville ON COMMIT DROP AS
SELECT DISTINCT ON (upper(btrim(a.town_name)), coalesce(btrim(a.zip), ''), a.country)
  upper(btrim(a.town_name)) AS nom, btrim(a.zip) AS cp, a.country,
  (SELECT c.id FROM base_city c WHERE upper(btrim(c.name)) = upper(btrim(a.town_name)) AND c.country = a.country
     AND (c.zip IS NULL OR c.zip = btrim(a.zip)) ORDER BY (c.zip = btrim(a.zip)) DESC NULLS LAST, c.id LIMIT 1) AS id
FROM base_address a
WHERE a.import_origin = 'GESCOM' AND a.city IS NULL AND gescom.txt(a.town_name) IS NOT NULL;
UPDATE mig_ville SET id = nextval('base_city_seq') WHERE id IS NULL AND NOT EXISTS (SELECT 1 FROM base_city c WHERE c.id = mig_ville.id);
INSERT INTO base_city (id, version, created_on, name, zip, country, full_name, import_id, import_origin)
SELECT v.id, 0, now(), v.nom, NULLIF(v.cp, ''), v.country, concat_ws(' ', NULLIF(v.cp, ''), v.nom),
  'GESCOM-VILLE-' || v.id, 'GESCOM'
FROM mig_ville v WHERE NOT EXISTS (SELECT 1 FROM base_city c WHERE c.id = v.id);
UPDATE base_address a SET city = v.id
FROM mig_ville v
WHERE a.import_origin = 'GESCOM' AND a.city IS NULL AND upper(btrim(a.town_name)) = v.nom
  AND coalesce(btrim(a.zip), '') = coalesce(v.cp, '') AND a.country = v.country;

-- ---------- contacts des fournisseurs (CONTACT, CONTACT_CIAL) ----------
CREATE TEMP TABLE mig_contact_fou ON COMMIT DROP AS
SELECT t.id AS fournisseur, x.nom, x.cle, x.tel, x.portable, x.email, nextval('base_partner_seq') AS id
FROM mig_tiers t JOIN gescom.fou f ON t.genre = 'FOU' AND btrim(f.focleunik) = t.ref
JOIN LATERAL (SELECT gescom.txt(f.contact) AS nom, 'GESCOM-CTF-' || t.ref AS cle, gescom.txt(f.tel) AS tel,
                     gescom.txt(f.portable) AS portable, NULL::text AS email
              UNION ALL
              SELECT gescom.txt(f.contact_cial), 'GESCOM-CTFC-' || t.ref, gescom.txt(f.tel_cial),
                     gescom.txt(f.portable_cial), gescom.txt(f.email_cial)) x ON x.nom IS NOT NULL
WHERE NOT EXISTS (SELECT 1 FROM base_partner p WHERE p.import_id = x.cle);
INSERT INTO base_partner (id, version, created_on, import_id, import_origin, partner_type_select, name, full_name,
  simple_full_name, is_contact, is_customer, is_supplier, is_carrier, is_prospect, is_employee, main_partner,
  fixed_phone, mobile_phone, localization)
SELECT k.id, 0, now(), k.cle, 'GESCOM', 2, k.nom, k.nom, k.nom, true, false, false, false, false, false, k.fournisseur,
  k.tel, k.portable, d.langue
FROM mig_contact_fou k CROSS JOIN mig_def d;
INSERT INTO base_partner_contact_partner_set (base_partner, contact_partner_set) SELECT fournisseur, id FROM mig_contact_fou;

-- ---------- société et comptes client / fournisseur ----------
INSERT INTO base_partner_company_set (base_partner, company_set)
SELECT m.id, d.societe FROM mig_tiers m CROSS JOIN mig_def d WHERE m.nouveau AND d.societe IS NOT NULL;
INSERT INTO account_accounting_situation (id, version, created_on, partner, company, customer_account, supplier_account,
  import_id, import_origin)
SELECT nextval('account_accounting_situation_seq'), 0, now(), m.id, d.societe,
  CASE WHEN m.genre = 'CLI' THEN d.compte_client END, CASE WHEN m.genre = 'FOU' THEN d.compte_fournisseur END,
  m.cle, 'GESCOM'
FROM mig_tiers m CROSS JOIN mig_def d WHERE m.nouveau AND m.genre IN ('CLI', 'FOU') AND d.societe IS NOT NULL;

-- ---------- fournisseur habituel des articles ----------
UPDATE base_product p SET default_supplier_partner = t.id
FROM gescom.articles a JOIN mig_tiers t ON t.cle = 'GESCOM-FOU-' || btrim(split_part(a.focleunik, ',', 1))
WHERE p.import_id = 'GESCOM-ART-' || btrim(a.arcleunik) AND p.default_supplier_partner IS NULL;

COMMIT;

-- ---------- contrôle ----------
SELECT (SELECT count(*) FROM gescom.clients) AS clients_gescom,
       (SELECT count(*) FROM base_partner WHERE import_id LIKE 'GESCOM-CLI-%') AS clients_axelor,
       (SELECT count(*) FROM gescom.fou) AS fournisseurs_gescom,
       (SELECT count(*) FROM base_partner WHERE import_id LIKE 'GESCOM-FOU-%') AS fournisseurs_axelor,
       (SELECT count(*) FROM gescom.transporteur) AS transporteurs_gescom,
       (SELECT count(*) FROM base_partner WHERE import_id LIKE 'GESCOM-TRA-%') AS transporteurs_axelor,
       (SELECT count(*) FROM base_partner WHERE import_id LIKE 'GESCOM-CTC-%') AS contacts,
       (SELECT count(*) FROM base_partner WHERE import_id LIKE 'GESCOM-CTF%') AS contacts_fournisseurs,
       (SELECT count(*) FROM base_address WHERE import_origin = 'GESCOM' AND town_name IS NOT NULL AND city IS NULL)
         AS adresses_sans_ville,
       (SELECT count(*) FROM base_partner_address WHERE import_id LIKE 'GESCOM-ADRL-%') AS adresses_livraison,
       (SELECT count(*) FROM base_partner WHERE import_id LIKE 'GESCOM-CLI-%' AND lvme_client_comptant) AS clients_comptant,
       (SELECT count(*) FROM auth_user WHERE import_id LIKE 'GESCOM-COM-%') AS commerciaux,
       (SELECT count(*) FROM base_product WHERE import_origin = 'GESCOM' AND default_supplier_partner IS NOT NULL)
         AS articles_avec_fournisseur;

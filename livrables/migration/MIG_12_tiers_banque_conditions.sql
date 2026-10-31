-- =====================================================================
-- MIG_12 : coordonnées bancaires et conditions des clients GESCOM (CLIENTS, FOU), restées dans l'archive à MIG_02
--   - coordonnées bancaires Axelor (base_bank_details) : IBAN de GESCOM, sinon IBAN calculé depuis le RIB français à
--     23 chiffres (clé IBAN calculée, FR76…) ; banque Axelor (base_bank) par BIC : BIC de GESCOM, sinon BIC d'un autre
--     client de la même banque (5 premiers chiffres du RIB), sinon banque « BIC A COMPLETER (GESCOM) » ;
--   - client payeur (CLIENTPAYEUR), plafond de crédit (pour information : aucun blocage des commandes), mode de
--     facturation (TYPE_BL), périodicité de facturation, relevé de factures (RANG_TOURNEE), tarif, GROUP_2 ;
--     code 0 = non renseigné.
--   RIB « 000… », RIB qui ne font pas 23 chiffres, et IBAN invalides : non repris (restent dans l'archive, comptés
--   par le contrôle).
-- Prérequis : MIG_00, MIG_02 (tiers). Colonnes LVME créées si besoin (avant le premier démarrage du code).
-- Tomcat arrêté. Relançable.
-- =====================================================================
BEGIN;

ALTER TABLE base_partner
  ADD COLUMN IF NOT EXISTS lvme_client_payeur bigint,
  ADD COLUMN IF NOT EXISTS lvme_plafond_credit numeric(20, 2),
  ADD COLUMN IF NOT EXISTS lvme_mode_facturation varchar(255),
  ADD COLUMN IF NOT EXISTS lvme_periodicite_facturation varchar(255),
  ADD COLUMN IF NOT EXISTS lvme_releve_factures varchar(255),
  ADD COLUMN IF NOT EXISTS lvme_tarif varchar(255),
  ADD COLUMN IF NOT EXISTS lvme_groupe2 varchar(255);

-- ---------- listes de choix (libellés de TABLE_BASE) ----------
CREATE TEMP TABLE mig_liste (liste text, valeur text, titre text, ordre int) ON COMMIT DROP;
INSERT INTO mig_liste VALUES
  ('lvme.partner.mode.facturation.select', 'FI', 'Facture immédiate', 1),
  ('lvme.partner.mode.facturation.select', 'CH', 'BL chiffré', 2),
  ('lvme.partner.mode.facturation.select', 'OH', 'BL obligatoire - chiffré', 3),
  ('lvme.partner.periodicite.facturation.select', 'M', 'Fin de mois', 1),
  ('lvme.partner.periodicite.facturation.select', 'Z', 'À la demande', 2),
  ('lvme.partner.periodicite.facturation.select', 'F', 'Affacturage', 3),
  ('lvme.partner.releve.factures.select', 'PAS', 'Pas de relevé', 1),
  ('lvme.partner.releve.factures.select', 'MOI', 'Au mois', 2),
  ('lvme.partner.releve.factures.select', 'DEM', 'À la demande', 3),
  ('lvme.partner.tarif.select', 'PP', 'Prix public', 1),
  ('lvme.partner.tarif.select', 'PR', 'Prix de revient', 2);
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, l.liste, 0, true FROM (SELECT DISTINCT liste FROM mig_liste) l
WHERE NOT EXISTS (SELECT 1 FROM meta_select s WHERE s.name = l.liste);
DELETE FROM meta_select_item WHERE select_id IN (SELECT id FROM meta_select WHERE name IN (SELECT liste FROM mig_liste));
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, (SELECT id FROM meta_select WHERE name = l.liste), l.valeur, l.titre, l.ordre
FROM mig_liste l;

-- ---------- conditions des clients ----------
CREATE TEMP TABLE mig_cli ON COMMIT DROP AS
SELECT p.id, c.*
FROM gescom.clients c JOIN base_partner p ON p.import_id = 'GESCOM-CLI-' || btrim(c.clcleunik);
CREATE INDEX ON mig_cli (clcleunik);

UPDATE base_partner p SET
  lvme_client_payeur = (SELECT y.id FROM mig_cli y WHERE btrim(y.clcleunik) = btrim(c.clientpayeur)
                        AND y.id <> p.id LIMIT 1),
  lvme_plafond_credit = NULLIF(gescom.num(c.plafond_credit), 0),
  lvme_mode_facturation = CASE btrim(c.type_bl) WHEN '106' THEN 'FI' WHEN '60' THEN 'CH' WHEN '155' THEN 'OH' END,
  lvme_periodicite_facturation = CASE btrim(c.periodicite_fact) WHEN '71' THEN 'M' WHEN '73' THEN 'Z' WHEN '89' THEN 'F' END,
  lvme_releve_factures = CASE btrim(c.rang_tournee) WHEN '100' THEN 'PAS' WHEN '103' THEN 'MOI' WHEN '104' THEN 'DEM' END,
  lvme_tarif = CASE btrim(c.tarif) WHEN '62' THEN 'PP' WHEN '121' THEN 'PR' END,
  lvme_groupe2 = NULLIF(gescom.txt(c.group_2), '000'),
  version = p.version + 1, updated_on = now()
FROM mig_cli c WHERE c.id = p.id;

-- ---------- coordonnées bancaires ----------
-- IBAN ou RIB nettoyés, clients puis fournisseurs
CREATE TEMP TABLE mig_rib ON COMMIT DROP AS
SELECT p.id AS partner, p.name AS nom, upper(regexp_replace(coalesce(c.iban, ''), '\s', '', 'g')) AS iban,
  upper(regexp_replace(coalesce(c.bic, ''), '\s', '', 'g')) AS bic, regexp_replace(coalesce(c.rib, ''), '\D', '', 'g') AS rib,
  gescom.txt(c.dom_banq) AS domiciliation
FROM gescom.clients c JOIN base_partner p ON p.import_id = 'GESCOM-CLI-' || btrim(c.clcleunik)
UNION ALL
SELECT p.id, p.name, upper(regexp_replace(coalesce(f.iban, ''), '\s', '', 'g')), upper(regexp_replace(coalesce(f.bic, ''), '\s', '', 'g')),
  regexp_replace(coalesce(f.rib, ''), '\D', '', 'g'), gescom.txt(f.dom_banq)
FROM gescom.fou f JOIN base_partner p ON p.import_id = 'GESCOM-FOU-' || btrim(f.focleunik);

-- IBAN retenu : celui de GESCOM s'il a la forme d'un IBAN, sinon calculé depuis un RIB français de 23 chiffres
-- (clé = 98 - (RIB + « FR00 » converti en chiffres) mod 97)
CREATE TEMP TABLE mig_iban ON COMMIT DROP AS
SELECT r.*, CASE
    WHEN r.iban ~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}$' THEN r.iban
    WHEN r.rib ~ '^[0-9]{23}$' AND r.rib !~ '^0+$'
      THEN 'FR' || lpad((98 - mod((r.rib || '152700')::numeric, 97))::int::text, 2, '0') || r.rib
  END AS iban_final
FROM mig_rib r;
DELETE FROM mig_iban WHERE iban_final IS NULL;

-- BIC par code banque (caractères 5 à 9 de l'IBAN français), d'après les clients qui ont IBAN et BIC
CREATE TEMP TABLE mig_bic ON COMMIT DROP AS
SELECT DISTINCT ON (substr(iban_final, 5, 5)) substr(iban_final, 5, 5) AS code_banque, bic
FROM mig_iban WHERE bic ~ '^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$' AND iban_final LIKE 'FR%'
GROUP BY substr(iban_final, 5, 5), bic ORDER BY substr(iban_final, 5, 5), count(*) DESC;

UPDATE mig_iban i SET bic = coalesce(
  CASE WHEN i.bic ~ '^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$' THEN i.bic END,
  (SELECT b.bic FROM mig_bic b WHERE i.iban_final LIKE 'FR%' AND b.code_banque = substr(i.iban_final, 5, 5)),
  'XXXXFRXX');

-- banques Axelor : une par BIC (nom = domiciliation la plus fréquente)
INSERT INTO base_bank (id, version, created_on, import_id, import_origin, code, bank_name, bank_details_type_select,
  business_party_prefix, business_party_suffix, branch_identifier, country, full_name)
SELECT nextval('base_bank_seq'), 0, now(), 'GESCOM-BANQUE-' || x.bic, 'GESCOM', x.bic, x.nom, 1,
  substr(x.bic, 1, 4), substr(x.bic, 7, 2), coalesce(NULLIF(substr(x.bic, 9, 3), ''), 'XXX'),
  (SELECT id FROM base_country WHERE alpha2code = substr(x.bic, 5, 2) LIMIT 1), x.bic || ' - ' || x.nom
FROM (SELECT bic, CASE WHEN bic = 'XXXXFRXX' THEN 'BIC A COMPLETER (GESCOM)'
             ELSE coalesce(mode() WITHIN GROUP (ORDER BY domiciliation), bic) END AS nom
      FROM mig_iban GROUP BY bic) x
WHERE NOT EXISTS (SELECT 1 FROM base_bank b WHERE b.import_id = 'GESCOM-BANQUE-' || x.bic);

-- coordonnées bancaires : une par tiers (relançable)
DELETE FROM base_bank_details WHERE import_id LIKE 'GESCOM-RIB-%';
INSERT INTO base_bank_details (id, version, created_on, import_id, import_origin, partner, bank, iban, bank_code, sort_code,
  account_nbr, bban_key, iban_bic, owner_name, label, active, is_default, full_name)
SELECT DISTINCT ON (i.partner) nextval('base_bank_details_seq'), 0, now(), 'GESCOM-RIB-' || i.partner, 'GESCOM', i.partner,
  b.id, i.iban_final,
  CASE WHEN i.iban_final LIKE 'FR%' THEN substr(i.iban_final, 5, 5) END,
  CASE WHEN i.iban_final LIKE 'FR%' THEN substr(i.iban_final, 10, 5) END,
  CASE WHEN i.iban_final LIKE 'FR%' THEN substr(i.iban_final, 15, 11) END,
  CASE WHEN i.iban_final LIKE 'FR%' THEN substr(i.iban_final, 26, 2) END,
  i.iban_final || ' ' || i.bic, i.nom, i.domiciliation, true, true,
  coalesce(i.domiciliation || ' - ', '') || i.iban_final || ' - ' || b.full_name
FROM mig_iban i JOIN base_bank b ON b.import_id = 'GESCOM-BANQUE-' || i.bic
ORDER BY i.partner;

ANALYZE base_bank_details;

COMMIT;

-- contrôles
SELECT (SELECT count(*) FROM base_bank_details WHERE import_id LIKE 'GESCOM-RIB-%') AS coordonnees_bancaires,
  (SELECT count(*) FROM base_bank_details d JOIN base_bank b ON b.id = d.bank
   WHERE d.import_id LIKE 'GESCOM-RIB-%' AND b.code = 'XXXXFRXX') AS bic_a_completer,
  (SELECT count(*) FROM base_bank WHERE import_id LIKE 'GESCOM-BANQUE-%') AS banques,
  (SELECT count(*) FROM base_partner WHERE lvme_client_payeur IS NOT NULL) AS clients_payeur,
  (SELECT count(*) FROM base_partner WHERE lvme_plafond_credit IS NOT NULL) AS plafonds,
  (SELECT count(*) FROM base_partner WHERE lvme_mode_facturation IS NOT NULL) AS mode_facturation;
-- RIB / IBAN de GESCOM non repris (renseignés mais ni IBAN valide, ni RIB de 23 chiffres)
SELECT count(*) AS rib_non_repris FROM gescom.clients c
WHERE (nullif(btrim(c.rib), '') IS NOT NULL AND regexp_replace(c.rib, '\D', '', 'g') !~ '^0+$'
       AND regexp_replace(c.rib, '\D', '', 'g') !~ '^[0-9]{23}$')
  AND upper(regexp_replace(coalesce(c.iban, ''), '\s', '', 'g')) !~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}$';

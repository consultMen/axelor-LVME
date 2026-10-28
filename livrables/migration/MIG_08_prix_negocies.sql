-- =====================================================================
-- MIGRATION GESCOM — étape 08 : prix négociés (PRIX_NEGOC, PRIX_NEGOCE_COUT)
--   Source : archive gescom.prix_negoc, gescom.prix_negoce_cout (MIG_00). Prérequis : MIG_01 (articles), MIG_02
--   (clients). Décision du 28/10/2026 : table et écran « Prix négociés » (le prix n'est pas encore proposé sur la
--   ligne de commande client).
--   - PRIX_NEGOC : une ligne par client, article et période étudiée : ventes de la période (colis, quantité, poids,
--     CA, dernière vente, dernier prix, rang au palmarès, dernier conditionnement), prix négocié et sa période ;
--   - PRIX_NEGOCE_COUT : éléments de coût (RFA, commission, congélation, port, remise) par client, article et période
--     de validité du prix négocié, rattachés à la ligne du même client, article et période ; coût sans prix négocié
--     correspondant : ligne à part (rien n'est perdu).
--   Client / article retrouvés par leur code GESCOM. Table lvme_prix_negocie (modèle PrixNegocie) créée ici si le
--   serveur ne l'a pas encore créée. Relançable.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

CREATE TABLE IF NOT EXISTS lvme_prix_negocie (
  id bigint PRIMARY KEY, version integer, archived boolean, import_id varchar(255) UNIQUE, import_origin varchar(255),
  process_instance_id varchar(255), attrs jsonb, created_on timestamp, updated_on timestamp, created_by bigint,
  updated_by bigint, client bigint REFERENCES base_partner (id), product bigint REFERENCES base_product (id),
  designation varchar(255), date_deb_stats date, date_fin_stats date, nb_colis numeric(20,3), qtes_uv numeric(20,3),
  unite varchar(255), poids_kg numeric(20,3), montant_ht numeric(20,2), dern_date_vente date,
  dern_prix_vente numeric(20,4), dern_prix_kg numeric(20,4), rang_palmares integer, dern_conditionnement varchar(255),
  prix_negocie numeric(20,4), date_deb_neg date, date_fin_neg date, pourc_rfa numeric(10,2), pourc_comm numeric(10,2),
  frais_congel numeric(10,4), cout_port_kg numeric(10,4), remise numeric(10,2));
CREATE SEQUENCE IF NOT EXISTS lvme_prix_negocie_seq INCREMENT BY 1;
CREATE INDEX IF NOT EXISTS lvme_prix_negocie_client_idx ON lvme_prix_negocie (client);
CREATE INDEX IF NOT EXISTS lvme_prix_negocie_product_idx ON lvme_prix_negocie (product);

CREATE TEMP TABLE mig_client ON COMMIT DROP AS
SELECT DISTINCT ON (upper(partner_seq)) upper(partner_seq) AS code, id FROM base_partner
WHERE is_customer AND partner_seq IS NOT NULL ORDER BY upper(partner_seq), (import_origin = 'GESCOM') DESC, id;
CREATE TEMP TABLE mig_article ON COMMIT DROP AS
SELECT DISTINCT ON (upper(code)) upper(code) AS code, id, name FROM base_product
WHERE code IS NOT NULL ORDER BY upper(code), (import_origin = 'GESCOM') DESC, id;

-- coûts (PRIX_NEGOCE_COUT) : même client, article et période de validité du prix négocié
CREATE TEMP TABLE mig_cout ON COMMIT DROP AS
SELECT btrim(c.idprix_negoce_cout) AS cle, upper(btrim(c.client)) AS client, upper(btrim(c.produit)) AS produit,
  gescom.dt(c.date_deb) AS debut, gescom.dt(c.date_fin) AS fin, gescom.txt(c.des_art) AS designation,
  gescom.num(c.rfa) AS rfa, gescom.num(c.comm) AS comm, gescom.num(c.congel) AS congel,
  gescom.num(c.cout_port) AS port, gescom.num(c.remmax) AS remise
FROM gescom.prix_negoce_cout c WHERE gescom.txt(c.idprix_negoce_cout) IS NOT NULL;

CREATE TEMP TABLE mig_prix ON COMMIT DROP AS
SELECT btrim(n.idprix_negoce) AS cle, cl.id AS client, ar.id AS article,
  coalesce(gescom.txt(n.des_art), ar.name) AS designation,
  gescom.dt(n.date_deb) AS deb_stats, gescom.dt(n.date_fin) AS fin_stats,
  gescom.num(n.nb_colis) AS colis, gescom.num(n.qtes_uv) AS qtes, gescom.txt(n.unite) AS unite,
  gescom.num(n.pds_kg) AS poids, gescom.num(n.mt_vte_ht) AS montant, gescom.dt(n.dern_dat_vte) AS dern_date,
  gescom.num(n.dern_prix_vte) AS dern_prix, gescom.num(n.dern_prix_kg) AS dern_prix_kg,
  gescom.num(n.rang_palm)::integer AS rang, gescom.txt(n.dern_condit) AS dern_condit,
  NULLIF(gescom.num(n.prix_negocie), 0) AS prix, gescom.dt(n.date_deb_neg) AS deb_neg, gescom.dt(n.date_fin_neg) AS fin_neg,
  (SELECT c.cle FROM mig_cout c WHERE c.client = upper(btrim(n.client)) AND c.produit = upper(btrim(n.produit))
     AND c.debut IS NOT DISTINCT FROM gescom.dt(n.date_deb_neg) AND c.fin IS NOT DISTINCT FROM gescom.dt(n.date_fin_neg)
   ORDER BY c.cle LIMIT 1) AS cout
FROM gescom.prix_negoc n
LEFT JOIN mig_client cl ON cl.code = upper(btrim(n.client))
LEFT JOIN mig_article ar ON ar.code = upper(btrim(n.produit))
WHERE gescom.txt(n.idprix_negoce) IS NOT NULL;

INSERT INTO lvme_prix_negocie (id, version, created_on, import_id, import_origin, client, product, designation,
  date_deb_stats, date_fin_stats, nb_colis, qtes_uv, unite, poids_kg, montant_ht, dern_date_vente, dern_prix_vente,
  dern_prix_kg, rang_palmares, dern_conditionnement, prix_negocie, date_deb_neg, date_fin_neg, pourc_rfa, pourc_comm,
  frais_congel, cout_port_kg, remise)
SELECT nextval('lvme_prix_negocie_seq'), 0, now(), 'GESCOM-PNEG-' || p.cle, 'GESCOM', p.client, p.article, p.designation,
  p.deb_stats, p.fin_stats, p.colis, p.qtes, p.unite, p.poids, p.montant, p.dern_date, p.dern_prix, p.dern_prix_kg,
  p.rang, p.dern_condit, p.prix, p.deb_neg, p.fin_neg, c.rfa, c.comm, c.congel, c.port, c.remise
FROM mig_prix p LEFT JOIN mig_cout c ON c.cle = p.cout
WHERE p.client IS NOT NULL AND p.article IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM lvme_prix_negocie x WHERE x.import_id = 'GESCOM-PNEG-' || p.cle);

-- coûts sans prix négocié correspondant : une ligne à part (client, article, période de validité, coûts)
INSERT INTO lvme_prix_negocie (id, version, created_on, import_id, import_origin, client, product, designation,
  date_deb_neg, date_fin_neg, pourc_rfa, pourc_comm, frais_congel, cout_port_kg, remise)
SELECT nextval('lvme_prix_negocie_seq'), 0, now(), 'GESCOM-PNEGC-' || c.cle, 'GESCOM', cl.id, ar.id,
  coalesce(c.designation, ar.name), c.debut, c.fin, c.rfa, c.comm, c.congel, c.port, c.remise
FROM mig_cout c
JOIN mig_client cl ON cl.code = c.client
JOIN mig_article ar ON ar.code = c.produit
WHERE NOT EXISTS (SELECT 1 FROM mig_prix p WHERE p.cout = c.cle AND p.client IS NOT NULL AND p.article IS NOT NULL)
  AND NOT EXISTS (SELECT 1 FROM lvme_prix_negocie x WHERE x.import_id = 'GESCOM-PNEGC-' || c.cle);

-- lignes non reprises (client ou article introuvable)
SELECT 'PRIX_NEGOC' AS fichier, n.idprix_negoce AS cle, n.client, n.produit
FROM gescom.prix_negoc n
WHERE NOT EXISTS (SELECT 1 FROM mig_client cl WHERE cl.code = upper(btrim(n.client)))
   OR NOT EXISTS (SELECT 1 FROM mig_article ar WHERE ar.code = upper(btrim(n.produit)))
UNION ALL
SELECT 'PRIX_NEGOCE_COUT', c.cle, c.client, c.produit
FROM mig_cout c
WHERE NOT EXISTS (SELECT 1 FROM mig_client cl WHERE cl.code = c.client)
   OR NOT EXISTS (SELECT 1 FROM mig_article ar WHERE ar.code = c.produit);

COMMIT;

-- ---------- contrôle ----------
SELECT (SELECT count(*) FROM gescom.prix_negoc) AS prix_gescom,
       (SELECT count(*) FROM lvme_prix_negocie WHERE import_id LIKE 'GESCOM-PNEG-%') AS prix_axelor,
       (SELECT count(*) FROM lvme_prix_negocie WHERE import_id LIKE 'GESCOM-PNEG-%' AND prix_negocie IS NOT NULL)
         AS avec_prix_negocie,
       (SELECT count(*) FROM gescom.prix_negoce_cout) AS couts_gescom,
       (SELECT count(*) FROM lvme_prix_negocie WHERE import_id LIKE 'GESCOM-PNEG%'
          AND coalesce(pourc_rfa, pourc_comm, frais_congel, cout_port_kg, remise) IS NOT NULL) AS lignes_avec_couts,
       (SELECT count(*) FROM lvme_prix_negocie WHERE import_id LIKE 'GESCOM-PNEGC-%') AS couts_a_part;

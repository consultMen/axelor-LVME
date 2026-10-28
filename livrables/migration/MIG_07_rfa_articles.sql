-- =====================================================================
-- MIGRATION GESCOM — étape 07 : règles de RFA par produit (RFA_ART)
--   Source : archive gescom.rfa_art (MIG_00). Prérequis : MIG_01 (articles, familles), MIG_02 (clients, groupements).
--   Une règle = % de RFA accordé à un client (TYPE_REMCLT C) ou à un groupement (G), sur un article (TYPE_REMART A)
--   ou une famille d'articles (F), du DAT_DEB au DAT_FIN. Écran « Règles RFA par produit » (PROD_95) ; sert à la
--   liste des RFA par produit / facture. Client / groupement / article / famille retrouvés par leur code GESCOM ;
--   règle dont la cible est introuvable : non reprise, listée au contrôle. Relançable.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE mig_rfa ON COMMIT DROP AS
SELECT btrim(r.idrfa_art) AS cle, upper(btrim(r.type_remclt)) AS type_clt, upper(btrim(r.type_remart)) AS type_art,
  btrim(r.clt_group) AS code_clt, btrim(r.art_famart) AS code_art,
  gescom.dt(r.dat_deb) AS debut, gescom.dt(r.dat_fin) AS fin, coalesce(gescom.num(r.p_rfa), 0) AS pourc,
  CASE WHEN upper(btrim(r.type_remclt)) = 'C' THEN
    (SELECT p.id FROM base_partner p WHERE upper(p.partner_seq) = upper(btrim(r.clt_group)) AND p.is_customer
     ORDER BY (p.import_origin = 'GESCOM') DESC, p.id LIMIT 1) END AS client,
  CASE WHEN upper(btrim(r.type_remclt)) = 'G' THEN
    (SELECT g.id FROM sale_groupement g WHERE upper(g.code) = upper(btrim(r.clt_group)) ORDER BY g.id LIMIT 1) END
    AS groupement,
  CASE WHEN upper(btrim(r.type_remart)) = 'A' THEN
    (SELECT p.id FROM base_product p WHERE upper(p.code) = upper(btrim(r.art_famart))
     ORDER BY (p.import_origin = 'GESCOM') DESC, p.id LIMIT 1) END AS article,
  CASE WHEN upper(btrim(r.type_remart)) = 'F' THEN
    (SELECT f.id FROM base_product_category f WHERE upper(f.code) = upper(btrim(r.art_famart)) ORDER BY f.id LIMIT 1) END
    AS famille
FROM gescom.rfa_art r
WHERE gescom.txt(r.idrfa_art) IS NOT NULL;

INSERT INTO supplychain_rfa_article (id, version, created_on, import_id, import_origin, type_client, client, groupement,
  type_article, product, famille, date_debut, date_fin, pourc_rfa)
SELECT nextval('supplychain_rfa_article_seq'), 0, now(), 'GESCOM-RFA-' || m.cle, 'GESCOM',
  CASE WHEN m.type_clt = 'G' THEN 2 ELSE 1 END, m.client, m.groupement,
  CASE WHEN m.type_art = 'F' THEN 2 ELSE 1 END, m.article, m.famille, m.debut, m.fin, m.pourc
FROM mig_rfa m
WHERE coalesce(m.client, m.groupement) IS NOT NULL AND coalesce(m.article, m.famille) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM supplychain_rfa_article x WHERE x.import_id = 'GESCOM-RFA-' || m.cle);

-- règles non reprises (client / groupement ou article / famille introuvable)
SELECT cle AS rfa_non_reprise, type_clt, code_clt, type_art, code_art, pourc
FROM mig_rfa
WHERE coalesce(client, groupement) IS NULL OR coalesce(article, famille) IS NULL;

COMMIT;

-- ---------- contrôle ----------
SELECT (SELECT count(*) FROM gescom.rfa_art) AS rfa_gescom,
       (SELECT count(*) FROM supplychain_rfa_article WHERE import_id LIKE 'GESCOM-RFA-%') AS rfa_axelor;
SELECT coalesce(c.partner_seq, g.code) AS client_ou_groupement, count(*) AS regles,
       min(r.date_debut) AS du, max(r.date_fin) AS au, min(r.pourc_rfa) AS pourc_min, max(r.pourc_rfa) AS pourc_max
FROM supplychain_rfa_article r
LEFT JOIN base_partner c ON c.id = r.client
LEFT JOIN sale_groupement g ON g.id = r.groupement
WHERE r.import_id LIKE 'GESCOM-RFA-%'
GROUP BY 1 ORDER BY 1;

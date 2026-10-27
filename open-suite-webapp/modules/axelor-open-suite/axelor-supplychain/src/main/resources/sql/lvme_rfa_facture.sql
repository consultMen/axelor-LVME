-- =====================================================================
-- LVME : règles RFA par produit (modèle RfaArticle, table supplychain_rfa_article) et vue lvme_rfa_facture (modèle
-- RfaFacture) de l'écran « Liste des RFA par produit / facture » de GESCOM.
-- Une ligne par ligne de facture client validée (factures et avoirs, avoirs en négatif) qui a une règle de RFA :
--   - règle du client avant celle de son groupement, sur l'article avant celle sur sa famille ;
--   - règle valable à la date de la facture (du / au vides = toujours) ;
--   - montant de la remise = montant HT x % RFA, arrondi au centime.
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec les modèles RfaArticle / RfaFacture, sinon
-- Hibernate crée une table lvme_rfa_facture à la place de la vue. Relançable.
-- =====================================================================

CREATE TABLE IF NOT EXISTS supplychain_rfa_article (
  id bigint PRIMARY KEY,
  version integer,
  archived boolean,
  import_id varchar(255) UNIQUE,
  import_origin varchar(255),
  process_instance_id varchar(255),
  attrs jsonb,
  created_on timestamp without time zone,
  updated_on timestamp without time zone,
  created_by bigint REFERENCES auth_user (id),
  updated_by bigint REFERENCES auth_user (id),
  type_client integer NOT NULL DEFAULT 1,
  client bigint REFERENCES base_partner (id),
  groupement bigint REFERENCES sale_groupement (id),
  type_article integer NOT NULL DEFAULT 1,
  product bigint REFERENCES base_product (id),
  famille bigint REFERENCES base_product_category (id),
  date_debut date,
  date_fin date,
  pourc_rfa numeric(5, 2) DEFAULT 0
);
CREATE SEQUENCE IF NOT EXISTS supplychain_rfa_article_seq START 1 INCREMENT 1;
CREATE INDEX IF NOT EXISTS supplychain_rfa_article_client_idx ON supplychain_rfa_article (client);
CREATE INDEX IF NOT EXISTS supplychain_rfa_article_groupement_idx ON supplychain_rfa_article (groupement);
CREATE INDEX IF NOT EXISTS supplychain_rfa_article_product_idx ON supplychain_rfa_article (product);
CREATE INDEX IF NOT EXISTS supplychain_rfa_article_famille_idx ON supplychain_rfa_article (famille);

DROP VIEW IF EXISTS lvme_rfa_facture;
CREATE VIEW lvme_rfa_facture AS
SELECT l.id                              AS id,
       0                                 AS version,
       false                             AS archived,
       NULL::bigint                      AS created_by,
       now()                             AS created_on,
       NULL::bigint                      AS updated_by,
       NULL::timestamp without time zone AS updated_on,
       NULL::character varying           AS import_id,
       NULL::character varying           AS import_origin,
       NULL::character varying           AS process_instance_id,
       NULL::jsonb                       AS attrs,
       i.id                              AS invoice_id,
       l.id                              AS invoice_line_id,
       p.id                              AS client_id,
       g.id                              AS groupement_id,
       g.code::varchar                   AS groupement_code,
       g.name::varchar                   AS groupement_nom,
       p.partner_seq::varchar            AS client_code,
       p.name::varchar                   AS client_nom,
       i.invoice_id::varchar             AS numero_facture,
       i.invoice_date                    AS date_facture,
       COALESCE(l.product_name, pr.name)::varchar AS produit,
       (CASE WHEN i.operation_type_select = 4 THEN -1 ELSE 1 END * l.ex_tax_total)::numeric(20, 2) AS montant_ht,
       r.pourc_rfa                       AS pourc_rfa,
       round(CASE WHEN i.operation_type_select = 4 THEN -1 ELSE 1 END * l.ex_tax_total * r.pourc_rfa / 100, 2)
                                         AS montant_rfa
FROM account_invoice_line l
JOIN account_invoice i ON i.id = l.invoice
JOIN base_partner p ON p.id = i.partner
LEFT JOIN sale_groupement g ON g.id = p.groupement
LEFT JOIN base_product pr ON pr.id = l.product
JOIN LATERAL (
  SELECT ra.pourc_rfa
  FROM supplychain_rfa_article ra
  WHERE COALESCE(ra.archived, false) = false
    AND i.invoice_date BETWEEN COALESCE(ra.date_debut, DATE '1900-01-01') AND COALESCE(ra.date_fin, DATE '2999-12-31')
    AND ((ra.type_client = 1 AND ra.client = p.id) OR (ra.type_client = 2 AND ra.groupement = p.groupement))
    AND ((ra.type_article = 1 AND ra.product = l.product) OR (ra.type_article = 2 AND ra.famille = pr.product_category))
  ORDER BY ra.type_client, ra.type_article, ra.id DESC
  LIMIT 1) r ON true
WHERE i.operation_type_select IN (3, 4) AND i.status_select IN (2, 3);

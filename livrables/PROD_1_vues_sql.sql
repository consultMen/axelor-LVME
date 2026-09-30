-- =====================================================================
-- PROD étape 1 : vues SQL des écrans REC-003 (rotation, âge des lots) et REC-038 (état des stocks par lots)
--
-- Contexte : le code a été déployé et redémarré AVANT la création des vues. Hibernate (ddl=update)
-- a donc créé à leur place 3 TABLES VIDES du même nom. Ce script les remplace par les vraies vues.
--
-- 1) Lancer d'abord le bloc CONTRÔLE seul (lecture seule) et vérifier le résultat.
-- 2) Faire la sauvegarde de la base.
-- 3) Lancer le bloc CORRECTION (une seule transaction : tout passe ou rien ne change).
-- =====================================================================

-- ---------- CONTRÔLE (lecture seule) ----------
-- type : 'r' = table (à remplacer), 'v' = vue (déjà bonne), vide = n'existe pas
axelor@axelor-erp-v2:~/src$ psql -U axelor axelor 
psql (15.19 (Debian 15.19-0+deb12u1))
Type "help" for help.

axelor=> SELECT n.name,
       c.relkind AS type,
       CASE WHEN c.relkind = 'r' THEN (xpath('/row/c/text()',
            query_to_xml(format('SELECT count(*) AS c FROM %I', n.name), false, true, '')))[1]::text::int END AS nb_lignes
FROM (VALUES ('lvme_age_lot'), ('lvme_rotation_stock'), ('lvme_etat_stock_lot')) AS n(name)
LEFT JOIN pg_class c ON c.relname = n.name AND c.relnamespace = 'public'::regnamespace;
        name         | type | nb_lignes 
---------------------+------+-----------
 lvme_age_lot        | r    |         0
 lvme_rotation_stock | r    |         0
 lvme_etat_stock_lot | r    |         0
(3 rows)

axelor=> 
-- ---------- CORRECTION ----------
BEGIN;

-- Supprime les tables vides créées par Hibernate (refuse si une table contient des lignes)
DO $$
DECLARE t text; nb int;
BEGIN
  FOREACH t IN ARRAY ARRAY['lvme_age_lot', 'lvme_rotation_stock', 'lvme_etat_stock_lot'] LOOP
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = t AND relkind = 'r'
               AND relnamespace = 'public'::regnamespace) THEN
      EXECUTE format('SELECT count(*) FROM %I', t) INTO nb;
      IF nb > 0 THEN
        RAISE EXCEPTION 'La table % contient % lignes : arrêt, rien n''est modifié', t, nb;
      END IF;
      EXECUTE format('DROP TABLE %I CASCADE', t);
      RAISE NOTICE 'Table vide % supprimée', t;
    END IF;
  END LOOP;
END $$;


-- ---------- lvme_age_lot ----------
-- =====================================================================
-- REC-003 : vue lvme_age_lot (modèle Axelor AgeLot)
-- Une ligne par lot et par frigo : quantité, valeur, âge, DLUO.
--
-- Historique :
--   v1 : créée manuellement dans pgAdmin.
--   v2 (28/09/2026) : correction de la valorisation.
--        Sur les lignes de lot, avg_price vaut 0 (et non NULL), donc
--        COALESCE(l.avg_price, ...) retenait 0. La valeur est désormais
--        calculée avec le prix moyen de la ligne d'emplacement
--        correspondante, même règle que lvme_rotation_stock : la somme
--        des lots est ainsi cohérente avec la valeur de la rotation.
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le
-- modèle AgeLot, sinon Hibernate crée une table du même nom.
-- =====================================================================

CREATE OR REPLACE VIEW lvme_age_lot AS
SELECT l.id,
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
       l.product                         AS product_id,
       l.tracking_number                 AS tracking_number_id,
       COALESCE(l.details_stock_location, l.stock_location) AS stock_location_id,
       l.current_qty                     AS qty,
       -- v2 : prix moyen de la ligne d'emplacement (le PMP n'est pas porté par les lignes de lot)
       l.current_qty * COALESCE(loc.avg_price, 0) AS stock_value,
       COALESCE(t.date_arrivage, t.created_on::date) AS arrival_date,
       CASE WHEN t.date_arrivage IS NOT NULL THEN 'Arrivage'
            ELSE 'Création (migration)' END AS date_source,
       CURRENT_DATE - COALESCE(t.date_arrivage, t.created_on::date) AS age_days,
       CASE
           WHEN CURRENT_DATE - COALESCE(t.date_arrivage, t.created_on::date) <= 30  THEN '0-30 j'
           WHEN CURRENT_DATE - COALESCE(t.date_arrivage, t.created_on::date) <= 90  THEN '30-90 j'
           WHEN CURRENT_DATE - COALESCE(t.date_arrivage, t.created_on::date) <= 180 THEN '90-180 j'
           ELSE '> 180 j'
       END                               AS age_bucket,
       t.perishable_expiration_date      AS dluo,
       t.perishable_expiration_date - CURRENT_DATE AS days_to_dluo,
       t.perishable_expiration_date < CURRENT_DATE AS is_expired
FROM stock_stock_location_line l
JOIN stock_stock_location sl ON sl.id = COALESCE(l.details_stock_location, l.stock_location)
JOIN stock_tracking_number t ON t.id = l.tracking_number
LEFT JOIN stock_stock_location_line loc
       ON loc.stock_location = l.details_stock_location
      AND loc.product = l.product
      AND loc.details_stock_location IS NULL
WHERE l.current_qty > 0
  AND sl.type_select = 1;

-- ---------- lvme_rotation_stock ----------
-- =====================================================================
-- REC-003 : vue lvme_rotation_stock (modèle Axelor RotationStock)
-- Une ligne par produit : stock, ventes, couverture, rotation, ancienneté.
--
-- Les 4 KPI de la rotation des stocks :
--   1. Couverture (jours de stock) = stock / vente moyenne par jour (90 j)
--   2. Taux de rotation (fois / an) = ventes 12 mois / stock actuel
--   3. Âge moyen du stock (j)       = âge des lots en stock, pondéré par la quantité
--   4. Stock dormant                = aucune vente depuis plus de 90 j (valeur immobilisée)
--
-- Historique :
--   v1 : créée manuellement dans pgAdmin.
--   v2 (28/09/2026) : correction du double comptage du stock.
--        Le CTE "stock" ne lit plus que les lignes d'emplacement
--        (details_stock_location IS NULL). Les lignes de lot ventilent
--        le même stock et ne doivent pas s'y ajouter.
--   v3 (29/09/2026) : 4 KPI.
--        La couverture est calculée dès qu'il y a une vente sur 90 j
--        (avant : seulement à partir de 10) ; le statut « A commander »
--        reste réservé aux produits aux ventes significatives (>= 10 / 90 j).
--        Colonnes ajoutées en fin de vue : ventes 12 mois, taux de rotation,
--        âge moyen pondéré, valeur dormante, jours depuis la dernière vente,
--        code / désignation / famille du produit (filtres et affichage).
--
-- Déploiement : exécuter AVANT le démarrage d'Axelor avec la version du
-- modèle RotationStock qui contient ces colonnes, sinon Hibernate tente de
-- les ajouter à une vue et échoue.
-- =====================================================================

CREATE OR REPLACE VIEW lvme_rotation_stock AS
WITH stock AS (
    -- Stock de référence : lignes d'emplacement uniquement (v2)
    SELECT l.product,
           SUM(l.current_qty)                            AS qty,
           SUM(l.current_qty * COALESCE(l.avg_price, 0)) AS valeur
    FROM stock_stock_location_line l
    JOIN stock_stock_location sl ON sl.id = l.stock_location
    WHERE l.details_stock_location IS NULL
      AND sl.type_select = 1
    GROUP BY l.product
),
ventes AS (
    SELECT sml.product,
           SUM(CASE WHEN sm.real_date >= CURRENT_DATE - 90
                    THEN sml.real_qty ELSE 0 END)        AS qty_90j,
           SUM(CASE WHEN sm.real_date >= CURRENT_DATE - 365
                    THEN sml.real_qty ELSE 0 END)        AS qty_365j,
           MAX(sm.real_date)                             AS derniere_vente
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    WHERE sm.type_select = 2
      AND sm.status_select = 3
    GROUP BY sml.product
),
lots AS (
    -- Ancienneté : lignes de lot en stock
    SELECT l.product,
           MIN(t.date_arrivage)                          AS plus_ancien,
           -- v3 : âge moyen pondéré par la quantité (date d'arrivage, sinon création du lot)
           ROUND(SUM(l.current_qty * (CURRENT_DATE - COALESCE(t.date_arrivage, t.created_on::date)))
                 / NULLIF(SUM(l.current_qty), 0))        AS age_moyen
    FROM stock_stock_location_line l
    JOIN stock_stock_location sl ON sl.id = COALESCE(l.details_stock_location, l.stock_location)
    JOIN stock_tracking_number t ON t.id = l.tracking_number
    WHERE l.current_qty > 0
      AND sl.type_select = 1
    GROUP BY l.product
),
calc AS (
    SELECT s.product,
           s.qty,
           s.valeur,
           COALESCE(v.qty_90j, 0)                        AS qty_90j,
           COALESCE(v.qty_365j, 0)                       AS qty_365j,
           ROUND(COALESCE(v.qty_90j, 0) / 90.0, 3)       AS moy_jour,
           -- v3 : couverture calculée dès la première vente sur 90 j
           CASE WHEN COALESCE(v.qty_90j, 0) > 0
                THEN ROUND(s.qty / (v.qty_90j / 90.0))
                ELSE NULL::numeric END                   AS jours_stock,
           (COALESCE(v.qty_90j, 0) >= 10)                AS significatif,
           v.derniere_vente,
           lo.plus_ancien,
           lo.age_moyen,
           CASE WHEN lo.plus_ancien IS NOT NULL
                THEN CURRENT_DATE - lo.plus_ancien
                ELSE NULL::integer END                   AS age_max,
           (v.derniere_vente IS NULL
            OR v.derniere_vente < CURRENT_DATE - 90)     AS dormant
    FROM stock s
    LEFT JOIN ventes v ON v.product = s.product
    LEFT JOIN lots  lo ON lo.product = s.product
    WHERE s.qty > 0
)
SELECT c.product                         AS id,
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
       c.product                         AS product_id,
       c.qty                             AS stock_qty,
       c.valeur                          AS stock_value,
       c.qty_90j                         AS sales_90d,
       c.moy_jour                        AS avg_daily_sales,
       c.jours_stock                     AS days_of_stock,
       c.derniere_vente                  AS last_sale_date,
       c.plus_ancien                     AS oldest_lot_date,
       c.age_max                         AS oldest_lot_age,
       c.dormant                         AS is_dormant,
       CASE
           WHEN c.significatif AND c.jours_stock < 60 THEN 'A commander'
           WHEN c.dormant                             THEN 'Dormant'
           WHEN c.age_max > 180                       THEN 'Lot ancien'
           WHEN NOT c.significatif                    THEN 'Ventes faibles'
           ELSE 'OK'
       END                               AS statut,
       -- ===== v3 : colonnes ajoutées (toujours en fin de vue) =====
       c.qty_365j                        AS sales_365d,
       ROUND(c.qty_365j / NULLIF(c.qty, 0), 2) AS rotation_rate,
       c.age_moyen::integer              AS avg_age_days,
       CASE WHEN c.dormant THEN c.valeur ELSE 0 END AS dormant_value,
       (CURRENT_DATE - c.derniere_vente)::integer AS days_since_last_sale,
       p.code                            AS product_code,
       p.name                            AS product_name,
       p.product_category                AS product_category_id
FROM calc c
JOIN base_product p ON p.id = c.product;

-- ---------- lvme_etat_stock_lot ----------
-- =====================================================================
-- REC-038 : vue lvme_etat_stock_lot (modèle Axelor EtatStockLot)
-- Reproduit l'écran « État des stocks par lots » de l'ancien système.
-- Une ligne par lot et par frigo :
--   * arrivages réels   : BR fournisseur réalisés (entrées, sorties, stock)
--   * arrivages flottants : BR fournisseur planifiés (« ce qu'il aura »)
--   * lots en stock sans BR d'origine (reprise / inventaire)
--
-- Règles :
--   Entrées   = quantités reçues du lot sur ce frigo (BR réalisés)
--   Stock     = quantité actuelle de la ligne de lot du frigo
--   Sorties   = Entrées - Stock (réel) ; 0 pour un flottant
--   Commandes = lignes de livraison client planifiées sur ce lot / frigo
--   Colis     = quantité / (quantité par colis de l'arrivage)
--   Valeur    = montant réel d'entrée au prorata du stock, sinon stock x PR
--
-- Déploiement : exécuter AVANT le premier démarrage d'Axelor avec le
-- modèle EtatStockLot, sinon Hibernate crée une table du même nom.
-- =====================================================================

CREATE OR REPLACE VIEW lvme_etat_stock_lot AS
WITH arrivages AS (
    -- Lignes de BR fournisseur (hors retours), réalisées ou planifiées
    SELECT sml.tracking_number,
           COALESCE(sml.to_stock_location, sm.to_stock_location)          AS frigo,
           MAX(sml.product)                                                AS product,
           MAX(sm.partner)                                                 AS supplier,
           STRING_AGG(DISTINCT sm.stock_move_seq, ', ')                    AS arrival_number,
           MAX(sml.origine)                                                AS origine,
           MAX(COALESCE(NULLIF(cond.label, ''), cond.code))                  AS conditionnement,
           MAX(sml.dluo)                                                   AS dluo_ligne,
           MAX(sml.prix_revient_reel)                                      AS pr_ligne,
           MAX(sml.unit)                                                   AS unit,
           MIN(COALESCE(sm.real_date, sm.estimated_date))                  AS entry_date,
           (sm.status_select = 2)                                          AS is_flottant,
           SUM(CASE WHEN sm.status_select = 3 THEN sml.real_qty ELSE sml.qty END) AS entree_qty,
           SUM(COALESCE(sml.nb_colis, 0))                                  AS nb_colis_in,
           MAX(COALESCE(sml.poids_par_colis, 0))                           AS poids_par_colis,
           SUM(COALESCE(sml.montant_reel, 0))                              AS montant_in
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    LEFT JOIN purchase_purchase_order_line pol ON pol.id = sml.purchase_order_line
    LEFT JOIN purchase_conditionnement cond ON cond.id = pol.conditionnement
    WHERE sm.type_select = 3
      AND sm.status_select IN (2, 3)
      AND COALESCE(sm.is_reversion, false) = false
      AND sml.tracking_number IS NOT NULL
    GROUP BY sml.tracking_number, COALESCE(sml.to_stock_location, sm.to_stock_location), (sm.status_select = 2)
),
stock_lots AS (
    -- Stock actuel des lots, par frigo (lignes de lot)
    SELECT l.tracking_number,
           l.details_stock_location AS frigo,
           MAX(l.product)           AS product,
           SUM(l.current_qty)       AS stock_qty
    FROM stock_stock_location_line l
    JOIN stock_stock_location sl ON sl.id = l.details_stock_location
    WHERE l.tracking_number IS NOT NULL
      AND sl.type_select = 1
    GROUP BY l.tracking_number, l.details_stock_location
),
commandes AS (
    -- Livraisons clients planifiées (non réalisées) sur le lot / frigo
    SELECT sml.tracking_number,
           COALESCE(sml.from_stock_location, sm.from_stock_location) AS frigo,
           SUM(sml.qty) AS cdes_qty
    FROM stock_stock_move_line sml
    JOIN stock_stock_move sm ON sm.id = sml.stock_move
    WHERE sm.type_select = 2
      AND sm.status_select = 2
      AND sml.tracking_number IS NOT NULL
    GROUP BY sml.tracking_number, COALESCE(sml.from_stock_location, sm.from_stock_location)
),
base AS (
    SELECT COALESCE(a.tracking_number, s.tracking_number) AS tracking_number,
           COALESCE(a.frigo, s.frigo)                     AS frigo,
           COALESCE(a.product, s.product)                 AS product,
           a.supplier, a.arrival_number, a.origine, a.conditionnement,
           a.dluo_ligne, a.pr_ligne, a.unit, a.entry_date,
           COALESCE(a.is_flottant, false)                 AS is_flottant,
           COALESCE(a.entree_qty, 0)                      AS entree_qty,
           COALESCE(a.nb_colis_in, 0)                     AS nb_colis_in,
           COALESCE(a.poids_par_colis, 0)                 AS poids_par_colis,
           COALESCE(a.montant_in, 0)                      AS montant_in,
           COALESCE(s.stock_qty, 0)                       AS stock_lot_qty
    FROM arrivages a
    FULL OUTER JOIN stock_lots s
      ON s.tracking_number = a.tracking_number AND s.frigo = a.frigo AND a.is_flottant = false
),
calc AS (
    SELECT b.*,
           t.tracking_number_seq,
           COALESCE(t.perishable_expiration_date, b.dluo_ligne)            AS dluo,
           COALESCE(NULLIF(t.prix_revient_reel, 0), b.pr_ligne, 0)         AS prix_revient,
           COALESCE(t.date_arrivage, b.entry_date)                         AS arrival_date,
           COALESCE(b.supplier, t.supplier)                                AS supplier_id,
           -- Stock : réel = ligne de lot ; flottant = quantité attendue
           CASE WHEN b.is_flottant THEN b.entree_qty ELSE b.stock_lot_qty END AS stock_qty,
           CASE WHEN b.is_flottant THEN 0 ELSE b.entree_qty - b.stock_lot_qty END AS sortie_qty,
           COALESCE(c.cdes_qty, 0)                                         AS cdes_qty,
           -- Quantité par colis de l'arrivage
           CASE WHEN b.nb_colis_in > 0 AND b.entree_qty > 0 THEN b.entree_qty / b.nb_colis_in
                WHEN b.poids_par_colis > 0 THEN b.poids_par_colis
                ELSE NULL END                                              AS qty_per_colis
    FROM base b
    JOIN stock_tracking_number t ON t.id = b.tracking_number
    LEFT JOIN commandes c ON c.tracking_number = b.tracking_number AND c.frigo = b.frigo AND b.is_flottant = false
)
SELECT ((c.tracking_number * 1000000 + COALESCE(c.frigo, 0)) * 10 + CASE WHEN c.is_flottant THEN 2 ELSE 1 END)::bigint AS id,
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
       c.product                         AS product_id,
       p.code                            AS product_code,
       p.name                            AS product_name,
       p.product_category                AS product_category_id,
       c.supplier_id                     AS supplier_id,
       pa.full_name                      AS supplier_name,
       c.frigo                           AS stock_location_id,
       c.tracking_number                 AS tracking_number_id,
       c.tracking_number_seq             AS lot_number,
       c.arrival_number                  AS arrival_number,
       c.origine                         AS origine,
       c.entry_date                      AS entry_date,
       c.arrival_date                    AS arrival_date,
       c.conditionnement                 AS conditionnement,
       c.dluo                            AS dluo,
       c.prix_revient                    AS prix_revient,
       COALESCE(c.unit, p.unit)          AS unit_id,
       CASE WHEN c.is_flottant THEN 2 ELSE 1 END AS nature_arrivage,
       CASE WHEN c.is_flottant THEN 'Flottant' ELSE 'Réel' END AS nature_label,
       ROUND(c.qty_per_colis, 3)         AS qty_per_colis,
       c.nb_colis_in                     AS nb_colis_in,
       ROUND(COALESCE(c.sortie_qty / c.qty_per_colis, 0), 3) AS nb_colis_out,
       ROUND(COALESCE(c.cdes_qty  / c.qty_per_colis, 0), 3) AS nb_colis_cdes,
       ROUND(COALESCE(c.stock_qty / c.qty_per_colis, 0), 3) AS nb_colis_stock,
       c.entree_qty                      AS entree_qty,
       c.sortie_qty                      AS sortie_qty,
       c.cdes_qty                        AS cdes_qty,
       c.stock_qty                       AS stock_qty,
       c.stock_qty - c.cdes_qty          AS dispo_qty,
       ROUND(CASE WHEN c.montant_in > 0 AND c.entree_qty > 0
                  THEN c.montant_in * c.stock_qty / c.entree_qty
                  ELSE c.stock_qty * c.prix_revient END, 2) AS stock_value
FROM calc c
JOIN base_product p ON p.id = c.product
LEFT JOIN base_partner pa ON pa.id = c.supplier_id;

COMMIT;

-- Vérification : les 3 doivent être de type 'v' et renvoyer des lignes
SELECT 'lvme_age_lot' AS vue, count(*) FROM lvme_age_lot
UNION ALL SELECT 'lvme_rotation_stock', count(*) FROM lvme_rotation_stock
UNION ALL SELECT 'lvme_etat_stock_lot', count(*) FROM lvme_etat_stock_lot;

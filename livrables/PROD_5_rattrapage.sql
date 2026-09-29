-- =====================================================================
-- PROD étape 5 : RATTRAPAGE des données existantes, avec les mêmes règles que le code déployé
--   1. Lignes de commande client : marge LVME (MarginComputeServiceLVMEImpl)
--        coût = arrondi(P.R. Net x qté, 2) ; Marge HT = arrondi(Total HT - coût, 2)
--        % marge = Marge / Total HT x 100 ; % markup = Marge / coût x 100
--   2. Commandes : marge commerciale = somme des marges de lignes (SaleOrderMarginServiceLVMEImpl)
--   3. Lignes de BL client (SaleOrderStockServiceImpl + prorata des livraisons partielles) :
--        PR (U.V) = PR de la ligne de commande ; PR réel = P.R. Net ;
--        Marge HT = marge de la ligne de commande x qté BL / qté commande ; % marge = celui de la ligne ;
--        colisage recopié (au prorata) seulement s'il est vide sur le BL.
--      BL réalisés : qté réelle ; aucun effet sur le stock (champs d'information uniquement).
-- Une seule transaction. Faire une sauvegarde avant.
-- =====================================================================
BEGIN;

-- Photo avant
CREATE TEMP TABLE _avant AS
SELECT 'commandes' AS quoi, ROUND(SUM(COALESCE(total_gross_margin, 0)), 2) AS marge FROM sale_sale_order
UNION ALL
SELECT 'lignes BL', ROUND(SUM(COALESCE(sml.marge_ht, 0)), 2)
FROM stock_stock_move_line sml JOIN stock_stock_move sm ON sm.id = sml.stock_move
WHERE sm.type_select = 2 AND sml.sale_order_line IS NOT NULL;

-- 1. Lignes de commande client
WITH c AS (
  SELECT id,
         COALESCE(ex_tax_total, 0) AS ht,
         ROUND(COALESCE(prix_revient_net, 0) * COALESCE(qty, 0), 2) AS cout
  FROM sale_sale_order_line
), m AS (
  SELECT id, ht, cout, ROUND(ht - cout, 2) AS marge FROM c
)
UPDATE sale_sale_order_line sol
SET sub_total_cost_price   = m.cout,
    sub_total_gross_margin = m.marge,
    sub_margin_rate        = CASE WHEN m.ht <> 0 THEN ROUND(m.marge * 100 / m.ht, 2) ELSE 0 END,
    sub_total_markup       = CASE WHEN m.cout <> 0 THEN ROUND(m.marge * 100 / m.cout, 2) ELSE 0 END
FROM m
WHERE m.id = sol.id;

-- 2. Commandes
WITH t AS (
  SELECT sale_order,
         SUM(COALESCE(sub_total_gross_margin, 0)) AS marge,
         SUM(ROUND(COALESCE(prix_revient_net, 0) * COALESCE(qty, 0), 2)) AS cout,
         SUM(COALESCE(company_ex_tax_total, 0)) AS ca
  FROM sale_sale_order_line
  GROUP BY sale_order
)
UPDATE sale_sale_order so
SET total_gross_margin = t.marge,
    total_cost_price   = t.cout,
    accounted_revenue  = t.ca,
    margin_rate        = CASE WHEN t.ca <> 0 THEN ROUND(t.marge * 100 / t.ca, 2) ELSE 0 END,
    markup             = CASE WHEN t.cout <> 0 THEN ROUND(t.marge * 100 / t.cout, 2) ELSE 0 END
FROM t
WHERE t.sale_order = so.id;

-- 3. Lignes de BL client (brouillon, planifié, réalisé)
WITH b AS (
  SELECT sml.id,
         sol.prix_revient, sol.prix_revient_net, sol.sub_total_gross_margin, sol.sub_margin_rate,
         sol.nb_colis AS sol_nb_colis, sol.nb_unites_par_colis, sol.poids_par_colis,
         sol.coef_poids_net, sol.poids_par_colis_net,
         CASE WHEN COALESCE(sol.qty, 0) = 0 THEN 1
              ELSE ROUND((CASE WHEN sm.status_select = 3 THEN sml.real_qty ELSE sml.qty END) / sol.qty, 6) END AS ratio
  FROM stock_stock_move_line sml
  JOIN stock_stock_move sm ON sm.id = sml.stock_move
  JOIN sale_sale_order_line sol ON sol.id = sml.sale_order_line
  WHERE sm.type_select = 2 AND sm.status_select IN (1, 2, 3)
)
UPDATE stock_stock_move_line sml
SET pr_kg             = COALESCE(b.prix_revient, 0),
    prix_revient_reel = COALESCE(b.prix_revient_net, 0),
    marge_ht          = ROUND(COALESCE(b.sub_total_gross_margin, 0) * b.ratio, 3),
    taux_marge        = COALESCE(b.sub_margin_rate, 0),
    nb_colis          = CASE WHEN COALESCE(sml.nb_colis, 0) = 0 AND COALESCE(b.sol_nb_colis, 0) > 0
                             THEN ROUND(b.sol_nb_colis * b.ratio, 3) ELSE sml.nb_colis END,
    nb_unites_par_colis = CASE WHEN COALESCE(sml.nb_colis, 0) = 0 AND COALESCE(b.sol_nb_colis, 0) > 0
                             THEN COALESCE(b.nb_unites_par_colis, 0) ELSE sml.nb_unites_par_colis END,
    poids_par_colis   = CASE WHEN COALESCE(sml.nb_colis, 0) = 0 AND COALESCE(b.sol_nb_colis, 0) > 0
                             THEN COALESCE(b.poids_par_colis, 0) ELSE sml.poids_par_colis END,
    coef_poids_net    = CASE WHEN COALESCE(sml.nb_colis, 0) = 0 AND COALESCE(b.sol_nb_colis, 0) > 0
                             THEN COALESCE(b.coef_poids_net, 1) ELSE sml.coef_poids_net END,
    poids_par_colis_net = CASE WHEN COALESCE(sml.nb_colis, 0) = 0 AND COALESCE(b.sol_nb_colis, 0) > 0
                             THEN COALESCE(b.poids_par_colis_net, 0) ELSE sml.poids_par_colis_net END,
    poids_total_net   = CASE WHEN COALESCE(sml.nb_colis, 0) = 0 AND COALESCE(b.sol_nb_colis, 0) > 0
                             THEN ROUND(ROUND(b.sol_nb_colis * b.ratio, 3) * COALESCE(b.poids_par_colis_net, 0), 3)
                             ELSE sml.poids_total_net END,
    unites_tot        = CASE WHEN COALESCE(sml.nb_colis, 0) = 0 AND COALESCE(b.sol_nb_colis, 0) > 0
                             THEN ROUND(ROUND(b.sol_nb_colis * b.ratio, 3) * COALESCE(b.nb_unites_par_colis, 0), 3)
                             ELSE sml.unites_tot END
FROM b
WHERE b.id = sml.id;

-- Avant / après
SELECT a.quoi, a.marge AS marge_avant, n.marge AS marge_apres
FROM _avant a
JOIN (SELECT 'commandes' AS quoi, ROUND(SUM(COALESCE(total_gross_margin, 0)), 2) AS marge FROM sale_sale_order
      UNION ALL
      SELECT 'lignes BL', ROUND(SUM(COALESCE(sml.marge_ht, 0)), 2)
      FROM stock_stock_move_line sml JOIN stock_stock_move sm ON sm.id = sml.stock_move
      WHERE sm.type_select = 2 AND sml.sale_order_line IS NOT NULL) n ON n.quoi = a.quoi;

COMMIT;

-- =====================================================================
-- PROD étape 4 : CONTRÔLE avant rattrapage (LECTURE SEULE, ne modifie rien)
--   A. Marges des lignes de commande client : valeur enregistrée vs formule LVME
--      (Marge HT = Total HT - arrondi(P.R. Net x qté, 2))
--   B. Lignes de BL client : colisage, lot, PR et marge manquants par rapport à la commande
-- =====================================================================

-- ---------- A1. Lignes de commande dont la marge enregistrée diffère de la formule LVME ----------
WITH l AS (
  SELECT so.status_select,
         sol.sub_total_gross_margin AS marge_actuelle,
         sol.ex_tax_total - ROUND(COALESCE(sol.prix_revient_net, 0) * COALESCE(sol.qty, 0), 2) AS marge_lvme
  FROM sale_sale_order_line sol
  JOIN sale_sale_order so ON so.id = sol.sale_order
  WHERE COALESCE(sol.type_select, 0) = 0
)
SELECT CASE status_select WHEN 1 THEN '1 Devis brouillon' WHEN 2 THEN '2 Devis finalisé'
            WHEN 3 THEN '3 Commande confirmée' WHEN 4 THEN '4 Commande terminée' ELSE '5 Annulée / autre' END AS statut,
       COUNT(*) AS nb_lignes,
       COUNT(*) FILTER (WHERE ROUND(COALESCE(marge_actuelle, 0), 2) <> ROUND(marge_lvme, 2)) AS nb_lignes_a_corriger,
       ROUND(SUM(COALESCE(marge_actuelle, 0)), 2) AS marge_actuelle_totale,
       ROUND(SUM(marge_lvme), 2) AS marge_lvme_totale
FROM l GROUP BY 1 ORDER BY 1;

-- ---------- A2. Les 20 commandes les plus impactées ----------
SELECT so.sale_order_seq AS commande, so.status_select AS statut,
       so.total_gross_margin AS marge_commerciale_actuelle,
       ROUND(SUM(sol.ex_tax_total - ROUND(COALESCE(sol.prix_revient_net, 0) * COALESCE(sol.qty, 0), 2)), 2) AS marge_commerciale_lvme
FROM sale_sale_order so
JOIN sale_sale_order_line sol ON sol.sale_order = so.id AND COALESCE(sol.type_select, 0) = 0
GROUP BY so.id
HAVING ROUND(COALESCE(so.total_gross_margin, 0), 2)
    <> ROUND(SUM(sol.ex_tax_total - ROUND(COALESCE(sol.prix_revient_net, 0) * COALESCE(sol.qty, 0), 2)), 2)
ORDER BY ABS(COALESCE(so.total_gross_margin, 0)
           - SUM(sol.ex_tax_total - ROUND(COALESCE(sol.prix_revient_net, 0) * COALESCE(sol.qty, 0), 2))) DESC
LIMIT 20;

-- ---------- A3. Lignes sans P.R. Net (la marge LVME y vaudra le total HT) ----------
SELECT COUNT(*) AS lignes_sans_pr_net,
       COUNT(DISTINCT sol.sale_order) AS commandes_concernees
FROM sale_sale_order_line sol
WHERE COALESCE(sol.type_select, 0) = 0 AND COALESCE(sol.prix_revient_net, 0) = 0;

-- ---------- B. Lignes de BL client liées à une ligne de commande ----------
SELECT CASE sm.status_select WHEN 1 THEN '1 Brouillon' WHEN 2 THEN '2 Planifié' WHEN 3 THEN '3 Réalisé' END AS statut_bl,
       COUNT(*) AS nb_lignes_bl,
       COUNT(*) FILTER (WHERE COALESCE(sml.nb_colis, 0) = 0 AND COALESCE(sol.nb_colis, 0) > 0) AS colisage_manquant,
       COUNT(*) FILTER (WHERE sml.tracking_number IS NULL AND lot.tracking_number IS NOT NULL) AS lot_manquant,
       COUNT(*) FILTER (WHERE COALESCE(sml.pr_kg, 0) = 0 AND COALESCE(sol.prix_revient, 0) > 0) AS pr_manquant,
       COUNT(*) FILTER (WHERE COALESCE(sml.prix_revient_reel, 0) = 0 AND COALESCE(sol.prix_revient_net, 0) > 0) AS pr_net_manquant,
       COUNT(*) FILTER (WHERE COALESCE(sml.marge_ht, 0) = 0) AS marge_manquante
FROM stock_stock_move_line sml
JOIN stock_stock_move sm ON sm.id = sml.stock_move
JOIN sale_sale_order_line sol ON sol.id = sml.sale_order_line
LEFT JOIN LATERAL (SELECT l.tracking_number FROM supplychain_sale_order_line_lot l
                   WHERE l.sale_order_line = sol.id AND l.tracking_number IS NOT NULL
                   ORDER BY l.id DESC LIMIT 1) lot ON true
WHERE sm.type_select = 2 AND sm.status_select IN (1, 2, 3)
GROUP BY sm.status_select ORDER BY sm.status_select;

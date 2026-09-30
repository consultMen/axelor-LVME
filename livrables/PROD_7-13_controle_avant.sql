-- =====================================================================
-- Contrôle AVANT le lot « écrans GESCOM » (PROD_7 à PROD_13) — LECTURE SEULE, n'écrit rien.
-- À lancer depuis la racine du dépôt, après le git pull :
--   psql -U axelor axelor -f livrables/PROD_7-13_controle_avant.sql
-- Résultat attendu : « manquant » vide, et les vues sources trouvées (1 ligne chacune).
-- =====================================================================

-- 1. Colonnes / tables déjà présentes en prod dont les scripts ont besoin
SELECT v.tbl || '.' || COALESCE(v.col, '*') AS manquant
FROM (VALUES
  ('stock_stock_move', 'nature'), ('stock_stock_move', 'is_reversion'), ('stock_stock_move', 'real_date'),
  ('stock_stock_move_line', 'nb_colis'), ('stock_stock_move_line', 'poids_total_net'),
  ('stock_stock_move_line', 'poids_par_colis'), ('stock_stock_move_line', 'date_congelation'),
  ('stock_stock_move_line', 'dluo'), ('stock_stock_move_line', 'origine'),
  ('stock_stock_move_line', 'montant_reel'), ('stock_stock_move_line', 'prix_revient_reel'),
  ('purchase_purchase_order_line', 'nb_colis'), ('purchase_purchase_order_line', 'poids_total_net'),
  ('purchase_purchase_order_line', 'conditionnement'), ('purchase_purchase_order_line', 'is_title_line'),
  ('stock_stock_move_purchase_order_set', 'stock_stock_move'),
  ('stock_stock_move_purchase_order_set', 'purchase_order_set'),
  ('purchase_conditionnement', 'label'),
  ('stock_tracking_number', 'tracking_number_seq'),
  ('base_product', 'sale_price'), ('base_product', 'product_family'),
  ('account_account_management_sale_tax_set', 'sale_tax_set'),
  ('account_tax', 'active_tax_line')
) AS v(tbl, col)
WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns c
                  WHERE c.table_schema = 'public' AND c.table_name = v.tbl AND c.column_name = v.col);

-- 2. Vues de module utilisées comme source par PROD_7 / PROD_8 / PROD_11
SELECT name, type, priority, module, length(xml) AS taille
FROM meta_view
WHERE name IN ('sale-order-form', 'purchase-order-form', 'product-form')
  AND module IS NOT NULL AND COALESCE(extension, false) = false
ORDER BY name, priority DESC;

-- 3. Menus parents / menus modifiés par le lot
SELECT name, title FROM meta_menu
WHERE name IN ('stock-root', 'stock-root-conf', 'stock-root-suparrivals', 'sc-root-purchase-orders',
               'sc-root-sale-orders', 'sc-root-sale-customers', 'sc-root-purchase-suppliers',
               'sc-root-sale-products', 'sc-root-purchase-products')
ORDER BY name;

-- 4. Personnalisations de colonnes des utilisateurs sur les listes modifiées
--    (s'il y en a : l'utilisateur fera « Réinitialiser » dans l'engrenage de la liste)
SELECT v.name AS vue, u.code AS utilisateur
FROM meta_view_custom v LEFT JOIN auth_user u ON u.id = v.user_id
WHERE v.name IN ('sale-order-line-grid', 'purchase-order-line-purchase-order-grid', 'partner-customer-grid',
                 'partner-supplier-grid', 'product-grid', 'product-purchase-grid')
ORDER BY 1, 2;

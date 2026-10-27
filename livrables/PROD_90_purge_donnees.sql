-- =====================================================================
-- PROD étape 90 : purge des données avant la nouvelle migration GESCOM
--   Supprime TOUTES les données : commandes clients / fournisseurs, arrivages, BL, lots, stock, inventaires,
--   cessions, factures et écritures (de test), clients, fournisseurs, transporteurs, contacts, adresses, articles,
--   familles. Garde le paramétrage : société, utilisateurs, frigos, vues, menus, actions, impressions, taxes,
--   comptes, unités, modes / conditions de paiement, numérotations (remises à 1).
--   Les fiches encore utilisées par le paramétrage (tiers de la société LVME, des utilisateurs…) sont gardées et
--   listées.
-- Sécurité : tout se fait dans une seule transaction. Si une ligne du paramétrage pointe vers une donnée à
--   supprimer, le script s'arrête AVANT toute suppression et affiche les tables en cause (rien n'est modifié).
-- Prérequis : pg_dump juste avant. Application arrêtée (ou personne connecté). NE PAS relancer après la migration.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = notice;

BEGIN;

-- tables vidées entièrement (celles qui n'existent pas sont ignorées)
CREATE TEMP TABLE purge_total (tbl text PRIMARY KEY) ON COMMIT DROP;
INSERT INTO purge_total
SELECT t FROM unnest(ARRAY[
  -- ventes
  'sale_sale_order', 'sale_sale_order_line', 'sale_sale_order_line_tax', 'sale_sale_order_line_tax_line_set',
  'sale_sale_order_line_tree', 'sale_sale_order_batch_set', 'sale_cart', 'sale_cart_line',
  'supplychain_sale_order_line_arrivage', 'supplychain_sale_order_line_lot',
  'supplychain_sale_order_line_stock_location', 'supplychain_timetable', 'supplychain_palmares_commercial',
  -- achats
  'purchase_purchase_order', 'purchase_purchase_order_line', 'purchase_purchase_order_line_tax',
  'purchase_purchase_order_line_tax_line_set', 'purchase_purchase_request', 'purchase_purchase_request_line',
  'purchase_supplier_catalog',
  -- stock, arrivages, BL, lots
  'stock_stock_move', 'stock_stock_move_line', 'stock_stock_move_purchase_order_set',
  'stock_stock_move_sale_order_set', 'stock_stock_move_line_location', 'stock_tracking_number',
  'stock_stock_location_line', 'stock_stock_location_line_history', 'stock_wap_history', 'stock_inventory',
  'stock_inventory_line', 'stock_stock_correction', 'stock_cession_stock', 'stock_lot_fournisseur',
  'stock_partner_product_quality_rating', 'stock_partner_stock_settings', 'stock_logistical_form',
  'stock_logistical_form_line', 'stock_mass_stock_move', 'stock_stock_history_line',
  -- factures et écritures (tests)
  'account_invoice', 'account_invoice_line', 'account_invoice_line_tax', 'account_invoice_line_tax_line_set',
  'account_invoice_term', 'account_invoice_payment', 'account_invoice_term_payment', 'account_move',
  'account_move_line', 'account_move_line_tax_line_set', 'account_analytic_move_line', 'account_reconcile',
  'account_reconcile_group', 'account_payment_voucher', 'account_pay_voucher_due_element',
  'account_pay_voucher_element_to_pay', 'account_payment_schedule', 'account_payment_schedule_line',
  'account_accounting_situation', 'account_invoice_invoice_set', 'account_invoice_batch_set',
  -- liens des tiers et des articles
  'base_partner_company_set', 'base_company_partner_list', 'base_partner_link', 'base_product_company',
  'base_price_list_line', 'base_partner_contact_set', 'base_bank_details', 'base_partner_partner_category_set'
]) AS t
WHERE to_regclass(t) IS NOT NULL;

-- tables dont on garde les lignes encore utilisées par le paramétrage
CREATE TEMP TABLE purge_partiel (tbl text PRIMARY KEY) ON COMMIT DROP;
INSERT INTO purge_partiel
SELECT t FROM unnest(ARRAY['base_partner', 'base_partner_address', 'base_address', 'base_product',
  'base_product_category', 'base_product_family']) AS t
WHERE to_regclass(t) IS NOT NULL;

-- clés étrangères (une colonne) de la base
CREATE TEMP TABLE purge_fk ON COMMIT DROP AS
SELECT c.conrelid::regclass::text AS src, a.attname::text AS col, c.confrelid::regclass::text AS tgt
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
JOIN pg_class r ON r.oid = c.conrelid AND r.relkind = 'r'
WHERE c.contype = 'f' AND array_length(c.conkey, 1) = 1;

-- lignes gardées des tables partielles : utilisées par le paramétrage, puis de proche en proche
CREATE TEMP TABLE purge_garde (tbl text, id bigint, PRIMARY KEY (tbl, id)) ON COMMIT DROP;
DO $$
DECLARE r record; n bigint; total bigint;
BEGIN
  FOR r IN SELECT * FROM purge_fk WHERE tgt IN (SELECT tbl FROM purge_partiel)
             AND src NOT IN (SELECT tbl FROM purge_total) AND src NOT IN (SELECT tbl FROM purge_partiel) LOOP
    EXECUTE format('INSERT INTO purge_garde SELECT %L, %I FROM %s WHERE %I IS NOT NULL ON CONFLICT DO NOTHING',
                   r.tgt, r.col, r.src, r.col);
  END LOOP;
  LOOP
    total := 0;
    -- adresses des tiers gardés
    INSERT INTO purge_garde SELECT 'base_partner_address', pa.id FROM base_partner_address pa
      WHERE pa.partner IN (SELECT id FROM purge_garde WHERE tbl = 'base_partner') ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT; total := total + n;
    FOR r IN SELECT * FROM purge_fk WHERE src IN (SELECT tbl FROM purge_partiel)
               AND tgt IN (SELECT tbl FROM purge_partiel) LOOP
      EXECUTE format('INSERT INTO purge_garde SELECT %L, s.%I FROM %s s WHERE s.%I IS NOT NULL'
                     ' AND s.id IN (SELECT id FROM purge_garde WHERE tbl = %L) ON CONFLICT DO NOTHING',
                     r.tgt, r.col, r.src, r.col, r.src);
      GET DIAGNOSTICS n = ROW_COUNT; total := total + n;
    END LOOP;
    EXIT WHEN total = 0;
  END LOOP;
END $$;

-- contrôle : rien du paramétrage ne doit pointer vers une donnée vidée entièrement
DO $$
DECLARE r record; n bigint; bloquants text := '';
BEGIN
  FOR r IN SELECT * FROM purge_fk WHERE tgt IN (SELECT tbl FROM purge_total)
             AND src NOT IN (SELECT tbl FROM purge_total) LOOP
    IF r.src IN (SELECT tbl FROM purge_partiel) THEN
      EXECUTE format('SELECT count(*) FROM %s WHERE %I IS NOT NULL AND id IN (SELECT id FROM purge_garde WHERE tbl = %L)',
                     r.src, r.col, r.src) INTO n;
    ELSE
      EXECUTE format('SELECT count(*) FROM %s WHERE %I IS NOT NULL', r.src, r.col) INTO n;
    END IF;
    IF n > 0 THEN
      bloquants := bloquants || format(E'\n  %s.%s -> %s : %s ligne(s)', r.src, r.col, r.tgt, n);
    END IF;
  END LOOP;
  IF bloquants <> '' THEN
    RAISE EXCEPTION 'Purge arrêtée, rien n''a été supprimé. Le paramétrage utilise des données à supprimer :%', bloquants;
  END IF;
END $$;

-- fiches gardées (à vérifier : société LVME, utilisateurs…)
SELECT 'Tiers gardé' AS fiche, p.id, p.name FROM base_partner p
WHERE p.id IN (SELECT id FROM purge_garde WHERE tbl = 'base_partner')
UNION ALL
SELECT 'Article gardé', p.id, p.code || ' ' || p.name FROM base_product p
WHERE p.id IN (SELECT id FROM purge_garde WHERE tbl = 'base_product')
UNION ALL
SELECT 'Famille gardée', c.id, c.name FROM base_product_category c
WHERE c.id IN (SELECT id FROM purge_garde WHERE tbl = 'base_product_category')
ORDER BY 1, 2;

-- historique (messages / abonnements) des fiches supprimées
CREATE TEMP TABLE purge_modele ON COMMIT DROP AS
SELECT m.full_name AS modele, lower(m.table_name) AS tbl, (lower(m.table_name) IN (SELECT tbl FROM purge_partiel)) AS partiel
FROM meta_model m
WHERE lower(m.table_name) IN (SELECT tbl FROM purge_total UNION SELECT tbl FROM purge_partiel);

-- suppression : une seule instruction, les contrôles des clés se font à la fin (l'ordre n'a pas d'importance)
DO $$
DECLARE r record; sql text := ''; sel text := ''; i int := 0; res text;
BEGIN
  FOR r IN SELECT tbl, false AS partiel FROM purge_total UNION ALL SELECT tbl, true FROM purge_partiel ORDER BY 1 LOOP
    i := i + 1;
    sql := sql || CASE WHEN i = 1 THEN 'WITH ' ELSE ', ' END
      || format('d%s AS (DELETE FROM %s%s RETURNING 1)', i, r.tbl,
                CASE WHEN r.partiel THEN format(' WHERE id NOT IN (SELECT id FROM purge_garde WHERE tbl = %L)', r.tbl)
                     ELSE '' END);
    sel := sel || CASE WHEN i = 1 THEN '' ELSE ' || '' '' || ' END
      || format('%L || ''='' || (SELECT count(*) FROM d%s)', r.tbl, i);
  END LOOP;
  EXECUTE sql || ' SELECT ' || sel INTO res;
  RAISE NOTICE 'Lignes supprimées : %', res;
END $$;

DO $$
DECLARE n bigint;
BEGIN
  IF to_regclass('mail_message') IS NOT NULL THEN
    CREATE TEMP TABLE purge_message ON COMMIT DROP AS
    SELECT m.id FROM mail_message m JOIN purge_modele pm ON pm.modele = m.related_model
    WHERE NOT pm.partiel OR m.related_id NOT IN (SELECT id FROM purge_garde WHERE tbl = pm.tbl);
    IF to_regclass('mail_flags') IS NOT NULL THEN
      DELETE FROM mail_flags WHERE message IN (SELECT id FROM purge_message);
    END IF;
    WITH d AS (DELETE FROM mail_message WHERE id IN (SELECT id FROM purge_message) RETURNING 1)
    SELECT count(*) INTO n FROM d;
    RAISE NOTICE 'Messages supprimés : %', n;
  END IF;
  IF to_regclass('mail_follower') IS NOT NULL THEN
    DELETE FROM mail_follower f USING purge_modele pm WHERE pm.modele = f.related_model
      AND (NOT pm.partiel OR f.related_id NOT IN (SELECT id FROM purge_garde WHERE tbl = pm.tbl));
  END IF;
END $$;

-- compteurs (n° de commandes, d'achats, d'arrivages, de BL, de lots, de tiers, de factures…) remis à 1
UPDATE base_sequence_version SET next_num = 1, version = COALESCE(version, 0) + 1 WHERE next_num <> 1;

COMMIT;

-- contrôle : tout doit être à 0 (sauf les fiches gardées listées plus haut)
SELECT (SELECT count(*) FROM sale_sale_order) AS cdes_clients,
       (SELECT count(*) FROM purchase_purchase_order) AS cdes_fournisseurs,
       (SELECT count(*) FROM stock_stock_move) AS arrivages_bl,
       (SELECT count(*) FROM stock_tracking_number) AS lots,
       (SELECT count(*) FROM stock_stock_location_line) AS stock,
       (SELECT count(*) FROM account_invoice) AS factures,
       (SELECT count(*) FROM base_partner) AS tiers_gardes,
       (SELECT count(*) FROM base_product) AS articles_gardes,
       (SELECT count(*) FROM base_product_category) AS familles_gardees,
       (SELECT count(*) FROM base_sequence_version WHERE next_num <> 1) AS compteurs_non_remis;

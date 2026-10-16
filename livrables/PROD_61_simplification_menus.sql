-- =====================================================================
-- PROD étape 61 : simplification des menus (liste validée le 16/10, livrables/SIMPLIFICATION_MENUS.md)
--   - fiches et paramétrage (clients, fournisseurs, contacts, produits, emplacements, conditionnements…)
--     rangés dans le sous-menu Configuration de chaque module
--   - restent dans les menus métier : commandes, arrivages, listes, tableaux de bord, statistiques ;
--     État en-cours fournisseur, Synthèse risques clients et Export Coditour remontés hors Configuration
--   - MRP masqué (Achats et Stock)
--   Aucun menu supprimé (seulement le parent, l'ordre, ou « caché »). Arrêt sans rien modifier si un menu
--   ou un parent est introuvable.
-- Relançable. Pas de redémarrage nécessaire (recharger la page).
-- Après chaque déploiement : vérifier que les menus standard Axelor n'ont pas repris leur parent d'origine.
-- =====================================================================
BEGIN;

CREATE TEMP TABLE lvme_menus (menu text, parent text, ordre int) ON COMMIT DROP;
INSERT INTO lvme_menus VALUES
  -- Ventes -> Configuration
  ('sc-root-sale-customers',           'sc-root-sale-conf',       -40),
  ('sc-root-sale-contacts',            'sc-root-sale-conf',       -30),
  ('sc-root-sale-products',            'sc-root-sale-conf',       -20),
  ('sc-root-abc-analysis',             'sc-root-sale-conf',      1100),
  -- Achats -> Configuration
  ('sc-root-purchase-suppliers',       'sc-root-purchase-conf',   -40),
  ('sc-root-purchase-contacts',        'sc-root-purchase-conf',   -30),
  ('sc-root-purchase-products',        'sc-root-purchase-conf',   -20),
  ('Conditionnement',                  'sc-root-purchase-conf',   -10),
  ('stock-multi-purchase-invoicing',   'sc-root-purchase-conf',   300),
  ('purchase-root-abc-analysis',       'sc-root-purchase-conf',   400),
  ('lvme-menu-encours-fournisseur',    'sc-root-purchase',       1250),
  -- Stock -> Configuration
  ('stock-root-products',              'stock-root-conf',         -20),
  ('stock-root-stock-location',        'stock-root-conf',         -10),
  ('stock-root-search',                'stock-root-conf',        1300),
  -- CRM -> Configuration
  ('crm-root-customers',               'crm-conf',                -20),
  ('crm-root-contacts',                'crm-conf',                -10),
  -- Comptabilité : états remontés hors Configuration
  ('lvme-menu-synthese-risque-client', 'account-root-accounting', 400),
  ('lvme-menu-coditour-export',        'account-root-accounting', 500);

DO $$
DECLARE n int; manquants text;
BEGIN
  SELECT string_agg(x, ', ') INTO manquants FROM (
    SELECT l.menu AS x FROM lvme_menus l WHERE (SELECT count(*) FROM meta_menu m WHERE m.name = l.menu) <> 1
    UNION SELECT l.parent FROM lvme_menus l WHERE (SELECT count(*) FROM meta_menu m WHERE m.name = l.parent) <> 1
    UNION SELECT x FROM (VALUES ('purchase-mrp'), ('stock-mrp')) v(x) WHERE (SELECT count(*) FROM meta_menu m WHERE m.name = v.x) <> 1
  ) t;
  IF manquants IS NOT NULL THEN
    RAISE EXCEPTION 'menus introuvables ou en double : % — arrêt, rien n''est modifié', manquants;
  END IF;

  UPDATE meta_menu m
     SET parent = (SELECT p.id FROM meta_menu p WHERE p.name = l.parent), order_seq = l.ordre,
         updated_on = now(), version = COALESCE(m.version, 0) + 1
    FROM lvme_menus l
   WHERE m.name = l.menu
     AND (m.parent IS DISTINCT FROM (SELECT p.id FROM meta_menu p WHERE p.name = l.parent) OR m.order_seq IS DISTINCT FROM l.ordre);
  GET DIAGNOSTICS n = ROW_COUNT;
  RAISE NOTICE '% menu(s) déplacé(s)', n;

  UPDATE meta_menu SET hidden = true, updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE name IN ('purchase-mrp', 'stock-mrp') AND hidden IS DISTINCT FROM true;
  GET DIAGNOSTICS n = ROW_COUNT;
  RAISE NOTICE '% menu(s) masqué(s)', n;
END $$;

-- contrôle : chaque menu à sa place
SELECT l.menu, p.name AS parent, m.order_seq, (p.name = l.parent AND m.order_seq = l.ordre) AS ok
FROM lvme_menus l JOIN meta_menu m ON m.name = l.menu LEFT JOIN meta_menu p ON p.id = m.parent
ORDER BY l.parent, l.ordre;

COMMIT;

SELECT name, hidden FROM meta_menu WHERE name IN ('purchase-mrp', 'stock-mrp');

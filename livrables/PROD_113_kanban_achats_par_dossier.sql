-- =====================================================================
-- PROD étape 113 : Kanban « Suivi des commandes d'achat » classé par n° de dossier, le plus récent en haut
--   (demande du 29/10/2026). Axelor ne trie le Kanban que sur l'ordre des cartes (lvme_kanban_seq), vide sur
--   les commandes reprises : ordre = - n° de dossier. N° GESCOM « AAMM + numéro » (260926 = 2026, septembre,
--   dossier 26 ; 7 dossiers de 2021-2022 sur 3 chiffres : 2106106) : classé par AAMM puis numéro. Brouillons
--   (« #52174 ») : leurs chiffres. Les nouvelles commandes et les déplacements de cartes le recalculent dans le
--   code (PurchaseOrderSupplychainRepository.ordreKanban, même règle).
-- Données seulement : pas de redémarrage nécessaire. Relançable.
-- =====================================================================
BEGIN;

UPDATE purchase_purchase_order o
SET lvme_kanban_seq = x.ordre
FROM (SELECT id, CASE
        WHEN purchase_order_seq NOT LIKE '#%' AND length(c) IN (6, 7)
          THEN - (CAST(left(c, 4) AS integer) * 1000 + CAST(substr(c, 5) AS integer))
        ELSE - CAST(c AS integer) END AS ordre
      FROM (SELECT id, purchase_order_seq, regexp_replace(coalesce(purchase_order_seq, ''), '\D', '', 'g') AS c
            FROM purchase_purchase_order) n
      WHERE c ~ '^[0-9]{1,9}$') x
WHERE o.id = x.id AND o.lvme_kanban_seq IS DISTINCT FROM x.ordre;

COMMIT;

-- contrôle : commandes sans ordre de carte (attendu 1 : n° sans chiffre) ; les 5 premières cartes (dossiers 2026)
SELECT count(*) FILTER (WHERE lvme_kanban_seq IS NULL) AS sans_ordre, count(*) AS commandes FROM purchase_purchase_order;
SELECT purchase_order_seq, order_date, lvme_kanban_seq FROM purchase_purchase_order
WHERE purchase_order_seq NOT LIKE '#%' ORDER BY lvme_kanban_seq NULLS LAST LIMIT 5;

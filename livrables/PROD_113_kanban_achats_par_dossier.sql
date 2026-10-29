-- =====================================================================
-- PROD étape 113 : Kanban « Suivi des commandes d'achat » classé par n° de dossier, le plus récent en haut
--   (demande du 29/10/2026). Axelor ne trie le Kanban que sur l'ordre des cartes (lvme_kanban_seq), vide sur
--   les commandes reprises : ordre = - n° de dossier. Les nouvelles commandes et les déplacements de cartes le
--   recalculent dans le code (PurchaseOrderSupplychainRepository.save).
-- Données seulement : pas de redémarrage nécessaire. Relançable.
-- =====================================================================
BEGIN;

UPDATE purchase_purchase_order
SET lvme_kanban_seq = - CAST(regexp_replace(purchase_order_seq, '\D', '', 'g') AS integer)
WHERE regexp_replace(coalesce(purchase_order_seq, ''), '\D', '', 'g') ~ '^[0-9]{1,9}$'
  AND lvme_kanban_seq IS DISTINCT FROM - CAST(regexp_replace(purchase_order_seq, '\D', '', 'g') AS integer);

COMMIT;

-- contrôle : commandes sans ordre de carte (attendu 0) ; les 5 premières cartes
SELECT count(*) FILTER (WHERE lvme_kanban_seq IS NULL) AS sans_ordre, count(*) AS commandes FROM purchase_purchase_order;
SELECT purchase_order_seq, lvme_kanban_seq FROM purchase_purchase_order ORDER BY lvme_kanban_seq NULLS LAST LIMIT 5;

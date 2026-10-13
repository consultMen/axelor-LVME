-- =====================================================================
-- PROD étape 32 : retour client scénario 1, point 6 (commande d'achat)
--   Icône « Dupliquer la ligne » cliquable dès que la ligne est saisie, sans enregistrer
--   la commande à la main : le bouton enregistre la commande puis duplique la ligne
--   (le Java retrouve la ligne qui vient d'être enregistrée).
--   Reste grisée une fois la commande validée.
-- À lancer avec le code de ce lot, avant le redémarrage. Relançable.
-- =====================================================================
BEGIN;

UPDATE meta_view
   SET xml = replace(xml,
         'readonlyIf="id == null || $get(''purchaseOrder.statusSelect'') &gt; 2"',
         'readonlyIf="$get(''purchaseOrder.statusSelect'') &gt; 2"'),
       updated_on = now(), version = COALESCE(version, 0) + 1
 WHERE module IS NULL AND name = 'purchase-order-line-purchase-order-grid'
   AND position('readonlyIf="id == null || $get(''purchaseOrder.statusSelect'') &gt; 2"' IN xml) > 0;

COMMIT;

SELECT name, priority,
       position('lvmeDuplicateLineBtn' IN xml) > 0 AS bouton,
       position('id == null' IN xml) = 0 AS cliquable_sans_enregistrer
FROM meta_view WHERE module IS NULL AND name = 'purchase-order-line-purchase-order-grid'
ORDER BY priority;

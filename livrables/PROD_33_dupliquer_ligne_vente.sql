-- =====================================================================
-- PROD étape 33 : duplication de ligne de commande client, comme pour la commande d'achat (PROD_32)
--   - l'action de duplication des ventes avait un guillemet en trop dans son nom
--     (« action-lvme-sale-order-line-method-duplicate" ») : le bouton ne la trouvait pas
--   - icône « Dupliquer la ligne » cliquable dès que la ligne est saisie : le bouton enregistre
--     la commande puis duplique (le Java retrouve la ligne qui vient d'être enregistrée)
--   - reste grisée une fois la commande confirmée
-- À lancer avec le code de ce lot, avant le redémarrage. Relançable.
-- =====================================================================
BEGIN;

-- ---------- Action (nom corrigé) ----------
DELETE FROM meta_action WHERE module IS NULL
  AND name IN ('action-lvme-sale-order-line-method-duplicate"', 'action-lvme-sale-order-line-method-duplicate');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority)
VALUES (nextval('meta_action_seq'), 0, now(), 'action-lvme-sale-order-line-method-duplicate', 'action-method', NULL,
'<action-method name="action-lvme-sale-order-line-method-duplicate">
  <call class="com.axelor.apps.supplychain.web.SaleOrderLineDuplicateLvmeController" method="duplicateLine"/>
</action-method>', false, false, 0);

-- ---------- Icône cliquable sans enregistrer ----------
UPDATE meta_view
   SET xml = replace(xml,
         'readonlyIf="id == null || $get(''saleOrder.statusSelect'') &gt; 2"',
         'readonlyIf="$get(''saleOrder.statusSelect'') &gt; 2"'),
       updated_on = now(), version = COALESCE(version, 0) + 1
 WHERE module IS NULL AND name LIKE 'sale-order-line%grid%'
   AND position('readonlyIf="id == null || $get(''saleOrder.statusSelect'') &gt; 2"' IN xml) > 0;

COMMIT;

SELECT name, coalesce(module, 'admin') AS origine FROM meta_action WHERE name LIKE 'action-lvme-sale-order-line-method-duplicate%';
SELECT name, priority, position('id == null' IN xml) = 0 AS cliquable_sans_enregistrer
FROM meta_view WHERE module IS NULL AND name LIKE 'sale-order-line%grid%' AND position('lvmeDuplicateLineBtn' IN xml) > 0
ORDER BY name, priority;

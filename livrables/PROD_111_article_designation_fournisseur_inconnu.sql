-- =====================================================================
-- PROD étape 111 : remarques du 29/10/2026
--   - lignes de commande client : le champ Article et sa liste de saisie montrent « [CODE] Désignation » au lieu
--     du code seul (comme les lignes de commande d'achat et d'arrivage) ; avec le code à jour (Product.fullName),
--     la saisie cherche aussi dans la désignation, la référence fournisseur et le gencode
--   - « FOURNISSEUR INCONNU (GESCOM) » archivé : il n'apparaît plus dans les listes ni dans les choix de fournisseur.
--     Il reste sur les 56 arrivages GESCOM de 2014-2015 sans fournisseur valable dans GESCOM (46 sans code
--     fournisseur, 10 avec un code supprimé de GESCOM), sans stock restant.
-- À lancer depuis la racine du dépôt, Tomcat arrêté, puis redémarrer (vues en cache). Relançable.
-- =====================================================================
BEGIN;

UPDATE meta_view SET xml = replace(xml, 'target-name="code" title="Article"', 'title="Article"'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'sale-order-line-form' AND xml LIKE '%target-name="code" title="Article"%';

UPDATE base_partner SET archived = true, updated_on = now(), version = version + 1
WHERE import_id = 'GESCOM-FOU-INCONNU' AND archived IS NOT TRUE;

COMMIT;

-- contrôle : 0 champ Article en code seul ; fournisseur inconnu archivé
SELECT (length(xml) - length(replace(xml, 'target-name="code" title="Article"', '')))
  / length('target-name="code" title="Article"') AS article_code_seul
FROM meta_view WHERE module IS NULL AND name = 'sale-order-line-form';
SELECT name, archived FROM base_partner WHERE import_id = 'GESCOM-FOU-INCONNU';

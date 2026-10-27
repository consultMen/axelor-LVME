-- =====================================================================
-- PROD étape 88 : liste des commandes clients imprimable, listes Articles comme GESCOM
--   - bouton « Imprimer » de la liste des commandes clients : impression LVME (logo, colonnes de la liste dont
--     N° BL et Préparateur, mêmes filtres et alertes que l'écran, sommes du montant et de la marge)
--   - listes Articles (ventes et achats) : repère lvme-ges-art (présentation GESCOM sur un seul écran dans
--     css/lvme.css)
-- Prérequis : code avec LvmeImpressionListesController.imprimerCommandesClients et
-- reports/LvmeListeCommandesClients.rptdesign (recompiler) ; PROD_82. Sources : livrables/ui/commande-client-search-form.xml,
-- lvme-article-search-form.xml, lvme-article-achat-search-form.xml. Relançable.
-- =====================================================================
\set cdes `cat livrables/ui/commande-client-search-form.xml`
SELECT set_config('lvme.cde_recherche', :'cdes', false) IS NOT NULL AS commandes_lu;
\set art `cat livrables/ui/lvme-article-search-form.xml`
SELECT set_config('lvme.art', :'art', false) IS NOT NULL AS articles_lu;
\set arta `cat livrables/ui/lvme-article-achat-search-form.xml`
SELECT set_config('lvme.arta', :'arta', false) IS NOT NULL AS articles_achat_lu;

BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-cde-client-imprimer-liste';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-imprimer-liste', 'action-method', NULL,
'<action-method name="action-lvme-cde-client-imprimer-liste">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerCommandesClients"/>
</action-method>', false, false, 0);

UPDATE meta_view SET xml = current_setting('lvme.cde_recherche'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-commande-client-search-form' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.art'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-article-search-form' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.arta'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-article-achat-search-form' AND module IS NULL;

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND (
          (name = 'lvme-commande-client-search-form' AND xml LIKE '%imprimerListeBtn%')
          OR (name IN ('lvme-article-search-form', 'lvme-article-achat-search-form') AND xml LIKE '%lvme-ges-art%')))
       AS ecrans_modifies;

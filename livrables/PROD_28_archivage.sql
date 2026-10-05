-- =====================================================================
-- PROD étape 28 : archiver / désarchiver depuis les listes (demande client)
--   - listes Arrivages, Clients, Fournisseurs, Articles (ventes et achats) :
--       * boutons « Archiver » / « Désarchiver » dans la barre de la liste : agissent sur toutes les lignes cochées
--       * icône Archiver / Désarchiver sur chaque ligne
--   - une fiche archivée sort de la liste et des choix ; rien n'est supprimé ; désarchivée, elle revient
--   - pour retrouver les archivés : Arrivages > « Arrivages Archivés » ; Clients / Fournisseurs / Articles > case « Archivés »
--   - méthode Java LvmeArchivageController (code à déployer avec ce script)
-- Relance de PROD_9, PROD_11 et PROD_12 depuis leurs sources à jour (relançables).
-- À lancer depuis la racine du dépôt, puis redémarrer Axelor. Relançable.
-- =====================================================================
BEGIN;

-- ---------- Actions ----------
DELETE FROM meta_action WHERE module IS NULL
  AND (name LIKE 'action-lvme-archiver-%' OR name LIKE 'action-lvme-desarchiver-%' OR name = 'action-lvme-basculer-archivage');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom)
SELECT nextval('meta_action_seq'), 0, now(), v.name, 'action-method', NULL,
       '<action-method name="' || v.name || '">
  <call class="com.axelor.apps.base.web.LvmeArchivageController" method="' || v.method || '"/>
</action-method>', false, false
FROM (VALUES ('action-lvme-archiver-selection', 'archiver'),
             ('action-lvme-desarchiver-selection', 'desarchiver'),
             ('action-lvme-basculer-archivage', 'basculerArchivage')) AS v(name, method);

-- ---------- Nettoyage d'une version précédente (boutons sur les fiches, retirés : l'archivage se fait depuis la liste) ----------
UPDATE meta_view
   SET xml = regexp_replace(xml, '<panel name="lvmeArchivePanel".*?</panel>\s*', '', 's'),
       updated_on = now(), version = COALESCE(version, 0) + 1
 WHERE module IS NULL AND name IN ('partner-form', 'product-form') AND position('lvmeArchivePanel' IN xml) > 0;
DELETE FROM meta_view WHERE module IS NULL AND name = 'tracking-number-form' AND position('lvmeArchivePanel' IN xml) > 0;
COMMIT;

-- ---------- Écrans ----------
\i livrables/PROD_9_arrivages.sql
\i livrables/PROD_11_listes_tiers_articles.sql
\i livrables/PROD_12_recherche_tiers_articles.sql

SELECT name, position('lvmeArchiverSelBtn' IN xml) > 0 AS barre, position('lvmeArchiverBtn' IN xml) > 0 AS icone_ligne
FROM meta_view
WHERE module IS NULL AND name IN ('lvme-arrivage-grid', 'partner-customer-grid', 'partner-supplier-grid', 'product-grid', 'product-purchase-grid')
ORDER BY name;

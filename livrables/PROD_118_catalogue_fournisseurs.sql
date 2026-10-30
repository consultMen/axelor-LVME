-- =====================================================================
-- PROD étape 118 : écran « Catalogue fournisseurs » (menu Achats), consultation du catalogue repris de GESCOM
--   (FOUART, MIG_09) : Fournisseur, Article, Désignation, Réf. fournisseur, Prix d'achat, Unité, Prix de revient,
--   Dernière commande, Origine, Zone, Cond., Poids colis, Marque, Gencode ; filtres et tri dans les en-têtes.
--   Consultation seule ; la saisie des commandes d'achat ne change pas. Fiche propre (lvme-catalogue-fournisseur-form) :
--   la fiche Axelor ne s'ouvre que depuis une fiche article ou tiers (erreur « Cannot get property '_model' »).
-- Prérequis : MIG_09 ; code avec les champs LVME du catalogue (SupplierCatalog). À lancer depuis la racine du dépôt,
-- Tomcat arrêté, puis redémarrer. Sources : livrables/ui/lvme-catalogue-fournisseur-grid.xml, -form.xml. Relançable.
-- =====================================================================
\set gCat `cat livrables/ui/lvme-catalogue-fournisseur-grid.xml`
SELECT set_config('lvme.gCat', :'gCat', false) IS NOT NULL AS liste_lue;
\set fCat `cat livrables/ui/lvme-catalogue-fournisseur-form.xml`
SELECT set_config('lvme.fCat', :'fCat', false) IS NOT NULL AS fiche_lue;

BEGIN;

DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-catalogue-fournisseur-grid', 'lvme-catalogue-fournisseur-form');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-catalogue-fournisseur-grid', 'Catalogue fournisseurs', 'grid',
 'com.axelor.apps.purchase.db.SupplierCatalog', 20, current_setting('lvme.gCat'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-catalogue-fournisseur-form', 'Catalogue fournisseur', 'form',
 'com.axelor.apps.purchase.db.SupplierCatalog', 20, current_setting('lvme.fCat'), false, false);

UPDATE meta_menu SET action = NULL WHERE action IN (SELECT id FROM meta_action WHERE module IS NULL
  AND name = 'action-lvme-catalogue-fournisseur-open');
DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-catalogue-fournisseur-open';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-catalogue-fournisseur-open', 'action-view',
 'com.axelor.apps.purchase.db.SupplierCatalog',
'<action-view name="action-lvme-catalogue-fournisseur-open" title="Catalogue fournisseurs"
  model="com.axelor.apps.purchase.db.SupplierCatalog">
  <view type="grid" name="lvme-catalogue-fournisseur-grid"/>
  <view type="form" name="lvme-catalogue-fournisseur-form"/>
</action-view>', false, false, 0);

DELETE FROM meta_menu WHERE name = 'lvme-menu-catalogue-fournisseurs';
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, hidden, left_menu, mobile_menu, priority)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-catalogue-fournisseurs', 'Catalogue fournisseurs',
  (SELECT id FROM meta_menu WHERE name = 'sc-root-purchase' ORDER BY id LIMIT 1),
  (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-catalogue-fournisseur-open'),
  coalesce((SELECT order_seq + 5 FROM meta_menu WHERE name = 'lvme-menu-encours-fournisseur'), 1255), false, true, false, 0;

COMMIT;

-- contrôle : 2 | 1 | 1
SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND name LIKE 'lvme-catalogue-fournisseur-%') AS vues,
  (SELECT count(*) FROM meta_action WHERE module IS NULL AND name = 'action-lvme-catalogue-fournisseur-open') AS action,
  (SELECT count(*) FROM meta_menu WHERE name = 'lvme-menu-catalogue-fournisseurs' AND action IS NOT NULL) AS menu;

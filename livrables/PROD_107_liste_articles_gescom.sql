-- =====================================================================
-- PROD étape 107 : loupe « Article » des lignes comme GESCOM
--   La loupe du champ Article des lignes de commande client, de commande d'achat et d'arrivage ouvre la liste
--   « Articles » de GESCOM (Référence, Désignation article, Fournisseur, Référence Fournisseur, Gencode, Unité, Poids
--   Unitaire, Poids Colis, P.Vente HT, P.Vente TTC, Commentaires) au lieu de la liste « Produits » d'Axelor ; un clic
--   sur un article le choisit et ferme la liste (js/lvme.js), lignes blanc / gris (css/lvme.css).
--   Seul l'attribut grid-view du champ Article change dans les 3 fiches. Prérequis : code avec js/lvme.js et
--   css/lvme.css à jour (déploiement du war). À lancer depuis la racine du dépôt. Source :
--   livrables/ui/lvme-article-selection-grid.xml. Relançable.
-- =====================================================================
\set gArt `cat livrables/ui/lvme-article-selection-grid.xml`
SELECT set_config('lvme.gArt', :'gArt', false) IS NOT NULL AS liste_lue;

BEGIN;

DELETE FROM meta_view WHERE module IS NULL AND name = 'lvme-article-selection-grid';
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-article-selection-grid', 'Articles', 'grid',
 'com.axelor.apps.base.db.Product', 20, current_setting('lvme.gArt'), false, false);

-- champ Article des lignes de commande client (deux variantes selon l'appli supplychain) et d'arrivage
UPDATE meta_view SET xml = replace(replace(xml,
    'form-view="product-form" grid-view="product-grid" x-image-field="picture"',
    'form-view="product-form" grid-view="lvme-article-selection-grid" x-image-field="picture"'),
    'form-view="product-form" grid-view="stock-move-line-product-grid" x-image-field="picture"',
    'form-view="product-form" grid-view="lvme-article-selection-grid" x-image-field="picture"'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name IN ('sale-order-line-form', 'lvme-arrivage-line-form');
-- champ Article des lignes de commande d'achat
UPDATE meta_view SET xml = replace(xml,
    'form-view="product-form" grid-view="product-purchase-grid" x-image-field="picture"',
    'form-view="product-form" grid-view="lvme-article-selection-grid" x-image-field="picture"'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-commande-achat-line-form';

COMMIT;

-- contrôle : nombre de champs Article branchés sur la liste GESCOM (attendu : 2, 1, 1 ; 0 ancienne liste)
SELECT name,
  (length(xml) - length(replace(xml, 'grid-view="lvme-article-selection-grid"', '')))
    / length('grid-view="lvme-article-selection-grid"') AS liste_gescom,
  (length(xml) - length(replace(xml, 'grid-view="stock-move-line-product-grid"', '')))
    / length('grid-view="stock-move-line-product-grid"') AS ancienne_liste
FROM meta_view
WHERE module IS NULL AND name IN ('sale-order-line-form', 'lvme-commande-achat-line-form', 'lvme-arrivage-line-form')
ORDER BY name;

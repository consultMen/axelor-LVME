-- =====================================================================
-- MIG_11 : sous-familles d'articles GESCOM (table SFAMILLE_ARTICLES, colonne IDSFAMART des articles)
--   14 sous-familles dans GESCOM (CREVETTE 2/4 - 800G, F.SOLE TROP PF 90/120, PRODUITS CARNES…) :
--   - liste de choix lvme.product.sous.famille.select : code GESCOM et libellé, sans « NEANT » (= pas de sous-famille) ;
--   - sous-famille de chaque article (Product.lvmeSousFamille = code GESCOM) : 48 articles.
--   La fiche Produit n'est pas modifiée (en attente des captures GESCOM) : le champ sera affiché à ce moment-là.
-- Prérequis : MIG_00 (archive), MIG_01 (articles). Colonne créée si besoin (avant le premier démarrage du code).
-- Tomcat arrêté. Relançable.
-- =====================================================================
BEGIN;

ALTER TABLE base_product ADD COLUMN IF NOT EXISTS lvme_sous_famille varchar(255);

-- liste des sous-familles (code GESCOM -> libellé)
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.product.sous.famille.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.product.sous.famille.select');
DELETE FROM meta_select_item WHERE select_id = (SELECT id FROM meta_select WHERE name = 'lvme.product.sous.famille.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, (SELECT id FROM meta_select WHERE name = 'lvme.product.sous.famille.select'),
  btrim(s.code), btrim(s.libelle), gescom.num(s.idsfamart)::int
FROM gescom.sfamille_articles s
WHERE gescom.txt(s.code) IS NOT NULL AND upper(btrim(s.libelle)) <> 'NEANT';

-- sous-famille des articles (NEANT et sans sous-famille : vide)
UPDATE base_product p SET lvme_sous_famille = x.code, version = p.version + 1, updated_on = now()
FROM (SELECT upper(btrim(a.ref)) AS ref, btrim(s.code) AS code
      FROM gescom.articles a
      JOIN gescom.sfamille_articles s ON btrim(s.idsfamart) = btrim(a.idsfamart)
      WHERE upper(btrim(s.libelle)) <> 'NEANT') x
WHERE p.code = x.ref AND p.lvme_sous_famille IS DISTINCT FROM x.code;

COMMIT;

-- contrôle : 13 sous-familles ; 48 articles avec une sous-famille
SELECT (SELECT count(*) FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
        WHERE s.name = 'lvme.product.sous.famille.select') AS sous_familles,
  (SELECT count(*) FROM base_product WHERE lvme_sous_famille IS NOT NULL) AS articles;
SELECT i.value AS code, i.title AS sous_famille, count(p.id) AS articles
FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
LEFT JOIN base_product p ON p.lvme_sous_famille = i.value
WHERE s.name = 'lvme.product.sous.famille.select' GROUP BY i.value, i.title, i.order_seq ORDER BY i.order_seq;

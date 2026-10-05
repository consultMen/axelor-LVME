-- =====================================================================
-- PROD étape 30 : nom complet des articles (en-tête de la fiche, choix d'article dans les commandes)
--   La reprise GESCOM a enregistré le nom complet avec l'ancien numéro interne ([1000] COFFRE DE HOMARDS)
--   au lieu de la référence (HOMACOFF999). Axelor le recalcule à chaque enregistrement d'un article ;
--   ce script le recalcule pour tous les articles, au même format : [référence] désignation.
--   Seul le nom complet change : référence, désignation et documents existants restent intacts.
-- Relançable. Pas de redémarrage nécessaire.
-- =====================================================================
BEGIN;

SELECT count(*) AS a_corriger FROM base_product
WHERE code IS NOT NULL AND name IS NOT NULL
  AND full_name IS DISTINCT FROM '[' || code || '] ' || name;

UPDATE base_product
   SET full_name = '[' || code || '] ' || name,
       updated_on = now(), version = COALESCE(version, 0) + 1
 WHERE code IS NOT NULL AND name IS NOT NULL
   AND full_name IS DISTINCT FROM '[' || code || '] ' || name;

COMMIT;

SELECT id, code, name, full_name FROM base_product WHERE code IS NULL OR name IS NULL;

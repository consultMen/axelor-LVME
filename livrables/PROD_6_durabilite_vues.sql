-- =====================================================================
-- PROD étape 6 : rendre durables les vues modifiées directement (vues calculées « bleues »
-- ou vues de base de module), pour qu'une mise à jour des modules ne les efface pas.
--
-- Principe : on copie la version ACTUELLE de chaque vue dans une vue admin (module vide)
-- de priorité 30. Axelor sert la vue de plus haute priorité : la copie admin prend le relais,
-- et une mise à jour des modules (qui régénère les vues de module) ne la touche pas.
-- Rien ne change à l'écran aujourd'hui : c'est le même contenu.
-- Limite : si une future version d'AOS modifie ces écrans, il faudra reporter ses
-- nouveautés dans ces copies (ou supprimer la copie).
--
--   stock-move-form          : réception / BL, symbole de devise, mise en page sans onglets
--   purchase-order-form      : devise d'achat / devise comptable
--   stock-move-line-form     : ligne de BL, conditionnement vente + marge
-- Relançable : ne crée pas de doublon. Une seule transaction.
-- =====================================================================
BEGIN;

INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed)
SELECT nextval('meta_view_seq'), 0, now(), v.name, v.title, v.type, v.model, 30, v.xml, false, false
FROM (
  SELECT DISTINCT ON (name) name, title, type, model, xml
  FROM meta_view
  WHERE name IN ('stock-move-form', 'purchase-order-form', 'stock-move-line-form')
    AND module IS NOT NULL AND COALESCE(extension, false) = false
  ORDER BY name, priority DESC, COALESCE(computed, false) DESC
) v
WHERE NOT EXISTS (SELECT 1 FROM meta_view a WHERE a.name = v.name AND a.module IS NULL AND a.priority = 30);

COMMIT;

-- Vérification : la vue servie (plus haute priorité) doit être la copie admin de priorité 30,
-- avec le même contenu que la vue de module qu'elle remplace
SELECT a.name, a.priority, 'admin' AS module,
       a.xml = (SELECT m.xml FROM meta_view m
                WHERE m.name = a.name AND m.module IS NOT NULL AND COALESCE(m.extension, false) = false
                ORDER BY m.priority DESC, COALESCE(m.computed, false) DESC LIMIT 1) AS contenu_identique
FROM meta_view a
WHERE a.name IN ('stock-move-form', 'purchase-order-form', 'stock-move-line-form')
  AND a.module IS NULL AND a.priority = 30
ORDER BY a.name;

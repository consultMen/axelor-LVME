-- =====================================================================
-- PROD étape 17 : écrans de recherche LVME — la fiche s'ouvre dans une fenêtre par-dessus la liste
--   Avant : double-clic sur une ligne = nouvel onglet dont la flèche « retour » ne marche pas
--   (la liste de l'écran de recherche dépend de ses filtres). Maintenant : fenêtre (Fermer / Ok),
--   la liste et les filtres restent en place. Commandes clients, achats, arrivages : fenêtre plein écran.
-- Actions seulement (déjà intégré dans les scripts PROD_9, 10, 12 à 15 pour leurs relances ;
-- après une relance de PROD_2, relancer ce script).
-- À lancer depuis la racine du dépôt, puis redémarrer Axelor (cache des actions). Relançable.
-- =====================================================================
BEGIN;

-- 1. retire d'éventuels réglages mal placés (relance)
UPDATE meta_action
SET xml = regexp_replace(xml, '\s*<view-param name="popup(-save|\.maximized)?" value="true"/>', '', 'g')
WHERE module IS NULL AND type = 'action-view' AND name LIKE 'action-lvme-%-dashlet' AND xml LIKE '%name="popup%';

-- 2. les place juste après les vues (Axelor exige : vues, puis view-param, puis domain / context)
UPDATE meta_action
SET xml = regexp_replace(xml, '(<view type="form" name="[^"]+"/>)',
      '\1' || chr(10) || '  <view-param name="popup" value="true"/>'
      || chr(10) || '  <view-param name="popup-save" value="true"/>'
      || CASE WHEN name IN ('action-lvme-arrivage-dashlet', 'action-lvme-achat-dashlet', 'action-lvme-cde-client-dashlet')
              THEN chr(10) || '  <view-param name="popup.maximized" value="true"/>' ELSE '' END),
    version = version + 1, updated_on = now()
WHERE module IS NULL AND type = 'action-view'
  AND name IN ('action-lvme-client-dashlet', 'action-lvme-fournisseur-dashlet', 'action-lvme-article-dashlet',
               'action-lvme-article-achat-dashlet', 'action-lvme-cde-client-dashlet', 'action-lvme-achat-dashlet',
               'action-lvme-arrivage-dashlet', 'action-lvme-lots-verifies-dashlet', 'action-lvme-etat-stock-lot-dashlet',
               'action-lvme-rotation-stock-dashlet', 'action-lvme-historique-produit-dashlet',
               'action-lvme-synthese-arrivage-dashlet');

COMMIT;

SELECT name, (xml LIKE '%name="popup"%') AS fenetre, (xml LIKE '%popup.maximized%') AS plein_ecran,
       (position('<view-param name="popup"' IN xml) < GREATEST(position('<domain>' IN xml), position('<context' IN xml), 1)
        OR (position('<domain>' IN xml) = 0 AND position('<context' IN xml) = 0)) AS bien_place
FROM meta_action
WHERE module IS NULL AND name LIKE 'action-lvme-%-dashlet'
ORDER BY name;

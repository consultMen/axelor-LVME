-- =====================================================================
-- PROD étape 38 : fiche Arrivage — bouton « Appliquer à toutes les lignes » sous le Frigo
--   Met le frigo de l'en-tête sur toutes les lignes de l'arrivage (tous statuts sauf réalisé) ;
--   arrivage planifié : stock prévisionnel des frigos recalculé (Java LvmeArrivageFrigoController).
--   Caché une fois l'arrivage réalisé.
--   Titre de la liste des lignes : « Lignes d'arrivage » (au lieu de « Lignes de BR »).
-- Relance PROD_9 depuis sa source à jour (livrables/ui/arrivage-form.xml).
-- À lancer depuis la racine du dépôt, avec le code de ce lot, avant le redémarrage. Relançable.
-- =====================================================================
BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-arrivage-appliquer-frigo';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority)
VALUES (nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-appliquer-frigo', 'action-method', NULL,
'<action-method name="action-lvme-arrivage-appliquer-frigo">
  <call class="com.axelor.apps.stock.web.LvmeArrivageFrigoController" method="appliquerFrigo"/>
</action-method>', false, false, 0);

-- ---------- Titre de la liste des lignes : « Lignes d'arrivage » au lieu de « Lignes de BR » ----------
-- (Axelor remplace le titre à l'ouverture par la traduction de « Incoming move lines »)
UPDATE meta_translation SET message_value = 'Lignes d''arrivage', version = COALESCE(version, 0) + 1
 WHERE message_key = 'Incoming move lines' AND language = 'fr';
INSERT INTO meta_translation (id, version, message_key, message_value, language)
SELECT nextval('meta_translation_seq'), 0, 'Incoming move lines', 'Lignes d''arrivage', 'fr'
WHERE NOT EXISTS (SELECT 1 FROM meta_translation WHERE message_key = 'Incoming move lines' AND language = 'fr');

COMMIT;

\i livrables/PROD_9_arrivages.sql

SELECT name, position('lvmeAppliquerFrigoBtn' IN xml) > 0 AS bouton_frigo
FROM meta_view WHERE module IS NULL AND name = 'lvme-arrivage-form';

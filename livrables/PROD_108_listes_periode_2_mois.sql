-- =====================================================================
-- PROD étape 108 : période par défaut de 2 mois à l'ouverture des listes (demande du 29/10/2026)
--   - Listes Commandes Clients : Date du = aujourd'hui - 2 mois, au = aujourd'hui
--   - Liste des achats fournisseurs : Date du = aujourd'hui - 2 mois, au = aujourd'hui
--   - Arrivages : Arrivée du = aujourd'hui - 2 mois, sans date de fin (arrivages des 2 derniers mois et flottants à
--     venir) ; « Date du » des arrivages est la date de création dans LVME (jour de la migration pour l'historique)
--   L'utilisateur change ou vide les dates pour filtrer autrement. Redémarrer Tomcat après (actions en cache). Relançable.
-- =====================================================================
BEGIN;

UPDATE meta_action SET xml = '<action-attrs name="action-lvme-cde-client-defaults">
  <attribute name="value" for="$dateDu" expr="eval: __date__.minusMonths(2)"/>
  <attribute name="value" for="$dateAu" expr="eval: __date__"/>
</action-attrs>', updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'action-lvme-cde-client-defaults';

UPDATE meta_action SET xml = '<action-attrs name="action-lvme-achat-defaults">
  <attribute name="value" for="$dateDu" expr="eval: __date__.minusMonths(2)"/>
  <attribute name="value" for="$dateAu" expr="eval: __date__"/>
</action-attrs>', updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'action-lvme-achat-defaults';

UPDATE meta_action SET xml = '<action-attrs name="action-lvme-arrivage-defaults">
  <attribute name="value" for="$arriveeDu" expr="eval: __date__.minusMonths(2)"/>
</action-attrs>', updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'action-lvme-arrivage-defaults';

COMMIT;

SELECT name, xml LIKE '%minusMonths(2)%' AS periode_2_mois FROM meta_action
WHERE module IS NULL AND name IN ('action-lvme-cde-client-defaults', 'action-lvme-achat-defaults',
  'action-lvme-arrivage-defaults') ORDER BY name;

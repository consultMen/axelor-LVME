-- =====================================================================
-- PROD étape 109 : État des stocks par lots comme GESCOM (demande du 29/10/2026)
--   - barre des totaux en bas de la liste : Nb colis entrées / sorties / cdes / stock, Unt/Poids stock, Montant HT
--     stock, Nb colis dispo, Unt/Poids dispo, sur TOUS les lots filtrés ; recalculés à chaque recherche
--     (« Lancer la recherche », N° lot, périodes prédéfinies, boutons DLUO) et à l'ouverture
--   - bandeau DLUO : bouton « Voir périmés + DLUO proche » (les deux à la fois), en plus des deux boutons existants
--   - la liste prend toute la hauteur de l'écran, totaux et boutons d'impression collés en bas (css/lvme.css)
--   Les impressions des listes passent en Excel dans le code (LvmeImpressionListesController.ouvrir), rien en base.
-- Prérequis : PROD_104 ; code avec LvmeImpressionListesController.totauxEtatStock et css/lvme.css à jour
-- (recompiler). À lancer depuis la racine du dépôt, Tomcat arrêté, puis redémarrer. Source :
-- livrables/ui/etat-stock-lot-search-form.xml. Relançable.
-- =====================================================================
\set fEtat `cat livrables/ui/etat-stock-lot-search-form.xml`
SELECT set_config('lvme.fEtat', :'fEtat', false) IS NOT NULL AS vue_etat_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.fEtat'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-etat-stock-lot-search-form' AND module IS NULL;

-- « recherche » de l'écran : totaux + rafraîchissement de la liste (avant : rafraîchissement seul)
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-etat-stock-lot-refresh',
  'action-lvme-etat-stock-lot-group-onnew', 'action-lvme-etat-stock-lot-attrs-dluo-tous',
  'action-lvme-etat-stock-lot-group-dluo-tous');
-- bouton « Voir périmés + DLUO proche » du bandeau DLUO : filtre DLUO « Dépassées + moins de 30 jours »
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-attrs-dluo-tous', 'action-attrs', NULL,
'<action-attrs name="action-lvme-etat-stock-lot-attrs-dluo-tous">
  <attribute name="value" for="$dluoFiltre" expr="eval: 3"/>
  <attribute name="value" for="$etatLot" expr="eval: 1"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-group-dluo-tous', 'action-group', NULL,
'<action-group name="action-lvme-etat-stock-lot-group-dluo-tous">
  <action name="action-lvme-etat-stock-lot-attrs-dluo-tous"/>
  <action name="action-lvme-etat-stock-lot-refresh"/>
</action-group>', false, false, 0);
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-refresh', 'action-method', NULL,
'<action-method name="action-lvme-etat-stock-lot-refresh">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="totauxEtatStock"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-etat-stock-lot-group-onnew">
  <action name="action-lvme-etat-stock-lot-defaults"/>
  <action name="action-lvme-etat-stock-lot-alertes-dluo"/>
  <action name="action-lvme-etat-stock-lot-info-dluo"/>
  <action name="action-lvme-etat-stock-lot-depuis-ligne" if="_produitId"/>
  <action name="action-lvme-etat-stock-lot-refresh"/>
</action-group>', false, false, 0);

COMMIT;

SELECT name, type FROM meta_action WHERE module IS NULL
  AND name IN ('action-lvme-etat-stock-lot-refresh', 'action-lvme-etat-stock-lot-group-onnew') ORDER BY name;
SELECT name, xml LIKE '%totauxPanel%' AS barre_totaux FROM meta_view
WHERE module IS NULL AND name = 'lvme-etat-stock-lot-search-form';

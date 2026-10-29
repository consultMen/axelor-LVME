-- =====================================================================
-- PROD étape 116 : période par défaut de 2 mois et totaux à l'ouverture (demande du 29/10/2026)
--   - Historique Produit : Entrée du = aujourd'hui - 2 mois (avant : 3 ans), au = aujourd'hui ; les totaux du bas
--     (Total colis, Stock période, Poids entrées / sorties) et la liste sont calculés dès l'ouverture, sans
--     cliquer sur Valider (avant : seulement en venant d'une ligne avec un produit)
--   - Rotation des stocks : Entrée du = aujourd'hui - 2 mois, au = aujourd'hui (liste des lots, rafraîchie à
--     l'ouverture)
--   - État des stocks par lots : Entrée du = aujourd'hui - 2 mois, au = aujourd'hui ; liste et totaux du bas
--     limités aux lots entrés sur la période (vider les dates pour tout le stock)
--   L'utilisateur change ou vide les dates pour filtrer autrement. Tomcat arrêté, puis redémarrer. Relançable.
-- =====================================================================
BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-historique-produit-defaults',
  'action-lvme-historique-produit-group-onnew', 'action-lvme-rotation-lot-defaults',
  'action-lvme-etat-stock-lot-defaults', 'action-lvme-rotation-stock-group-onnew');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-historique-produit-defaults">
  <attribute name="value" for="$entreeDu" expr="eval: __date__.minusMonths(2)"/>
  <attribute name="value" for="$entreeAu" expr="eval: __date__"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-produit-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-historique-produit-group-onnew">
  <action name="action-lvme-historique-produit-defaults"/>
  <action name="action-lvme-historique-produit-depuis-ligne" if="_produitId"/>
  <action name="action-lvme-historique-produit-designation" if="_produitId"/>
  <action name="action-lvme-historique-produit-valider"/>
</action-group>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-lot-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-rotation-lot-defaults">
  <attribute name="value" for="$affichage" expr="eval: 1"/>
  <attribute name="value" for="$entreeDu" expr="eval: __date__.minusMonths(2)"/>
  <attribute name="value" for="$entreeAu" expr="eval: __date__"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-stock-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-rotation-stock-group-onnew">
  <action name="action-lvme-rotation-lot-defaults"/>
  <action name="action-lvme-rotation-stock-kpi"/>
  <action name="action-lvme-rotation-stock-refresh"/>
</action-group>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-etat-stock-lot-defaults">
  <attribute name="value" for="$natureArrivage" expr="eval: 0"/>
  <attribute name="value" for="$etatLot" expr="eval: 1"/>
  <attribute name="value" for="$entreeDu" expr="eval: __date__.minusMonths(2)"/>
  <attribute name="value" for="$entreeAu" expr="eval: __date__"/>
</action-attrs>', false, false, 0);

COMMIT;

-- contrôle : 3 actions avec la période de 2 mois ; Valider à l'ouverture de l'Historique Produit
SELECT count(*) FILTER (WHERE xml LIKE '%minusMonths(2)%') AS periode_2_mois,
  bool_or(name = 'action-lvme-historique-produit-group-onnew'
          AND xml LIKE '%<action name="action-lvme-historique-produit-valider"/>%') AS totaux_ouverture
FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-historique-produit-defaults',
  'action-lvme-historique-produit-group-onnew', 'action-lvme-rotation-lot-defaults', 'action-lvme-etat-stock-lot-defaults');

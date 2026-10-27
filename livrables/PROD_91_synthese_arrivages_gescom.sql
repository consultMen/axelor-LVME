-- =====================================================================
-- PROD étape 91 : « Synthèse des Arrivages » comme GESCOM, sur un seul écran
--   - écran : N° d'arrivage du / au, cadre Arrivée jaune, Lancer la recherche, Fermer à droite ; liste sur toute la
--     hauteur avec la ligne de l'arrivage en blanc, les lignes produit cyan au texte violet et les totaux de
--     l'arrivage (couleurs dans css/lvme.css, repère lvme-ges-synth)
--   - bouton « Synthèse » en bas à droite : impression LVME (logo, en-tête par arrivage, lignes, totaux)
-- Prérequis : code avec LvmeImpressionListesController.imprimerSyntheseArrivages et
-- reports/LvmeSyntheseArrivages.rptdesign (recompiler) ; PROD_15. Sources : livrables/ui/lvme-synthese-arrivage-form.xml,
-- lvme-synthese-arrivage-grid.xml. Relançable.
-- =====================================================================
\set synth `cat livrables/ui/lvme-synthese-arrivage-form.xml`
SELECT set_config('lvme.synth_form', :'synth', false) IS NOT NULL AS ecran_lu;
\set synthg `cat livrables/ui/lvme-synthese-arrivage-grid.xml`
SELECT set_config('lvme.synth_grid', :'synthg', false) IS NOT NULL AS liste_lue;

BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-synthese-arrivage-imprimer';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-synthese-arrivage-imprimer', 'action-method', NULL,
'<action-method name="action-lvme-synthese-arrivage-imprimer">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerSyntheseArrivages"/>
</action-method>', false, false, 0);

UPDATE meta_view SET xml = current_setting('lvme.synth_form'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-synthese-arrivage-form' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.synth_grid'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-synthese-arrivage-grid' AND module IS NULL;

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND (
          (name = 'lvme-synthese-arrivage-form' AND xml LIKE '%lvme-ges-synth%')
          OR (name = 'lvme-synthese-arrivage-grid' AND xml NOT LIKE '%color="pink"%'))) AS ecrans_modifies,
       (SELECT count(*) FROM meta_action WHERE module IS NULL
          AND name = 'action-lvme-synthese-arrivage-imprimer') AS actions;

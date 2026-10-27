-- =====================================================================
-- PROD étape 92 : « Listes Dossiers » et « Lots Vérifiés » comme GESCOM, sur un seul écran
--   - Listes Dossiers : cadre Recherche (Type doc / client / transporteur, Livraison du / au, BL facturés, Détail
--     produits, Lancer la recherche), boutons Quitter / Nouveau BL / Nouveau retour / Suppression à droite,
--     Recherche direct par N° sous le cadre, liste blanc / bleu très clair sur toute la hauteur
--   - Lots Vérifiés : Référence Produit ou Lot n° (violet), cadres Entrées et Sélection, Afficher Lots / Fermer à
--     droite, liste blanc / gris, en bas N° Lot et Lot vérifié / non vérifié encadrés d'orange, Valider / Annuler
--   (couleurs dans css/lvme.css, repères lvme-ges-dossiers et lvme-ges-lots-verif)
-- Prérequis : PROD_13, PROD_23. Sources : livrables/ui/dossiers-search-form.xml, lvme-lots-verifies-form.xml,
-- lvme-lots-verifies-grid.xml. Relançable. Sans code Java.
-- =====================================================================
\set dossiers `cat livrables/ui/dossiers-search-form.xml`
SELECT set_config('lvme.dossiers', :'dossiers', false) IS NOT NULL AS dossiers_lu;
\set lots `cat livrables/ui/lvme-lots-verifies-form.xml`
SELECT set_config('lvme.lots_verif', :'lots', false) IS NOT NULL AS lots_lu;
\set lotsg `cat livrables/ui/lvme-lots-verifies-grid.xml`
SELECT set_config('lvme.lots_verif_grid', :'lotsg', false) IS NOT NULL AS lots_liste_lue;

BEGIN;

DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-lots-verifies-annuler';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-lots-verifies-annuler', 'action-attrs', 'com.axelor.utils.db.Wizard',
'<action-attrs name="action-lvme-lots-verifies-annuler">
  <attribute name="value" for="$lotAVerifier" expr="eval: null"/>
  <attribute name="value" for="$verification" expr="eval: 1"/>
</action-attrs>', false, false, 0);

UPDATE meta_view SET xml = current_setting('lvme.dossiers'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-dossiers-search-form' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.lots_verif'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-lots-verifies-form' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.lots_verif_grid'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-lots-verifies-grid' AND module IS NULL;

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND (
          (name = 'lvme-dossiers-search-form' AND xml LIKE '%lvme-ges-dossiers%')
          OR (name = 'lvme-lots-verifies-form' AND xml LIKE '%lvme-ges-lots-verif%')
          OR (name = 'lvme-lots-verifies-grid' AND xml NOT LIKE '%hilite%'))) AS ecrans_modifies,
       (SELECT count(*) FROM meta_action WHERE module IS NULL AND name = 'action-lvme-lots-verifies-annuler') AS actions;

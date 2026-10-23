-- =====================================================================
-- PROD étape 75 : « Etat des stocks par lots » et « liste des achats fournisseurs » aux couleurs GESCOM
--   - Etat des stocks : fond bleu clair, cadres de dates jaune pâle, lignes blanc / cyan (texte violet), en-têtes
--     bleus ; choix Arrivage / Lots / DLUO à l'horizontale sur une ligne (écran resserré) ; colonnes dans l'ordre GESCOM avec les intitulés GESCOM, + Nb colis Dispo et Unt/Poids Dispo ;
--     Nb colis Stock et Nb colis Dispo en jaune ; alertes DLUO (rouge / orange) et boutons des lots périmés conservés
--   - liste des achats : cadres de dates lavande, lignes jaune pâle / blanc, en-têtes bleus
-- Sources : livrables/ui/etat-stock-lot-grid.xml, livrables/ui/etat-stock-lot-search-form.xml, livrables/ui/achat-search-form.xml (PROD_70) ; couleurs dans
--   css/lvme.css (recompiler). Prérequis : code avec EtatStockLot.nbColisDispo. Depuis la racine du dépôt. Relançable.
-- =====================================================================
\set grille `cat livrables/ui/etat-stock-lot-grid.xml`
SELECT set_config('lvme.etat_grille', :'grille', false) IS NOT NULL AS grille_lue;
\set recherche `cat livrables/ui/etat-stock-lot-search-form.xml`
SELECT set_config('lvme.etat_recherche', :'recherche', false) IS NOT NULL AS ecran_lu;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.etat_grille'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-etat-stock-lot-grid' AND module IS NULL;

-- Etat des stocks : écran (fond bleu, dates jaunes, choix Arrivage / Lots / DLUO à l'horizontale sur une ligne)
UPDATE meta_view SET xml = current_setting('lvme.etat_recherche'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-etat-stock-lot-search-form' AND module IS NULL;

-- liste des achats : classes de style (même modification que livrables/ui/achat-search-form.xml, si PROD_70 est déjà passé)
UPDATE meta_view SET xml = replace(replace(replace(xml,
  '<panel name="rechercheAchatPanel" showTitle="false" colSpan="12">', '<panel name="rechercheAchatPanel" showTitle="false" colSpan="12" css="lvme-ges-achats">'),
  '<panel name="filtreDatePanel" colSpan="3" itemSpan="12">', '<panel name="filtreDatePanel" colSpan="3" itemSpan="12" css="lvme-ges-dates-lavande">'),
  '<panel name="filtreArriveePanel" colSpan="3" itemSpan="12">', '<panel name="filtreArriveePanel" colSpan="3" itemSpan="12" css="lvme-ges-dates-lavande">'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-achat-search-form' AND module IS NULL AND xml NOT LIKE '%lvme-ges-achats%';

COMMIT;

SELECT name, (length(xml) - length(replace(xml, 'lvme-ges-', ''))) / 9 AS classes FROM meta_view
WHERE module IS NULL AND name IN ('lvme-etat-stock-lot-search-form', 'lvme-achat-search-form');
SELECT position('nbColisDispo' IN xml) > 0 AS colonnes_dispo FROM meta_view WHERE name = 'lvme-etat-stock-lot-grid' AND module IS NULL;

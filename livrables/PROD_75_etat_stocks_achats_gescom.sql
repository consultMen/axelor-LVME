-- =====================================================================
-- PROD étape 75 : « Etat des stocks par lots » et « liste des achats fournisseurs » aux couleurs GESCOM
--   - Etat des stocks : fond bleu clair, cadres de dates jaune pâle, lignes blanc / cyan (texte violet), en-têtes
--     bleus ; colonnes dans l'ordre GESCOM avec les intitulés GESCOM, + Nb colis Dispo et Unt/Poids Dispo ;
--     Nb colis Stock et Nb colis Dispo en jaune ; alertes DLUO (rouge / orange) et boutons des lots périmés conservés
--   - liste des achats : cadres de dates lavande, lignes jaune pâle / blanc, en-têtes bleus
-- Sources : livrables/ui/etat-stock-lot-grid.xml, livrables/ui/achat-search-form.xml (PROD_70) ; couleurs dans
--   css/lvme.css (recompiler). Prérequis : code avec EtatStockLot.nbColisDispo. Depuis la racine du dépôt. Relançable.
-- =====================================================================
\set grille `cat livrables/ui/etat-stock-lot-grid.xml`
SELECT set_config('lvme.etat_grille', :'grille', false) IS NOT NULL AS grille_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.etat_grille'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-etat-stock-lot-grid' AND module IS NULL;

-- Etat des stocks : classes de style sur les panneaux (fond bleu, dates jaunes, cadres)
UPDATE meta_view SET xml = replace(replace(replace(replace(xml,
  '<panel name="alertesDluoPanel" showTitle="false" colSpan="12">', '<panel name="alertesDluoPanel" showTitle="false" colSpan="12" css="lvme-ges-etat">'),
  '<panel name="filtresPanel" showTitle="false" colSpan="12">', '<panel name="filtresPanel" showTitle="false" colSpan="12" css="lvme-ges-etat">'),
  '<panel name="filtreDatesPanel" colSpan="4" itemSpan="4">', '<panel name="filtreDatesPanel" colSpan="4" itemSpan="4" css="lvme-ges-dates-jaune">'),
  '<panel name="filtreOptionsPanel" colSpan="2" itemSpan="12">', '<panel name="filtreOptionsPanel" colSpan="2" itemSpan="12" css="lvme-ges-cadre">'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-etat-stock-lot-search-form' AND module IS NULL AND xml NOT LIKE '%lvme-ges-etat%';

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

-- liste des achats : colonnes dans l'ordre GESCOM (N°, Fournisseur, Nom, Numéro Arrivage, Nature, Date Arrivage,
-- Date Arrivée, Nb unités, Tonnage en kg, Mt Arrivage H.T.) ; « À embarquer » (info LVME) gardée en fin de ligne.
-- Prérequis : code avec PurchaseOrder.lvmeNumeroArrivage (recompiler).
UPDATE meta_view SET xml = replace(replace(replace(xml,
  '  <field name="lvmeAEmbarquer" title="À embarquer" width="85"/>' || E'\n', ''),
  '<field name="supplierPartner.name" title="Nom" width="220"/>',
  '<field name="supplierPartner.name" title="Nom" width="220"/>' || E'\n  ' || '<field name="lvmeNumeroArrivage" title="Numéro Arrivage" width="100"/>'),
  '<field name="exTaxTotal" title="Mt Arrivage H.T." aggregate="sum" width="120"/>',
  '<field name="exTaxTotal" title="Mt Arrivage H.T." aggregate="sum" width="120"/>' || E'\n  ' || '<field name="lvmeAEmbarquer" title="À embarquer" width="85"/>'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-achat-grid' AND module IS NULL AND xml NOT LIKE '%lvmeNumeroArrivage%';

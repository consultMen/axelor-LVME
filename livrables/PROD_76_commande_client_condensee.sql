-- =====================================================================
-- PROD étape 76 : fiche Commande client resserrée pour tenir à l'écran (zoom 100 %) comme GESCOM
--   - en-tête (statuts, n°) et bloc GESCOM (client, commande, boutons, totaux) : moins d'espace entre les champs,
--     cases moins hautes, libellés plus petits et jamais coupés (« Date Commande » en entier), boutons plus bas
--   - lignes du tableau resserrées
--   Les styles sont dans css/lvme.css (recompiler) ; ce script pose les classes sur les panneaux.
-- Source : livrables/ui/commande-client-form.xml (PROD_63). Depuis la racine du dépôt. Relançable.
-- =====================================================================
BEGIN;

UPDATE meta_view SET xml = replace(replace(xml,
  '<panel name="mainPanel" colSpan="12">', '<panel name="mainPanel" colSpan="12" css="lvme-compact lvme-cde-serre lvme-cde-entete">'),
  '<panel name="lvmeGescomPanel" colSpan="12" css="lvme-cde-client lvme-cde-fond">',
  '<panel name="lvmeGescomPanel" colSpan="12" css="lvme-cde-client lvme-cde-fond lvme-compact lvme-cde-serre">'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30 AND xml NOT LIKE '%lvme-cde-serre%';

COMMIT;

SELECT (length(xml) - length(replace(xml, 'lvme-cde-serre', ''))) / 14 AS panneaux_resserres
FROM meta_view WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30;

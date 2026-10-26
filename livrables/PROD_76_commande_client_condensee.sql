-- =====================================================================
-- PROD étape 76 : fiche Commande client resserrée pour tenir à l'écran (zoom 100 %) comme GESCOM
--   - en-tête (statuts, n°) et bloc GESCOM (client, commande, boutons, totaux) : moins d'espace entre les champs,
--     cases moins hautes, libellés plus petits et jamais coupés (« Date Commande » en entier), boutons plus bas
--   - lignes du tableau resserrées ; « Commentaire » sur toute la largeur du cadre Commande, « Coût port/kg » dessous
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

-- cadre Commande : « Commentaire » sur toute la largeur, « Coût port/kg » juste dessous (comme GESCOM)
UPDATE meta_view SET xml = replace(xml,
  '<field name="coutPortKg" title="Coût port/kg" colSpan="4"/>' || E'\n        ' || '<field height="2" name="internalNote" title="&lt; Commentaire &gt;" colSpan="8" widget="Html" x-lite="true"/>',
  '<field height="2" name="internalNote" title="&lt; Commentaire &gt;" colSpan="12" widget="Html" x-lite="true"/>' || E'\n        ' || '<field name="coutPortKg" title="Coût port/kg" colSpan="4"/>'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30
  AND xml LIKE '%name="internalNote" title="&lt; Commentaire &gt;" colSpan="8"%';

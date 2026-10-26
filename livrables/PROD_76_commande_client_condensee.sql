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

-- bloc Client : plus de vignette (image) devant Client et contact (vide à gauche), plus de 2e libellé « Adresse »
UPDATE meta_view SET xml = regexp_replace(regexp_replace(xml,
  '(<field[^\n]*name="clientPartner"[^\n]*?) x-image-field="picture"', '\1'),
  '(<field[^\n]*name="contactPartner"[^\n]*?) x-image-field="picture"', '\1'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30 AND xml ~ 'name="(clientPartner|contactPartner)"[^\n]*x-image-field';
UPDATE meta_view SET xml = replace(xml,
  '<field name="mainInvoicingAddress.addressL4" title="Adresse" readonly="true" colSpan="12" showIf="mainInvoicingAddress"/>',
  '<field name="mainInvoicingAddress.addressL4" title="" readonly="true" colSpan="12" showTitle="false" showIf="mainInvoicingAddress"/>'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30
  AND xml LIKE '%name="mainInvoicingAddress.addressL4" title="Adresse"%';

-- boutons de droite : Finaliser / Confirmation Commande en premier, puis Fermer et Imprimer commande
-- (remis devant « Complete manually sale order », le bouton qui suit les deux Confirmation Commande)
UPDATE meta_view SET xml = replace(replace(xml,
  $q$
      <button name="lvmeFermerBtn" title="Fermer" icon="x-circle" css="btn-danger" onClick="close"/>
      <button name="lvmeImprimerCommandeBtn" title="Imprimer commande" icon="printer" showIf="id" onClick="save,action-sale-order-view-reports-wizard"/>$q$, ''),
  $q$
      <button if="(__config__.app.isApp('supplychain') &amp;&amp; __config__.app.getApp('supplychain')?.allowCompleteManuallySaleOrder) || (!__config__.app.isApp('supplychain'))" name="completeManuallySaleOrderBtn"$q$,
  $q$
      <button name="lvmeFermerBtn" title="Fermer" icon="x-circle" css="btn-danger" onClick="close"/>
      <button name="lvmeImprimerCommandeBtn" title="Imprimer commande" icon="printer" showIf="id" onClick="save,action-sale-order-view-reports-wizard"/>
      <button if="(__config__.app.isApp('supplychain') &amp;&amp; __config__.app.getApp('supplychain')?.allowCompleteManuallySaleOrder) || (!__config__.app.isApp('supplychain'))" name="completeManuallySaleOrderBtn"$q$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30
  AND position('name="lvmeFermerBtn"' IN xml) < position('name="finalizeBtn"' IN xml)
  AND position($q$
      <button if="(__config__.app.isApp('supplychain') &amp;&amp; __config__.app.getApp('supplychain')?.allowCompleteManuallySaleOrder) || (!__config__.app.isApp('supplychain'))" name="completeManuallySaleOrderBtn"$q$ IN xml) > 0;

SELECT position('name="finalizeBtn"' IN xml) < position('name="lvmeFermerBtn"' IN xml) AS fermer_apres_finaliser,
       xml LIKE '%name="completeManuallySaleOrderBtn"%' AS bouton_terminer_present
FROM meta_view WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30;

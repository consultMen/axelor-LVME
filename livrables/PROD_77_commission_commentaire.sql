-- =====================================================================
-- PROD étape 77 : fiche Commande client et fenêtre Lignes Commandes
--   - fenêtre Lignes Commandes : « % Commission » à côté de « % RFA sur Produits » (il était seul sous la ligne
--     du bas) ; Frais de Stockage, % RFA, % Commission, Zone pêche, Colis / Couche, Prix Promo sur une ligne
--     (% RFA plus large, Prix Promo plus étroit)
--   - fiche Commande client : le texte tapé dans « < Commentaire > » est recopié aussitôt dans l'onglet
--     Commentaire (« Commentaire à afficher »), sans enregistrer
-- Depuis la racine du dépôt. Relançable.
-- =====================================================================
BEGIN;

-- action : recopie du commentaire dans « Commentaire à afficher »
DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-cde-commentaire-copie';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-commentaire-copie', 'action-record', 'com.axelor.apps.sale.db.SaleOrder',
'<action-record name="action-lvme-cde-commentaire-copie" model="com.axelor.apps.sale.db.SaleOrder">
  <!-- « < Commentaire > » de la fiche recopié dans l''onglet Commentaire (Commentaire à afficher) -->
  <field name="description" expr="eval: internalNote"/>
</action-record>', false, false, 0);

UPDATE meta_view SET xml = replace(xml, $q$        <field height="2" name="internalNote" title="&lt; Commentaire &gt;" colSpan="12" widget="Html" x-lite="true"/>$q$, $q$        <field height="2" name="internalNote" title="&lt; Commentaire &gt;" colSpan="12" widget="Html" x-lite="true" onChange="action-lvme-cde-commentaire-copie"/>$q$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30
  AND xml NOT LIKE '%action-lvme-cde-commentaire-copie%';

-- fenêtre Lignes Commandes : % Commission retiré de sous la ligne du bas et remis après % RFA sur Produits
UPDATE meta_view SET xml = replace(replace(replace(xml,
  $q$
      <field name="tauxCommission" title="% Commission" readonly="true" hideIf="product == null" colSpan="3" widget="Decimal" x-scale="2"/>$q$, ''),
  $q$        <field name="tauxRFA" title="% RFA sur Produits" readonly="true" hideIf="product == null" colSpan="3" widget="Decimal" x-scale="2"/>$q$, $q$        <field name="tauxRFA" title="% RFA sur Produits" readonly="true" hideIf="product == null" colSpan="2" widget="Decimal" x-scale="2"/>
        <field name="tauxCommission" title="% Commission" readonly="true" hideIf="product == null" colSpan="2" widget="Decimal" x-scale="2"/>$q$),
  $q$        <field name="lvmeZonePeche" title="Zone pêche" readonly="true" colSpan="3"/>$q$, $q$        <field name="lvmeZonePeche" title="Zone pêche" readonly="true" colSpan="2"/>$q$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-line-form' AND module IS NULL AND priority = 30
  AND position($q$      <field name="tauxCommission" title="% Commission" readonly="true" hideIf="product == null" colSpan="3" widget="Decimal" x-scale="2"/>$q$ IN xml) > 0;

-- % RFA sur Produits plus large (son libellé est long), Prix Promo (une case à cocher) plus étroit :
-- Frais de Stockage 2 | % RFA sur Produits 3 | % Commission 2 | Zone pêche 2 | Colis / Couche 2 | Prix Promo 1
UPDATE meta_view SET xml = replace(replace(xml,
  '<field name="tauxRFA" title="% RFA sur Produits" readonly="true" hideIf="product == null" colSpan="2" widget="Decimal" x-scale="2"/>',
  '<field name="tauxRFA" title="% RFA sur Produits" readonly="true" hideIf="product == null" colSpan="3" widget="Decimal" x-scale="2"/>'),
  '<field name="lvmePromo" title="Prix Promo" colSpan="2"/>', '<field name="lvmePromo" title="Prix Promo" colSpan="1"/>'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-line-form' AND module IS NULL AND priority = 30
  AND xml LIKE '%name="tauxRFA" title="% RFA sur Produits" readonly="true" hideIf="product == null" colSpan="2"%';

COMMIT;

SELECT name, xml LIKE '%action-lvme-cde-commentaire-copie%' AS commentaire_recopie,
  position('name="tauxCommission"' IN xml) > position('name="tauxRFA"' IN xml)
    AND position('name="tauxCommission"' IN xml) < position('name="lvmeZonePeche"' IN xml) AS commission_apres_rfa
FROM meta_view WHERE name IN ('sale-order-form', 'sale-order-line-form') AND module IS NULL AND priority = 30;

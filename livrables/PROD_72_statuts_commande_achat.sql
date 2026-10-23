-- =====================================================================
-- PROD étape 72 : statuts de la commande d'achat comme le Kanban « Suivi des commandes d'achat »
--   - barre de statut de la fiche Commande fournisseur : Brouillon, À embarquer, Flottant, En stock, Annulée
--     (étape de la commande, suivie depuis son arrivage) au lieu des statuts Axelor
--   - mêmes libellés dans les colonnes du Kanban
--   - « Nouvelle commande » à côté de « Lancer la recherche » et du bouton de suivi (Commandes clients, Achats) :
--     porté par PROD_68 / PROD_70 (livrables/ui/commande-client-search-form.xml, achat-search-form.xml)
-- Prérequis : PROD_69 (liste lvme.achat.etape.select), code avec PurchaseOrder.lvmeEtapeAchat (recompiler).
-- Depuis la racine du dépôt. Relançable.
-- Retour arrière : remettre la ligne <field name="statusSelect" … widget="NavSelect"/> dans purchase-order-form p30.
-- =====================================================================
BEGIN;

UPDATE meta_select_item SET title = CASE value WHEN '2' THEN 'À embarquer' WHEN '4' THEN 'En stock' ELSE title END
WHERE select_id = (SELECT id FROM meta_select WHERE name = 'lvme.achat.etape.select') AND value IN ('2', '4');

UPDATE meta_view SET xml = replace(xml,
  '<field name="statusSelect" showTitle="false" readonly="true" colSpan="12" widget="NavSelect"/>',
  '<!-- LVME : statuts de la commande d''achat comme le Kanban : Brouillon, À embarquer, Flottant, En stock, Annulée -->'
  || E'\n    ' || '<field name="lvmeEtapeAchat" showTitle="false" readonly="true" colSpan="12" widget="NavSelect"/>'
  || E'\n    ' || '<field name="statusSelect" hidden="true"/>'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'purchase-order-form' AND module IS NULL AND priority = 30 AND xml NOT LIKE '%name="lvmeEtapeAchat"%';

COMMIT;

SELECT position('name="lvmeEtapeAchat"' IN xml) > 0 AS barre_lvme FROM meta_view
WHERE name = 'purchase-order-form' AND module IS NULL AND priority = 30;
SELECT i.value, i.title FROM meta_select s JOIN meta_select_item i ON i.select_id = s.id
WHERE s.name = 'lvme.achat.etape.select' ORDER BY i.order_seq;

-- =====================================================================
-- PROD étape 69 : vues Kanban des commandes d'achat et des arrivages
--   - Arrivages : colonnes Brouillon / À embarquer / Flottant / Réel / Annulé ; carte = N° arrivage, fournisseur,
--     transport (bateau / camion, nom du bateau), arrivée prévue, colis, poids, montant HT ; rouge si en retard
--   - Commandes d'achat : colonnes Brouillon / Validée (à embarquer) / Flottant / Réceptionnée / Annulée ;
--     carte = N° commande, fournisseur, transport, dates de commande et de réception, montant HT et devise
--   - cartes non déplaçables (l'étape change par les boutons des fiches) ; clic sur une carte = fiche
--   - bouton « Vue Kanban » à côté de « Lancer la recherche » dans Liste des achats et Arrivages
-- Sources : livrables/ui/arrivage-kanban.xml, livrables/ui/achat-kanban.xml
-- Prérequis : code avec StockMove.lvmeEtapeArrivage / lvmeEnRetard et PurchaseOrder.lvmeEtapeAchat /
--   lvmeEnRetard (recompiler). Depuis la racine du dépôt. Relançable.
-- Retour arrière : DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-arrivage-kanban', 'lvme-achat-kanban');
-- =====================================================================
\set kanbanArrivage `cat livrables/ui/arrivage-kanban.xml`
\set kanbanAchat `cat livrables/ui/achat-kanban.xml`
SELECT set_config('lvme.kanban_arrivage', :'kanbanArrivage', false) IS NOT NULL AS arrivage_lu,
       set_config('lvme.kanban_achat', :'kanbanAchat', false) IS NOT NULL AS achat_lu;

BEGIN;

-- ---------- Étapes des commandes d'achat (celles des arrivages existent déjà : PROD_49) ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.achat.etape.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.achat.etape.select');
DELETE FROM meta_select_item WHERE select_id = (SELECT id FROM meta_select WHERE name = 'lvme.achat.etape.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('1', 'Brouillon', 1), ('2', 'Validée (à embarquer)', 2), ('3', 'Flottant', 3),
             ('4', 'Réceptionnée', 4), ('5', 'Annulée', 5)) AS v(value, title, seq) ON true
WHERE s.name = 'lvme.achat.etape.select';

-- ---------- Vues Kanban ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-arrivage-kanban', 'lvme-achat-kanban');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-arrivage-kanban', 'Arrivages', 'kanban',
 'com.axelor.apps.stock.db.StockMove', 20, current_setting('lvme.kanban_arrivage'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-achat-kanban', 'Commandes d''achat', 'kanban',
 'com.axelor.apps.purchase.db.PurchaseOrder', 20, current_setting('lvme.kanban_achat'), false, false);

-- ---------- Ouverture ----------
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-arrivage-kanban', 'action-lvme-achat-kanban');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-kanban', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-arrivage-kanban" title="Arrivages (Kanban)" model="com.axelor.apps.stock.db.StockMove">
  <view type="kanban" name="lvme-arrivage-kanban"/>
  <view type="grid" name="lvme-arrivage-grid"/>
  <view type="form" name="lvme-arrivage-form"/>
  <domain>self.typeSelect = 3 AND self.isReversion = FALSE</domain>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-kanban', 'action-view', 'com.axelor.apps.purchase.db.PurchaseOrder',
'<action-view name="action-lvme-achat-kanban" title="Commandes d''achat (Kanban)" model="com.axelor.apps.purchase.db.PurchaseOrder">
  <view type="kanban" name="lvme-achat-kanban"/>
  <view type="grid" name="lvme-achat-grid"/>
  <view type="form" name="purchase-order-form"/>
</action-view>', false, false, 0);

-- ---------- Bouton « Vue Kanban » à côté de « Lancer la recherche » ----------
UPDATE meta_view SET xml = regexp_replace(xml, '(<button name="lancerRechercheBtn"[^>]*/>)',
  '\1' || E'\n      ' || '<button name="lvmeKanbanBtn" title="Vue Kanban" icon="view_kanban" onClick="action-lvme-achat-kanban"/>', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-achat-search-form' AND module IS NULL AND xml NOT LIKE '%lvmeKanbanBtn%';
UPDATE meta_view SET xml = regexp_replace(xml, '(<button name="lancerRechercheBtn"[^>]*/>)',
  '\1' || E'\n      ' || '<button name="lvmeKanbanBtn" title="Vue Kanban" icon="view_kanban" onClick="action-lvme-arrivage-kanban"/>', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-arrivage-search-form' AND module IS NULL AND xml NOT LIKE '%lvmeKanbanBtn%';

COMMIT;

SELECT name, type FROM meta_view WHERE module IS NULL AND name IN ('lvme-arrivage-kanban', 'lvme-achat-kanban');
SELECT name, position('lvmeKanbanBtn' IN xml) > 0 AS bouton_kanban FROM meta_view
WHERE module IS NULL AND name IN ('lvme-achat-search-form', 'lvme-arrivage-search-form');

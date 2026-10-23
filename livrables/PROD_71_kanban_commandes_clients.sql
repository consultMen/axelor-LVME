-- =====================================================================
-- PROD étape 71 : Kanban « Suivi des commandes clients »
--   - colonnes : Devis, En préparation, Expédiée (BL Flottant), Livrée, Facturée, Annulée
--   - carte : N° commande, client, dates de commande et de livraison, % marge (rouge si négative), montant HT ;
--     bande de couleur par étape ; rose + « En retard » si la livraison prévue est dépassée
--   - déplacer une carte : Devis -> En préparation (confirme la commande, crée le BL) ; En préparation <->
--     Expédiée (case Flottant des BL) ; -> Livrée (ouvre le BL pour Réaliser) ; -> Annulée (ouvre la commande) ;
--     Facturée : depuis la commande / le BL ; sinon refus avec message
--   - bouton « Suivi des commandes clients » à côté de « Lancer la recherche » dans Listes Commandes Clients
-- Source : livrables/ui/commande-client-kanban.xml
-- Prérequis : code avec SaleOrder.lvmeEtapeCde / lvmeEnRetard / lvmeKanbanSeq et LvmeKanbanController (recompiler),
--   PROD_67 (statuts BL). Depuis la racine du dépôt. Relançable.
-- Retour arrière : DELETE FROM meta_view WHERE module IS NULL AND name = 'lvme-commande-client-kanban';
-- =====================================================================
\set kanban `cat livrables/ui/commande-client-kanban.xml`
SELECT set_config('lvme.kanban_cde_client', :'kanban', false) IS NOT NULL AS kanban_lu;

BEGIN;

ALTER TABLE sale_sale_order ADD COLUMN IF NOT EXISTS lvme_kanban_seq integer;

INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.cde.client.etape.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.cde.client.etape.select');
DELETE FROM meta_select_item WHERE select_id = (SELECT id FROM meta_select WHERE name = 'lvme.cde.client.etape.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('1', 'Devis', 1), ('2', 'En préparation', 2), ('3', 'Expédiée', 3), ('4', 'Livrée', 4),
             ('5', 'Facturée', 5), ('6', 'Annulée', 6)) AS v(value, title, seq) ON true
WHERE s.name = 'lvme.cde.client.etape.select';

DELETE FROM meta_view WHERE module IS NULL AND name = 'lvme-commande-client-kanban';
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-commande-client-kanban', 'Suivi des commandes clients', 'kanban',
 'com.axelor.apps.sale.db.SaleOrder', 20, current_setting('lvme.kanban_cde_client'), false, false);

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-cde-client-kanban', 'action-lvme-kanban-deplacer-cde-client');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-kanban', 'action-view', 'com.axelor.apps.sale.db.SaleOrder',
'<action-view name="action-lvme-cde-client-kanban" title="Suivi des commandes clients" model="com.axelor.apps.sale.db.SaleOrder">
  <view type="kanban" name="lvme-commande-client-kanban"/>
  <view type="grid" name="lvme-commande-client-grid"/>
  <view type="form" name="sale-order-form"/>
  <domain>self.template = false</domain>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-kanban-deplacer-cde-client', 'action-method', NULL,
'<action-method name="action-lvme-kanban-deplacer-cde-client">
  <call class="com.axelor.apps.supplychain.web.LvmeKanbanController" method="deplacerCommandeClient"/>
</action-method>', false, false, 0);

UPDATE meta_view SET xml = regexp_replace(xml, '(<button name="lancerRechercheBtn"[^>]*/>)',
  '\1' || E'\n      ' || '<button name="lvmeKanbanBtn" title="Suivi des commandes clients" icon="view_kanban" css="lvme-btn-kanban" onClick="action-lvme-cde-client-kanban"/>', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-commande-client-search-form' AND module IS NULL AND xml NOT LIKE '%lvmeKanbanBtn%';

COMMIT;

SELECT name, type FROM meta_view WHERE module IS NULL AND name = 'lvme-commande-client-kanban';
SELECT position('lvmeKanbanBtn' IN xml) > 0 AS bouton FROM meta_view WHERE module IS NULL AND name = 'lvme-commande-client-search-form';

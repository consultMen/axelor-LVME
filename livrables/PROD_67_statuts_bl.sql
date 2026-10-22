-- =====================================================================
-- PROD étape 67 : statuts des BL (livraisons client) façon LVME
--   Brouillon -> En cours de préparation -> Flottant -> Réalisé, plus Annulé (Fusionné non affiché)
--   - BL planifié = « En cours de préparation » ; bouton « Flottant » (marchandise partie chez le
--     transporteur) et bouton retour « Flottant -> En cours de préparation » ; Réaliser inchangé
--   - fiche BL : barre des statuts LVME (pour un BL seulement ; arrivages et mouvements internes inchangés)
--   - liste Livraisons client : colonne Statut avec les mêmes libellés
--   Le statut Axelor du mouvement ne change pas : seul l'affichage change, plus la case Flottant du BL.
-- Sources : livrables/ui/stock-move-form-bl.xml et stock-move-out-grid-bl.xml (livrables/outils/gen_bl_statuts.py)
-- Prérequis : code avec StockMove.lvmeBlFlottant / lvmeEtapeBl (recompiler). Depuis la racine du dépôt. Relançable.
-- Retour arrière : DELETE FROM meta_view WHERE module IS NULL AND priority = 30
--   AND name IN ('stock-move-form', 'stock-move-out-grid');
-- =====================================================================
\set fiche `cat livrables/ui/stock-move-form-bl.xml`
SELECT set_config('lvme.bl_fiche', :'fiche', false) IS NOT NULL AS fiche_lue;
\set grille `cat livrables/ui/stock-move-out-grid-bl.xml`
SELECT set_config('lvme.bl_grille', :'grille', false) IS NOT NULL AS grille_lue;

BEGIN;

ALTER TABLE stock_stock_move ADD COLUMN IF NOT EXISTS lvme_bl_flottant boolean DEFAULT false;

-- ---------- Liste des statuts BL ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.bl.etape.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.bl.etape.select');
DELETE FROM meta_select_item WHERE select_id = (SELECT id FROM meta_select WHERE name = 'lvme.bl.etape.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('1', 'Brouillon', 1), ('2', 'En cours de préparation', 2), ('3', 'Flottant', 3),
             ('4', 'Réalisé', 4), ('5', 'Annulé', 5)) AS v(value, title, seq) ON true
WHERE s.name = 'lvme.bl.etape.select';

-- ---------- Fiche et liste ----------
DELETE FROM meta_view WHERE module IS NULL AND priority = 30 AND name IN ('stock-move-form', 'stock-move-out-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'stock-move-form', 'Stock move', 'form',
 'com.axelor.apps.stock.db.StockMove', 30, current_setting('lvme.bl_fiche'), false, false),
(nextval('meta_view_seq'), 0, now(), 'stock-move-out-grid', 'Stock moves', 'grid',
 'com.axelor.apps.stock.db.StockMove', 30, current_setting('lvme.bl_grille'), false, false);

-- ---------- Boutons Flottant / retour En cours de préparation ----------
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-bl-record-flottant', 'action-lvme-bl-record-preparation');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-bl-record-flottant', 'action-record', 'com.axelor.apps.stock.db.StockMove',
'<action-record name="action-lvme-bl-record-flottant" model="com.axelor.apps.stock.db.StockMove">
  <field name="lvmeBlFlottant" expr="eval: true"/>
</action-record>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-bl-record-preparation', 'action-record', 'com.axelor.apps.stock.db.StockMove',
'<action-record name="action-lvme-bl-record-preparation" model="com.axelor.apps.stock.db.StockMove">
  <field name="lvmeBlFlottant" expr="eval: false"/>
</action-record>', false, false, 0);

COMMIT;

SELECT name, priority FROM meta_view WHERE module IS NULL AND priority = 30 AND name IN ('stock-move-form', 'stock-move-out-grid');
SELECT i.value, i.title FROM meta_select s JOIN meta_select_item i ON i.select_id = s.id
WHERE s.name = 'lvme.bl.etape.select' ORDER BY i.order_seq;

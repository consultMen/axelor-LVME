-- =====================================================================
-- PROD étape 49 : barre des étapes de la fiche Arrivage, présentée comme celle de la commande fournisseur
--   Brouillon > A embarquer > Flottant > Réel > Annulé (d'après la nature de l'arrivage) au lieu des statuts
--   Axelor (Brouillon, Flottant, Réalisé, Annulé, Fusionné). Affichage seulement : on change d'étape par les
--   boutons de la fiche. La fiche elle-même est reconstruite par PROD_41 (livrables/ui/arrivage-form.xml).
-- Relançable. Pas de redémarrage nécessaire.
-- =====================================================================
BEGIN;

INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.arrivage.etape.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.arrivage.etape.select');

-- valeurs = celles de la nature de l'arrivage (DRAFT 0, à embarquer 1, FLOTTANT 2, REEL 3, ANNULE 4)
DELETE FROM meta_select_item WHERE select_id = (SELECT id FROM meta_select WHERE name = 'lvme.arrivage.etape.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('0', 'Brouillon', 1), ('1', 'A embarquer', 2), ('2', 'Flottant', 3), ('3', 'Réel', 4), ('4', 'Annulé', 5))
  AS v(value, title, seq) ON true
WHERE s.name = 'lvme.arrivage.etape.select';

DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-arrivage-attrs-etape';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-attrs-etape', 'action-attrs', 'com.axelor.apps.stock.db.StockMove',
'<action-attrs name="action-lvme-arrivage-attrs-etape" model="com.axelor.apps.stock.db.StockMove">
  <attribute name="value" for="$etapeArrivage"
    expr="eval: [DRAFT: 0, EN_COURS_DE_PRODUCTION: 1, FLOTTANT: 2, REEL: 3, ANNULE: 4][nature?.toString()] ?: 0"/>
</action-attrs>', false, false, 0);

COMMIT;

SELECT i.value, i.title FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
WHERE s.name = 'lvme.arrivage.etape.select' ORDER BY i.order_seq;

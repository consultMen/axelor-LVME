-- =====================================================================
-- REC-038 : listes de choix de l'écran « État des stocks par lots »
-- A exécuter une seule fois par base (local, puis prod).
-- Equivalent de la création manuelle dans Administration > Sélections.
-- Sans effet si la liste existe déjà (NOT EXISTS).
-- =====================================================================

BEGIN;

-- 1) Nature d'arrivage
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.etat.stock.nature.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.etat.stock.nature.select');

INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
CROSS JOIN (VALUES ('1', 'Arrivage réel', 1), ('2', 'Arrivage flottant', 2), ('0', 'Tous', 3)) AS v(value, title, seq)
WHERE s.name = 'lvme.etat.stock.nature.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- 2) Etat du lot
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.etat.stock.etat.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.etat.stock.etat.select');

INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
CROSS JOIN (VALUES ('1', 'Lots non soldés', 1), ('2', 'Lots soldés', 2), ('3', 'Lots négatifs', 3),
                   ('4', 'Lots non soldés + négatifs', 4)) AS v(value, title, seq)
WHERE s.name = 'lvme.etat.stock.etat.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- 3) Période prédéfinie
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.etat.stock.periode.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.etat.stock.periode.select');

INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
CROSS JOIN (VALUES ('1', 'Mois en cours', 1), ('2', '3 derniers mois', 2), ('3', '6 derniers mois', 3),
                   ('4', 'Année en cours', 4), ('5', '12 derniers mois', 5), ('6', 'Toutes dates', 6)) AS v(value, title, seq)
WHERE s.name = 'lvme.etat.stock.periode.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

COMMIT;

-- Vérification
SELECT s.name, i.value, i.title
FROM meta_select s JOIN meta_select_item i ON i.select_id = s.id
WHERE s.name LIKE 'lvme.etat.stock.%'
ORDER BY s.name, i.order_seq;

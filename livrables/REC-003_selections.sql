-- =====================================================================
-- REC-003 : liste de choix « Statut » de l'écran Rotation des stocks
-- A exécuter une seule fois par base (local, puis prod). Sans effet si déjà créée.
-- =====================================================================
BEGIN;

INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.rotation.statut.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.rotation.statut.select');

INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
CROSS JOIN (VALUES ('A commander', 'A commander (couverture < 60 j)', 1),
                   ('Dormant', 'Dormant (aucune vente depuis 90 j)', 2),
                   ('Lot ancien', 'Lot ancien (> 180 j)', 3),
                   ('Ventes faibles', 'Ventes faibles (< 10 sur 90 j)', 4),
                   ('OK', 'OK', 5)) AS v(value, title, seq)
WHERE s.name = 'lvme.rotation.statut.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

COMMIT;

SELECT s.name, i.value, i.title
FROM meta_select s JOIN meta_select_item i ON i.select_id = s.id
WHERE s.name = 'lvme.rotation.statut.select'
ORDER BY i.order_seq;

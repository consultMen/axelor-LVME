-- =====================================================================
-- PROD étape 74 : Rotation des stocks par lot, filtre par mode de transport, en couleurs
--   - filtre « Transport » : Tous / 🚚 Camion (Europe) / 🚢 Bateau (International)
--   - colonne « Transport » du tableau par lot : Camion en vert, Bateau en bleu
--   - le transport d'un lot est celui de son arrivage (Type transport), sinon celui de sa commande d'achat
-- Sources : livrables/ui/rotation-lot-grid.xml, livrables/ui/rotation-stock-filtres.xml (champ $transport)
-- Prérequis : code avec RotationLot.lvmeTransport (recompiler), PROD_22. Depuis la racine du dépôt. Relançable.
-- =====================================================================
\set grille `cat livrables/ui/rotation-lot-grid.xml`
SELECT set_config('lvme.rotation_grille', :'grille', false) IS NOT NULL AS grille_lue;

BEGIN;

INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.rotation.transport.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.rotation.transport.select');
DELETE FROM meta_select_item WHERE select_id = (SELECT id FROM meta_select WHERE name = 'lvme.rotation.transport.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('TOUS', 'Tous', 1), ('CAMION', '🚚 Camion (Europe)', 2), ('BATEAU', '🚢 Bateau (International)', 3))
  AS v(value, title, seq) ON true
WHERE s.name = 'lvme.rotation.transport.select';

-- tableau par lot : colonne Transport en couleur
UPDATE meta_view SET xml = current_setting('lvme.rotation_grille'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-rotation-lot-grid' AND module IS NULL;

-- écran Rotation des stocks : filtre Transport sous Frigo
UPDATE meta_view SET xml = regexp_replace(xml, '(<field name="\$frigo"[^>]*/>)',
  '\1' || E'\n      ' || '<field name="$transport" title="Transport" type="string" widget="RadioSelect" selection="lvme.rotation.transport.select"/>', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND xml LIKE '%name="$frigo"%' AND xml LIKE '%rotationLotDashlet%' AND xml NOT LIKE '%name="$transport"%';

-- liste par lot : filtre Transport
UPDATE meta_action SET xml = replace(replace(xml,
  'AND (:_entreeFiltre = false OR self.arrivalDate BETWEEN :_entreeDu AND :_entreeAu)</domain>',
  'AND (:_entreeFiltre = false OR self.arrivalDate BETWEEN :_entreeDu AND :_entreeAu)
    AND (:_transport = '''' OR self.lvmeTransport = :_transport)</domain>'),
  '</action-view>',
  '  <context name="_transport" expr="eval: transport == ''CAMION'' ? ''Camion'' : (transport == ''BATEAU'' ? ''Bateau'' : '''')"/>
</action-view>'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'action-lvme-rotation-lot-dashlet' AND module IS NULL AND xml NOT LIKE '%_transport%';

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND xml LIKE '%name="$transport"%' AND xml LIKE '%rotationLotDashlet%') AS filtre,
       (SELECT count(*) FROM meta_view WHERE name = 'lvme-rotation-lot-grid' AND xml LIKE '%lvmeTransport%') AS colonne,
       (SELECT count(*) FROM meta_action WHERE name = 'action-lvme-rotation-lot-dashlet' AND xml LIKE '%:_transport%') AS liste;

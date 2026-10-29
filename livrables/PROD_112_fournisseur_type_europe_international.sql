-- =====================================================================
-- PROD étape 112 : fournisseurs Europe / International (demande du 29/10/2026)
--   - liste lvme.partner.zone.select : Europe, International
--   - fiche Tiers : champ « Type » à côté de la référence, affiché seulement pour un fournisseur, saisi par le client
--     (vide au départ : pas de reprise GESCOM, GESCOM n'a pas ce champ)
--   - liste Fournisseurs : colonne « Type » à côté du nom
-- Prérequis : code avec Partner.lvmeZoneFournisseur (recompiler ; colonne lvme_zone_fournisseur créée au démarrage).
-- À lancer depuis la racine du dépôt, Tomcat arrêté, puis redémarrer (vues en cache). Source :
-- livrables/ui/partner-supplier-grid.xml. Relançable.
-- =====================================================================
\set gFou `cat livrables/ui/partner-supplier-grid.xml`
SELECT set_config('lvme.gFou', :'gFou', false) IS NOT NULL AS liste_lue;

BEGIN;

INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.partner.zone.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.partner.zone.select');
DELETE FROM meta_select_item WHERE select_id = (SELECT id FROM meta_select WHERE name = 'lvme.partner.zone.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, (SELECT id FROM meta_select WHERE name = 'lvme.partner.zone.select'), v, t, o
FROM (VALUES ('EUROPE', 'Europe', 1), ('INTERNATIONAL', 'International', 2)) x(v, t, o);

UPDATE meta_view SET xml = current_setting('lvme.gFou'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'partner-supplier-grid';

-- fiche Tiers : champ Type à côté de la référence (fournisseurs seulement)
UPDATE meta_view SET xml = replace(xml,
    '<field name="partnerSeq" showTitle="false" colSpan="2" css="label-bold bold large"/>',
    '<field name="partnerSeq" showTitle="false" colSpan="2" css="label-bold bold large"/>
        <field name="lvmeZoneFournisseur" title="Type" showIf="isSupplier" colSpan="3"/>'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'partner-form' AND xml NOT LIKE '%lvmeZoneFournisseur%';

COMMIT;

-- contrôle : 2 valeurs ; colonne dans la liste ; champ sur la fiche
SELECT (SELECT count(*) FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
        WHERE s.name = 'lvme.partner.zone.select') AS valeurs,
  (SELECT xml LIKE '%lvmeZoneFournisseur%' FROM meta_view WHERE module IS NULL AND name = 'partner-supplier-grid') AS liste,
  (SELECT xml LIKE '%lvmeZoneFournisseur%' FROM meta_view WHERE module IS NULL AND name = 'partner-form') AS fiche;

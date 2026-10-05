-- =====================================================================
-- PROD étape 28 : archiver / désarchiver à la main (demande client)
--   - boutons « Archiver » / « Désarchiver » sur les fiches Arrivage, Article, Tiers (client, fournisseur,
--     transporteur : même fiche) et Numéro de suivi (lot). Une fiche archivée sort des listes et des choix,
--     rien n'est supprimé, on peut la désarchiver.
--   - recherche des Arrivages : « Arrivages Archivés » = les arrivages archivés à la main ; les autres options
--     n'affichent pas les archivés (relance de PROD_9 depuis sa source à jour).
-- Fiches Article / Tiers : boutons ajoutés en place dans les vues admin (priorité 30) existantes.
-- Fiche Numéro de suivi : vue admin (priorité 30) créée depuis la vue de module.
-- À lancer depuis la racine du dépôt, puis redémarrer Axelor. Relançable.
-- =====================================================================
BEGIN;

-- ---------- Actions (une paire par modèle) ----------
DELETE FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-archiver-%' OR (module IS NULL AND name LIKE 'action-lvme-desarchiver-%');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom)
SELECT nextval('meta_action_seq'), 0, now(), a.name, a.type, a.model, a.xml, false, false
FROM (
  SELECT 'action-lvme-' || v.verbe || '-' || m.code || '-record' AS name, 'action-record' AS type, m.model,
         '<action-record name="action-lvme-' || v.verbe || '-' || m.code || '-record" model="' || m.model || '">
  <field name="archived" expr="eval: ' || v.valeur || '"/>
</action-record>' AS xml
  FROM (VALUES ('stockmove', 'com.axelor.apps.stock.db.StockMove'), ('product', 'com.axelor.apps.base.db.Product'),
               ('partner', 'com.axelor.apps.base.db.Partner'), ('trackingnumber', 'com.axelor.apps.stock.db.TrackingNumber')) AS m(code, model),
       (VALUES ('archiver', 'true'), ('desarchiver', 'false')) AS v(verbe, valeur)
  UNION ALL
  SELECT 'action-lvme-' || v.verbe || '-' || m.code, 'action-group', NULL,
         '<action-group name="action-lvme-' || v.verbe || '-' || m.code || '">
  <action name="action-lvme-' || v.verbe || '-' || m.code || '-record"/>
  <action name="save"/>
</action-group>'
  FROM (VALUES ('stockmove'), ('product'), ('partner'), ('trackingnumber')) AS m(code),
       (VALUES ('archiver'), ('desarchiver')) AS v(verbe)
) a;

-- ---------- Boutons sur les fiches Article, Tiers, Numéro de suivi ----------
DO $$
DECLARE r record; v_id bigint; v_xml text; a int; n int; snippet text;
BEGIN
  -- fiche Numéro de suivi : vue admin créée depuis la vue de module (une seule fois)
  IF NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'tracking-number-form' AND module IS NULL) THEN
    INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed)
    SELECT nextval('meta_view_seq'), 0, now(), name, title, type, model, 30, xml, false, false
    FROM meta_view WHERE name = 'tracking-number-form' AND module IS NOT NULL AND COALESCE(extension, false) = false
    ORDER BY priority DESC, COALESCE(computed, false) DESC LIMIT 1;
  END IF;

  FOR r IN SELECT * FROM (VALUES ('product-form', 'product', 'cet article'),
                                 ('partner-form', 'partner', 'ce tiers'),
                                 ('tracking-number-form', 'trackingnumber', 'ce lot')) AS t(vue, code, libelle) LOOP
    SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = r.vue AND module IS NULL ORDER BY priority DESC LIMIT 1;
    IF v_id IS NULL THEN RAISE EXCEPTION 'Vue admin % introuvable : arrêt, rien n''est modifié', r.vue; END IF;
    IF position('lvmeArchiverBtn' IN v_xml) > 0 THEN
      RAISE NOTICE '% : boutons déjà présents', r.vue;
      CONTINUE;
    END IF;
    SELECT count(*) INTO n FROM regexp_matches(v_xml, '<panel name="mainPanel"', 'g');
    IF n < 1 THEN RAISE EXCEPTION '% : panneau mainPanel non trouvé : arrêt', r.vue; END IF;
    snippet := '<panel name="lvmeArchivePanel" showTitle="false" colSpan="12" showIf="id">
    <field name="archived" hidden="true"/>
    <button name="lvmeArchiverBtn" title="Archiver" icon="archive" colSpan="2" showIf="!archived" prompt="Archiver ' || r.libelle || ' ? Il n''apparaîtra plus dans les listes et les choix (rien n''est supprimé)." onClick="save,action-lvme-archiver-' || r.code || '"/>
    <button name="lvmeDesarchiverBtn" title="Désarchiver" icon="archive" colSpan="2" showIf="archived" onClick="action-lvme-desarchiver-' || r.code || '"/>
  </panel>
  ';
    a := position('<panel name="mainPanel"' IN v_xml);
    v_xml := substr(v_xml, 1, a - 1) || snippet || substr(v_xml, a);
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
    RAISE NOTICE '% : boutons Archiver / Désarchiver ajoutés', r.vue;
  END LOOP;
END $$;
COMMIT;

-- ---------- Arrivages (fiche + recherche) ----------
\i livrables/PROD_9_arrivages.sql

SELECT name, position('lvmeArchiverBtn' IN xml) > 0 AS boutons FROM meta_view
WHERE module IS NULL AND name IN ('lvme-arrivage-form', 'product-form', 'partner-form', 'tracking-number-form');

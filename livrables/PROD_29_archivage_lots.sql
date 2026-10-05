-- =====================================================================
-- PROD étape 29 : archiver / désarchiver les lots depuis « État des stocks par lots » (demande client)
--   - vue SQL lvme_etat_stock_lot : colonne « lot archivé » ajoutée en fin de vue
--   - recherche : option « Lots archivés » dans le filtre « Lots » + bouton « Archiver / Désarchiver »
--     qui ouvre la liste filtrée : on coche des lignes puis Archiver / Désarchiver (barre de la liste)
--   - c'est le lot (numéro de suivi) qui est archivé : il sort de la liste et des choix de lot, rien n'est supprimé
--   - méthode Java LvmeArchivageLotController (code à déployer avec ce script)
-- Transforme en place la version ACTUELLE de l'écran, de sa liste et de son action (modifs déjà faites gardées).
-- À lancer depuis la racine du dépôt, AVANT le redémarrage d'Axelor. Relançable.
-- =====================================================================
BEGIN;

\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_etat_stock_lot.sql

-- ---------- Filtre « Lots » : option « Lots archivés » ----------
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, '5', 'Lots archivés', 5
FROM meta_select s
WHERE s.name = 'lvme.etat.stock.etat.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = '5');

-- ---------- Actions ----------
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-lots-archiver-selection', 'action-lvme-lots-desarchiver-selection');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom)
SELECT nextval('meta_action_seq'), 0, now(), v.name, 'action-method', NULL,
       '<action-method name="' || v.name || '">
  <call class="com.axelor.apps.supplychain.web.LvmeArchivageLotController" method="' || v.method || '"/>
</action-method>', false, false
FROM (VALUES ('action-lvme-lots-archiver-selection', 'archiver'),
             ('action-lvme-lots-desarchiver-selection', 'desarchiver')) AS v(name, method);

DO $$
DECLARE v_id bigint; v_xml text; a int; n int;
BEGIN
  -- ---------- Liste : boutons Archiver / Désarchiver dans sa barre ----------
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'lvme-etat-stock-lot-grid' AND module IS NULL;
  IF v_id IS NULL THEN RAISE EXCEPTION 'lvme-etat-stock-lot-grid introuvable : arrêt'; END IF;
  IF position('lvmeLotsArchiverBtn' IN v_xml) = 0 THEN
    IF position('<toolbar' IN v_xml) > 0 THEN RAISE EXCEPTION 'la liste a déjà une barre <toolbar> : à fusionner à la main, arrêt'; END IF;
    a := position('>' IN substr(v_xml, position('<grid' IN v_xml))) + position('<grid' IN v_xml) - 1;
    v_xml := substr(v_xml, 1, a) || '
  <toolbar>
    <button name="lvmeLotsArchiverBtn" title="Archiver" icon="archive" prompt="Archiver les lots cochés ? Ils n''apparaîtront plus dans la liste ni dans les choix de lot (case « Lots archivés » pour les retrouver)." onClick="action-lvme-lots-archiver-selection"/>
    <button name="lvmeLotsDesarchiverBtn" title="Désarchiver" icon="arrow-counterclockwise" onClick="action-lvme-lots-desarchiver-selection"/>
  </toolbar>' || substr(v_xml, a + 1);
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
    RAISE NOTICE 'Liste : boutons Archiver / Désarchiver ajoutés';
  ELSE
    RAISE NOTICE 'Liste : boutons déjà présents';
  END IF;

  -- ---------- Écran de recherche : bouton « Archiver / Désarchiver » (case « Lots archivés » d'une version précédente retirée) ----------
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'lvme-etat-stock-lot-search-form' AND module IS NULL;
  IF v_id IS NULL THEN RAISE EXCEPTION 'lvme-etat-stock-lot-search-form introuvable : arrêt'; END IF;
  v_xml := regexp_replace(v_xml, '<field name="\$lotsArchives"[^>]*/>\s*', '', 'g');
  IF position('lvmeArchivageBtn' IN v_xml) = 0 THEN
    SELECT count(*) INTO n FROM regexp_matches(v_xml, '<button name="lancerRechercheBtn"[^>]*/>', 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'bouton Lancer la recherche trouvé % fois : arrêt', n; END IF;
    v_xml := regexp_replace(v_xml, '(<button name="lancerRechercheBtn"[^>]*/>)',
      chr(92) || '1
      <button name="lvmeArchivageBtn" title="Archiver / Désarchiver" icon="archive" onClick="action-lvme-etat-stock-lot-dashlet"/>');
  END IF;
  UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  RAISE NOTICE 'Recherche : bouton Archiver / Désarchiver en place';

  -- ---------- Action de la liste : option 5 = lots archivés, les autres options = lots non archivés ----------
  SELECT id, xml INTO v_id, v_xml FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-dashlet' AND module IS NULL;
  IF v_id IS NULL THEN RAISE EXCEPTION 'action-lvme-etat-stock-lot-dashlet introuvable : arrêt'; END IF;
  -- version précédente (case « Lots archivés ») retirée ; balise </domain> perdue par une version précédente réparée
  v_xml := replace(v_xml, chr(1), '</domain>');
  v_xml := regexp_replace(v_xml, '\s*AND \(\(:_lotsArch = true[^<]*\)\)(</domain>)', chr(92) || '1');
  v_xml := regexp_replace(v_xml, '\s*<context name="_lotsArch"[^>]*/>', '');
  IF position('self.lotArchive' IN v_xml) = 0 THEN
    IF position('OR (:_etat = 4 AND self.stockQty != 0))' IN v_xml) = 0 THEN
      RAISE EXCEPTION 'critère « Lots » de la liste non reconnu : arrêt, rien n''est modifié';
    END IF;
    v_xml := replace(v_xml, 'OR (:_etat = 4 AND self.stockQty != 0))',
      'OR (:_etat = 4 AND self.stockQty != 0) OR :_etat = 5)
    AND ((:_etat = 5 AND self.lotArchive = true) OR (:_etat != 5 AND self.lotArchive = false))');
  END IF;
  UPDATE meta_action SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
  RAISE NOTICE 'Liste : option Lots archivés en place';
END $$;

COMMIT;

SELECT count(*) AS lignes, count(*) FILTER (WHERE lot_archive) AS lots_archives FROM lvme_etat_stock_lot;

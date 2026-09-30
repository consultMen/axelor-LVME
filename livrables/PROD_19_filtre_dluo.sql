-- =====================================================================
-- PROD étape 19 : État des stocks par lots, filtre « DLUO » (lots périmés / DLUO proche)
--   - liste de choix lvme.etat.stock.dluo.select : Toutes / Dépassées / Dans moins de 30 jours / les deux
--   - filtre « DLUO » dans le cadre de recherche
--   - sous le bandeau d'alerte : boutons « Voir les lots périmés » et « Voir les lots à DLUO proche »
--     (remplissent le filtre et lancent la recherche ; visibles seulement s'il y a des lots concernés)
-- Transforme la version ACTUELLE de l'écran et de sa liste (les modifications déjà faites sont gardées).
-- Relançable : ne refait rien si le filtre est déjà présent. Une seule transaction. Puis redémarrer Axelor.
-- =====================================================================
BEGIN;

-- ---------- Liste de choix ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.etat.stock.dluo.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select WHERE name = 'lvme.etat.stock.dluo.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
CROSS JOIN (VALUES ('0', 'Toutes', 1), ('1', 'Dépassées (périmés)', 2), ('2', 'Dans moins de 30 jours', 3),
                   ('3', 'Dépassées + moins de 30 jours', 4)) AS v(value, title, seq)
WHERE s.name = 'lvme.etat.stock.dluo.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- ---------- Actions des boutons ----------
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-etat-stock-lot-attrs-dluo-perimes',
  'action-lvme-etat-stock-lot-attrs-dluo-proche', 'action-lvme-etat-stock-lot-group-dluo-perimes',
  'action-lvme-etat-stock-lot-group-dluo-proche');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-attrs-dluo-perimes', 'action-attrs', NULL,
'<action-attrs name="action-lvme-etat-stock-lot-attrs-dluo-perimes">
  <attribute name="value" for="$dluoFiltre" expr="eval: 1"/>
  <attribute name="value" for="$etatLot" expr="eval: 1"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-attrs-dluo-proche', 'action-attrs', NULL,
'<action-attrs name="action-lvme-etat-stock-lot-attrs-dluo-proche">
  <attribute name="value" for="$dluoFiltre" expr="eval: 2"/>
  <attribute name="value" for="$etatLot" expr="eval: 1"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-group-dluo-perimes', 'action-group', NULL,
'<action-group name="action-lvme-etat-stock-lot-group-dluo-perimes">
  <action name="action-lvme-etat-stock-lot-attrs-dluo-perimes"/>
  <action name="action-lvme-etat-stock-lot-refresh"/>
</action-group>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-group-dluo-proche', 'action-group', NULL,
'<action-group name="action-lvme-etat-stock-lot-group-dluo-proche">
  <action name="action-lvme-etat-stock-lot-attrs-dluo-proche"/>
  <action name="action-lvme-etat-stock-lot-refresh"/>
</action-group>', false, false);

DO $$
DECLARE v_id bigint; v_xml text; a int; b int; n int;
BEGIN
  -- ---------- Liste (dashlet) : critère DLUO ----------
  SELECT id, xml INTO v_id, v_xml FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-dashlet' AND module IS NULL;
  IF v_id IS NULL THEN RAISE EXCEPTION 'action-lvme-etat-stock-lot-dashlet introuvable : arrêt'; END IF;
  IF position(':_dluo' IN v_xml) = 0 THEN
    SELECT count(*) INTO n FROM regexp_matches(v_xml, '</domain>', 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'domaine de la liste non trouvé une seule fois : arrêt'; END IF;
    v_xml := replace(v_xml, '</domain>', '
    AND (:_dluo = 0 OR (:_dluo = 1 AND self.dluo &lt; :_today)
      OR (:_dluo = 2 AND self.dluo BETWEEN :_today AND :_today30)
      OR (:_dluo = 3 AND self.dluo &lt;= :_today30))</domain>');
    v_xml := replace(v_xml, '</action-view>', '  <context name="_dluo" expr="eval: (dluoFiltre ?: 0) as Integer"/>
  <context name="_today" expr="eval: __date__"/>
  <context name="_today30" expr="eval: __date__.plusDays(30)"/>
</action-view>');
    UPDATE meta_action SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
    RAISE NOTICE 'Liste : critère DLUO ajouté';
  ELSE
    RAISE NOTICE 'Liste : critère DLUO déjà présent';
  END IF;

  -- ---------- Écran de recherche : filtre + boutons sous le bandeau ----------
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'lvme-etat-stock-lot-search-form' AND module IS NULL;
  IF v_id IS NULL THEN RAISE EXCEPTION 'lvme-etat-stock-lot-search-form introuvable : arrêt'; END IF;
  IF position('$dluoFiltre' IN v_xml) = 0 THEN
    -- filtre DLUO, juste avant « Seulement les dispo négatifs »
    a := position('<field name="$dispoNegatif"' IN v_xml);
    IF a = 0 THEN RAISE EXCEPTION 'champ $dispoNegatif non trouvé : arrêt'; END IF;
    v_xml := substr(v_xml, 1, a - 1)
      || '<field name="$dluoFiltre" title="DLUO" type="integer" widget="RadioSelect" selection="lvme.etat.stock.dluo.select"/>
      ' || substr(v_xml, a);
    -- boutons : à la fin du panneau du bandeau (juste avant le cadre des filtres)
    b := position('<panel name="filtresPanel"' IN v_xml);
    IF b = 0 THEN RAISE EXCEPTION 'cadre filtresPanel non trouvé : arrêt'; END IF;
    a := b - position(reverse('</panel>') IN reverse(substr(v_xml, 1, b - 1))) - length('</panel>') + 1;
    IF a <= 0 OR position('alertesDluoPanel' IN substr(v_xml, 1, a)) = 0 THEN
      RAISE EXCEPTION 'panneau du bandeau DLUO non trouvé : arrêt';
    END IF;
    v_xml := substr(v_xml, 1, a - 1)
      || '<button name="voirPerimesBtn" title="Voir les lots périmés" css="btn-danger" colSpan="3" icon="exclamation-triangle" showIf="$nbDluoDepassee &gt; 0" onClick="action-lvme-etat-stock-lot-group-dluo-perimes"/>
    <button name="voirDluoProcheBtn" title="Voir les lots à DLUO proche" css="btn-warning" colSpan="3" icon="clock" showIf="$nbDluoProche &gt; 0" onClick="action-lvme-etat-stock-lot-group-dluo-proche"/>
  ' || substr(v_xml, a);
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
    RAISE NOTICE 'Écran : filtre DLUO et boutons ajoutés';
  ELSE
    RAISE NOTICE 'Écran : filtre DLUO déjà présent';
  END IF;
END $$;

COMMIT;

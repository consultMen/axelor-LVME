-- =====================================================================
-- PROD étape 25 : REC-010 chrono de facturation mensuelle + clôture mois par mois
--   1. Périodes 2026 : l'exercice 2026 n'a qu'UNE période (01/01 → 31/12), impossible de clôturer
--      un mois. Elle devient la période de janvier et les périodes février → décembre sont créées
--      (même nommage). Les écritures comptables déjà passées sont rattachées à la période de leur mois.
--   2. Chrono (format B validé) : factures FC + AAMM + compteur (FC26100001), avoirs AC26..., commandes
--      clients SO26..., compteur remis à zéro chaque mois. La version de numérotation annuelle en cours
--      est arrêtée à la fin du mois précédent : le mois en cours repart à 0001.
--   Le reste de REC-010 est natif (inventaires export / import CSV, impression du stock valorisé,
--   Comptabilité > Périodes > Clôturer).
-- À lancer depuis la racine du dépôt. Relançable (ne refait rien si c'est déjà fait). Une seule transaction.
-- Pas de redémarrage nécessaire.
-- =====================================================================
BEGIN;

-- ---------- 1. Périodes mensuelles 2026 ----------
DO $$
DECLARE y record; p record; m int; v_from date; v_to date; v_id bigint; n int;
BEGIN
  FOR y IN SELECT * FROM base_year WHERE from_date = DATE '2026-01-01' AND to_date = DATE '2026-12-31' AND type_select = 1 LOOP
    SELECT count(*) INTO n FROM base_period WHERE year = y.id;
    IF n <> 1 THEN
      RAISE NOTICE 'Exercice % : % période(s), déjà découpé, rien à faire', y.code, n;
      CONTINUE;
    END IF;
    SELECT * INTO p FROM base_period WHERE year = y.id;
    IF p.from_date <> DATE '2026-01-01' OR p.to_date <> DATE '2026-12-31' OR left(p.name, 3) <> '01/' THEN
      RAISE EXCEPTION 'Exercice % : période % inattendue (% → %), arrêt, rien n''est modifié', y.code, p.name, p.from_date, p.to_date;
    END IF;
    -- la période annuelle devient janvier
    UPDATE base_period SET to_date = DATE '2026-01-31', updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = p.id;
    FOR m IN 2..12 LOOP
      v_from := make_date(2026, m, 1);
      v_to := (v_from + interval '1 month' - interval '1 day')::date;
      INSERT INTO base_period (id, version, created_on, name, code, from_date, to_date, status_select, year,
                               allow_expense_creation, close_journals_on_period, keep_journals_open_on_period)
      VALUES (nextval('base_period_seq'), 0, now(), lpad(m::text, 2, '0') || substr(p.name, 3),
              lpad(m::text, 2, '0') || substr(p.code, 3), v_from, v_to, 1, y.id,
              p.allow_expense_creation, p.close_journals_on_period, p.keep_journals_open_on_period)
      RETURNING id INTO v_id;
      -- écritures du mois rattachées à la nouvelle période
      UPDATE account_move SET period = v_id WHERE period = p.id AND date_val BETWEEN v_from AND v_to;
      GET DIAGNOSTICS n = ROW_COUNT;
      RAISE NOTICE 'Exercice % : période % créée, % écriture(s) rattachée(s)', y.code, lpad(m::text, 2, '0') || substr(p.name, 3), n;
    END LOOP;
  END LOOP;
END $$;

-- ---------- 2. Chrono mensuelle (format B) ----------
DO $$
DECLARE s record; v_fin date := (date_trunc('month', current_date) - interval '1 day')::date; n int;
BEGIN
  FOR s IN SELECT * FROM base_sequence
           WHERE (code_select = 'invoice' AND prefixe IN ('FC%YY', 'AC%YY'))
              OR (code_select = 'saleOrder' AND prefixe = 'SO') LOOP
    UPDATE base_sequence
       SET prefixe = CASE WHEN s.code_select = 'saleOrder' THEN 'SO%YY%FM' ELSE s.prefixe || '%FM' END,
           yearly_reset_ok = true, monthly_reset_ok = true,
           updated_on = now(), version = COALESCE(version, 0) + 1
     WHERE id = s.id;
    -- la version en cours (annuelle ou sans fin) s'arrête à la fin du mois précédent
    UPDATE base_sequence_version
       SET end_date = v_fin, updated_on = now(), version = COALESCE(version, 0) + 1
     WHERE sequence = s.id AND start_date <= v_fin AND (end_date IS NULL OR end_date > v_fin);
    GET DIAGNOSTICS n = ROW_COUNT;
    -- une version déjà ouverte qui commence ce mois-ci (cas rare) est gardée telle quelle
    RAISE NOTICE 'Numérotation « % » (%) : mensuelle, % version(s) arrêtée(s) au %', s.name, s.id, n, v_fin;
  END LOOP;
END $$;

-- ---------- 3. Droit de clôturer les périodes ----------
-- La config comptable n'autorise que le rôle « Admin » à clôturer, mais aucun utilisateur ne l'a :
-- les boutons de clôture n'apparaissent pour personne. Le compte admin reçoit le rôle « Admin »
-- et le rôle « lvme.comptable » est autorisé (clôture définitive et temporaire).
INSERT INTO auth_user_roles (auth_user, roles)
SELECT u.id, r.id FROM auth_user u, auth_role r
WHERE u.code = 'admin' AND r.name = 'Admin'
  AND NOT EXISTS (SELECT 1 FROM auth_user_roles x WHERE x.auth_user = u.id AND x.roles = r.id);
INSERT INTO account_account_config_closure_authorized_role_list (account_account_config, closure_authorized_role_list)
SELECT c.id, r.id FROM account_account_config c, auth_role r
WHERE r.name IN ('Admin', 'lvme.comptable')
  AND NOT EXISTS (SELECT 1 FROM account_account_config_closure_authorized_role_list x
                  WHERE x.account_account_config = c.id AND x.closure_authorized_role_list = r.id);
INSERT INTO account_account_config_temporary_closure_authorized_role_list (account_account_config, temporary_closure_authorized_role_list)
SELECT c.id, r.id FROM account_account_config c, auth_role r
WHERE r.name IN ('Admin', 'lvme.comptable')
  AND NOT EXISTS (SELECT 1 FROM account_account_config_temporary_closure_authorized_role_list x
                  WHERE x.account_account_config = c.id AND x.temporary_closure_authorized_role_list = r.id);
-- Saisie sur un mois clôturé provisoirement : réservée au rôle « lvme.comptable » (le rôle « Admin »,
-- seul compte utilisé, contournerait sinon la clôture du mois).
DELETE FROM account_account_config_move_on_temp_closure_authorized_role_lis
WHERE move_on_temp_closure_authorized_role_list IN (SELECT id FROM auth_role WHERE name = 'Admin');
INSERT INTO account_account_config_move_on_temp_closure_authorized_role_lis (account_account_config, move_on_temp_closure_authorized_role_list)
SELECT c.id, r.id FROM account_account_config c, auth_role r
WHERE r.name = 'lvme.comptable'
  AND NOT EXISTS (SELECT 1 FROM account_account_config_move_on_temp_closure_authorized_role_lis x
                  WHERE x.account_account_config = c.id AND x.move_on_temp_closure_authorized_role_list = r.id);

COMMIT;

SELECT y.code AS exercice, p.name, p.from_date, p.to_date, p.status_select,
       (SELECT count(*) FROM account_move m WHERE m.period = p.id) AS ecritures
FROM base_period p JOIN base_year y ON y.id = p.year
WHERE y.from_date = DATE '2026-01-01' ORDER BY p.from_date;
SELECT id, name, prefixe, yearly_reset_ok, monthly_reset_ok FROM base_sequence
WHERE code_select IN ('invoice', 'saleOrder') ORDER BY id;

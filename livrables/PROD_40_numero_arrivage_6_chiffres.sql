-- =====================================================================
-- PROD étape 40 : N° Arrivage sur 6 chiffres (demande client)
--   Format : année (2) + mois (2) + compteur (2), remis à zéro chaque mois
--     ex. 261001, 261002… puis 261101 en novembre (au lieu de 2610000019)
--   Numérotation des réceptions fournisseur (code inStockMove). Les arrivages existants gardent
--   leur numéro. Au-delà de 99 arrivages dans un mois, le compteur passe à 3 chiffres (7 au total).
-- Relançable.
-- =====================================================================
BEGIN;

DO $$
DECLARE s record; v_fin date := (date_trunc('month', current_date) - interval '1 day')::date; n int;
BEGIN
  FOR s IN SELECT * FROM base_sequence WHERE code_select = 'inStockMove' LOOP
    UPDATE base_sequence
       SET prefixe = '%YY%FM', suffixe = NULL, padding = 2,
           yearly_reset_ok = true, monthly_reset_ok = true,
           updated_on = now(), version = COALESCE(version, 0) + 1
     WHERE id = s.id;
    -- la version en cours (sans fin) s'arrête à la fin du mois précédent : Axelor ouvre ensuite
    -- une version par mois, qui repart à 01
    UPDATE base_sequence_version
       SET end_date = v_fin, updated_on = now(), version = COALESCE(version, 0) + 1
     WHERE sequence = s.id AND start_date <= v_fin AND (end_date IS NULL OR end_date > v_fin);
    GET DIAGNOSTICS n = ROW_COUNT;
    RAISE NOTICE 'Numérotation « % » (%) : 6 chiffres mensuels, % version(s) arrêtée(s) au %', s.name, s.id, n, v_fin;
  END LOOP;
END $$;

COMMIT;

SELECT s.id, s.name, s.prefixe, s.padding, s.monthly_reset_ok,
       v.start_date, v.end_date, v.next_num
FROM base_sequence s LEFT JOIN base_sequence_version v ON v.sequence = s.id
WHERE s.code_select = 'inStockMove'
ORDER BY s.id, v.start_date;

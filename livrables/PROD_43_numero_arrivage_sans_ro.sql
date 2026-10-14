-- =====================================================================
-- PROD étape 43 : n° des arrivages repris de GESCOM sans le préfixe « RO- »
--   La reprise a enregistré « RO-210137 » au lieu du n° GESCOM « 210137 ». Le préfixe est retiré :
--   n° de l'arrivage, son libellé (« RO-210137 - Fournisseur ») et l'origine de ses lots.
--   Seuls les arrivages (réceptions fournisseur) dont le n° est exactement « RO- » + chiffres.
--   Arrêt sans rien modifier si un n° obtenu existe déjà.
-- Relançable (ne fait plus rien une fois passé). Pas de redémarrage nécessaire.
-- =====================================================================
BEGIN;

-- ---------- 1. Contrôles ----------
SELECT count(*) AS arrivages_a_renumeroter
FROM stock_stock_move WHERE type_select = 3 AND stock_move_seq ~ '^RO-[0-9]+$';

DO $$
DECLARE n int;
BEGIN
  -- un n° sans « RO- » déjà pris par un autre arrivage
  SELECT count(*) INTO n
  FROM stock_stock_move m
  JOIN stock_stock_move o ON o.stock_move_seq = substring(m.stock_move_seq FROM 4) AND o.id <> m.id
  WHERE m.type_select = 3 AND m.stock_move_seq ~ '^RO-[0-9]+$';
  IF n > 0 THEN RAISE EXCEPTION '% n° d''arrivage existent déjà sans « RO- » : arrêt, rien n''est modifié', n; END IF;

  -- deux arrivages repris avec le même n°
  SELECT count(*) INTO n FROM (
    SELECT stock_move_seq FROM stock_stock_move
    WHERE type_select = 3 AND stock_move_seq ~ '^RO-[0-9]+$'
    GROUP BY stock_move_seq HAVING count(*) > 1) d;
  IF n > 0 THEN RAISE EXCEPTION '% n° d''arrivage repris en double : arrêt, rien n''est modifié', n; END IF;
END $$;

-- ---------- 2. Origine des lots (avant de changer le n° des arrivages) ----------
UPDATE stock_tracking_number t
   SET origin = substring(t.origin FROM 4), updated_on = now(), version = COALESCE(t.version, 0) + 1
 WHERE t.origin ~ '^RO-[0-9]+$'
   AND EXISTS (SELECT 1 FROM stock_stock_move m WHERE m.type_select = 3 AND m.stock_move_seq = t.origin);

-- ---------- 3. N° et libellé des arrivages ----------
UPDATE stock_stock_move
   SET name = CASE WHEN name LIKE stock_move_seq || '%'
                   THEN substring(stock_move_seq FROM 4) || substring(name FROM length(stock_move_seq) + 1)
                   ELSE name END,
       stock_move_seq = substring(stock_move_seq FROM 4),
       updated_on = now(), version = COALESCE(version, 0) + 1
 WHERE type_select = 3 AND stock_move_seq ~ '^RO-[0-9]+$';

COMMIT;

SELECT count(*) FILTER (WHERE stock_move_seq ~ '^RO-') AS restent_avec_ro,
       count(*) FILTER (WHERE stock_move_seq ~ '^[0-9]{6}$') AS numeros_6_chiffres
FROM stock_stock_move WHERE type_select = 3;

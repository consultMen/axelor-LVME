-- =====================================================================
-- PROD étape 39 : n° des lots générés selon l'état de l'arrivage (demande du 13/10)
--   à embarquer : « AE » + numéro ; flottant : « FL » + numéro ; réel : numéro seul (comme aujourd'hui)
--   Le même lot est renommé à chaque étape (il garde ses liens : commande, stock, ventes).
--   Seuls les lots générés automatiquement à partir de ce lot de code sont concernés (colonne
--   lvme_numero_base remplie) ; lots saisis à la main et lots existants : inchangés.
--   Le renommage est fait par le code (enregistrement de l'arrivage) ; ce script ajoute la colonne.
--   Compteur des lots générés à l'achat réglé au format GESCOM : 8 chiffres sans préfixe, repart après
--   le plus grand n° de lot existant.
-- À lancer AVANT le démarrage du nouveau code. Relançable.
-- =====================================================================
BEGIN;

ALTER TABLE stock_tracking_number ADD COLUMN IF NOT EXISTS lvme_numero_base varchar(255);

-- ---------- Compteur des lots générés à l'achat : format GESCOM (8 chiffres, sans préfixe) ----------
-- AE00012605 -> FL00012605 -> 00012605 ; il repart après le plus grand n° de lot GESCOM existant
-- (00012604, AE00012604 ou FL00012604), sans jamais reculer.
UPDATE base_sequence
   SET prefixe = NULL, suffixe = NULL, padding = 8, yearly_reset_ok = false, monthly_reset_ok = false,
       updated_on = now(), version = COALESCE(version, 0) + 1
 WHERE id IN (SELECT sequence FROM stock_tracking_number_configuration
              WHERE generate_purchase_auto_tracking_nbr = true AND sequence IS NOT NULL);

UPDATE base_sequence_version v
   SET next_num = GREATEST(v.next_num,
         (SELECT COALESCE(max(substring(t.tracking_number_seq FROM '^(?:AE|FL)?([0-9]{8})$')::bigint), 0) + 1
            FROM stock_tracking_number t)),
       updated_on = now(), version = COALESCE(v.version, 0) + 1
 WHERE v.sequence IN (SELECT sequence FROM stock_tracking_number_configuration
                      WHERE generate_purchase_auto_tracking_nbr = true AND sequence IS NOT NULL)
   AND (v.end_date IS NULL OR v.end_date >= current_date);

COMMIT;

SELECT count(*) AS lots, count(lvme_numero_base) AS lots_avec_numero_base FROM stock_tracking_number;
SELECT c.name AS configuration, s.name AS compteur, coalesce(s.prefixe, '') AS prefixe, s.padding,
       v.next_num AS prochain_numero, lpad(v.next_num::text, s.padding, '0') AS prochain_lot
FROM stock_tracking_number_configuration c
JOIN base_sequence s ON s.id = c.sequence
LEFT JOIN base_sequence_version v ON v.sequence = s.id AND (v.end_date IS NULL OR v.end_date >= current_date)
WHERE c.generate_purchase_auto_tracking_nbr = true;

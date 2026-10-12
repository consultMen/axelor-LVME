-- =====================================================================
-- PROD étape 31 : retours client du scénario 1 (commande d'achat), points 1, 2 et 3
--   1. Cours / Couvert / Flottant / Réel vides par défaut (au lieu de 0,0000) :
--      le code les rend facultatifs (nullable) ; ici, les 0 déjà enregistrés sont vidés.
--   2. « Type transport » : modes de livraison « Bateau » et « Camion » créés s'ils n'existent pas.
--   3. Ligne de commande d'achat : « Code fournisseur » devient « Code Produit »
--      (fiche de ligne : par le code ; liste des lignes : ici).
-- À lancer avec le code de ce lot, avant le redémarrage. Relançable.
-- =====================================================================
BEGIN;

-- ---------- 1. Cours : 0 -> vide ----------
UPDATE purchase_purchase_order SET lvme_cours = NULL WHERE lvme_cours = 0;
UPDATE purchase_purchase_order SET lvme_couvert = NULL WHERE lvme_couvert = 0;
UPDATE purchase_purchase_order SET lvme_flottant = NULL WHERE lvme_flottant = 0;
UPDATE purchase_purchase_order SET lvme_reel = NULL WHERE lvme_reel = 0;
UPDATE stock_stock_move SET lvme_cours = NULL WHERE lvme_cours = 0;
UPDATE stock_stock_move SET lvme_couvert = NULL WHERE lvme_couvert = 0;
UPDATE stock_stock_move SET lvme_flottant = NULL WHERE lvme_flottant = 0;
UPDATE stock_stock_move SET lvme_reel = NULL WHERE lvme_reel = 0;

-- ---------- 2. Type transport : Bateau / Camion ----------
INSERT INTO stock_shipment_mode (id, version, created_on, name, has_carriage_paid_possibility)
SELECT nextval('stock_shipment_mode_seq'), 0, now(), v.name, false
FROM (VALUES ('Bateau'), ('Camion')) AS v(name)
WHERE NOT EXISTS (SELECT 1 FROM stock_shipment_mode m WHERE upper(trim(m.name)) = upper(v.name));

-- ---------- 3. Liste des lignes de commande d'achat : colonne « Code Produit » ----------
UPDATE meta_view
   SET xml = replace(xml, '<field name="productCode" title="Code fourn."', '<field name="productCode" title="Code Produit"'),
       updated_on = now(), version = COALESCE(version, 0) + 1
 WHERE module IS NULL AND name = 'purchase-order-line-purchase-order-grid'
   AND position('<field name="productCode" title="Code fourn."' IN xml) > 0;

COMMIT;

SELECT id, name, archived FROM stock_shipment_mode ORDER BY name;
SELECT name, priority, position('title="Code Produit"' IN xml) > 0 AS code_produit
FROM meta_view WHERE module IS NULL AND name = 'purchase-order-line-purchase-order-grid';

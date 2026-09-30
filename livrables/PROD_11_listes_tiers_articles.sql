-- =====================================================================
-- PROD étape 11 : listes Clients / Fournisseurs / Articles à la manière de GESCOM (diapos 30, 5, 9)
--   - partner-customer-grid, partner-supplier-grid, product-grid, product-purchase-grid :
--     vues admin de priorité 30 avec les colonnes et libellés GESCOM
--   - champs Gencode, Référence Fournisseur, Poids Colis, P.Vente TTC sur l'article (colonnes créées ici,
--     déclarées aussi dans le code) ; Gencode, Réf. fournisseur et Poids Colis ajoutés
--     sur la fiche article juste après le Code (fiche construite à partir de la vue actuelle de la base)
-- À lancer depuis la racine du dépôt, puis redémarrer Axelor. Relançable. Une seule transaction.
-- Si un utilisateur a personnalisé ses colonnes (engrenage de la liste), il doit faire « Réinitialiser ».
-- =====================================================================
\set cli `cat livrables/ui/partner-customer-grid.xml`
\set fou `cat livrables/ui/partner-supplier-grid.xml`
\set art `cat livrables/ui/product-grid.xml`
\set artAchat `cat livrables/ui/product-purchase-grid.xml`
SELECT set_config('lvme.cli', :'cli', false), set_config('lvme.fou', :'fou', false),
       set_config('lvme.art', :'art', false), set_config('lvme.artAchat', :'artAchat', false);

BEGIN;

ALTER TABLE base_product ADD COLUMN IF NOT EXISTS gencode varchar(255);
ALTER TABLE base_product ADD COLUMN IF NOT EXISTS ref_fournisseur varchar(255);
ALTER TABLE base_product ADD COLUMN IF NOT EXISTS poids_colis numeric(20,3);
ALTER TABLE base_product ADD COLUMN IF NOT EXISTS sale_price_ttc numeric(20,4);

-- P.Vente TTC des articles existants : même calcul que le code (TVA de vente de l'article, sinon de sa famille)
UPDATE base_product p
SET sale_price_ttc = ROUND(p.sale_price * (1 + COALESCE(
      (SELECT tl.value FROM account_account_management am
         JOIN account_account_management_sale_tax_set st ON st.account_account_management = am.id
         JOIN account_tax t ON t.id = st.sale_tax_set JOIN account_tax_line tl ON tl.id = t.active_tax_line
       WHERE am.product = p.id ORDER BY am.id LIMIT 1),
      (SELECT tl.value FROM account_account_management am
         JOIN account_account_management_sale_tax_set st ON st.account_account_management = am.id
         JOIN account_tax t ON t.id = st.sale_tax_set JOIN account_tax_line tl ON tl.id = t.active_tax_line
       WHERE am.product_family = p.product_family ORDER BY am.id LIMIT 1), 0) / 100), 4)
WHERE p.sale_price IS NOT NULL;

-- ---------- Listes ----------
DELETE FROM meta_view WHERE module IS NULL AND priority = 30
  AND name IN ('partner-customer-grid', 'partner-supplier-grid', 'product-grid', 'product-purchase-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'partner-customer-grid', 'Clients', 'grid', 'com.axelor.apps.base.db.Partner', 30, current_setting('lvme.cli'), false, false),
(nextval('meta_view_seq'), 0, now(), 'partner-supplier-grid', 'Fournisseurs', 'grid', 'com.axelor.apps.base.db.Partner', 30, current_setting('lvme.fou'), false, false),
(nextval('meta_view_seq'), 0, now(), 'product-grid', 'Articles', 'grid', 'com.axelor.apps.base.db.Product', 30, current_setting('lvme.art'), false, false),
(nextval('meta_view_seq'), 0, now(), 'product-purchase-grid', 'Articles', 'grid', 'com.axelor.apps.base.db.Product', 30, current_setting('lvme.artAchat'), false, false);

-- ---------- Gencode sur la fiche article ----------
DO $$
DECLARE src text; res text; p text; n int;
BEGIN
  SELECT xml INTO src FROM meta_view
   WHERE name = 'product-form' AND module IS NOT NULL AND COALESCE(extension, false) = false
     AND xml NOT LIKE '%name="gencode"%'
   ORDER BY priority DESC, COALESCE(computed, false) DESC LIMIT 1;
  IF src IS NULL THEN RAISE EXCEPTION 'product-form introuvable'; END IF;
  -- point d'ancrage : le champ Code saisi à la main (if="!...GenerateProductSequence()")
  p := '(<field if="!__config__[^"]*GenerateProductSequence\(\)" name="code"(?:[^"/>]|"[^"]*")*/>)';
  SELECT count(*) INTO n FROM regexp_matches(src, p, 'g');
  IF n <> 1 THEN RAISE EXCEPTION 'Champ Code de la fiche article trouvé % fois (1 attendu) : arrêt', n; END IF;
  res := regexp_replace(src, p, '\1<field name="gencode" title="Gencode" colSpan="3"/><field name="refFournisseur" title="Référence Fournisseur" colSpan="3"/><field name="poidsColis" title="Poids Colis" colSpan="3"/><field name="salePriceTtc" title="P.Vente TTC" colSpan="3" readonly="true"/>');

  DELETE FROM meta_view WHERE name = 'product-form' AND module IS NULL AND priority = 30;
  INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed)
  SELECT nextval('meta_view_seq'), 0, now(), name, title, type, model, 30, res, false, false
  FROM meta_view WHERE name = 'product-form' AND module IS NOT NULL AND COALESCE(extension, false) = false
    AND xml NOT LIKE '%name="gencode"%'
  ORDER BY priority DESC, COALESCE(computed, false) DESC LIMIT 1;
  RAISE NOTICE 'Fiche article : Gencode ajouté après le Code';
END $$;

COMMIT;

SELECT name, priority, COALESCE(module, 'admin') AS module, length(xml) AS taille FROM meta_view
WHERE module IS NULL AND priority = 30
  AND name IN ('partner-customer-grid', 'partner-supplier-grid', 'product-grid', 'product-purchase-grid', 'product-form')
ORDER BY name;

-- =====================================================================
-- PROD étape 101 : « Historique Produit » sans produit choisi = tous les produits de la période (ex. les 3 derniers
-- mois) ; avec un produit, inchangé. Totaux du bas : LvmeHistoriqueProduitController.valider (recompiler).
-- L'impression reste par produit. Relançable.
-- =====================================================================
BEGIN;

UPDATE meta_action SET xml = replace(xml, '<domain>self.product.id = :_prod AND',
                                          '<domain>(:_prod = 0 OR self.product.id = :_prod) AND'),
       updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'action-lvme-historique-produit-dashlet'
  AND xml LIKE '%<domain>self.product.id = :_prod AND%';

COMMIT;

SELECT count(*) AS action_modifiee FROM meta_action
WHERE module IS NULL AND name = 'action-lvme-historique-produit-dashlet' AND xml LIKE '%:_prod = 0 OR%';

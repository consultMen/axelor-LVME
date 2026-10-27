-- =====================================================================
-- PROD étape 93 : filtres « Secteur » et « Client en compte / Client comptant » de Listes Dossiers, comme GESCOM
--   - Secteur commercial (GMS…) = « Secteur d'activité » du client (liste base_industry_sector, remplie à la
--     migration depuis la table SECTEUR de GESCOM) ; vide = TOUS
--   - client comptant (paie à la commande, sans facilité de paiement) = nouvelle case lvme_client_comptant du tiers
--     (reprise de GESCOM à la migration) ; « Client en compte » par défaut, comme GESCOM
--   - les listes BL / BL retour, Détail produits et Facture / Avoir suivent ces deux filtres (la recherche directe
--     par N° les ignore)
-- Prérequis : code avec Partner.lvmeClientComptant (recompiler) ; PROD_23, PROD_92. Source :
-- livrables/ui/dossiers-search-form.xml. Relançable.
-- =====================================================================
\set dossiers `cat livrables/ui/dossiers-search-form.xml`
SELECT set_config('lvme.dossiers', :'dossiers', false) IS NOT NULL AS dossiers_lu;

BEGIN;

ALTER TABLE base_partner ADD COLUMN IF NOT EXISTS lvme_client_comptant boolean;

-- liste de choix Client en compte / Client comptant
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.dossier.client.compte.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select s WHERE s.name = 'lvme.dossier.client.compte.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('1', 'Client en compte', 1), ('2', 'Client comptant', 2)) AS v(value, title, seq) ON true
WHERE s.name = 'lvme.dossier.client.compte.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- « Client en compte » par défaut
UPDATE meta_action
SET xml = replace(xml, '</action-attrs>', '  <attribute name="value" for="$clientCompte" expr="eval: 1"/>
</action-attrs>'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'action-lvme-dossiers-defaults' AND xml NOT LIKE '%$clientCompte%';

-- filtres des trois listes (BL et factures : self.partner ; détail produits : self.stockMove.partner)
UPDATE meta_action
SET xml = replace(replace(xml,
      'AND (:_client = 0 OR self.partner.id = :_client)',
      $c$AND (:_client = 0 OR self.partner.id = :_client)
        AND (:_secteur = 0 OR self.partner.id IN (SELECT p.id FROM Partner p WHERE p.industrySector.id = :_secteur))
        AND ((:_comptant = 1 AND self.partner.id NOT IN (SELECT p.id FROM Partner p WHERE p.lvmeClientComptant = true))
          OR (:_comptant = 2 AND self.partner.id IN (SELECT p.id FROM Partner p WHERE p.lvmeClientComptant = true)))$c$),
    '</action-view>', $c$  <context name="_secteur" expr="eval: (secteur?.id ?: 0) as Long"/>
  <context name="_comptant" expr="eval: (clientCompte ?: 1) as Integer"/>
</action-view>$c$),
    updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name IN ('action-lvme-dossiers-bl-dashlet', 'action-lvme-dossiers-factures-dashlet')
  AND xml NOT LIKE '%_secteur%';
UPDATE meta_action
SET xml = replace(replace(xml,
      'AND (:_client = 0 OR self.stockMove.partner.id = :_client)',
      $c$AND (:_client = 0 OR self.stockMove.partner.id = :_client)
        AND (:_secteur = 0 OR self.stockMove.partner.id IN (SELECT p.id FROM Partner p WHERE p.industrySector.id = :_secteur))
        AND ((:_comptant = 1 AND self.stockMove.partner.id NOT IN (SELECT p.id FROM Partner p WHERE p.lvmeClientComptant = true))
          OR (:_comptant = 2 AND self.stockMove.partner.id IN (SELECT p.id FROM Partner p WHERE p.lvmeClientComptant = true)))$c$),
    '</action-view>', $c$  <context name="_secteur" expr="eval: (secteur?.id ?: 0) as Long"/>
  <context name="_comptant" expr="eval: (clientCompte ?: 1) as Integer"/>
</action-view>$c$),
    updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'action-lvme-dossiers-lignes-dashlet' AND xml NOT LIKE '%_secteur%';

UPDATE meta_view SET xml = current_setting('lvme.dossiers'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-dossiers-search-form' AND module IS NULL;

COMMIT;

SELECT (SELECT count(*) FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-dossiers-bl-dashlet',
          'action-lvme-dossiers-factures-dashlet', 'action-lvme-dossiers-lignes-dashlet')
          AND xml LIKE '%:_secteur = 0%' AND xml LIKE '%name="_comptant"%') AS listes_filtrees,
       (SELECT count(*) FROM meta_action WHERE module IS NULL AND name = 'action-lvme-dossiers-defaults'
          AND xml LIKE '%$clientCompte%') AS defaut,
       (SELECT count(*) FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
          WHERE s.name = 'lvme.dossier.client.compte.select') AS choix,
       (SELECT count(*) FROM meta_view WHERE module IS NULL AND name = 'lvme-dossiers-search-form'
          AND xml LIKE '%$clientCompte%') AS ecran;

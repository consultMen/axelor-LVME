-- =====================================================================
-- PROD étape 114 : loupe des champs fournisseur et client comme GESCOM (demande du 29/10/2026)
--   La loupe ouvre la liste « Fournisseurs » ou « Clients » de GESCOM (mêmes colonnes que les listes du menu,
--   sans les boutons Archiver) au lieu de la liste Axelor :
--   - fournisseur : État des stocks par lots, Rotation des stocks, liste des achats, Arrivages (recherche et fiche),
--     Aides réappro, État des besoins, Palmarès ;
--   - client : Listes Commandes Clients, Listes Dossiers, Lignes commandes clients, Historique prix, État des
--     besoins, Palmarès, Prix négociés, fiche commande client ;
--   - fiche commande d'achat : champ Fournisseur.
--   Seul l'attribut grid-view des champs change. Prérequis : PROD_112 (colonne Type). À lancer depuis la racine
--   du dépôt, Tomcat arrêté, puis redémarrer (vues en cache). Sources : livrables/ui/lvme-fournisseur-selection-grid.xml,
--   lvme-client-selection-grid.xml. Relançable.
-- =====================================================================
\set gFou `cat livrables/ui/lvme-fournisseur-selection-grid.xml`
SELECT set_config('lvme.gFou', :'gFou', false) IS NOT NULL AS liste_fournisseurs_lue;
\set gCli `cat livrables/ui/lvme-client-selection-grid.xml`
SELECT set_config('lvme.gCli', :'gCli', false) IS NOT NULL AS liste_clients_lue;

BEGIN;

DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-fournisseur-selection-grid', 'lvme-client-selection-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-fournisseur-selection-grid', 'Fournisseurs', 'grid',
 'com.axelor.apps.base.db.Partner', 20, current_setting('lvme.gFou'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-client-selection-grid', 'Clients', 'grid',
 'com.axelor.apps.base.db.Partner', 20, current_setting('lvme.gCli'), false, false);

-- écrans de recherche : champs $fournisseur / $fournisseurDu / $fournisseurAu et $client
UPDATE meta_view SET xml = regexp_replace(xml, '<field name="(\$(fournisseur|fournisseurDu|fournisseurAu))"',
    '<field name="\1" grid-view="lvme-fournisseur-selection-grid"', 'g'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND type = 'form' AND xml ~ '<field name="\$(fournisseur|fournisseurDu|fournisseurAu)"'
  AND xml NOT LIKE '%lvme-fournisseur-selection-grid%';
UPDATE meta_view SET xml = regexp_replace(xml, '<field name="(\$client)"',
    '<field name="\1" grid-view="lvme-client-selection-grid"', 'g'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND type = 'form' AND xml ~ '<field name="\$client"'
  AND xml NOT LIKE '%lvme-client-selection-grid%';

-- fiches : commande client, commande d'achat, arrivage
-- (la balise contient « > » dans readonlyIf : recherche limitée à la ligne du champ)
UPDATE meta_view SET xml = regexp_replace(xml, '(name="clientPartner"[^\n]*?)grid-view="[^"]*"',
    '\1grid-view="lvme-client-selection-grid"'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'sale-order-form' AND xml NOT LIKE '%lvme-client-selection-grid%';
UPDATE meta_view SET xml = regexp_replace(xml, '(name="supplierPartner"[^\n]*?)grid-view="[^"]*"',
    '\1grid-view="lvme-fournisseur-selection-grid"'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'purchase-order-form' AND xml NOT LIKE '%lvme-fournisseur-selection-grid%';
UPDATE meta_view SET xml = regexp_replace(xml, '(<field name="partner" title="Fournisseur"[^\n]*?)grid-view="partner-grid"',
    '\1grid-view="lvme-fournisseur-selection-grid"'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-arrivage-form' AND xml NOT LIKE '%lvme-fournisseur-selection-grid%';

COMMIT;

-- contrôle : écrans branchés sur chaque liste (attendu : fournisseurs 9, clients 8)
SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND type = 'form'
          AND xml LIKE '%grid-view="lvme-fournisseur-selection-grid"%') AS ecrans_fournisseurs,
  (SELECT count(*) FROM meta_view WHERE module IS NULL AND type = 'form'
          AND xml LIKE '%grid-view="lvme-client-selection-grid"%') AS ecrans_clients;

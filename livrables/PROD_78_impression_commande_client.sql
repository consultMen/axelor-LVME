-- =====================================================================
-- PROD étape 78 : impression LVME de la commande client (document interne)
--   - modèle d'impression « LVME Commande client » sur LvmeCommandeClient.rptdesign : logo LVME en haut à gauche,
--     cadre Client, cadre Commande, statut et totaux, puis les lignes avec toutes les colonnes de la fiche
--     (PR, marges), aux couleurs de la fiche
--   - boutons « Imprimer commande » et « Rapports » (renommé « Imprimer ») : impriment directement ce modèle, sans
--     fenêtre de choix (ce n'est pas le modèle de la
--     configuration des ventes : il ne part donc jamais en pièce jointe chez le client)
-- Prérequis : code avec LvmeImpressionController et reports/LvmeCommandeClient.rptdesign (recompiler).
-- Depuis la racine du dépôt. Relançable.
-- =====================================================================
BEGIN;

-- modèle BIRT et ses paramètres (repris du modèle Axelor « SaleOrder PDF » : n° de commande, langue, fuseau)
INSERT INTO base_birt_template (id, version, created_on, attach, format, name, template_engine_select, template_link,
  created_by, meta_model)
SELECT nextval('base_birt_template_seq'), 0, now(), false, 'pdf', 'LVME Commande client PDF', 2,
  'LvmeCommandeClient.rptdesign', 1, (SELECT id FROM meta_model WHERE name = 'SaleOrder')
WHERE NOT EXISTS (SELECT 1 FROM base_birt_template WHERE name = 'LVME Commande client PDF');

INSERT INTO base_birt_template_parameter (id, version, created_on, name, type, value, created_by, birt_template)
SELECT nextval('base_birt_template_parameter_seq'), 0, now(), p.name, p.type, p.value, 1,
  (SELECT id FROM base_birt_template WHERE name = 'LVME Commande client PDF')
FROM (VALUES
  ('SaleOrderId', 'decimal', '$SaleOrder.id'),
  ('Timezone', 'string', '${SaleOrder.company?.timezone}'),
  ('__locale', 'string', '${com.axelor.apps.report.engine.ReportSettings.getPrintingLocale(SaleOrder.clientPartner)}')
) AS p(name, type, value)
WHERE NOT EXISTS (SELECT 1 FROM base_birt_template_parameter x
  WHERE x.name = p.name AND x.birt_template = (SELECT id FROM base_birt_template WHERE name = 'LVME Commande client PDF'));

-- modèle d'impression (nom du fichier : « Commande client SO… - date »)
INSERT INTO base_printing_template (id, version, created_on, name, script_field_name, status_select, to_attach,
  created_by, meta_model)
SELECT nextval('base_printing_template_seq'), 0, now(), 'LVME Commande client',
  '${''Commande client '' + SaleOrder.saleOrderSeq + ''-'' + date}', 2, false, 1,
  (SELECT id FROM meta_model WHERE name = 'SaleOrder')
WHERE NOT EXISTS (SELECT 1 FROM base_printing_template WHERE name = 'LVME Commande client');

INSERT INTO base_printing_template_line (id, version, created_on, sequence, type_select, created_by, birt_template,
  print_template)
SELECT nextval('base_printing_template_line_seq'), 0, now(), 0, 2, 1,
  (SELECT id FROM base_birt_template WHERE name = 'LVME Commande client PDF'),
  (SELECT id FROM base_printing_template WHERE name = 'LVME Commande client')
WHERE NOT EXISTS (SELECT 1 FROM base_printing_template_line
  WHERE print_template = (SELECT id FROM base_printing_template WHERE name = 'LVME Commande client'));

-- action du bouton « Imprimer commande »
DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-cde-imprimer';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-imprimer', 'action-method', NULL,
'<action-method name="action-lvme-cde-imprimer">
  <!-- impression interne LVME de la commande client (modèle « LVME Commande client ») -->
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionController" method="imprimerCommandeClient"/>
</action-method>', false, false, 0);

UPDATE meta_view SET xml = replace(xml,
  '<button name="lvmeImprimerCommandeBtn" title="Imprimer commande" icon="printer" showIf="id" onClick="save,action-sale-order-view-reports-wizard"/>',
  '<button name="lvmeImprimerCommandeBtn" title="Imprimer commande" icon="printer" showIf="id" onClick="save,action-lvme-cde-imprimer"/>'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30
  AND xml LIKE '%name="lvmeImprimerCommandeBtn"%onClick="save,action-sale-order-view-reports-wizard"%';

-- bouton « Rapports » de la barre du haut (renommé « Imprimer ») : même impression directe, plus de fenêtre de
-- choix du modèle
UPDATE meta_view SET xml = replace(xml,
  '<button name="printBtn" title="Reports" hideIf="clientPartner == null" readonlyIf="!id" icon="fa-print" onClick="save,action-sale-order-view-reports-wizard"/>',
  '<button name="printBtn" title="Imprimer" hideIf="clientPartner == null" readonlyIf="!id" icon="fa-print" onClick="save,action-lvme-cde-imprimer"/>'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30
  AND xml LIKE '%name="printBtn"%onClick="save,action-sale-order-view-reports-wizard"%';

COMMIT;

SELECT pt.name AS modele, bt.template_link AS fichier,
  (SELECT count(*) FROM base_birt_template_parameter x WHERE x.birt_template = bt.id) AS parametres,
  (SELECT (length(xml) - length(replace(xml, 'action-lvme-cde-imprimer', ''))) / 24 FROM meta_view
    WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30) AS boutons_branches
FROM base_printing_template pt
JOIN base_printing_template_line l ON l.print_template = pt.id
JOIN base_birt_template bt ON bt.id = l.birt_template
WHERE pt.name = 'LVME Commande client';

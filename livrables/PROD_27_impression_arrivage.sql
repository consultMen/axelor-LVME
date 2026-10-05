-- =====================================================================
-- PROD étape 27 : impression de l'Arrivage comme l'écran GESCOM (bouton « Editer » > « Imprimer l'arrivage »)
--   - rapport BIRT LvmeArrivage.rptdesign (code : axelor-stock/src/main/resources/reports), paysage A4 :
--     en-tête Fournisseur / Arrivage / Devise (Cours, Couvert, Flottant, Réel, Mt Achat HT, équivalent,
--     Nb Colis, Poids Total) + toutes les colonnes des lignes + ligne « Somme »
--   - modèle d'impression « Arrivage LVME » + action d'impression
--   - recherche des Arrivages : filtre « N° Arrivage » (relance de PROD_9 depuis sa source à jour)
-- Code à déployer avec ce script (rapport + méthode StockMoveController.printArrivageLvme).
-- À lancer depuis la racine du dépôt, puis redémarrer Axelor. Relançable.
-- =====================================================================
BEGIN;

-- ---------- Modèle BIRT ----------
INSERT INTO base_birt_template (id, version, created_on, name, template_link, format, template_engine_select, meta_model, attach)
SELECT nextval('base_birt_template_seq'), 0, now(), 'Arrivage LVME', 'LvmeArrivage.rptdesign', 'pdf', 2,
       (SELECT id FROM meta_model WHERE name = 'StockMove'), false
WHERE NOT EXISTS (SELECT 1 FROM base_birt_template WHERE name = 'Arrivage LVME');
UPDATE base_birt_template SET template_link = 'LvmeArrivage.rptdesign', format = 'pdf' WHERE name = 'Arrivage LVME';

INSERT INTO base_birt_template_parameter (id, version, created_on, birt_template, name, type, value)
SELECT nextval('base_birt_template_parameter_seq'), 0, now(), b.id, v.name, v.type, v.value
FROM base_birt_template b
JOIN (VALUES ('StockMoveId', 'decimal', '$StockMove.id'),
             ('Timezone', 'string', '${StockMove.company?.timezone}')) AS v(name, type, value) ON true
WHERE b.name = 'Arrivage LVME'
  AND NOT EXISTS (SELECT 1 FROM base_birt_template_parameter p WHERE p.birt_template = b.id AND p.name = v.name);

-- ---------- Modèle d'impression ----------
INSERT INTO base_printing_template (id, version, created_on, name, script_field_name, status_select, to_attach, meta_model)
SELECT nextval('base_printing_template_seq'), 0, now(), 'Arrivage LVME',
       '${''Arrivage '' + StockMove.stockMoveSeq}', 2, false, (SELECT id FROM meta_model WHERE name = 'StockMove')
WHERE NOT EXISTS (SELECT 1 FROM base_printing_template WHERE name = 'Arrivage LVME');

INSERT INTO base_printing_template_line (id, version, created_on, sequence, type_select, birt_template, print_template)
SELECT nextval('base_printing_template_line_seq'), 0, now(), 0, 2,
       (SELECT id FROM base_birt_template WHERE name = 'Arrivage LVME'),
       (SELECT id FROM base_printing_template WHERE name = 'Arrivage LVME')
WHERE NOT EXISTS (SELECT 1 FROM base_printing_template_line l
                  WHERE l.print_template = (SELECT id FROM base_printing_template WHERE name = 'Arrivage LVME'));

-- ---------- Action « Imprimer l'arrivage » ----------
DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-arrivage-imprimer';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-imprimer', 'action-method', NULL,
'<action-method name="action-lvme-arrivage-imprimer">
  <call class="com.axelor.apps.stock.web.StockMoveController" method="printArrivageLvme"/>
</action-method>', false, false);
COMMIT;

-- ---------- Écrans Arrivages (bouton Editer + filtre N° Arrivage) ----------
\i livrables/PROD_9_arrivages.sql

SELECT t.name, b.template_link, (SELECT count(*) FROM base_birt_template_parameter p WHERE p.birt_template = b.id) AS parametres
FROM base_printing_template t
JOIN base_printing_template_line l ON l.print_template = t.id
JOIN base_birt_template b ON b.id = l.birt_template
WHERE t.name = 'Arrivage LVME';

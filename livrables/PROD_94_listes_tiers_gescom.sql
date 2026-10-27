-- =====================================================================
-- PROD étape 94 : listes Clients, Fournisseurs et Transporteurs comme GESCOM, sur un seul écran
--   - Clients / Fournisseurs : présentation GESCOM de la liste Articles (repère lvme-ges-art : cadre Recherche,
--     en-têtes gris, lignes serrées, liste sur toute la hauteur) ; colonnes GESCOM (diapos 5 et 30) avec Contact
--     (premier contact du tiers) et Secteur pour les clients
--   - Transporteurs : nouvel écran sur le même modèle (recherche rapide par nom / ville / code postal / téléphone,
--     nouveau transporteur, archivés) ; le menu « Freight Carrier » devient « Transporteurs » et ouvre cet écran
-- Prérequis : code avec Partner.lvmeContact (recompiler) ; PROD_12. Sources : livrables/ui/lvme-client-search-form.xml,
-- lvme-fournisseur-search-form.xml, partner-customer-grid.xml, partner-supplier-grid.xml,
-- lvme-transporteur-search-form.xml, lvme-transporteur-grid.xml. Relançable.
-- =====================================================================
\set fCli `cat livrables/ui/lvme-client-search-form.xml`
\set fFou `cat livrables/ui/lvme-fournisseur-search-form.xml`
\set gCli `cat livrables/ui/partner-customer-grid.xml`
\set gFou `cat livrables/ui/partner-supplier-grid.xml`
\set fTra `cat livrables/ui/lvme-transporteur-search-form.xml`
\set gTra `cat livrables/ui/lvme-transporteur-grid.xml`
SELECT set_config('lvme.fCli', :'fCli', false) IS NOT NULL AND set_config('lvme.fFou', :'fFou', false) IS NOT NULL
   AND set_config('lvme.gCli', :'gCli', false) IS NOT NULL AND set_config('lvme.gFou', :'gFou', false) IS NOT NULL
   AND set_config('lvme.fTra', :'fTra', false) IS NOT NULL AND set_config('lvme.gTra', :'gTra', false) IS NOT NULL
   AS vues_lues;

BEGIN;

-- liste de choix « Recherche rapide par » des transporteurs
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, 'lvme.recherche.transporteur.select', 0, true
WHERE NOT EXISTS (SELECT 1 FROM meta_select s WHERE s.name = 'lvme.recherche.transporteur.select');
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('1', 'Nom transporteur', 1), ('3', 'Ville', 2), ('4', 'Code Postal', 3), ('5', 'Téléphone', 4))
  AS v(value, title, seq) ON true
WHERE s.name = 'lvme.recherche.transporteur.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- actions de l'écran Transporteurs
UPDATE meta_menu SET action = NULL
WHERE action IN (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-transporteur-open');
DELETE FROM meta_action WHERE module IS NULL
  AND name IN ('action-lvme-transporteur-open', 'action-lvme-transporteur-dashlet', 'action-lvme-transporteur-new');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-transporteur-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-transporteur-open" title="Transporteurs" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-transporteur-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-transporteur-dashlet', 'action-view', 'com.axelor.apps.base.db.Partner',
'<action-view name="action-lvme-transporteur-dashlet" title="Transporteurs" model="com.axelor.apps.base.db.Partner">
  <view type="grid" name="lvme-transporteur-grid"/>
  <view type="form" name="partner-form"/>
  <view-param name="showArchived" value="true"/>
  <view-param name="dashlet.canSearch" value="true"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <domain>self.isContact = false AND self.isCarrier = true
    AND (:_val = ''%'' OR (:_crit = 1 AND LOWER(self.name) LIKE :_val)
      OR (:_crit = 3 AND EXISTS (SELECT 1 FROM Address a WHERE a = self.mainAddress AND LOWER(a.city.name) LIKE :_val))
      OR (:_crit = 4 AND EXISTS (SELECT 1 FROM Address a WHERE a = self.mainAddress AND a.zip LIKE :_val))
      OR (:_crit = 5 AND (self.fixedPhone LIKE :_val OR self.mobilePhone LIKE :_val)))
    AND ((:_archives = true AND self.archived = true) OR (:_archives = false AND (self.archived IS NULL OR self.archived = false)))</domain>
  <context name="_archives" expr="eval: archives ? true : false"/>
  <context name="_crit" expr="eval: (critere ?: 1) as Integer"/>
  <context name="_val" expr="eval: valeur ? ''%'' + valeur.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_isCarrier" expr="true"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-transporteur-new', 'action-view', 'com.axelor.apps.base.db.Partner',
'<action-view name="action-lvme-transporteur-new" title="Transporteur" model="com.axelor.apps.base.db.Partner">
  <view type="form" name="partner-form"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_isCarrier" expr="true"/>
</action-view>', false, false, 0);

-- vues
UPDATE meta_view SET xml = current_setting('lvme.fCli'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-client-search-form' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.fFou'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-fournisseur-search-form' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.gCli'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'partner-customer-grid' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.gFou'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'partner-supplier-grid' AND module IS NULL;
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-transporteur-search-form', 'lvme-transporteur-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-transporteur-search-form', 'Transporteurs', 'form', 'com.axelor.utils.db.Wizard',
 20, current_setting('lvme.fTra'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-transporteur-grid', 'Transporteurs', 'grid', 'com.axelor.apps.base.db.Partner',
 20, current_setting('lvme.gTra'), false, false);

-- menu « Freight Carrier » -> « Transporteurs »
UPDATE meta_menu SET title = 'Transporteurs',
  action = (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-transporteur-open')
WHERE name = 'stock-root-conf-freight-carrier';

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND (
          (name IN ('lvme-client-search-form', 'lvme-fournisseur-search-form', 'lvme-transporteur-search-form')
           AND xml LIKE '%lvme-ges-art%')
          OR (name IN ('partner-customer-grid', 'partner-supplier-grid', 'lvme-transporteur-grid') AND xml LIKE '%lvmeContact%')))
         AS vues_modifiees,
       (SELECT a.name FROM meta_menu m JOIN meta_action a ON a.id = m.action WHERE m.name = 'stock-root-conf-freight-carrier')
         AS menu_transporteurs;

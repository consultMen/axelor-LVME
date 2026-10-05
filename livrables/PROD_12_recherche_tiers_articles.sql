-- =====================================================================
-- PROD étape 12 : écrans « Recherche rapide par … » de GESCOM pour Clients, Fournisseurs, Articles
--   Cadre Recherche (critère + saisie + bouton Recherche) au-dessus de la liste (grilles de PROD_11).
--   Menus Ventes > Clients, Achats > Fournisseurs, Ventes / Achats > Produits ouverts sur ces écrans
--   (mêmes filtres de base que les menus Axelor d'origine).
-- Prérequis : PROD_11. À lancer depuis la racine du dépôt, puis redémarrer Axelor. Relançable.
-- =====================================================================
\set fCli `cat livrables/ui/lvme-client-search-form.xml`
\set fFou `cat livrables/ui/lvme-fournisseur-search-form.xml`
\set fArt `cat livrables/ui/lvme-article-search-form.xml`
\set fArtA `cat livrables/ui/lvme-article-achat-search-form.xml`
SELECT set_config('lvme.fCli', :'fCli', false), set_config('lvme.fFou', :'fFou', false),
       set_config('lvme.fArt', :'fArt', false), set_config('lvme.fArtA', :'fArtA', false);

BEGIN;

-- ---------- Listes « Recherche rapide par » ----------
INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, v.name, 0, true
FROM (VALUES ('lvme.recherche.client.select'), ('lvme.recherche.fournisseur.select'), ('lvme.recherche.article.select')) AS v(name)
WHERE NOT EXISTS (SELECT 1 FROM meta_select s WHERE s.name = v.name);
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, v.value, v.title, v.seq
FROM meta_select s
JOIN (VALUES ('lvme.recherche.client.select', '1', 'Nom client', 1), ('lvme.recherche.client.select', '2', 'Référence', 2),
             ('lvme.recherche.client.select', '3', 'Ville', 3), ('lvme.recherche.client.select', '4', 'Code Postal', 4),
             ('lvme.recherche.client.select', '5', 'Téléphone', 5), ('lvme.recherche.client.select', '6', 'Vendeur', 6),
             ('lvme.recherche.fournisseur.select', '1', 'Nom fournisseur', 1), ('lvme.recherche.fournisseur.select', '2', 'Référence', 2),
             ('lvme.recherche.fournisseur.select', '3', 'Ville', 3), ('lvme.recherche.fournisseur.select', '4', 'Code Postal', 4),
             ('lvme.recherche.fournisseur.select', '5', 'Téléphone', 5),
             ('lvme.recherche.article.select', '1', 'Référence article', 1), ('lvme.recherche.article.select', '2', 'Désignation', 2),
             ('lvme.recherche.article.select', '3', 'Gencode', 3), ('lvme.recherche.article.select', '4', 'Fournisseur', 4))
  AS v(sel, value, title, seq) ON v.sel = s.name
WHERE NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = v.value);

-- ---------- Actions ----------
UPDATE meta_menu SET action = NULL
WHERE name IN ('sc-root-sale-customers', 'sc-root-purchase-suppliers', 'sc-root-sale-products', 'sc-root-purchase-products')
  AND action IN (SELECT id FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-client-open',
    'action-lvme-fournisseur-open', 'action-lvme-article-open', 'action-lvme-article-achat-open'));
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-recherche-defaults', 'action-lvme-recherche-refresh',
  'action-lvme-client-open', 'action-lvme-client-dashlet', 'action-lvme-client-new',
  'action-lvme-fournisseur-open', 'action-lvme-fournisseur-dashlet', 'action-lvme-fournisseur-new',
  'action-lvme-article-open', 'action-lvme-article-dashlet', 'action-lvme-article-new',
  'action-lvme-article-achat-open', 'action-lvme-article-achat-dashlet', 'action-lvme-article-achat-new');

INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-recherche-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-recherche-defaults">
  <attribute name="value" for="$critere" expr="eval: 1"/>
</action-attrs>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-recherche-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-recherche-refresh">
  <attribute name="refresh" for="listeDashlet" expr="eval: true"/>
</action-attrs>', false, false),

-- Clients
(nextval('meta_action_seq'), 0, now(), 'action-lvme-client-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-client-open" title="Clients" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-client-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-client-dashlet', 'action-view', 'com.axelor.apps.base.db.Partner',
'<action-view name="action-lvme-client-dashlet" title="Clients" model="com.axelor.apps.base.db.Partner">
  <view type="grid" name="partner-customer-grid"/>
  <view type="form" name="partner-customer-form"/>
  <view-param name="showArchived" value="true"/>
  <view-param name="dashlet.canSearch" value="true"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <domain>self.isContact = false AND (self.isCustomer = true OR self.isProspect = true)
    AND (:_val = ''%'' OR (:_crit = 1 AND LOWER(self.name) LIKE :_val) OR (:_crit = 2 AND LOWER(self.partnerSeq) LIKE :_val)
      OR (:_crit = 3 AND EXISTS (SELECT 1 FROM Address a WHERE a = self.mainAddress AND LOWER(a.city.name) LIKE :_val))
      OR (:_crit = 4 AND EXISTS (SELECT 1 FROM Address a WHERE a = self.mainAddress AND a.zip LIKE :_val))
      OR (:_crit = 5 AND (self.fixedPhone LIKE :_val OR self.mobilePhone LIKE :_val))
      OR (:_crit = 6 AND EXISTS (SELECT 1 FROM User u WHERE u = self.commercial AND LOWER(u.name) LIKE :_val)))
    AND ((:_archives = true AND self.archived = true) OR (:_archives = false AND (self.archived IS NULL OR self.archived = false)))</domain>
  <context name="_archives" expr="eval: archives ? true : false"/>
  <context name="_crit" expr="eval: (critere ?: 1) as Integer"/>
  <context name="_val" expr="eval: valeur ? ''%'' + valeur.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_isCustomer" expr="true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-client-new', 'action-view', 'com.axelor.apps.base.db.Partner',
'<action-view name="action-lvme-client-new" title="Client" model="com.axelor.apps.base.db.Partner">
  <view type="form" name="partner-customer-form"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_isCustomer" expr="true"/>
</action-view>', false, false),

-- Fournisseurs
(nextval('meta_action_seq'), 0, now(), 'action-lvme-fournisseur-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-fournisseur-open" title="Fournisseurs" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-fournisseur-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-fournisseur-dashlet', 'action-view', 'com.axelor.apps.base.db.Partner',
'<action-view name="action-lvme-fournisseur-dashlet" title="Fournisseurs" model="com.axelor.apps.base.db.Partner">
  <view type="grid" name="partner-supplier-grid"/>
  <view type="form" name="partner-supplier-form"/>
  <view-param name="showArchived" value="true"/>
  <view-param name="dashlet.canSearch" value="true"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <domain>self.isContact = false AND self.isSupplier = true
    AND (:_val = ''%'' OR (:_crit = 1 AND LOWER(self.name) LIKE :_val) OR (:_crit = 2 AND LOWER(self.partnerSeq) LIKE :_val)
      OR (:_crit = 3 AND EXISTS (SELECT 1 FROM Address a WHERE a = self.mainAddress AND LOWER(a.city.name) LIKE :_val))
      OR (:_crit = 4 AND EXISTS (SELECT 1 FROM Address a WHERE a = self.mainAddress AND a.zip LIKE :_val))
      OR (:_crit = 5 AND (self.fixedPhone LIKE :_val OR self.mobilePhone LIKE :_val)))
    AND ((:_archives = true AND self.archived = true) OR (:_archives = false AND (self.archived IS NULL OR self.archived = false)))</domain>
  <context name="_archives" expr="eval: archives ? true : false"/>
  <context name="_crit" expr="eval: (critere ?: 1) as Integer"/>
  <context name="_val" expr="eval: valeur ? ''%'' + valeur.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_isSupplier" expr="true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-fournisseur-new', 'action-view', 'com.axelor.apps.base.db.Partner',
'<action-view name="action-lvme-fournisseur-new" title="Fournisseur" model="com.axelor.apps.base.db.Partner">
  <view type="form" name="partner-supplier-form"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_isSupplier" expr="true"/>
</action-view>', false, false),

-- Articles (ventes)
(nextval('meta_action_seq'), 0, now(), 'action-lvme-article-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-article-open" title="Articles" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-article-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-article-dashlet', 'action-view', 'com.axelor.apps.base.db.Product',
'<action-view name="action-lvme-article-dashlet" title="Articles" model="com.axelor.apps.base.db.Product">
  <view type="grid" name="product-grid"/>
  <view type="form" name="product-form"/>
  <view-param name="showArchived" value="true"/>
  <view-param name="dashlet.canSearch" value="true"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <domain>self.isModel = false AND self.sellable = true AND self.isShippingCostsProduct = false AND self.dtype = ''Product''
    AND (:_val = ''%'' OR (:_crit = 1 AND LOWER(self.code) LIKE :_val) OR (:_crit = 2 AND LOWER(self.name) LIKE :_val)
      OR (:_crit = 3 AND self.gencode LIKE :_val)
      OR (:_crit = 4 AND EXISTS (SELECT 1 FROM Partner p WHERE p = self.defaultSupplierPartner AND LOWER(p.name) LIKE :_val)))
    AND ((:_archives = true AND self.archived = true) OR (:_archives = false AND (self.archived IS NULL OR self.archived = false)))</domain>
  <context name="_archives" expr="eval: archives ? true : false"/>
  <context name="_crit" expr="eval: (critere ?: 1) as Integer"/>
  <context name="_val" expr="eval: valeur ? ''%'' + valeur.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_fromSale" expr="eval: true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-article-new', 'action-view', 'com.axelor.apps.base.db.Product',
'<action-view name="action-lvme-article-new" title="Article" model="com.axelor.apps.base.db.Product">
  <view type="form" name="product-form"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_fromSale" expr="eval: true"/>
</action-view>', false, false),

-- Articles (achats)
(nextval('meta_action_seq'), 0, now(), 'action-lvme-article-achat-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-article-achat-open" title="Articles" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-article-achat-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-article-achat-dashlet', 'action-view', 'com.axelor.apps.base.db.Product',
'<action-view name="action-lvme-article-achat-dashlet" title="Articles" model="com.axelor.apps.base.db.Product">
  <view type="grid" name="product-purchase-grid"/>
  <view type="form" name="product-form"/>
  <view-param name="showArchived" value="true"/>
  <view-param name="dashlet.canSearch" value="true"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <domain>self.isModel = false AND self.purchasable = true AND self.dtype = ''Product''
    AND (:_val = ''%'' OR (:_crit = 1 AND LOWER(self.code) LIKE :_val) OR (:_crit = 2 AND LOWER(self.name) LIKE :_val)
      OR (:_crit = 3 AND self.gencode LIKE :_val)
      OR (:_crit = 4 AND EXISTS (SELECT 1 FROM Partner p WHERE p = self.defaultSupplierPartner AND LOWER(p.name) LIKE :_val)))
    AND ((:_archives = true AND self.archived = true) OR (:_archives = false AND (self.archived IS NULL OR self.archived = false)))</domain>
  <context name="_archives" expr="eval: archives ? true : false"/>
  <context name="_crit" expr="eval: (critere ?: 1) as Integer"/>
  <context name="_val" expr="eval: valeur ? ''%'' + valeur.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_fromPurchase" expr="eval: true"/>
</action-view>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-article-achat-new', 'action-view', 'com.axelor.apps.base.db.Product',
'<action-view name="action-lvme-article-achat-new" title="Article" model="com.axelor.apps.base.db.Product">
  <view type="form" name="product-form"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_fromPurchase" expr="eval: true"/>
</action-view>', false, false);

-- ---------- Vues ----------
DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-client-search-form', 'lvme-fournisseur-search-form',
  'lvme-article-search-form', 'lvme-article-achat-search-form');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-client-search-form', 'Clients', 'form', 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fCli'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-fournisseur-search-form', 'Fournisseurs', 'form', 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fFou'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-article-search-form', 'Articles', 'form', 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fArt'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-article-achat-search-form', 'Articles', 'form', 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fArtA'), false, false);

-- ---------- Menus ----------
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-client-open') WHERE name = 'sc-root-sale-customers';
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-fournisseur-open') WHERE name = 'sc-root-purchase-suppliers';
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-article-open') WHERE name = 'sc-root-sale-products';
UPDATE meta_menu SET action = (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-article-achat-open') WHERE name = 'sc-root-purchase-products';

COMMIT;

SELECT m.name, a.name AS action FROM meta_menu m LEFT JOIN meta_action a ON a.id = m.action
WHERE m.name IN ('sc-root-sale-customers', 'sc-root-purchase-suppliers', 'sc-root-sale-products', 'sc-root-purchase-products');

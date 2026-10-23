-- =====================================================================
-- PROD étape 73 : filtres des écrans « Suivi des … » (Kanban) et suppression de plusieurs pièces
--   - menu ▾ de la recherche des 3 Kanban : filtres tout prêts (en retard, bateau / camion, du mois, livraison
--     aujourd'hui, marge négative)
--   - les boutons « Suivi des … » ouvrent le Kanban avec les filtres saisis au-dessus de la liste
--   - corbeille native dans l'en-tête de la liste de chaque écran de recherche (commandes clients, achats,
--     arrivages, clients, fournisseurs, articles) : supprime les lignes cochées ; pour les
--     commandes et arrivages, contrôle avant (brouillons et annulés seulement, sinon rien n'est supprimé)
-- Sources : livrables/ui/*-kanban-filtres.xml ; écrit par livrables/outils/gen_prod73_filtres_suppression.py
-- Prérequis : PROD_68 à PROD_71 ; code avec LvmeSuppressionController (suppression de plusieurs lignes, recompiler).
-- Depuis la racine du dépôt. Relançable.
-- =====================================================================
\set f0 `cat livrables/ui/arrivage-kanban-filtres.xml`
SELECT set_config('lvme.filtres0', :'f0', false) IS NOT NULL AS filtres_lus;
\set f1 `cat livrables/ui/achat-kanban-filtres.xml`
SELECT set_config('lvme.filtres1', :'f1', false) IS NOT NULL AS filtres_lus;
\set f2 `cat livrables/ui/commande-client-kanban-filtres.xml`
SELECT set_config('lvme.filtres2', :'f2', false) IS NOT NULL AS filtres_lus;

BEGIN;

DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-arrivage-kanban-filters', 'lvme-achat-kanban-filters', 'lvme-commande-client-kanban-filters');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-arrivage-kanban-filters', 'lvme-arrivage-kanban-filters', 'search-filters', 'com.axelor.apps.stock.db.StockMove', 20, current_setting('lvme.filtres0'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-achat-kanban-filters', 'lvme-achat-kanban-filters', 'search-filters', 'com.axelor.apps.purchase.db.PurchaseOrder', 20, current_setting('lvme.filtres1'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-commande-client-kanban-filters', 'lvme-commande-client-kanban-filters', 'search-filters', 'com.axelor.apps.sale.db.SaleOrder', 20, current_setting('lvme.filtres2'), false, false);

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-arrivage-kanban', 'action-lvme-achat-kanban', 'action-lvme-cde-client-kanban', 'action-lvme-verifier-suppression-cde-client', 'action-lvme-verifier-suppression-cde-achat', 'action-lvme-verifier-suppression-arrivage');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-arrivage-kanban', 'action-view', 'com.axelor.apps.stock.db.StockMove',
'<action-view name="action-lvme-arrivage-kanban" title="Suivi des arrivages" model="com.axelor.apps.stock.db.StockMove">
  <view type="kanban" name="lvme-arrivage-kanban"/>
  <view type="grid" name="lvme-arrivage-grid"/>
  <view type="form" name="lvme-arrivage-form"/>
  <view-param name="search-filters" value="lvme-arrivage-kanban-filters"/>
  <!-- LVME : mêmes filtres que ceux saisis au-dessus de la liste -->
  <domain>self.typeSelect = 3 AND self.isReversion = FALSE AND (self.archived IS NULL OR self.archived = false)
    AND LOWER(COALESCE(self.stockMoveSeq, '''')) LIKE :_num
    AND (:_fou = 0 OR self.partner.id = :_fou)
    AND (:_dateFiltre = false OR self.createdOn BETWEEN :_dateDu AND :_dateAu)
    AND (:_arrFiltre = false OR (self.realDate BETWEEN :_arrDu AND :_arrAu)
         OR (self.realDate IS NULL AND self.estimatedDate BETWEEN :_arrDu AND :_arrAu))</domain>
  <context name="_num" expr="eval: numeroArrivage ? ''%'' + numeroArrivage.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_fou" expr="eval: (fournisseur?.id ?: 0) as Long"/>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)).atStartOfDay() : java.time.LocalDateTime.of(1900, 1, 1, 0, 0)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)).atTime(23, 59, 59) : java.time.LocalDateTime.of(2999, 12, 31, 0, 0)"/>
  <context name="_arrFiltre" expr="eval: arriveeDu != null || arriveeAu != null"/>
  <context name="_arrDu" expr="eval: arriveeDu ? java.time.LocalDate.parse(arriveeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_arrAu" expr="eval: arriveeAu ? java.time.LocalDate.parse(arriveeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-kanban', 'action-view', 'com.axelor.apps.purchase.db.PurchaseOrder',
'<action-view name="action-lvme-achat-kanban" title="Suivi des commandes d''achat" model="com.axelor.apps.purchase.db.PurchaseOrder">
  <view type="kanban" name="lvme-achat-kanban"/>
  <view type="grid" name="lvme-achat-grid"/>
  <view type="form" name="purchase-order-form"/>
  <view-param name="search-filters" value="lvme-achat-kanban-filters"/>
  <!-- LVME : mêmes filtres que ceux saisis au-dessus de la liste -->
  <domain>(:_dateFiltre = false OR self.orderDate BETWEEN :_dateDu AND :_dateAu)
    AND (:_arrFiltre = false OR self.estimatedReceiptDate BETWEEN :_arrDu AND :_arrAu)
    AND (:_fouDu = '''' OR self.supplierPartner.name &gt;= :_fouDu) AND (:_fouAu = '''' OR self.supplierPartner.name &lt;= :_fouAu)
    AND (:_transport = 0 OR self.shipmentMode.id = :_transport)</domain>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_arrFiltre" expr="eval: arriveeDu != null || arriveeAu != null"/>
  <context name="_arrDu" expr="eval: arriveeDu ? java.time.LocalDate.parse(arriveeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_arrAu" expr="eval: arriveeAu ? java.time.LocalDate.parse(arriveeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_fouDu" expr="eval: fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.name ?: '''') : ''''"/>
  <context name="_fouAu" expr="eval: fournisseurAu?.id ? (__repo__(Partner).find(fournisseurAu.id as Long)?.name ?: '''') : (fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.name ?: '''') : '''')"/>
  <context name="_transport" expr="eval: (typeTransport?.id ?: 0) as Long"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-kanban', 'action-view', 'com.axelor.apps.sale.db.SaleOrder',
'<action-view name="action-lvme-cde-client-kanban" title="Suivi des commandes clients" model="com.axelor.apps.sale.db.SaleOrder">
  <view type="kanban" name="lvme-commande-client-kanban"/>
  <view type="grid" name="lvme-commande-client-grid"/>
  <view type="form" name="sale-order-form"/>
  <view-param name="search-filters" value="lvme-commande-client-kanban-filters"/>
  <!-- LVME : mêmes filtres que ceux saisis au-dessus de la liste -->
  <domain>self.template = false
    AND (:_client = 0 OR self.clientPartner.id = :_client)
    AND (:_commercial = 0 OR self.commercial.id = :_commercial)
    AND (:_dateFiltre = false OR COALESCE(self.orderDate, self.creationDate) BETWEEN :_dateDu AND :_dateAu)
    AND (:_livFiltre = false OR self.estimatedDeliveryDate BETWEEN :_livDu AND :_livAu)</domain>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_commercial" expr="eval: (commercialFiltre?.id ?: 0) as Long"/>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_livFiltre" expr="eval: livraisonDu != null || livraisonAu != null"/>
  <context name="_livDu" expr="eval: livraisonDu ? java.time.LocalDate.parse(livraisonDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_livAu" expr="eval: livraisonAu ? java.time.LocalDate.parse(livraisonAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-verifier-suppression-cde-client', 'action-method', NULL,
'<action-method name="action-lvme-verifier-suppression-cde-client">
  <call class="com.axelor.apps.supplychain.web.LvmeSuppressionController" method="verifierSuppressionCommandeClient"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-verifier-suppression-cde-achat', 'action-method', NULL,
'<action-method name="action-lvme-verifier-suppression-cde-achat">
  <call class="com.axelor.apps.supplychain.web.LvmeSuppressionController" method="verifierSuppressionCommandeAchat"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-verifier-suppression-arrivage', 'action-method', NULL,
'<action-method name="action-lvme-verifier-suppression-arrivage">
  <call class="com.axelor.apps.supplychain.web.LvmeSuppressionController" method="verifierSuppressionArrivage"/>
</action-method>', false, false, 0);

-- contrôle avant la corbeille native (3 listes de pièces) ; ancien bouton « Supprimer la sélection » retiré
UPDATE meta_view SET xml = regexp_replace(regexp_replace(regexp_replace(xml,
    '\n\s*<button name="lvmeSupprimerSelBtn"[^>]*/>', '', 'g'),
    '\s+onDelete="[^"]*"', '', 'g'),
    '^(<grid\s)', '\1onDelete="action-lvme-verifier-suppression-cde-client" ', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-commande-client-grid' AND module IS NULL;
UPDATE meta_view SET xml = regexp_replace(regexp_replace(regexp_replace(xml,
    '\n\s*<button name="lvmeSupprimerSelBtn"[^>]*/>', '', 'g'),
    '\s+onDelete="[^"]*"', '', 'g'),
    '^(<grid\s)', '\1onDelete="action-lvme-verifier-suppression-cde-achat" ', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-achat-grid' AND module IS NULL;
UPDATE meta_view SET xml = regexp_replace(regexp_replace(regexp_replace(xml,
    '\n\s*<button name="lvmeSupprimerSelBtn"[^>]*/>', '', 'g'),
    '\s+onDelete="[^"]*"', '', 'g'),
    '^(<grid\s)', '\1onDelete="action-lvme-verifier-suppression-arrivage" ', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-arrivage-grid' AND module IS NULL;
UPDATE meta_view SET xml = regexp_replace(xml, '\n\s*<toolbar>\s*</toolbar>', '', 'g'), updated_on = now()
WHERE module IS NULL AND name IN ('lvme-commande-client-grid', 'lvme-achat-grid', 'lvme-arrivage-grid') AND xml ~ '<toolbar>\s*</toolbar>';

-- corbeille native dans l'en-tête des listes intégrées des écrans de recherche
UPDATE meta_view SET xml = regexp_replace(xml, '\n\s*<button name="lvmeSelectionBtn"[^>]*/>', '', 'g'), updated_on = now()
WHERE module IS NULL AND name IN ('lvme-commande-client-search-form', 'lvme-achat-search-form', 'lvme-arrivage-search-form', 'lvme-client-search-form', 'lvme-fournisseur-search-form', 'lvme-article-search-form', 'lvme-article-achat-search-form') AND xml LIKE '%lvmeSelectionBtn%';
UPDATE meta_view SET xml = replace(xml, '<panel-dashlet ', '<panel-dashlet canDelete="true" '),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name IN ('lvme-commande-client-search-form', 'lvme-achat-search-form', 'lvme-arrivage-search-form', 'lvme-client-search-form', 'lvme-fournisseur-search-form', 'lvme-article-search-form', 'lvme-article-achat-search-form') AND xml NOT LIKE '%panel-dashlet canDelete=%';
UPDATE meta_view SET xml = replace(xml, 'title="Archiver / Supprimer"', 'title="Archiver / Désarchiver"'), updated_on = now()
WHERE module IS NULL AND name = 'lvme-arrivage-search-form' AND xml LIKE '%title="Archiver / Supprimer"%';


COMMIT;

SELECT name, type FROM meta_view WHERE module IS NULL AND name LIKE '%kanban-filters';
SELECT name, substring(xml from 'onDelete="([^"]*)"') AS controle FROM meta_view
WHERE module IS NULL AND name IN ('lvme-commande-client-grid', 'lvme-achat-grid', 'lvme-arrivage-grid');
SELECT name, position('panel-dashlet canDelete="true"' IN xml) > 0 AS corbeille FROM meta_view
WHERE module IS NULL AND name LIKE 'lvme-%search-form' ORDER BY name;

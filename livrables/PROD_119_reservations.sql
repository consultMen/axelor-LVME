-- =====================================================================
-- PROD étape 119 : écran Ventes > Réservations, comme GESCOM (30/10/2026)
--   Une réservation est une commande passée au nom d'un compte de réservation (« CASINO RESERVATIONS »…) pour un
--   groupe de clients livrés (CLIENT_RESERV, MIG_10). Un seul écran :
--   - filtres : compte de réservation, client livré, produit, période de commande, « seulement les réservations en
--     cours » (par défaut) ; boutons Rattacher / Détacher un client livré à un compte ;
--   - comptes de réservation : clients rattachés, réservations en cours, colis, poids, valeur HT ;
--   - réservé : lignes des commandes de réservation (n° de commande, compte, statut, produit, lot, frigo, D.D.M.,
--     colis, poids, montant) ; une ligne s'ouvre en consultation ;
--   - clients livrés rattachés au compte.
--   Lignes affichées : commandes des comptes de réservation, et commandes marquées « Réservation » (REC-009).
-- Prérequis : MIG_10 ; code avec les champs Partner.lvmeEstCompteReservation / lvmeCompteReservation et
-- LvmeReservationController (recompiler). À lancer depuis la racine du dépôt, Tomcat arrêté, puis redémarrer.
-- Sources : livrables/ui/lvme-reservation-search-form.xml, lvme-compte-reservation-grid.xml,
-- lvme-reservation-ligne-grid.xml, lvme-reservation-client-grid.xml. Relançable.
-- =====================================================================
\set fResa `cat livrables/ui/lvme-reservation-search-form.xml`
SELECT set_config('lvme.fResa', :'fResa', false) IS NOT NULL AS fiche_lue;
\set gComptes `cat livrables/ui/lvme-compte-reservation-grid.xml`
SELECT set_config('lvme.gComptes', :'gComptes', false) IS NOT NULL AS comptes_lus;
\set gLignes `cat livrables/ui/lvme-reservation-ligne-grid.xml`
SELECT set_config('lvme.gLignes', :'gLignes', false) IS NOT NULL AS lignes_lues;
\set gClients `cat livrables/ui/lvme-reservation-client-grid.xml`
SELECT set_config('lvme.gClients', :'gClients', false) IS NOT NULL AS clients_lus;

BEGIN;

DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-reservation-search-form', 'lvme-compte-reservation-grid',
  'lvme-reservation-ligne-grid', 'lvme-reservation-client-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-reservation-search-form', 'Réservations', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.fResa'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-compte-reservation-grid', 'Comptes de réservation', 'grid',
 'com.axelor.apps.base.db.Partner', 20, current_setting('lvme.gComptes'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-reservation-ligne-grid', 'Réservé', 'grid',
 'com.axelor.apps.sale.db.SaleOrderLine', 20, current_setting('lvme.gLignes'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-reservation-client-grid', 'Clients livrés rattachés', 'grid',
 'com.axelor.apps.base.db.Partner', 20, current_setting('lvme.gClients'), false, false);

UPDATE meta_menu SET action = NULL WHERE action IN (SELECT id FROM meta_action WHERE module IS NULL
  AND name = 'action-lvme-reservation-open');
DELETE FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-reservation-%';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-open', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-reservation-open" title="Réservations" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-reservation-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-reservation-group-onnew">
  <action name="action-lvme-reservation-defaults"/>
  <action name="action-lvme-reservation-refresh"/>
</action-group>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-reservation-defaults">
  <attribute name="value" for="$enCours" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-reservation-refresh">
  <attribute name="refresh" for="comptesDashlet" expr="eval: true"/>
  <attribute name="refresh" for="lignesDashlet" expr="eval: true"/>
  <attribute name="refresh" for="clientsDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-comptes-dashlet', 'action-view', 'com.axelor.apps.base.db.Partner',
'<action-view name="action-lvme-reservation-comptes-dashlet" title="Comptes de réservation" model="com.axelor.apps.base.db.Partner">
  <view type="grid" name="lvme-compte-reservation-grid"/>
  <view type="form" name="partner-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="forceReadonly" value="true"/>
  <domain>self.lvmeEstCompteReservation = true AND (:_compte = 0 OR self.id = :_compte)</domain>
  <context name="_compte" expr="eval: (compte?.id ?: 0) as Long"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-lignes-dashlet', 'action-view', 'com.axelor.apps.sale.db.SaleOrderLine',
'<action-view name="action-lvme-reservation-lignes-dashlet" title="Réservé" model="com.axelor.apps.sale.db.SaleOrderLine">
  <view type="grid" name="lvme-reservation-ligne-grid"/>
  <view type="form" name="sale-order-line-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="forceReadonly" value="true"/>
  <domain>self.saleOrder.template = false AND self.saleOrder.statusSelect != 5 AND self.product IS NOT NULL
    AND ((:_compte = 0 AND (self.saleOrder.clientPartner.lvmeEstCompteReservation = true OR self.saleOrder.isReservation = true))
      OR self.saleOrder.clientPartner.id = :_compte)
    AND (:_client = 0 OR self.saleOrder.clientPartner.id = :_client OR self.saleOrder.clientPartner.id = :_clientCompte)
    AND (:_produit = 0 OR self.product.id = :_produit)
    AND (:_enCours = false OR (self.saleOrder.statusSelect IN (1, 2, 3) AND COALESCE(self.deliveryState, 1) != 3))
    AND COALESCE(self.saleOrder.orderDate, self.saleOrder.creationDate) BETWEEN :_dateDu AND :_dateAu</domain>
  <context name="_compte" expr="eval: (compte?.id ?: 0) as Long"/>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_clientCompte" expr="eval: client?.id ? ((__repo__(Partner).find(client.id as Long)?.lvmeCompteReservation?.id ?: 0) as Long) : 0L"/>
  <context name="_produit" expr="eval: (produit?.id ?: 0) as Long"/>
  <context name="_enCours" expr="eval: enCours ? true : false"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-clients-dashlet', 'action-view', 'com.axelor.apps.base.db.Partner',
'<action-view name="action-lvme-reservation-clients-dashlet" title="Clients livrés rattachés" model="com.axelor.apps.base.db.Partner">
  <view type="grid" name="lvme-reservation-client-grid"/>
  <view type="form" name="partner-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="forceReadonly" value="true"/>
  <domain>self.lvmeCompteReservation IS NOT NULL AND (:_compte = 0 OR self.lvmeCompteReservation.id = :_compte)
    AND (:_client = 0 OR self.id = :_client)</domain>
  <context name="_compte" expr="eval: (compte?.id ?: 0) as Long"/>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-rattacher', 'action-method', NULL,
'<action-method name="action-lvme-reservation-rattacher">
  <call class="com.axelor.apps.supplychain.web.LvmeReservationController" method="rattacher"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-detacher', 'action-method', NULL,
'<action-method name="action-lvme-reservation-detacher">
  <call class="com.axelor.apps.supplychain.web.LvmeReservationController" method="detacher"/>
</action-method>', false, false, 0);

DELETE FROM meta_menu WHERE name = 'lvme-menu-reservations';
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, hidden, left_menu, mobile_menu, priority)
SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-reservations', 'Réservations',
  (SELECT id FROM meta_menu WHERE name = 'sc-root-sale' ORDER BY id LIMIT 1),
  (SELECT id FROM meta_action WHERE module IS NULL AND name = 'action-lvme-reservation-open'),
  coalesce((SELECT order_seq + 1 FROM meta_menu WHERE name = 'lvme-menu-prix-negocies'), 1013), false, true, false, 0;

COMMIT;

-- contrôle : 4 | 9 | 1
SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND name IN ('lvme-reservation-search-form',
          'lvme-compte-reservation-grid', 'lvme-reservation-ligne-grid', 'lvme-reservation-client-grid')) AS vues,
  (SELECT count(*) FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-reservation-%') AS actions,
  (SELECT count(*) FROM meta_menu WHERE name = 'lvme-menu-reservations' AND action IS NOT NULL) AS menu;

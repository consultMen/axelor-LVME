-- =====================================================================
-- PROD étape 64 : fiche Ligne de commande client copiée sur la fenêtre « Lignes Commandes » GESCOM
--   - bloc GESCOM (fond bleu) : Article, désignation, Gencode, Nom Scientifique ; N° Arrivage, Frigo,
--     Congélation, Conditionnement, Coef. ; N° Lot, Origine, D.L.U.O., Marque, Nb Colis / Palette ; Frais de
--     Stockage, % RFA sur Produits, Zone pêche, Colis / Couche, Prix Promo ; quantités (Nb unités ou Poids du
--     colis, Nb Colis Réservé, Nb Colis Dispo, Nb Colis Commandés, Qtés Dispo, Qtés Commandées) et prix (Taux
--     TVA, Poids en Kg, Prix Revient, Prix Vente, Montant HT, P.V - Rem., P.R. net, % Marge)
--   - boutons : Historique lot (mouvements de stock du lot), Commandes/Lot, Commandes/Art., Sélect Arrivage,
--     F1 : Historique Prix (prix déjà vendus à ce client pour cet article ; touche F1 = code de ce lot)
--   - fenêtre en pleine largeur, fond bleu, ligne du bas sur une seule ligne (cases encadrées), boutons aux
--     couleurs GESCOM ; Historique Lot avec Colis Entrés / Sortis et Qtes Entrées / Sorties ; fenêtres des
--     boutons (Commandes Clients, Historique Prix, Historique Lot) aux couleurs GESCOM
--   - dessous, inchangés : lots disponibles, lots sélectionnés, arrivages, réservations stocks, stock
--     physique… ; onglets inchangés. Aucun champ retiré. Valeurs du lot calculées par le code de ce lot.
-- Source : livrables/ui/ligne-commande-client-form.xml (fiche admin sale-order-line-form, priorité 30).
-- À lancer depuis la racine du dépôt, avant le redémarrage. Relançable.
-- Retour arrière : DELETE FROM meta_view WHERE name = 'sale-order-line-form' AND module IS NULL AND priority = 30;
-- =====================================================================
\set fiche `cat livrables/ui/ligne-commande-client-form.xml`
SELECT set_config('lvme.ligne_client', :'fiche', false) IS NOT NULL AS fiche_lue;
\set grille `cat livrables/ui/historique-lot-grid.xml`
SELECT set_config('lvme.historique_lot', :'grille', false) IS NOT NULL AS grille_lue;

BEGIN;

DELETE FROM meta_view WHERE module IS NULL AND ((name = 'sale-order-line-form' AND priority = 30) OR name = 'lvme-historique-lot-grid');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'sale-order-line-form', 'Ligne de commande', 'form',
 'com.axelor.apps.sale.db.SaleOrderLine', 30, current_setting('lvme.ligne_client'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-historique-lot-grid', 'Liste des Mouvements de Stock', 'grid',
 'com.axelor.apps.stock.db.StockMoveLine', 20, current_setting('lvme.historique_lot'), false, false);

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-ligne-cde-historique-lot',
  'action-lvme-ligne-cde-cdes-client-lot', 'action-lvme-ligne-cde-historique-prix', 'action-lvme-cdes-client-lignes-defaults',
  'action-lvme-ligne-cde-taux-tva', 'action-lvme-ligne-cde-valeurs-lot');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cde-historique-lot', 'action-view', 'com.axelor.apps.stock.db.StockMoveLine',
'<action-view name="action-lvme-ligne-cde-historique-lot" title="Liste des Mouvements de Stock" model="com.axelor.apps.stock.db.StockMoveLine">
  <view type="grid" name="lvme-historique-lot-grid"/>
  <view type="form" name="stock-move-line-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <view-param name="forceReadonly" value="true"/>
  <domain>self.trackingNumber.id = :_lotId AND self.stockMove.statusSelect != 4</domain>
  <context name="_lotId" expr="eval: (saleOrderLineLotList?.find()?.trackingNumber?.id ?: 0) as Long"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cde-cdes-client-lot', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-ligne-cde-cdes-client-lot" title="Commandes Clients" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-cdes-client-lignes-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_lotId" expr="eval: saleOrderLineLotList?.find()?.trackingNumber?.id"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cde-historique-prix', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-ligne-cde-historique-prix" title="Historique Prix" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-cdes-client-lignes-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_produitId" expr="eval: product?.id"/>
  <context name="_clientId" expr="eval: saleOrder?.clientPartner?.id ?: _parent?.clientPartner?.id"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cdes-client-lignes-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cdes-client-lignes-defaults">
  <attribute name="value" for="$dateDu" expr="eval: java.time.LocalDate.of(2000, 1, 1)"/>
  <attribute name="value" for="$dateAu" expr="eval: __date__"/>
  <attribute name="value" for="$produit" expr="eval: _produitId ? __repo__(com.axelor.apps.base.db.Product).find(_produitId as Long) : null"/>
  <attribute name="value" for="$lot" expr="eval: _lotId ? __repo__(com.axelor.apps.stock.db.TrackingNumber).find(_lotId as Long) : null"/>
  <attribute name="value" for="$client" expr="eval: _clientId ? __repo__(com.axelor.apps.base.db.Partner).find(_clientId as Long) : null"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cde-taux-tva', 'action-attrs', NULL,
'<action-attrs name="action-lvme-ligne-cde-taux-tva">
  <attribute name="value" for="$tauxTva" expr="eval: taxLineSet?.find()?.value"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cde-valeurs-lot', 'action-attrs', NULL,
'<action-attrs name="action-lvme-ligne-cde-valeurs-lot">
  <!-- valeurs du lot remplies dès le choix du lot (mêmes règles que les champs calculés de la ligne) -->
  <attribute name="value" for="lvmeLots" expr="eval: saleOrderLineLotList?.collect{ it.trackingNumber?.trackingNumberSeq }?.findAll{ it }?.unique()?.join('', '') ?: null"/>
  <attribute name="value" for="lvmeArrivages" expr="eval: saleOrderLineLotList?.collect{ it.trackingNumber?.originStockMoveLine?.stockMove?.stockMoveSeq }?.findAll{ it }?.unique()?.join('', '') ?: null"/>
  <attribute name="value" for="lvmeFrigo" expr="eval: saleOrderLineLotList?.collect{ it.trackingNumber?.originStockMoveLine?.toStockLocation?.name }?.findAll{ it }?.unique()?.join('', '') ?: null"/>
  <attribute name="value" for="lvmeOrigine" expr="eval: saleOrderLineLotList?.collect{ it.trackingNumber?.originStockMoveLine?.origine }?.findAll{ it }?.unique()?.join('', '') ?: null"/>
  <attribute name="value" for="lvmeMarque" expr="eval: saleOrderLineLotList?.collect{ it.trackingNumber?.originStockMoveLine?.marque }?.findAll{ it }?.unique()?.join('', '') ?: null"/>
  <attribute name="value" for="lvmeZonePeche" expr="eval: saleOrderLineLotList?.collect{ it.trackingNumber?.originStockMoveLine?.zonePeche }?.findAll{ it }?.unique()?.join('', '') ?: null"/>
  <attribute name="value" for="lvmeDdm" expr="eval: saleOrderLineLotList?.collect{ it.trackingNumber?.originStockMoveLine?.dluo }?.findAll{ it }?.min()"/>
  <attribute name="value" for="lvmeDateCongelation" expr="eval: saleOrderLineLotList?.collect{ it.trackingNumber?.originStockMoveLine?.dateCongelation }?.findAll{ it }?.min()"/>
  <attribute name="value" for="lvmeColisPalette" expr="eval: saleOrderLineLotList?.collect{ it.trackingNumber?.originStockMoveLine?.purchaseOrderLine?.nbColisParPalette }?.findAll{ it != null }?.max()"/>
  <attribute name="value" for="lvmeColisCouche" expr="eval: saleOrderLineLotList?.collect{ it.trackingNumber?.originStockMoveLine?.purchaseOrderLine?.nbColisParCouche }?.findAll{ it != null }?.max()"/>
  <attribute name="value" for="lvmeColisRsv" expr="eval: saleOrderLineLotList ? __repo__(com.axelor.apps.supplychain.db.EtatStockLot).all().filter(''self.trackingNumber.id IN (?1)'', saleOrderLineLotList.collect{ it.trackingNumber?.id }.findAll{ it } ?: [0L]).fetch().sum(0){ it.nbColisCdes ?: 0 } : null"/>
  <attribute name="value" for="lvmeColisDispo" expr="eval: saleOrderLineLotList ? __repo__(com.axelor.apps.supplychain.db.EtatStockLot).all().filter(''self.trackingNumber.id IN (?1)'', saleOrderLineLotList.collect{ it.trackingNumber?.id }.findAll{ it } ?: [0L]).fetch().sum(0){ (it.nbColisStock ?: 0) - (it.nbColisCdes ?: 0) } : null"/>
  <attribute name="value" for="lvmeQteDispo" expr="eval: saleOrderLineLotList ? __repo__(com.axelor.apps.supplychain.db.EtatStockLot).all().filter(''self.trackingNumber.id IN (?1)'', saleOrderLineLotList.collect{ it.trackingNumber?.id }.findAll{ it } ?: [0L]).fetch().sum(0){ it.dispoQty ?: 0 } : null"/>
</action-attrs>', false, false, 0);

-- fenêtres Commandes Clients / Historique Prix ouvertes par les boutons : mêmes couleurs GESCOM (fond bleu, lignes cyan)
UPDATE meta_view SET xml = replace(xml, '<form name="lvme-cdes-client-lignes-form" ',
  '<form name="lvme-cdes-client-lignes-form" css="lvme-gescom-liste" ')
WHERE name = 'lvme-cdes-client-lignes-form' AND module IS NULL AND xml NOT LIKE '%lvme-gescom-liste%';
UPDATE meta_view SET xml = replace(xml, '<panel name="filtresPanel" showTitle="false" colSpan="12">',
  '<panel name="filtresPanel" showTitle="false" colSpan="12" css="lvme-gescom-liste">')
WHERE name = 'lvme-cdes-client-lignes-form' AND module IS NULL AND xml NOT LIKE '%filtresPanel" showTitle="false" colSpan="12" css=%';

COMMIT;

SELECT name, priority, xml LIKE '%lvme-gescom-liste%' OR xml LIKE '%lvme-ligne-cde%' AS couleurs FROM meta_view WHERE module IS NULL
  AND name IN ('sale-order-line-form', 'lvme-historique-lot-grid', 'lvme-cdes-client-lignes-form');

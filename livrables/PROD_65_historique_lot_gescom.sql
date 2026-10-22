-- =====================================================================
-- PROD étape 65 : bouton Historique Lot de la ligne de commande client = « Liste des Mouvements de Stock » GESCOM
--   - en haut : Produit (code + désignation), N° Lot, Poids du Colis, Entrée du / au, Période prédéfinie,
--     Valider (relance la recherche) / Fermer
--   - mouvements du lot sur la période (Date, Libellé Mvts, Type, Réf.Tiers, Prix Vente, Prix Revient, Colis
--     Entrés / Sortis, Qtes Entrées / Sorties), ligne Somme
--   - en bas : Stock Période (Qtes Entrées - Qtes Sorties) et cadres des totaux
-- Source : livrables/ui/historique-lot-form.xml (fiche admin) ; écrit par livrables/outils/gen_prod65_historique_lot.py
-- Prérequis : PROD_64 (liste lvme-historique-lot-grid). À lancer depuis la racine du dépôt. Relançable.
-- Retour arrière : relancer PROD_64 (remet l'ancienne action) puis
--   DELETE FROM meta_view WHERE name = 'lvme-historique-lot-form' AND module IS NULL;
-- =====================================================================
\set fiche `cat livrables/ui/historique-lot-form.xml`
SELECT set_config('lvme.historique_lot_form', :'fiche', false) IS NOT NULL AS fiche_lue;

BEGIN;

DELETE FROM meta_view WHERE module IS NULL AND name = 'lvme-historique-lot-form';
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-historique-lot-form', 'Liste des Mouvements de Stock', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.historique_lot_form'), false, false);

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-ligne-cde-historique-lot', 'action-lvme-historique-lot-dashlet', 'action-lvme-historique-lot-defaults', 'action-lvme-historique-lot-produit-nom', 'action-lvme-historique-lot-totaux', 'action-lvme-historique-lot-refresh', 'action-lvme-historique-lot-group-refresh', 'action-lvme-historique-lot-group-onnew');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-ligne-cde-historique-lot', 'action-view', 'com.axelor.utils.db.Wizard',
'<action-view name="action-lvme-ligne-cde-historique-lot" title="Liste des Mouvements de Stock" model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-historique-lot-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_produitId" expr="eval: product?.id"/>
  <context name="_lotId" expr="eval: saleOrderLineLotList?.find()?.trackingNumber?.id"/>
  <context name="_poidsColis" expr="eval: nbUnitesParColis"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-lot-dashlet', 'action-view', 'com.axelor.apps.stock.db.StockMoveLine',
'<action-view name="action-lvme-historique-lot-dashlet" title="Liste des Mouvements de Stock" model="com.axelor.apps.stock.db.StockMoveLine">
  <view type="grid" name="lvme-historique-lot-grid"/>
  <view type="form" name="stock-move-line-form"/>
  <view-param name="forceReadonly" value="true"/>
  <domain>self.trackingNumber.id = :_lot AND self.stockMove.statusSelect != 4
    AND COALESCE(self.stockMove.realDate, self.stockMove.estimatedDate) BETWEEN :_dateDu AND :_dateAu</domain>
  <context name="_lot" expr="eval: (lot?.id ?: 0) as Long"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-lot-defaults', 'action-attrs', NULL,
'<action-attrs name="action-lvme-historique-lot-defaults">
  <attribute name="value" for="$produit" expr="eval: _produitId ? __repo__(com.axelor.apps.base.db.Product).find(_produitId as Long) : null"/>
  <attribute name="value" for="$produitNom" expr="eval: _produitId ? __repo__(com.axelor.apps.base.db.Product).find(_produitId as Long)?.name : null"/>
  <attribute name="value" for="$lot" expr="eval: _lotId ? __repo__(com.axelor.apps.stock.db.TrackingNumber).find(_lotId as Long) : null"/>
  <attribute name="value" for="$poidsColis" expr="eval: _poidsColis"/>
  <attribute name="value" for="$dateDu" expr="eval: __date__.minusYears(2)"/>
  <attribute name="value" for="$dateAu" expr="eval: __date__.plusYears(1)"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-lot-produit-nom', 'action-attrs', NULL,
'<action-attrs name="action-lvme-historique-lot-produit-nom">
  <attribute name="value" for="$produitNom" expr="eval: produit?.id ? __repo__(com.axelor.apps.base.db.Product).find(produit.id as Long)?.name : null"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-lot-totaux', 'action-attrs', NULL,
'<action-attrs name="action-lvme-historique-lot-totaux">
  <attribute name="value" for="$colisEntres" expr="eval: def du = dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1); def au = dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31); def l = lot ? __repo__(com.axelor.apps.stock.db.StockMoveLine).all().filter(''self.trackingNumber.id = ?1 AND self.stockMove.statusSelect != 4 AND COALESCE(self.stockMove.realDate, self.stockMove.estimatedDate) BETWEEN ?2 AND ?3'', lot.id, du, au).fetch() : []; l.sum(0) { it.lvmeColisEntres ?: 0 }"/>
  <attribute name="value" for="$colisSortis" expr="eval: def du = dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1); def au = dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31); def l = lot ? __repo__(com.axelor.apps.stock.db.StockMoveLine).all().filter(''self.trackingNumber.id = ?1 AND self.stockMove.statusSelect != 4 AND COALESCE(self.stockMove.realDate, self.stockMove.estimatedDate) BETWEEN ?2 AND ?3'', lot.id, du, au).fetch() : []; l.sum(0) { it.lvmeColisSortis ?: 0 }"/>
  <attribute name="value" for="$qteEntrees" expr="eval: def du = dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1); def au = dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31); def l = lot ? __repo__(com.axelor.apps.stock.db.StockMoveLine).all().filter(''self.trackingNumber.id = ?1 AND self.stockMove.statusSelect != 4 AND COALESCE(self.stockMove.realDate, self.stockMove.estimatedDate) BETWEEN ?2 AND ?3'', lot.id, du, au).fetch() : []; l.sum(0) { it.lvmeQteEntrees ?: 0 }"/>
  <attribute name="value" for="$qteSorties" expr="eval: def du = dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1); def au = dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31); def l = lot ? __repo__(com.axelor.apps.stock.db.StockMoveLine).all().filter(''self.trackingNumber.id = ?1 AND self.stockMove.statusSelect != 4 AND COALESCE(self.stockMove.realDate, self.stockMove.estimatedDate) BETWEEN ?2 AND ?3'', lot.id, du, au).fetch() : []; l.sum(0) { it.lvmeQteSorties ?: 0 }"/>
  <attribute name="value" for="$stockPeriode" expr="eval: def du = dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1); def au = dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31); def l = lot ? __repo__(com.axelor.apps.stock.db.StockMoveLine).all().filter(''self.trackingNumber.id = ?1 AND self.stockMove.statusSelect != 4 AND COALESCE(self.stockMove.realDate, self.stockMove.estimatedDate) BETWEEN ?2 AND ?3'', lot.id, du, au).fetch() : []; l.sum(0) { (it.lvmeQteEntrees ?: 0) - (it.lvmeQteSorties ?: 0) }"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-lot-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-historique-lot-refresh">
  <attribute name="refresh" for="mouvementsDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-lot-group-refresh', 'action-group', NULL,
'<action-group name="action-lvme-historique-lot-group-refresh">
  <action name="action-lvme-historique-lot-totaux"/>
  <action name="action-lvme-historique-lot-refresh"/>
</action-group>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-lot-group-onnew', 'action-group', NULL,
'<action-group name="action-lvme-historique-lot-group-onnew">
  <action name="action-lvme-historique-lot-defaults"/>
  <action name="action-lvme-historique-lot-group-refresh"/>
</action-group>', false, false, 0);

COMMIT;

SELECT count(*) AS actions FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-ligne-cde-historique-lot', 'action-lvme-historique-lot-dashlet', 'action-lvme-historique-lot-defaults', 'action-lvme-historique-lot-produit-nom', 'action-lvme-historique-lot-totaux', 'action-lvme-historique-lot-refresh', 'action-lvme-historique-lot-group-refresh', 'action-lvme-historique-lot-group-onnew');
SELECT name FROM meta_view WHERE module IS NULL AND name = 'lvme-historique-lot-form';

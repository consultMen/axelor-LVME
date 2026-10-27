-- =====================================================================
-- PROD étape 79 : écran « Historique prix » GESCOM (F1 / bouton « F1 : Historique Prix » de la ligne de commande
-- client)
--   - filtres : période du / au, période prédéfinie, client et produit de la ligne, bouton Recherche
--   - colonnes dans l'ordre GESCOM : Référence, Désignation (« B.L. N° … Du AAAAMMJJ/client », ou « Cde N° … » si
--     la commande n'est pas encore livrée), Date, Origine, Conditionnement, Poids Unitaire, Nbre Colis, Poids,
--     P.Vente Net, Montant H.T. ; ventes livrées et non livrées
--   - présentation GESCOM (police, lignes blanc / cyan, tout sur un écran) dans css/lvme.css
-- Sources : livrables/ui/historique-prix-grid.xml, livrables/ui/historique-prix-form.xml.
-- Prérequis : code avec SaleOrderLine.lvmeHistoPiece / lvmeHistoDate (recompiler). Depuis la racine du dépôt.
-- Relançable. L'écran « Commandes Clients » (boutons Commandes/Lot, Commandes/Art.) n'est pas modifié.
-- =====================================================================
\set grille `cat livrables/ui/historique-prix-grid.xml`
SELECT set_config('lvme.histo_grille', :'grille', false) IS NOT NULL AS grille_lue;
\set fiche `cat livrables/ui/historique-prix-form.xml`
SELECT set_config('lvme.histo_fiche', :'fiche', false) IS NOT NULL AS fiche_lue;

BEGIN;

DELETE FROM meta_view WHERE module IS NULL AND name IN ('lvme-historique-prix-grid', 'lvme-historique-prix-form');
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES
(nextval('meta_view_seq'), 0, now(), 'lvme-historique-prix-grid', 'Historique prix', 'grid',
 'com.axelor.apps.sale.db.SaleOrderLine', 20, current_setting('lvme.histo_grille'), false, false),
(nextval('meta_view_seq'), 0, now(), 'lvme-historique-prix-form', 'Historique prix', 'form',
 'com.axelor.utils.db.Wizard', 20, current_setting('lvme.histo_fiche'), false, false);

-- liste de l'écran : ventes de l'article au client sur la période (mêmes filtres que l'écran Commandes Clients)
DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-historique-prix-dashlet';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-prix-dashlet', 'action-view',
 'com.axelor.apps.sale.db.SaleOrderLine',
'<action-view name="action-lvme-historique-prix-dashlet" title="Historique prix" model="com.axelor.apps.sale.db.SaleOrderLine">
  <view type="grid" name="lvme-historique-prix-grid"/>
  <view type="form" name="sale-order-line-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="forceReadonly" value="true"/>
  <domain>self.saleOrder.template = false AND self.saleOrder.statusSelect != 5 AND self.product IS NOT NULL
    AND (:_produit = 0 OR self.product.id = :_produit)
    AND (:_client = 0 OR self.saleOrder.clientPartner.id = :_client)
    AND COALESCE(self.saleOrder.orderDate, self.saleOrder.creationDate) BETWEEN :_dateDu AND :_dateAu</domain>
  <context name="_produit" expr="eval: (produit?.id ?: 0) as Long"/>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false, 0);

-- F1 de la ligne de commande client : ouvre l'écran Historique prix (titre « Historique Prix » : couleurs GESCOM
-- de la fenêtre, voir js/lvme.js)
UPDATE meta_action SET xml = replace(xml, '<view type="form" name="lvme-cdes-client-lignes-form"/>',
  '<view type="form" name="lvme-historique-prix-form"/>'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'action-lvme-ligne-cde-historique-prix' AND xml LIKE '%lvme-cdes-client-lignes-form%';

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND name LIKE 'lvme-historique-prix-%') AS vues,
  (SELECT xml LIKE '%lvme-historique-prix-form%' FROM meta_action WHERE name = 'action-lvme-ligne-cde-historique-prix')
    AS f1_branche;

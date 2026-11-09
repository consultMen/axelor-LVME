-- =====================================================================
-- PROD étape 120 : « Historique prix » (F1 de la ligne de commande client) rapide avec l'historique GESCOM
--   (09/11/2026). La liste lisait les lignes de commande client, dont trois colonnes de disponibilité (Colis Rsv,
--   Colis Dispo, Qté Dispo) relisent l'état des stocks à chaque ligne : avec les 432 000 lignes de vente (MIG_06 +
--   MIG_13), plus de 30 s d'attente. Elle lit maintenant la vue lvme_historique_prix_ligne (modèle
--   HistoriquePrixLigne) : mêmes colonnes et mêmes valeurs (pièce B.L. / Cde, date, origine…), 0,25 s.
--   L'impression « Imprimer » ne change pas (requête SQL propre).
-- Prérequis : code avec le modèle HistoriquePrixLigne (recompiler). À lancer depuis la racine du dépôt, Tomcat arrêté
-- et AVANT le premier démarrage du nouveau code (vue SQL), puis redémarrer. Source : livrables/ui/historique-prix-grid.xml.
-- Relançable.
-- =====================================================================
\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_historique_prix_ligne.sql

\set gHisto `cat livrables/ui/historique-prix-grid.xml`
SELECT set_config('lvme.gHisto', :'gHisto', false) IS NOT NULL AS liste_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.gHisto'), model = 'com.axelor.apps.supplychain.db.HistoriquePrixLigne',
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-historique-prix-grid';

DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-historique-prix-dashlet';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-historique-prix-dashlet', 'action-view',
 'com.axelor.apps.supplychain.db.HistoriquePrixLigne',
'<action-view name="action-lvme-historique-prix-dashlet" title="Historique prix" model="com.axelor.apps.supplychain.db.HistoriquePrixLigne">
  <view type="grid" name="lvme-historique-prix-grid"/>
  <view-param name="popup" value="true"/>
  <view-param name="forceReadonly" value="true"/>
  <domain>(:_produit = 0 OR self.product.id = :_produit)
    AND (:_client = 0 OR self.client.id = :_client)
    AND self.orderDate BETWEEN :_dateDu AND :_dateAu</domain>
  <context name="_produit" expr="eval: (produit?.id ?: 0) as Long"/>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
</action-view>', false, false, 0);

COMMIT;

-- contrôle : liste branchée sur la vue ; lignes de vente lisibles
SELECT (SELECT model FROM meta_view WHERE module IS NULL AND name = 'lvme-historique-prix-grid') AS modele_liste,
  (SELECT count(*) FROM lvme_historique_prix_ligne) AS lignes_historique;

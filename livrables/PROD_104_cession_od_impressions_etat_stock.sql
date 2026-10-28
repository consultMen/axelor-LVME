-- =====================================================================
-- PROD étape 104 : cession de stock comme GESCOM et impressions du bas de l'État des stocks par lots
--   - Opérations Diverses sur les Stocks / Lots : type de mouvement CESSION (CE, table GESCOM STKMVT) ; Valider avec
--     ce type ouvre la fenêtre « CESSION de Stock » remplie avec le lot choisi (produit, lot, poids, libellé
--     CESSION, Sortie) ; les autres types gardent le mouvement de stock d'avant
--   - fenêtre « CESSION de Stock » présentée comme GESCOM (fond jaune, lot cédé en haut, nouveau lot en dessous,
--     Valider / Annuler à droite) ; mêmes champs et mêmes calculs (CessionStockController inchangé)
--   - État des stocks par lots : boutons en bas « Etat des Stocks sur une ligne », « Etat des Stocks / Fournisseur »,
--     « Etat des Stocks » (tableaux avec logo LVME, mêmes filtres que l'écran)
-- Prérequis : PROD_89, PROD_99 ; code avec imprimerEtatStockFournisseur / imprimerEtatStockLigne et les modèles
-- LvmeEtatStockFournisseur / LvmeEtatStockLigne.rptdesign (recompiler). À lancer depuis la racine du dépôt.
-- Sources : livrables/ui/etat-stock-lot-search-form.xml, cession-stock-form.xml. Relançable.
-- =====================================================================
\set fEtat `cat livrables/ui/etat-stock-lot-search-form.xml`
SELECT set_config('lvme.fEtat', :'fEtat', false) IS NOT NULL AS vue_etat_lue;
\set fCession `cat livrables/ui/cession-stock-form.xml`
SELECT set_config('lvme.fCession', :'fCession', false) IS NOT NULL AS vue_cession_lue;

BEGIN;

-- type de mouvement CESSION dans Opérations Diverses
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, 'CE', 'CESSION', 14
FROM meta_select s
WHERE s.name = 'lvme.od.type.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = 'CE');

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-od-stock-valider', 'action-lvme-od-stock-valider-mvt',
  'action-lvme-od-stock-cession', 'action-lvme-od-stock-type', 'action-lvme-etat-stock-lot-imprimer-ligne',
  'action-lvme-etat-stock-lot-imprimer-fournisseur', 'action-cession-stock-group-depuis-od',
  'action-cession-stock-record-depuis-od', 'action-cession-stock-record-lot-od');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-valider', 'action-group', NULL,
'<action-group name="action-lvme-od-stock-valider">
  <action name="action-lvme-od-stock-cession" if="typeMouvement == &apos;CE&apos;"/>
  <action name="action-lvme-od-stock-valider-mvt" if="typeMouvement != &apos;CE&apos;"/>
</action-group>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-valider-mvt', 'action-method', NULL,
'<action-method name="action-lvme-od-stock-valider-mvt">
  <call class="com.axelor.apps.supplychain.web.LvmeOperationDiverseController" method="valider"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-cession', 'action-view', 'com.axelor.apps.stock.db.CessionStock',
'<action-view name="action-lvme-od-stock-cession" title="CESSION de Stock" model="com.axelor.apps.stock.db.CessionStock">
  <view type="form" name="cession-stock-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
  <context name="_odLot" expr="eval: lotOd?.id"/>
  <context name="_odPoids" expr="eval: poidsOd"/>
</action-view>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-od-stock-type', 'action-attrs', NULL,
'<action-attrs name="action-lvme-od-stock-type">
  <attribute name="value" for="$sensMvt" expr="eval: typeMouvement ? ([&apos;ED&apos;, &apos;RE&apos;].contains(typeMouvement) ? &apos;Entrée&apos; : &apos;Sortie&apos;) : null"/>
  <attribute name="value" for="$libelleMvt" expr="eval: &apos;CESSION&apos;" if="typeMouvement == &apos;CE&apos;"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-imprimer-ligne', 'action-method', NULL,
'<action-method name="action-lvme-etat-stock-lot-imprimer-ligne">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerEtatStockLigne"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-imprimer-fournisseur', 'action-method', NULL,
'<action-method name="action-lvme-etat-stock-lot-imprimer-fournisseur">
  <call class="com.axelor.apps.supplychain.web.LvmeImpressionListesController" method="imprimerEtatStockFournisseur"/>
</action-method>', false, false, 0),
-- fenêtre de cession ouverte depuis les OD : type cession, produit et lot du choix, poids saisi ; le chargement du
-- produit (dernière réception) passe avant pour que le lot et le poids choisis restent ceux des OD
(nextval('meta_action_seq'), 0, now(), 'action-cession-stock-group-depuis-od', 'action-group', NULL,
'<action-group name="action-cession-stock-group-depuis-od">
  <action name="action-cession-stock-record-depuis-od" if="_odLot"/>
  <action name="action-cession-stock-method-load-from-product" if="_odLot"/>
  <action name="action-cession-stock-record-lot-od" if="_odLot"/>
  <action name="action-cession-stock-method-copy-poids-to-dest" if="_odLot"/>
</action-group>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-cession-stock-record-depuis-od', 'action-record', 'com.axelor.apps.stock.db.CessionStock',
'<action-record name="action-cession-stock-record-depuis-od" model="com.axelor.apps.stock.db.CessionStock">
  <field name="typeCession" expr="eval: &apos;RECONDITIONNEMENT&apos;"/>
  <field name="product" expr="eval: __repo__(com.axelor.apps.stock.db.TrackingNumber).find(_odLot as Long)?.product"/>
</action-record>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-cession-stock-record-lot-od', 'action-record', 'com.axelor.apps.stock.db.CessionStock',
'<action-record name="action-cession-stock-record-lot-od" model="com.axelor.apps.stock.db.CessionStock">
  <field name="lotSource" expr="eval: __repo__(com.axelor.apps.stock.db.TrackingNumber).find(_odLot as Long)"/>
  <field name="dluo" expr="eval: __repo__(com.axelor.apps.stock.db.TrackingNumber).find(_odLot as Long)?.perishableExpirationDate"/>
  <field name="poidsKg" expr="eval: _odPoids" if="_odPoids"/>
</action-record>', false, false, 0);

-- valeurs par défaut de la cession : libellé CESSION / Sortie sans apostrophes ; société de l'utilisateur, sinon la
-- société LVME (le n° de cession en dépend)
UPDATE meta_action SET xml = '<action-record name="action-cession-stock-record-default-values"
  model="com.axelor.apps.stock.db.CessionStock">
  <field name="libelleMvts" expr="CESSION"/>
  <field name="entreeSortie" expr="Sortie"/>
  <field name="cessionRealisee" expr="eval: false"/>
  <field name="cessionDate" expr="eval: __date__"/>
  <field name="company" expr="eval: __user__.activeCompany ?: __repo__(com.axelor.apps.base.db.Company).all().order(&apos;id&apos;).fetchOne()"/>
  <field name="cessionSeq"
    expr="call: com.axelor.apps.base.service.administration.SequenceService:getSequenceNumber(&apos;cessionStock&apos;, __user__.activeCompany ?: __repo__(com.axelor.apps.base.db.Company).all().order(&apos;id&apos;).fetchOne(), com.axelor.apps.stock.db.CessionStock.class, &apos;cessionSeq&apos;)"/>
</action-record>', updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'action-cession-stock-record-default-values' AND module IS NULL;

UPDATE meta_view SET xml = current_setting('lvme.fEtat'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-etat-stock-lot-search-form' AND module IS NULL;
UPDATE meta_view SET xml = current_setting('lvme.fCession'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'cession-stock-form' AND module IS NULL;

COMMIT;

SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND ((name = 'lvme-etat-stock-lot-search-form'
          AND xml LIKE '%imprimerEtatFournisseurBtn%') OR (name = 'cession-stock-form' AND xml LIKE '%lvme-cession-ges%')))
         AS vues_modifiees,
       (SELECT count(*) FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
         WHERE s.name = 'lvme.od.type.select' AND i.value = 'CE') AS type_cession,
       (SELECT count(*) FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-od-stock-valider',
         'action-lvme-od-stock-valider-mvt', 'action-lvme-od-stock-cession', 'action-lvme-etat-stock-lot-imprimer-ligne',
         'action-lvme-etat-stock-lot-imprimer-fournisseur', 'action-cession-stock-group-depuis-od',
         'action-cession-stock-record-depuis-od', 'action-cession-stock-record-lot-od')) AS actions;

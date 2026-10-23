-- =====================================================================
-- PROD étape 70 : KPI et alertes en haut de « liste des achats fournisseurs » (comme les commandes clients)
--   - cartes : Commandes en cours (+ montant HT), Flottants en mer (+ poids), Achats HT du mois (+ tendance vs
--     mois dernier), À recevoir sous 7 jours (+ en retard) ; montants en devise de la société
--   - boutons d'alerte qui filtrent la liste : réceptions en retard, brouillons de plus de 15 jours, à embarquer
--     depuis plus de 30 jours ; « Aucune alerte » ; « Retirer le filtre alerte » ; Lancer la recherche le retire aussi
-- Source : livrables/ui/achat-search-form.xml ; écrit par livrables/outils/gen_prod70_kpi_achats.py
-- Prérequis : css des boutons d'alerte (lvme.css, recompiler). Depuis la racine du dépôt. Relançable.
-- =====================================================================
\set recherche `cat livrables/ui/achat-search-form.xml`
SELECT set_config('lvme.achat_recherche', :'recherche', false) IS NOT NULL AS fiche_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.achat_recherche'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-achat-search-form' AND module IS NULL;

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-achat-kpi', 'action-lvme-achat-alerte-retard', 'action-lvme-achat-alerte-brouillons', 'action-lvme-achat-alerte-a-embarquer', 'action-lvme-achat-alerte-aucune', 'action-lvme-achat-refresh', 'action-lvme-achat-dashlet');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-kpi', 'action-attrs', NULL,
'<action-attrs name="action-lvme-achat-kpi">
  <attribute name="value" for="$kpaEnCours" expr="eval: __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4))'').count().toString()"/>
  <attribute name="value" for="$kpaEnCoursDetail" expr="eval: def l = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4))'').fetch(); java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE).format(((l.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal).setScale(0, java.math.RoundingMode.HALF_UP)) + '' € HT en cours''"/>
  <attribute name="value" for="$kpaFlottants" expr="eval: __repo__(com.axelor.apps.stock.db.StockMove).all().filter(''self.typeSelect = 3 AND self.statusSelect = 2 AND self.nature = 2'').count().toString()"/>
  <attribute name="value" for="$kpaFlottantsDetail" expr="eval: def l = __repo__(com.axelor.apps.stock.db.StockMove).all().filter(''self.typeSelect = 3 AND self.statusSelect = 2 AND self.nature = 2'').fetch(); java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE).format(((l.collect { it.poidsTotal ?: 0 }.sum() ?: 0) as BigDecimal).setScale(0, java.math.RoundingMode.HALF_UP)) + '' kg en mer''"/>
  <attribute name="value" for="$kpaAchatsMois" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ach = ((l.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def lp = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1.minusMonths(1), __date__.minusMonths(1)).fetch(); def achp = ((lp.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE).format(ach.setScale(0, java.math.RoundingMode.HALF_UP)) + '' €''"/>
  <attribute name="value" for="$kpaAchatsMoisDetail" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ach = ((l.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def lp = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1.minusMonths(1), __date__.minusMonths(1)).fetch(); def achp = ((lp.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); l.size() + '' commande(s) depuis le '' + d1.format(java.time.format.DateTimeFormatter.ofPattern(''dd/MM''))"/>
  <attribute name="value" for="$kpaAchatsEvol" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ach = ((l.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def lp = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1.minusMonths(1), __date__.minusMonths(1)).fetch(); def achp = ((lp.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def v = achp.signum() == 0 ? null : ((ach - achp) * 100 / achp).setScale(0, java.math.RoundingMode.HALF_UP); v == null ? ''Pas de comparaison'' : (v.signum() &gt;= 0 ? ''▲ +'' : ''▼ '') + v + '' % vs mois dernier''"/>
  <attribute name="value" for="$kpaAchatsHausse" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ach = ((l.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def lp = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1.minusMonths(1), __date__.minusMonths(1)).fetch(); def achp = ((lp.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); ach &gt;= achp ? ''true'' : null"/>
  <attribute name="value" for="$kpaARecevoir" expr="eval: __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4)) AND self.estimatedReceiptDate BETWEEN ?1 AND ?2'', __date__, __date__.plusDays(7)).count().toString()"/>
  <attribute name="value" for="$kpaARecevoirDetail" expr="eval: __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4)) AND self.estimatedReceiptDate &lt; ?1'', __date__).count() + '' en retard''"/>
  <attribute name="value" for="$alaRetard" expr="eval: def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4)) AND self.estimatedReceiptDate &lt; ?1'', __date__).count(); n &gt; 0 ? n + '' réception(s) en retard'' : null"/>
  <attribute name="value" for="$alaBrouillons" expr="eval: def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (1, 2) AND self.orderDate &lt; ?1'', __date__.minusDays(15)).count(); n &gt; 0 ? n + '' commande(s) en brouillon depuis plus de 15 jours'' : null"/>
  <attribute name="value" for="$alaAEmbarquer" expr="eval: def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND self.nature = 1 AND self.orderDate &lt; ?1'', __date__.minusDays(30)).count(); n &gt; 0 ? n + '' commande(s) à embarquer depuis plus de 30 jours'' : null"/>
  <attribute name="value" for="$alaAucune" expr="eval: [{ -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4)) AND self.estimatedReceiptDate &lt; ?1'', __date__).count(); n &gt; 0 ? n + '' réception(s) en retard'' : null }, { -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (1, 2) AND self.orderDate &lt; ?1'', __date__.minusDays(15)).count(); n &gt; 0 ? n + '' commande(s) en brouillon depuis plus de 15 jours'' : null }, { -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND self.nature = 1 AND self.orderDate &lt; ?1'', __date__.minusDays(30)).count(); n &gt; 0 ? n + '' commande(s) à embarquer depuis plus de 30 jours'' : null }].every { it() == null } ? ''Aucune alerte'' : null"/>
  <attribute name="title" for="lvmeAlaRetardBtn" expr="eval: ''⚠ '' + ({ -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4)) AND self.estimatedReceiptDate &lt; ?1'', __date__).count(); n &gt; 0 ? n + '' réception(s) en retard'' : null }() ?: '''')"/>
  <attribute name="hidden" for="lvmeAlaRetardBtn" expr="eval: { -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4)) AND self.estimatedReceiptDate &lt; ?1'', __date__).count(); n &gt; 0 ? n + '' réception(s) en retard'' : null }() == null"/>
  <attribute name="title" for="lvmeAlaBrouillonsBtn" expr="eval: ''⏳ '' + ({ -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (1, 2) AND self.orderDate &lt; ?1'', __date__.minusDays(15)).count(); n &gt; 0 ? n + '' commande(s) en brouillon depuis plus de 15 jours'' : null }() ?: '''')"/>
  <attribute name="hidden" for="lvmeAlaBrouillonsBtn" expr="eval: { -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (1, 2) AND self.orderDate &lt; ?1'', __date__.minusDays(15)).count(); n &gt; 0 ? n + '' commande(s) en brouillon depuis plus de 15 jours'' : null }() == null"/>
  <attribute name="title" for="lvmeAlaAEmbarquerBtn" expr="eval: ''⏳ '' + ({ -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND self.nature = 1 AND self.orderDate &lt; ?1'', __date__.minusDays(30)).count(); n &gt; 0 ? n + '' commande(s) à embarquer depuis plus de 30 jours'' : null }() ?: '''')"/>
  <attribute name="hidden" for="lvmeAlaAEmbarquerBtn" expr="eval: { -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND self.nature = 1 AND self.orderDate &lt; ?1'', __date__.minusDays(30)).count(); n &gt; 0 ? n + '' commande(s) à embarquer depuis plus de 30 jours'' : null }() == null"/>
  <attribute name="hidden" for="lvmeAlaAucuneBtn" expr="eval: { -> [{ -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4)) AND self.estimatedReceiptDate &lt; ?1'', __date__).count(); n &gt; 0 ? n + '' réception(s) en retard'' : null }, { -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect IN (1, 2) AND self.orderDate &lt; ?1'', __date__.minusDays(15)).count(); n &gt; 0 ? n + '' commande(s) en brouillon depuis plus de 15 jours'' : null }, { -> def n = __repo__(com.axelor.apps.purchase.db.PurchaseOrder).all().filter(''self.statusSelect = 3 AND self.nature = 1 AND self.orderDate &lt; ?1'', __date__.minusDays(30)).count(); n &gt; 0 ? n + '' commande(s) à embarquer depuis plus de 30 jours'' : null }].every { it() == null } ? ''Aucune alerte'' : null }() == null"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-alerte-retard', 'action-attrs', NULL,
'<action-attrs name="action-lvme-achat-alerte-retard">
  <attribute name="value" for="$alerteAchat" expr="eval: ''retard''"/>
  <attribute name="refresh" for="achatsDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-alerte-brouillons', 'action-attrs', NULL,
'<action-attrs name="action-lvme-achat-alerte-brouillons">
  <attribute name="value" for="$alerteAchat" expr="eval: ''brouillons''"/>
  <attribute name="refresh" for="achatsDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-alerte-a-embarquer', 'action-attrs', NULL,
'<action-attrs name="action-lvme-achat-alerte-a-embarquer">
  <attribute name="value" for="$alerteAchat" expr="eval: ''a-embarquer''"/>
  <attribute name="refresh" for="achatsDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-alerte-aucune', 'action-attrs', NULL,
'<action-attrs name="action-lvme-achat-alerte-aucune">
  <attribute name="value" for="$alerteAchat" expr="eval: null"/>
  <attribute name="refresh" for="achatsDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-achat-refresh">
  <attribute name="value" for="$alerteAchat" expr="eval: null"/>
  <attribute name="refresh" for="achatsDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-achat-dashlet', 'action-view', 'com.axelor.apps.purchase.db.PurchaseOrder',
'<action-view name="action-lvme-achat-dashlet" title="Achats fournisseurs" model="com.axelor.apps.purchase.db.PurchaseOrder">
  <view type="grid" name="lvme-achat-grid"/>
  <view type="form" name="purchase-order-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <!-- sans alerte choisie : filtres de l''écran ; avec une alerte (bouton sous les KPI) : seulement les commandes
       en alerte, sans les autres filtres -->
  <domain>(:_alerte = '''' AND self.statusSelect IN (3, 4)
    AND (:_dateFiltre = false OR self.orderDate BETWEEN :_dateDu AND :_dateAu)
    AND (:_arrFiltre = false OR self.estimatedReceiptDate BETWEEN :_arrDu AND :_arrAu)
    AND (:_fouDu = '''' OR self.supplierPartner.name &gt;= :_fouDu) AND (:_fouAu = '''' OR self.supplierPartner.name &lt;= :_fouAu)
    AND (:_transport = 0 OR self.shipmentMode.id = :_transport)
    AND ((:_nature = 1 AND self.nature = 3) OR (:_nature = 2 AND self.nature IN (1, 2)) OR :_nature = 3))
    OR (:_alerte = ''retard'' AND self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4))
        AND self.estimatedReceiptDate &lt; :_aujourdhui)
    OR (:_alerte = ''brouillons'' AND self.statusSelect IN (1, 2) AND self.orderDate &lt; :_date15)
    OR (:_alerte = ''a-embarquer'' AND self.statusSelect = 3 AND self.nature = 1 AND self.orderDate &lt; :_date30)</domain>
  <context name="_alerte" expr="eval: alerteAchat ?: ''''"/>
  <context name="_aujourdhui" expr="eval: __date__"/>
  <context name="_date15" expr="eval: __date__.minusDays(15)"/>
  <context name="_date30" expr="eval: __date__.minusDays(30)"/>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_arrFiltre" expr="eval: arriveeDu != null || arriveeAu != null"/>
  <context name="_arrDu" expr="eval: arriveeDu ? java.time.LocalDate.parse(arriveeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_arrAu" expr="eval: arriveeAu ? java.time.LocalDate.parse(arriveeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_fouDu" expr="eval: fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.name ?: '''') : ''''"/>
  <context name="_fouAu" expr="eval: fournisseurAu?.id ? (__repo__(Partner).find(fournisseurAu.id as Long)?.name ?: '''') : (fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.name ?: '''') : '''')"/>
  <context name="_transport" expr="eval: (typeTransport?.id ?: 0) as Long"/>
  <context name="_nature" expr="eval: (natureAchat ?: 3) as Integer"/>
  <context name="_internalUser" expr="eval: __user__.id"/>
</action-view>', false, false, 0);

COMMIT;

SELECT name, position('kpiAchatPanel' IN xml) > 0 AS kpi FROM meta_view WHERE module IS NULL AND name = 'lvme-achat-search-form';

-- =====================================================================
-- PROD étape 2 : écrans admin LVME (REC-003 Rotation / Âge des lots, REC-038 État des stocks par lots,
-- actions du bouton Dupliquer). Contenu exporté de la base locale où tout a été testé.
-- Idempotent : n'insère que ce qui n'existe pas encore (contrôle par nom). Une seule transaction.
-- Ne modifie AUCUNE vue existante.
-- =====================================================================
BEGIN;

-- ---------- Actions ----------
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'lvme-action-age-lot', 'action-view', 'com.axelor.apps.supplychain.db.AgeLot', '<action-view name="lvme-action-age-lot" title="Âge des lots"
  model="com.axelor.apps.supplychain.db.AgeLot">
  <view type="grid" name="lvme-age-lot-grid"/>
  <view type="form" name="lvme-age-lot-form"/>
</action-view>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'lvme-action-age-lot');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-sale-order-line-method-duplicate', 'action-method', NULL, '<action-method name="action-lvme-sale-order-line-method-duplicate">
  <call class="com.axelor.apps.supplychain.web.SaleOrderLineDuplicateLvmeController" method="duplicateLine"/>
</action-method>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-sale-order-line-method-duplicate');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-purchase-order-line-method-duplicate', 'action-method', NULL, '<action-method name="action-lvme-purchase-order-line-method-duplicate">
  <call class="com.axelor.apps.purchase.web.PurchaseOrderLineController" method="duplicateLine"/>
</action-method>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-purchase-order-line-method-duplicate');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-dashlet', 'action-view', 'com.axelor.apps.supplychain.db.EtatStockLot', '<action-view name="action-lvme-etat-stock-lot-dashlet" title="État des stocks par lots"
  model="com.axelor.apps.supplychain.db.EtatStockLot">
  <view type="grid" name="lvme-etat-stock-lot-grid"/>
  <view type="form" name="lvme-etat-stock-lot-form"/>
  <domain>(:_artDu = '''' OR self.productCode &gt;= :_artDu) AND (:_artAu = '''' OR self.productCode &lt;= :_artAu)
    AND (:_fouDu = '''' OR self.supplierName &gt;= :_fouDu) AND (:_fouAu = '''' OR self.supplierName &lt;= :_fouAu)
    AND (:_famille = 0 OR self.productCategory.id = :_famille)
    AND (:_frigo = 0 OR self.stockLocation.id = :_frigo)
    AND (:_origine = '''' OR self.origine = :_origine)
    AND LOWER(COALESCE(self.lotNumber, '''')) LIKE :_lot
    AND (:_entreeFiltre = false OR self.entryDate BETWEEN :_entreeDu AND :_entreeAu)
    AND (:_ddmFiltre = false OR self.dluo BETWEEN :_ddmDu AND :_ddmAu)
    AND (:_livrFiltre = false OR self.arrivalDate BETWEEN :_livrDu AND :_livrAu)
    AND (:_nature = 0 OR self.natureArrivage = :_nature)
    AND ((:_etat = 1 AND self.stockQty &gt; 0) OR (:_etat = 2 AND self.stockQty = 0)
      OR (:_etat = 3 AND self.stockQty &lt; 0) OR (:_etat = 4 AND self.stockQty != 0))
    AND (:_dispoNeg = false OR self.dispoQty &lt; 0)</domain>
  <context name="_artDu" expr="eval: articleDu?.id ? (__repo__(Product).find(articleDu.id as Long)?.code ?: '''') : ''''"/>
  <context name="_artAu" expr="eval: articleAu?.id ? (__repo__(Product).find(articleAu.id as Long)?.code ?: '''') : (articleDu?.id ? (__repo__(Product).find(articleDu.id as Long)?.code ?: '''') : '''')"/>
  <context name="_fouDu" expr="eval: fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.fullName ?: '''') : ''''"/>
  <context name="_fouAu" expr="eval: fournisseurAu?.id ? (__repo__(Partner).find(fournisseurAu.id as Long)?.fullName ?: '''') : (fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.fullName ?: '''') : '''')"/>
  <context name="_famille" expr="eval: (famille?.id ?: 0) as Long"/>
  <context name="_frigo" expr="eval: (frigo?.id ?: 0) as Long"/>
  <context name="_origine" expr="eval: origine ? origine.toString() : ''''"/>
  <context name="_lot" expr="eval: numeroLot ? ''%'' + numeroLot.toString().trim().toLowerCase() + ''%'' : ''%''"/>
  <context name="_entreeFiltre" expr="eval: entreeDu != null || entreeAu != null"/>
  <context name="_entreeDu" expr="eval: entreeDu ? java.time.LocalDate.parse(entreeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_entreeAu" expr="eval: entreeAu ? java.time.LocalDate.parse(entreeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_ddmFiltre" expr="eval: ddmDu != null || ddmAu != null"/>
  <context name="_ddmDu" expr="eval: ddmDu ? java.time.LocalDate.parse(ddmDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_ddmAu" expr="eval: ddmAu ? java.time.LocalDate.parse(ddmAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_livrFiltre" expr="eval: livrDu != null || livrAu != null"/>
  <context name="_livrDu" expr="eval: livrDu ? java.time.LocalDate.parse(livrDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_livrAu" expr="eval: livrAu ? java.time.LocalDate.parse(livrAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_nature" expr="eval: (natureArrivage ?: 0) as Integer"/>
  <context name="_etat" expr="eval: (etatLot ?: 1) as Integer"/>
  <context name="_dispoNeg" expr="eval: dispoNegatif ? true : false"/>
</action-view>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-dashlet');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-refresh', 'action-attrs', NULL, '<action-attrs name="action-lvme-etat-stock-lot-refresh">
  <attribute name="refresh" for="lotsDashlet" expr="eval: true"/>
</action-attrs>
', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-refresh');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-periode-entree', 'action-attrs', NULL, '<action-attrs name="action-lvme-etat-stock-lot-periode-entree">
  <attribute name="value" for="$entreeDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][entreePeriode as Integer]"/>
  <attribute name="value" for="$entreeAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][entreePeriode as Integer]"/>
</action-attrs>
', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-periode-entree');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-periode-ddm', 'action-attrs', NULL, '<action-attrs name="action-lvme-etat-stock-lot-periode-ddm">
  <attribute name="value" for="$ddmDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][ddmPeriode as Integer]"/>
  <attribute name="value" for="$ddmAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][ddmPeriode as Integer]"/>
</action-attrs>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-periode-ddm');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-periode-livr', 'action-attrs', NULL, '<action-attrs name="action-lvme-etat-stock-lot-periode-livr">
  <attribute name="value" for="$livrDu" expr="eval: [1: __date__.withDayOfMonth(1), 2: __date__.minusMonths(3), 3: __date__.minusMonths(6), 4: __date__.withDayOfYear(1), 5: __date__.minusMonths(12)][livrPeriode as Integer]"/>
  <attribute name="value" for="$livrAu" expr="eval: [1: __date__.withDayOfMonth(__date__.lengthOfMonth()), 2: __date__, 3: __date__, 4: __date__.withMonth(12).withDayOfMonth(31), 5: __date__][livrPeriode as Integer]"/>
</action-attrs>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-periode-livr');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-group-periode-entree', 'action-group', NULL, '<action-group name="action-lvme-etat-stock-lot-group-periode-entree">
  <action name="action-lvme-etat-stock-lot-periode-entree"/>
  <action name="action-lvme-etat-stock-lot-refresh"/>
</action-group>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-group-periode-entree');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-group-periode-ddm', 'action-group', NULL, '<action-group name="action-lvme-etat-stock-lot-group-periode-ddm">
  <action name="action-lvme-etat-stock-lot-periode-ddm"/>
  <action name="action-lvme-etat-stock-lot-refresh"/>
</action-group>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-group-periode-ddm');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-group-periode-livr', 'action-group', NULL, '<action-group name="action-lvme-etat-stock-lot-group-periode-livr">
  <action name="action-lvme-etat-stock-lot-periode-livr"/>
  <action name="action-lvme-etat-stock-lot-refresh"/>
</action-group>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-group-periode-livr');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-open', 'action-view', 'com.axelor.utils.db.Wizard', '<action-view name="action-lvme-etat-stock-lot-open" title="État des stocks par lots"
  model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-etat-stock-lot-search-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>
', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-open');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-alertes-dluo', 'action-attrs', NULL, '<action-attrs name="action-lvme-etat-stock-lot-alertes-dluo">
  <attribute name="value" for="$nbDluoDepassee"
    expr="eval: __repo__(EtatStockLot).all().filter(''self.stockQty &gt; 0 AND self.dluo &lt; ?1'', __date__).count()"/>
  <attribute name="value" for="$nbDluoProche"
    expr="eval: __repo__(EtatStockLot).all().filter(''self.stockQty &gt; 0 AND self.dluo &gt;= ?1 AND self.dluo &lt;= ?2'', __date__, __date__.plusDays(30)).count()"/>
</action-attrs>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-alertes-dluo');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-info-dluo', 'action-validate', NULL, '<action-validate name="action-lvme-etat-stock-lot-info-dluo">
  <info message="Attention : des lots en stock ont une DLUO dépassée (lignes rouges) ou dans moins de 30 jours (lignes orange)."
    if="eval: __repo__(EtatStockLot).all().filter(''self.stockQty &gt; 0 AND self.dluo &lt;= ?1'', __date__.plusDays(30)).count() &gt; 0"/>
</action-validate>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-info-dluo');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-group-onnew', 'action-group', NULL, '<action-group name="action-lvme-etat-stock-lot-group-onnew">
  <action name="action-lvme-etat-stock-lot-defaults"/>
  <action name="action-lvme-etat-stock-lot-alertes-dluo"/>
  <action name="action-lvme-etat-stock-lot-info-dluo"/>
</action-group>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-group-onnew');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-stock-dashlet', 'action-view', 'com.axelor.apps.supplychain.db.RotationStock', '<action-view name="action-lvme-rotation-stock-dashlet" title="Rotation des stocks"
  model="com.axelor.apps.supplychain.db.RotationStock">
  <view type="grid" name="lvme-rotation-stock-grid"/>
  <view type="form" name="lvme-rotation-stock-form"/>
  <domain>(:_artDu = '''' OR self.productCode &gt;= :_artDu) AND (:_artAu = '''' OR self.productCode &lt;= :_artAu)
    AND (:_famille = 0 OR self.productCategory.id = :_famille)
    AND (:_statut = '''' OR self.statut = :_statut)
    AND (:_couvMax = 0 OR (self.daysOfStock IS NOT NULL AND self.daysOfStock &lt; :_couvMax))
    AND (:_ageMin = 0 OR (self.avgAgeDays IS NOT NULL AND self.avgAgeDays &gt; :_ageMin))
    AND (:_dormant = false OR self.isDormant = true)</domain>
  <context name="_artDu" expr="eval: articleDu?.id ? (__repo__(Product).find(articleDu.id as Long)?.code ?: '''') : ''''"/>
  <context name="_artAu" expr="eval: articleAu?.id ? (__repo__(Product).find(articleAu.id as Long)?.code ?: '''') : (articleDu?.id ? (__repo__(Product).find(articleDu.id as Long)?.code ?: '''') : '''')"/>
  <context name="_famille" expr="eval: (famille?.id ?: 0) as Long"/>
  <context name="_statut" expr="eval: statutRotation ? statutRotation.toString() : ''''"/>
  <context name="_couvMax" expr="eval: (couvertureMax ?: 0) as Integer"/>
  <context name="_ageMin" expr="eval: (ageMin ?: 0) as Integer"/>
  <context name="_dormant" expr="eval: dormantsSeulement ? true : false"/>
</action-view>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-rotation-stock-dashlet');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-stock-refresh', 'action-attrs', NULL, '<action-attrs name="action-lvme-rotation-stock-refresh">
  <attribute name="refresh" for="rotationDashlet" expr="eval: true"/>
</action-attrs>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-rotation-stock-refresh');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-stock-kpi', 'action-attrs', NULL, '<action-attrs name="action-lvme-rotation-stock-kpi">
  <!-- KPI 1 : couverture moyenne (jours), pondérée par la valeur du stock -->
  <attribute name="value" for="$kpiCouverture"
    expr="eval: def l = __repo__(RotationStock).all().filter(''self.daysOfStock IS NOT NULL'').fetch(); def v = (l.collect{ it.stockValue ?: 0 }.sum() ?: 0) as BigDecimal; v &gt; 0 ? ((l.collect{ (it.daysOfStock ?: 0) * (it.stockValue ?: 0) }.sum() / v) as BigDecimal).setScale(0, java.math.RoundingMode.HALF_UP).toString() + '' j'' : ''n.d.''"/>
  <attribute name="value" for="$kpiACommander"
    expr="eval: __repo__(RotationStock).all().filter(''self.statut = ?1'', ''A commander'').count() + '' produit(s) à commander (moins de 60 j)''"/>
  <!-- KPI 2 : taux de rotation (fois / an), pondéré par la valeur -->
  <attribute name="value" for="$kpiRotation"
    expr="eval: def l = __repo__(RotationStock).all().fetch(); def v = (l.collect{ it.stockValue ?: 0 }.sum() ?: 0) as BigDecimal; v &gt; 0 ? ((l.collect{ (it.rotationRate ?: 0) * (it.stockValue ?: 0) }.sum() / v) as BigDecimal).setScale(2, java.math.RoundingMode.HALF_UP).toString() + '' fois / an'' : ''n.d.''"/>
  <!-- KPI 3 : âge moyen du stock (jours), pondéré par la valeur -->
  <attribute name="value" for="$kpiAge"
    expr="eval: def l = __repo__(RotationStock).all().filter(''self.avgAgeDays IS NOT NULL'').fetch(); def v = (l.collect{ it.stockValue ?: 0 }.sum() ?: 0) as BigDecimal; v &gt; 0 ? ((l.collect{ (it.avgAgeDays ?: 0) * (it.stockValue ?: 0) }.sum() / v) as BigDecimal).setScale(0, java.math.RoundingMode.HALF_UP).toString() + '' j'' : ''n.d.''"/>
  <attribute name="value" for="$kpiLotsAnciens"
    expr="eval: __repo__(RotationStock).all().filter(''self.oldestLotAge &gt; 180'').count() + '' produit(s) avec un lot de plus de 180 j''"/>
  <!-- KPI 4 : stock dormant (valeur, nombre, % du stock) -->
  <attribute name="value" for="$kpiDormant"
    expr="eval: String.format(java.util.Locale.FRANCE, ''%,.0f €'', ((__repo__(RotationStock).all().fetch().collect{ it.dormantValue ?: 0 }.sum() ?: 0) as BigDecimal))"/>
  <attribute name="value" for="$kpiDormantDetail"
    expr="eval: def l = __repo__(RotationStock).all().fetch(); def t = (l.collect{ it.stockValue ?: 0 }.sum() ?: 0) as BigDecimal; def d = (l.collect{ it.dormantValue ?: 0 }.sum() ?: 0) as BigDecimal; l.count{ it.isDormant } + '' produit(s) sans vente depuis 90 j'' + (t &gt; 0 ? '' ('' + (d * 100 / t).setScale(0, java.math.RoundingMode.HALF_UP) + '' % du stock)'' : '''')"/>
  <!-- Bandeau : stock total -->
  <attribute name="value" for="$kpiStockTotal"
    expr="eval: def l = __repo__(RotationStock).all().fetch(); ''Stock total : '' + String.format(java.util.Locale.FRANCE, ''%,.0f €'', ((l.collect{ it.stockValue ?: 0 }.sum() ?: 0) as BigDecimal)) + '' — '' + l.size() + '' produit(s) en stock — calculé le '' + __date__.format(java.time.format.DateTimeFormatter.ofPattern(''dd/MM/yyyy''))"/>
</action-attrs>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-rotation-stock-kpi');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-stock-group-onnew', 'action-group', NULL, '<action-group name="action-lvme-rotation-stock-group-onnew">
  <action name="action-lvme-rotation-stock-kpi"/>
</action-group>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-rotation-stock-group-onnew');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-stock-group-recalcul', 'action-group', NULL, '<action-group name="action-lvme-rotation-stock-group-recalcul">
  <action name="action-lvme-rotation-stock-kpi"/>
  <action name="action-lvme-rotation-stock-refresh"/>
</action-group>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-rotation-stock-group-recalcul');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-rotation-stock-open', 'action-view', 'com.axelor.utils.db.Wizard', '<action-view name="action-lvme-rotation-stock-open" title="Rotation des stocks"
  model="com.axelor.utils.db.Wizard">
  <view type="form" name="lvme-rotation-stock-dashboard-form"/>
  <view-param name="show-toolbar" value="false"/>
  <view-param name="forceEdit" value="true"/>
</action-view>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-rotation-stock-open');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) SELECT nextval('meta_action_seq'), 0, now(), 'action-lvme-etat-stock-lot-defaults', 'action-attrs', NULL, '<action-attrs name="action-lvme-etat-stock-lot-defaults">
  <attribute name="value" for="$natureArrivage" expr="eval: 0"/>
  <attribute name="value" for="$etatLot" expr="eval: 1"/>
</action-attrs>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-defaults');

-- ---------- Vues ----------
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) SELECT nextval('meta_view_seq'), 0, now(), 'lvme-rotation-stock-grid', 'Rotation des stocks', 'grid', 'com.axelor.apps.supplychain.db.RotationStock', 30, '<grid name="lvme-rotation-stock-grid" title="Rotation des stocks"
  model="com.axelor.apps.supplychain.db.RotationStock" orderBy="productCode"
  canNew="false" canEdit="false" canDelete="false">
  <hilite color="danger" strong="true" if="statut == ''A commander''"/>
  <hilite color="warning" if="statut == ''Dormant'' || statut == ''Lot ancien''"/>
  <field name="productCode" width="110"/>
  <field name="productName"/>
  <field name="productCategory" width="110"/>
  <field name="stockQty" aggregate="sum" width="90"/>
  <field name="stockValue" aggregate="sum" width="100"/>
  <field name="sales90d" width="85"/>
  <field name="avgDailySales" width="85"/>
  <field name="daysOfStock" title="Couverture (j)" width="90">
    <hilite background="danger" strong="true" if="statut == ''A commander''"/>
  </field>
  <field name="sales365d" width="90"/>
  <field name="rotationRate" width="85"/>
  <field name="avgAgeDays" width="85"/>
  <field name="oldestLotAge" width="85"/>
  <field name="lastSaleDate" width="95"/>
  <field name="daysSinceLastSale" width="85"/>
  <field name="dormantValue" aggregate="sum" width="100"/>
  <field name="statut" width="110"/>
</grid>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'lvme-rotation-stock-grid' AND module IS NULL);
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) SELECT nextval('meta_view_seq'), 0, now(), 'lvme-age-lot-grid', 'Âge des lots', 'grid', 'com.axelor.apps.supplychain.db.AgeLot', 20, '<grid name="lvme-age-lot-grid" title="Âge des lots"
  model="com.axelor.apps.supplychain.db.AgeLot"
  canNew="false" canEdit="false" canDelete="false" orderBy="-ageDays">
  <hilite color="danger" if="isExpired || (daysToDluo != null &amp;&amp; daysToDluo &lt; 90) || ageDays &gt; 180"/>
  <hilite color="warning" if="ageDays &gt; 90"/>
  <field name="product"/>
  <field name="trackingNumber"/>
  <field name="stockLocation"/>
  <field name="qty" aggregate="sum"/>
  <field name="stockValue" aggregate="sum"/>
  <field name="arrivalDate"/>
  <field name="ageDays"/>
  <field name="ageBucket"/>
  <field name="dluo"/>
  <field name="daysToDluo"/>
  <field name="isExpired"/>
</grid>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'lvme-age-lot-grid' AND module IS NULL);
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) SELECT nextval('meta_view_seq'), 0, now(), 'lvme-age-lot-form', 'Âge du lot', 'form', 'com.axelor.apps.supplychain.db.AgeLot', 20, '<form name="lvme-age-lot-form" title="Âge du lot"
  model="com.axelor.apps.supplychain.db.AgeLot"
  canNew="false" canEdit="false" canDelete="false">
  <panel name="mainPanel" readonly="true">
    <field name="product"/>
    <field name="trackingNumber"/>
    <field name="stockLocation"/>
    <field name="qty"/>
    <field name="stockValue"/>
    <field name="arrivalDate"/>
    <field name="dateSource"/>
    <field name="ageDays"/>
    <field name="ageBucket"/>
    <field name="dluo"/>
    <field name="daysToDluo"/>
    <field name="isExpired"/>
  </panel>
</form>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'lvme-age-lot-form' AND module IS NULL);
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) SELECT nextval('meta_view_seq'), 0, now(), 'lvme-etat-stock-lot-grid', 'État des stocks par lots', 'grid', 'com.axelor.apps.supplychain.db.EtatStockLot', 20, '<grid name="lvme-etat-stock-lot-grid" title="État des stocks par lots"
  model="com.axelor.apps.supplychain.db.EtatStockLot" orderBy="productCode,arrivalDate"
  canNew="false" canEdit="false" canDelete="false">
  <!-- LVME : DLUO dépassée (rouge) / DLUO dans moins de 30 jours (orange), uniquement s''il reste du stock -->
  <hilite color="danger" strong="true" if="dluo &amp;&amp; stockQty &gt; 0 &amp;&amp; $moment().diff(dluo, ''days'') &gt; 0"/>
  <hilite color="warning" if="dluo &amp;&amp; stockQty &gt; 0 &amp;&amp; $moment(dluo).diff($moment(), ''days'') &lt;= 30"/>
  <hilite color="info" if="natureArrivage == 2"/>
  <hilite color="danger" if="stockQty &lt; 0"/>
  <field name="productCode" width="110"/>
  <field name="productName"/>
  <field name="supplierName"/>
  <field name="stockLocation" width="90"/>
  <field name="lotNumber" width="110"/>
  <field name="arrivalNumber" width="110"/>
  <field name="origine" selection="lvme.origine.select" width="90"/>
  <field name="arrivalDate" width="95"/>
  <field name="conditionnement"/>
  <field name="dluo" title="DLUO" width="95">
    <hilite color="danger" strong="true" if="dluo &amp;&amp; $moment().diff(dluo, ''days'') &gt; 0"/>
    <hilite color="warning" strong="true" if="dluo &amp;&amp; $moment(dluo).diff($moment(), ''days'') &lt;= 30"/>
  </field>
  <field name="prixRevient" width="80"/>
  <field name="qtyPerColis" width="80"/>
  <field name="nbColisIn" aggregate="sum" width="80"/>
  <field name="nbColisOut" aggregate="sum" width="80"/>
  <field name="nbColisCdes" aggregate="sum" width="80"/>
  <field name="nbColisStock" aggregate="sum" width="85">
    <hilite background="warning" strong="true" if="true"/>
  </field>
  <field name="stockQty" aggregate="sum" width="90"/>
  <field name="stockValue" aggregate="sum" width="100"/>
  <field name="natureLabel" width="75"/>
  <field name="natureArrivage" hidden="true"/>
</grid>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'lvme-etat-stock-lot-grid' AND module IS NULL);
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) SELECT nextval('meta_view_seq'), 0, now(), 'lvme-etat-stock-lot-form', 'Lot en stock', 'form', 'com.axelor.apps.supplychain.db.EtatStockLot', 20, '<form name="lvme-etat-stock-lot-form" title="Lot en stock"
  model="com.axelor.apps.supplychain.db.EtatStockLot" canNew="false" canEdit="false" canDelete="false" canSave="false">
  <panel name="lotPanel" title="Lot" readonly="true">
    <field name="product"/>
    <field name="productCategory"/>
    <field name="trackingNumber"/>
    <field name="arrivalNumber"/>
    <field name="supplier"/>
    <field name="stockLocation"/>
    <field name="natureLabel"/>
    <field name="origine" selection="lvme.origine.select"/>
    <field name="conditionnement"/>
    <field name="unit"/>
    <field name="entryDate"/>
    <field name="arrivalDate"/>
    <field name="dluo"/>
    <field name="prixRevient"/>
  </panel>
  <panel name="qtyPanel" title="Quantités" readonly="true" itemSpan="3">
    <field name="qtyPerColis"/>
    <field name="nbColisIn"/>
    <field name="nbColisOut"/>
    <field name="nbColisCdes"/>
    <field name="nbColisStock"/>
    <field name="entreeQty"/>
    <field name="sortieQty"/>
    <field name="cdesQty"/>
    <field name="stockQty"/>
    <field name="dispoQty"/>
    <field name="stockValue"/>
  </panel>
</form>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'lvme-etat-stock-lot-form' AND module IS NULL);
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) SELECT nextval('meta_view_seq'), 0, now(), 'lvme-etat-stock-lot-search-form', 'État des stocks par lots', 'form', 'com.axelor.utils.db.Wizard', 20, '<form name="lvme-etat-stock-lot-search-form" title="État des stocks par lots"
  model="com.axelor.utils.db.Wizard" width="large" canNew="false" canSave="false" canCopy="false" canDelete="false"
  onNew="action-lvme-etat-stock-lot-group-onnew">
  <!-- LVME : bandeau d''alerte DLUO -->
  <panel name="alertesDluoPanel" showTitle="false" colSpan="12">
    <field name="$nbDluoDepassee" type="integer" hidden="true"/>
    <field name="$nbDluoProche" type="integer" hidden="true"/>
    <field name="$alerteDluo" showTitle="false" readonly="true" colSpan="12" type="string">
      <viewer depends="$nbDluoDepassee,$nbDluoProche"><![CDATA[
        <>
          {$nbDluoDepassee > 0 && <Badge bg="danger">{$nbDluoDepassee} lot(s) en stock avec DLUO dépassée (lignes rouges)</Badge>}
          {'' ''}
          {$nbDluoProche > 0 && <Badge bg="warning">{$nbDluoProche} lot(s) avec DLUO dans moins de 30 jours (lignes orange)</Badge>}
          {!($nbDluoDepassee > 0) && !($nbDluoProche > 0) && <Badge bg="success">Aucun lot en stock avec DLUO dépassée ou proche</Badge>}
        </>
      ]]></viewer>
    </field>
  </panel>
  <panel name="filtresPanel" showTitle="false" colSpan="12">
    <panel name="filtreArticlePanel" colSpan="3" itemSpan="12">
      <field name="$articleDu" title="Article du" type="many-to-one" target="com.axelor.apps.base.db.Product" canNew="false" canEdit="false" canView="false"/>
      <field name="$articleAu" title="au" type="many-to-one" target="com.axelor.apps.base.db.Product" canNew="false" canEdit="false" canView="false"/>
      <field name="$famille" title="Fam. article" type="many-to-one" target="com.axelor.apps.base.db.ProductCategory" canNew="false" canEdit="false" canView="false"/>
      <field name="$numeroLot" title="OU Lot n°" type="string" onChange="action-lvme-etat-stock-lot-refresh"/>
    </panel>
    <panel name="filtreFournisseurPanel" colSpan="3" itemSpan="12">
      <field name="$fournisseurDu" title="Fournisseur du" type="many-to-one" target="com.axelor.apps.base.db.Partner" domain="self.isSupplier = true" canNew="false" canEdit="false" canView="false"/>
      <field name="$fournisseurAu" title="au" type="many-to-one" target="com.axelor.apps.base.db.Partner" domain="self.isSupplier = true" canNew="false" canEdit="false" canView="false"/>
      <field name="$origine" title="Origine" type="string" selection="lvme.origine.select"/>
      <field name="$frigo" title="Frigo" type="many-to-one" target="com.axelor.apps.stock.db.StockLocation" domain="self.typeSelect = 1" canNew="false" canEdit="false" canView="false"/>
    </panel>
    <panel name="filtreDatesPanel" colSpan="4" itemSpan="4">
      <field name="$entreeDu" title="Entrée du" type="date"/>
      <field name="$entreeAu" title="au" type="date"/>
      <field name="$entreePeriode" title="Période prédéfinie" type="integer" selection="lvme.etat.stock.periode.select" onChange="action-lvme-etat-stock-lot-periode-entree"/>
      <field name="$ddmDu" title="D.D.M. du" type="date"/>
      <field name="$ddmAu" title="au" type="date"/>
      <field name="$ddmPeriode" title="Période prédéfinie" type="integer" selection="lvme.etat.stock.periode.select" onChange="action-lvme-etat-stock-lot-periode-ddm"/>
      <field name="$livrDu" title="Livr. du" type="date"/>
      <field name="$livrAu" title="au" type="date"/>
      <field name="$livrPeriode" title="Période prédéfinie" type="integer" selection="lvme.etat.stock.periode.select" onChange="action-lvme-etat-stock-lot-periode-livr"/>
    </panel>
    <panel name="filtreOptionsPanel" colSpan="2" itemSpan="12">
      <field name="$natureArrivage" title="Arrivage" type="integer" widget="RadioSelect" selection="lvme.etat.stock.nature.select"/>
      <field name="$etatLot" title="Lots" type="integer" widget="RadioSelect" selection="lvme.etat.stock.etat.select"/>
      <field name="$dispoNegatif" title="Seulement les dispo négatifs" type="boolean"/>
      <button name="lancerRechercheBtn" title="Lancer la recherche" icon="search" css="btn-primary" onClick="action-lvme-etat-stock-lot-refresh"/>
    </panel>
  </panel>
  <panel-dashlet name="lotsDashlet" title="Lots" colSpan="12" height="600"
    action="action-lvme-etat-stock-lot-dashlet"/>
</form>
', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'lvme-etat-stock-lot-search-form' AND module IS NULL);
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) SELECT nextval('meta_view_seq'), 0, now(), 'lvme-rotation-stock-form', 'Rotation des stocks', 'form', 'com.axelor.apps.supplychain.db.RotationStock', 30, '<form name="lvme-rotation-stock-form" title="Rotation des stocks"
  model="com.axelor.apps.supplychain.db.RotationStock" canNew="false" canEdit="false" canDelete="false" canSave="false">
  <panel name="mainPanel" title="Produit" readonly="true">
    <field name="product"/>
    <field name="productCategory"/>
    <field name="statut"/>
    <field name="isDormant"/>
  </panel>
  <panel name="kpiPanel" title="Indicateurs" readonly="true" itemSpan="3">
    <field name="daysOfStock" title="Couverture (j)"/>
    <field name="rotationRate"/>
    <field name="avgAgeDays"/>
    <field name="dormantValue"/>
  </panel>
  <panel name="detailPanel" title="Détail" readonly="true" itemSpan="3">
    <field name="stockQty"/>
    <field name="stockValue"/>
    <field name="sales90d"/>
    <field name="avgDailySales"/>
    <field name="sales365d"/>
    <field name="lastSaleDate"/>
    <field name="daysSinceLastSale"/>
    <field name="oldestLotDate"/>
    <field name="oldestLotAge"/>
  </panel>
</form>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'lvme-rotation-stock-form' AND module IS NULL);
INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) SELECT nextval('meta_view_seq'), 0, now(), 'lvme-rotation-stock-dashboard-form', 'Rotation des stocks', 'form', 'com.axelor.utils.db.Wizard', 20, '<form name="lvme-rotation-stock-dashboard-form" title="Rotation des stocks"
  model="com.axelor.utils.db.Wizard" width="large" canNew="false" canSave="false" canCopy="false" canDelete="false"
  onNew="action-lvme-rotation-stock-group-onnew">

  <!-- Les 4 KPI -->
  <panel name="kpiPanel" showTitle="false" colSpan="12">
    <field name="$kpiStockTotal" type="string" hidden="true"/>
    <field name="$kpiCouverture" type="string" hidden="true"/>
    <field name="$kpiACommander" type="string" hidden="true"/>
    <field name="$kpiRotation" type="string" hidden="true"/>
    <field name="$kpiAge" type="string" hidden="true"/>
    <field name="$kpiLotsAnciens" type="string" hidden="true"/>
    <field name="$kpiDormant" type="string" hidden="true"/>
    <field name="$kpiDormantDetail" type="string" hidden="true"/>
    <field name="$kpiTuiles" showTitle="false" readonly="true" colSpan="12" type="string">
      <viewer depends="$kpiStockTotal,$kpiCouverture,$kpiACommander,$kpiRotation,$kpiAge,$kpiLotsAnciens,$kpiDormant,$kpiDormantDetail"><![CDATA[
        <>
          <Box mb={2} style={{ color: ''#555'' }}>{$kpiStockTotal}</Box>
          <Box d="grid" style={{ gridTemplateColumns: ''repeat(4, 1fr)'', gap: 12 }}>
            <Box style={{ border: ''1px solid #dc3545'', borderLeft: ''6px solid #dc3545'', borderRadius: 8, padding: 12 }}>
              <Box style={{ fontSize: 13, color: ''#666'' }}>1. Couverture moyenne</Box>
              <Box style={{ fontSize: 26, fontWeight: ''bold'' }}>{$kpiCouverture}</Box>
              <Box style={{ fontSize: 12, color: ''#dc3545'' }}>{$kpiACommander}</Box>
            </Box>
            <Box style={{ border: ''1px solid #0d6efd'', borderLeft: ''6px solid #0d6efd'', borderRadius: 8, padding: 12 }}>
              <Box style={{ fontSize: 13, color: ''#666'' }}>2. Taux de rotation</Box>
              <Box style={{ fontSize: 26, fontWeight: ''bold'' }}>{$kpiRotation}</Box>
              <Box style={{ fontSize: 12, color: ''#666'' }}>Ventes 12 mois / stock actuel</Box>
            </Box>
            <Box style={{ border: ''1px solid #fd7e14'', borderLeft: ''6px solid #fd7e14'', borderRadius: 8, padding: 12 }}>
              <Box style={{ fontSize: 13, color: ''#666'' }}>3. Âge moyen du stock</Box>
              <Box style={{ fontSize: 26, fontWeight: ''bold'' }}>{$kpiAge}</Box>
              <Box style={{ fontSize: 12, color: ''#fd7e14'' }}>{$kpiLotsAnciens}</Box>
            </Box>
            <Box style={{ border: ''1px solid #6c757d'', borderLeft: ''6px solid #6c757d'', borderRadius: 8, padding: 12 }}>
              <Box style={{ fontSize: 13, color: ''#666'' }}>4. Stock dormant</Box>
              <Box style={{ fontSize: 26, fontWeight: ''bold'' }}>{$kpiDormant}</Box>
              <Box style={{ fontSize: 12, color: ''#666'' }}>{$kpiDormantDetail}</Box>
            </Box>
          </Box>
        </>
      ]]></viewer>
    </field>
  </panel>

  <!-- Filtres -->
  <panel name="filtresPanel" showTitle="false" colSpan="12">
    <panel name="filtreArticlePanel" colSpan="4" itemSpan="12">
      <field name="$articleDu" title="Article du" type="many-to-one" target="com.axelor.apps.base.db.Product" canNew="false" canEdit="false" canView="false"/>
      <field name="$articleAu" title="au" type="many-to-one" target="com.axelor.apps.base.db.Product" canNew="false" canEdit="false" canView="false"/>
    </panel>
    <panel name="filtreFamillePanel" colSpan="4" itemSpan="12">
      <field name="$famille" title="Fam. article" type="many-to-one" target="com.axelor.apps.base.db.ProductCategory" canNew="false" canEdit="false" canView="false"/>
      <field name="$statutRotation" title="Statut" type="string" selection="lvme.rotation.statut.select"/>
    </panel>
    <panel name="filtreSeuilPanel" colSpan="2" itemSpan="12">
      <field name="$couvertureMax" title="Couverture inférieure à (j)" type="integer"/>
      <field name="$ageMin" title="Âge moyen supérieur à (j)" type="integer"/>
    </panel>
    <panel name="filtreActionPanel" colSpan="2" itemSpan="12">
      <field name="$dormantsSeulement" title="Seulement les dormants" type="boolean"/>
      <button name="lancerRechercheBtn" title="Lancer la recherche" icon="search" css="btn-primary" onClick="action-lvme-rotation-stock-refresh"/>
      <button name="recalculBtn" title="Recalculer les KPI" icon="arrow-repeat" onClick="action-lvme-rotation-stock-group-recalcul"/>
    </panel>
  </panel>

  <!-- Tableau par produit -->
  <panel-dashlet name="rotationDashlet" title="Rotation par produit" colSpan="12" height="550"
    action="action-lvme-rotation-stock-dashlet"/>
</form>', false, false WHERE NOT EXISTS (SELECT 1 FROM meta_view WHERE name = 'lvme-rotation-stock-dashboard-form' AND module IS NULL);

-- ---------- Menus (sous Stocks) ----------
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, priority, hidden, left_menu, mobile_menu, tag_count) SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-rotation-stock', 'Rotation des stocks', (SELECT id FROM meta_menu WHERE name = 'stock-root' ORDER BY priority DESC LIMIT 1), (SELECT id FROM meta_action WHERE name = 'action-lvme-rotation-stock-open'), 0, 0, false, true, false, false WHERE NOT EXISTS (SELECT 1 FROM meta_menu WHERE name = 'lvme-menu-rotation-stock');
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, priority, hidden, left_menu, mobile_menu, tag_count) SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-age-lot', 'Âge des lots', (SELECT id FROM meta_menu WHERE name = 'stock-root' ORDER BY priority DESC LIMIT 1), (SELECT id FROM meta_action WHERE name = 'lvme-action-age-lot'), 0, 0, false, true, false, false WHERE NOT EXISTS (SELECT 1 FROM meta_menu WHERE name = 'lvme-menu-age-lot');
INSERT INTO meta_menu (id, version, created_on, name, title, parent, action, order_seq, priority, hidden, left_menu, mobile_menu, tag_count) SELECT nextval('meta_menu_seq'), 0, now(), 'lvme-menu-etat-stock-lot', 'État des stocks par lots', (SELECT id FROM meta_menu WHERE name = 'stock-root' ORDER BY priority DESC LIMIT 1), (SELECT id FROM meta_action WHERE name = 'action-lvme-etat-stock-lot-open'), 50, 0, false, true, false, false WHERE NOT EXISTS (SELECT 1 FROM meta_menu WHERE name = 'lvme-menu-etat-stock-lot');

COMMIT;

-- Vérification
SELECT 'action' AS type, count(*) FROM meta_action WHERE name LIKE '%lvme%' AND module IS NULL
UNION ALL SELECT 'vue', count(*) FROM meta_view WHERE name LIKE 'lvme-%' AND module IS NULL
UNION ALL SELECT 'menu', count(*) FROM meta_menu WHERE name IN ('lvme-menu-rotation-stock','lvme-menu-age-lot','lvme-menu-etat-stock-lot');

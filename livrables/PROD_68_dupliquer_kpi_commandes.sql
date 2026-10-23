-- =====================================================================
-- PROD étape 68 : bouton « Dupliquer » et KPI des commandes clients
--   - Supprimer (corbeille, avec confirmation) à côté de Dupliquer dans les 3 listes : brouillon ou annulé seulement
--   - Dupliquer (icône copie) : barre d'outils des fiches Commande client, Commande fournisseur et Arrivage,
--     et au bout de chaque ligne des listes Commandes clients, Achats fournisseurs et Arrivages. Copie comme
--     Axelor (nouvelle pièce en brouillon, nouveau numéro, mêmes lignes), enregistrée et ouverte. Commande
--     client : lots / arrivages des lignes à rechoisir ; achat et arrivage : nouveau lot AE par ligne ;
--     arrivage copié « à embarquer », sans lien avec la commande d'achat d'origine.
--   - Listes Commandes Clients : 4 KPI en haut (Commandes en cours, CA HT du mois, % Marge du mois,
--     À livrer aujourd'hui + en retard)
-- Sources : livrables/ui/commande-client-search-form.xml ; écrit par livrables/outils/gen_prod68_dupliquer_kpi.py
-- Prérequis : code avec LvmeDuplicationController et LvmeSuppressionController (recompiler) ; PROD_63.
-- À lancer depuis la racine du dépôt. Relançable.
-- =====================================================================
\set recherche `cat livrables/ui/commande-client-search-form.xml`
SELECT set_config('lvme.cde_client_recherche', :'recherche', false) IS NOT NULL AS fiche_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.cde_client_recherche'), updated_on = now(),
  version = COALESCE(version, 0) + 1
WHERE name = 'lvme-commande-client-search-form' AND module IS NULL;

UPDATE meta_view SET xml = CASE WHEN position('<toolbar>' IN xml) > 0
    THEN regexp_replace(xml, '<toolbar>', '<toolbar>
    ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="save,action-lvme-dupliquer-cde-client"/>', '')
    ELSE regexp_replace(xml, '(<form\s[^>]*>)', '\1
  <toolbar>
    ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="save,action-lvme-dupliquer-cde-client"/>' || '
  </toolbar>', '') END,
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30 AND xml NOT LIKE '%lvmeDupliquerBtn%';
UPDATE meta_view SET xml = CASE WHEN position('<toolbar>' IN xml) > 0
    THEN regexp_replace(xml, '<toolbar>', '<toolbar>
    ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="save,action-lvme-dupliquer-cde-achat"/>', '')
    ELSE regexp_replace(xml, '(<form\s[^>]*>)', '\1
  <toolbar>
    ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="save,action-lvme-dupliquer-cde-achat"/>' || '
  </toolbar>', '') END,
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'purchase-order-form' AND module IS NULL AND priority = 30 AND xml NOT LIKE '%lvmeDupliquerBtn%';
UPDATE meta_view SET xml = CASE WHEN position('<toolbar>' IN xml) > 0
    THEN regexp_replace(xml, '<toolbar>', '<toolbar>
    ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="save,action-lvme-dupliquer-arrivage"/>', '')
    ELSE regexp_replace(xml, '(<form\s[^>]*>)', '\1
  <toolbar>
    ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="save,action-lvme-dupliquer-arrivage"/>' || '
  </toolbar>', '') END,
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-arrivage-form' AND module IS NULL AND priority = 20 AND xml NOT LIKE '%lvmeDupliquerBtn%';

UPDATE meta_view SET xml = regexp_replace(regexp_replace(xml, '\n\s*<button name="lvme(Dupliquer|Supprimer)Btn"[^>]*/>', '', 'g'),
    '(\n\s*<field )', E'\n  ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="action-lvme-dupliquer-cde-client"/>' || E'\n  ' || '<button name="lvmeSupprimerBtn" title="Supprimer" icon="delete" css="lvme-btn-supprimer" prompt="Supprimer définitivement cette commande client ?" onClick="action-lvme-supprimer-cde-client"/>' || '\1', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-commande-client-grid' AND module IS NULL;
UPDATE meta_view SET xml = regexp_replace(regexp_replace(xml, '\n\s*<button name="lvme(Dupliquer|Supprimer)Btn"[^>]*/>', '', 'g'),
    '(\n\s*<field )', E'\n  ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="action-lvme-dupliquer-cde-achat"/>' || E'\n  ' || '<button name="lvmeSupprimerBtn" title="Supprimer" icon="delete" css="lvme-btn-supprimer" prompt="Supprimer définitivement cette commande d''achat ?" onClick="action-lvme-supprimer-cde-achat"/>' || '\1', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-achat-grid' AND module IS NULL;
UPDATE meta_view SET xml = regexp_replace(regexp_replace(xml, '\n\s*<button name="lvme(Dupliquer|Supprimer)Btn"[^>]*/>', '', 'g'),
    '(\n\s*<field )', E'\n  ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="action-lvme-dupliquer-arrivage"/>' || E'\n  ' || '<button name="lvmeSupprimerBtn" title="Supprimer" icon="delete" css="lvme-btn-supprimer" prompt="Supprimer définitivement cet arrivage ?" onClick="action-lvme-supprimer-arrivage"/>' || '\1', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-arrivage-grid' AND module IS NULL;

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-dupliquer-cde-client', 'action-lvme-dupliquer-cde-achat', 'action-lvme-dupliquer-arrivage', 'action-lvme-supprimer-cde-client', 'action-lvme-supprimer-cde-achat', 'action-lvme-supprimer-arrivage', 'action-lvme-cde-client-kpi', 'action-lvme-cde-client-alerte-retard', 'action-lvme-cde-client-alerte-marge-negative', 'action-lvme-cde-client-alerte-marge-faible', 'action-lvme-cde-client-alerte-devis', 'action-lvme-cde-client-alerte-aucune', 'action-lvme-cde-client-refresh', 'action-lvme-cde-client-dashlet');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-dupliquer-cde-client', 'action-method', NULL,
'<action-method name="action-lvme-dupliquer-cde-client">
  <call class="com.axelor.apps.supplychain.web.LvmeDuplicationController" method="dupliquerCommandeClient"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-dupliquer-cde-achat', 'action-method', NULL,
'<action-method name="action-lvme-dupliquer-cde-achat">
  <call class="com.axelor.apps.supplychain.web.LvmeDuplicationController" method="dupliquerCommandeAchat"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-dupliquer-arrivage', 'action-method', NULL,
'<action-method name="action-lvme-dupliquer-arrivage">
  <call class="com.axelor.apps.supplychain.web.LvmeDuplicationController" method="dupliquerArrivage"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-supprimer-cde-client', 'action-method', NULL,
'<action-method name="action-lvme-supprimer-cde-client">
  <call class="com.axelor.apps.supplychain.web.LvmeSuppressionController" method="supprimerCommandeClient"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-supprimer-cde-achat', 'action-method', NULL,
'<action-method name="action-lvme-supprimer-cde-achat">
  <call class="com.axelor.apps.supplychain.web.LvmeSuppressionController" method="supprimerCommandeAchat"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-supprimer-arrivage', 'action-method', NULL,
'<action-method name="action-lvme-supprimer-arrivage">
  <call class="com.axelor.apps.supplychain.web.LvmeSuppressionController" method="supprimerArrivage"/>
</action-method>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-kpi', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-kpi">
  <attribute name="value" for="$kpiEnCours" expr="eval: __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3)'').count().toString()"/>
  <attribute name="value" for="$kpiEnCoursDetail" expr="eval: def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3)'').fetch(); java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE).format(((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal).setScale(0, java.math.RoundingMode.HALF_UP)) + '' € HT à livrer''"/>
  <attribute name="value" for="$kpiCaMois" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); f.format(ca.setScale(0, java.math.RoundingMode.HALF_UP)) + '' €''"/>
  <attribute name="value" for="$kpiCaMoisDetail" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); l.size() + '' commande(s) depuis le '' + d1.format(java.time.format.DateTimeFormatter.ofPattern(''dd/MM''))"/>
  <attribute name="value" for="$kpiCaEvol" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); def lp = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1.minusMonths(1), __date__.minusMonths(1)).fetch(); def cap = ((lp.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def v = cap.signum() == 0 ? null : ((ca - cap) * 100 / cap).setScale(0, java.math.RoundingMode.HALF_UP); v == null ? ''Pas de comparaison'' : (v.signum() &gt;= 0 ? ''▲ +'' : ''▼ '') + v + '' % vs mois dernier''"/>
  <attribute name="value" for="$kpiCaHausse" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); def lp = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1.minusMonths(1), __date__.minusMonths(1)).fetch(); def cap = ((lp.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); ca &gt;= cap ? ''true'' : null"/>
  <attribute name="value" for="$kpiMarge" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); pct != null ? pct.toString().replace(''.'', '','') + '' %'' : ''n.d.''"/>
  <attribute name="value" for="$kpiMargeDetail" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); ''Marge HT : '' + f.format(mg.setScale(0, java.math.RoundingMode.HALF_UP)) + '' €''"/>
  <attribute name="value" for="$kpiMargeFaible" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); pct != null &amp;&amp; pct &lt; 10 ? ''true'' : null"/>
  <attribute name="value" for="$kpiALivrer" expr="eval: __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.estimatedDeliveryDate = ?1'', __date__).count().toString()"/>
  <attribute name="value" for="$kpiALivrerDetail" expr="eval: __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.estimatedDeliveryDate = ?1'', __date__.plusDays(1)).count() + '' à livrer demain''"/>
  <attribute name="value" for="$alRetard" expr="eval: def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.estimatedDeliveryDate &lt; ?1'', __date__).count(); n &gt; 0 ? n + '' commande(s) en retard de livraison'' : null"/>
  <attribute name="value" for="$alMargeNeg" expr="eval: def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.totalGrossMargin &lt; 0'').count(); n &gt; 0 ? n + '' commande(s) en cours à marge négative'' : null"/>
  <attribute name="value" for="$alMargeFaible" expr="eval: def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); pct != null &amp;&amp; pct &lt; 10 ? ''Marge du mois sous 10 %'' : null"/>
  <attribute name="value" for="$alDevis" expr="eval: def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (1, 2) AND self.creationDate &lt; ?1'', __date__.minusDays(15)).count(); n &gt; 0 ? n + '' devis de plus de 15 jours non confirmé(s)'' : null"/>
  <attribute name="value" for="$alAucune" expr="eval: [{ -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.estimatedDeliveryDate &lt; ?1'', __date__).count(); n &gt; 0 ? n + '' commande(s) en retard de livraison'' : null }, { -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.totalGrossMargin &lt; 0'').count(); n &gt; 0 ? n + '' commande(s) en cours à marge négative'' : null }, { -> def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); pct != null &amp;&amp; pct &lt; 10 ? ''Marge du mois sous 10 %'' : null }, { -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (1, 2) AND self.creationDate &lt; ?1'', __date__.minusDays(15)).count(); n &gt; 0 ? n + '' devis de plus de 15 jours non confirmé(s)'' : null }].every { it() == null } ? ''Aucune alerte'' : null"/>
  <attribute name="title" for="lvmeAlRetardBtn" expr="eval: ''⚠ '' + ({ -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.estimatedDeliveryDate &lt; ?1'', __date__).count(); n &gt; 0 ? n + '' commande(s) en retard de livraison'' : null }() ?: '''')"/>
  <attribute name="hidden" for="lvmeAlRetardBtn" expr="eval: { -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.estimatedDeliveryDate &lt; ?1'', __date__).count(); n &gt; 0 ? n + '' commande(s) en retard de livraison'' : null }() == null"/>
  <attribute name="title" for="lvmeAlMargeNegBtn" expr="eval: ''⚠ '' + ({ -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.totalGrossMargin &lt; 0'').count(); n &gt; 0 ? n + '' commande(s) en cours à marge négative'' : null }() ?: '''')"/>
  <attribute name="hidden" for="lvmeAlMargeNegBtn" expr="eval: { -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.totalGrossMargin &lt; 0'').count(); n &gt; 0 ? n + '' commande(s) en cours à marge négative'' : null }() == null"/>
  <attribute name="title" for="lvmeAlMargeFaibleBtn" expr="eval: ''⚠ '' + ({ -> def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); pct != null &amp;&amp; pct &lt; 10 ? ''Marge du mois sous 10 %'' : null }() ?: '''')"/>
  <attribute name="hidden" for="lvmeAlMargeFaibleBtn" expr="eval: { -> def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); pct != null &amp;&amp; pct &lt; 10 ? ''Marge du mois sous 10 %'' : null }() == null"/>
  <attribute name="title" for="lvmeAlDevisBtn" expr="eval: ''⏳ '' + ({ -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (1, 2) AND self.creationDate &lt; ?1'', __date__.minusDays(15)).count(); n &gt; 0 ? n + '' devis de plus de 15 jours non confirmé(s)'' : null }() ?: '''')"/>
  <attribute name="hidden" for="lvmeAlDevisBtn" expr="eval: { -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (1, 2) AND self.creationDate &lt; ?1'', __date__.minusDays(15)).count(); n &gt; 0 ? n + '' devis de plus de 15 jours non confirmé(s)'' : null }() == null"/>
  <attribute name="hidden" for="lvmeAlAucuneBtn" expr="eval: { -> [{ -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.estimatedDeliveryDate &lt; ?1'', __date__).count(); n &gt; 0 ? n + '' commande(s) en retard de livraison'' : null }, { -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.totalGrossMargin &lt; 0'').count(); n &gt; 0 ? n + '' commande(s) en cours à marge négative'' : null }, { -> def d1 = __date__.withDayOfMonth(1); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, __date__).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); pct != null &amp;&amp; pct &lt; 10 ? ''Marge du mois sous 10 %'' : null }, { -> def n = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (1, 2) AND self.creationDate &lt; ?1'', __date__.minusDays(15)).count(); n &gt; 0 ? n + '' devis de plus de 15 jours non confirmé(s)'' : null }].every { it() == null } ? ''Aucune alerte'' : null }() == null"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-alerte-retard', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-alerte-retard">
  <attribute name="value" for="$alerte" expr="eval: ''retard''"/>
  <attribute name="refresh" for="commandesDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-alerte-marge-negative', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-alerte-marge-negative">
  <attribute name="value" for="$alerte" expr="eval: ''marge-negative''"/>
  <attribute name="refresh" for="commandesDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-alerte-marge-faible', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-alerte-marge-faible">
  <attribute name="value" for="$alerte" expr="eval: ''marge-faible''"/>
  <attribute name="refresh" for="commandesDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-alerte-devis', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-alerte-devis">
  <attribute name="value" for="$alerte" expr="eval: ''devis''"/>
  <attribute name="refresh" for="commandesDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-alerte-aucune', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-alerte-aucune">
  <attribute name="value" for="$alerte" expr="eval: null"/>
  <attribute name="refresh" for="commandesDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-refresh', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-refresh">
  <attribute name="value" for="$alerte" expr="eval: null"/>
  <attribute name="refresh" for="commandesDashlet" expr="eval: true"/>
</action-attrs>', false, false, 0),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-dashlet', 'action-view', 'com.axelor.apps.sale.db.SaleOrder',
'<action-view name="action-lvme-cde-client-dashlet" title="Commandes clients" model="com.axelor.apps.sale.db.SaleOrder">
  <view type="grid" name="lvme-commande-client-grid"/>
  <view type="form" name="sale-order-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <!-- sans alerte choisie : filtres de l''écran ; avec une alerte (bouton sous les KPI) : seulement les commandes
       en alerte, sans les autres filtres -->
  <domain>self.template = false AND (
    (:_alerte = '''' AND self.statusSelect IN (3, 4)
    AND ((:_etat = 1 AND self.statusSelect = 3 AND self.deliveryState != 3 AND (self.isReservation IS NULL OR self.isReservation = false))
         OR (:_etat = 2 AND (self.statusSelect = 4 OR self.deliveryState = 3)) OR :_etat = 3
         OR (:_etat = 4 AND self.isReservation = true AND self.statusSelect = 3))
    AND (:_client = 0 OR self.clientPartner.id = :_client)
    AND (:_commercial = 0 OR self.commercial.id = :_commercial)
    AND (:_dateFiltre = false OR COALESCE(self.orderDate, self.creationDate) BETWEEN :_dateDu AND :_dateAu)
    AND (:_livFiltre = false OR self.estimatedDeliveryDate BETWEEN :_livDu AND :_livAu))
    OR (:_alerte = ''retard'' AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3)
        AND self.estimatedDeliveryDate &lt; :_aujourdhui)
    OR (:_alerte = ''marge-negative'' AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3)
        AND self.totalGrossMargin &lt; 0)
    OR (:_alerte = ''marge-faible'' AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN :_debutMois AND :_aujourdhui
        AND self.marginRate &lt; 10)
    OR (:_alerte = ''devis'' AND self.statusSelect IN (1, 2) AND self.creationDate &lt; :_dateDevis))</domain>
  <context name="_alerte" expr="eval: alerte ?: ''''"/>
  <context name="_aujourdhui" expr="eval: __date__"/>
  <context name="_debutMois" expr="eval: __date__.withDayOfMonth(1)"/>
  <context name="_dateDevis" expr="eval: __date__.minusDays(15)"/>
  <context name="_etat" expr="eval: (etatCommande ?: 1) as Integer"/>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_commercial" expr="eval: (commercialFiltre?.id ?: 0) as Long"/>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_livFiltre" expr="eval: livraisonDu != null || livraisonAu != null"/>
  <context name="_livDu" expr="eval: livraisonDu ? java.time.LocalDate.parse(livraisonDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_livAu" expr="eval: livraisonAu ? java.time.LocalDate.parse(livraisonAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_internalUser" expr="eval: __user__.id"/>
  <context name="_template" expr="eval: false"/>
  <context name="todayDate" expr="eval: __config__.date"/>
</action-view>', false, false, 0);

COMMIT;

SELECT name, priority, position('lvmeDupliquerBtn' IN xml) > 0 AS dupliquer, position('kpiCdeClientPanel' IN xml) > 0 AS kpi
FROM meta_view WHERE module IS NULL AND name IN ('sale-order-form', 'purchase-order-form', 'lvme-arrivage-form',
  'lvme-commande-client-grid', 'lvme-achat-grid', 'lvme-arrivage-grid', 'lvme-commande-client-search-form')
ORDER BY name;

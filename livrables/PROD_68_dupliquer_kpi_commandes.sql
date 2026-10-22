-- =====================================================================
-- PROD étape 68 : bouton « Dupliquer » et KPI des commandes clients
--   - Dupliquer (icône copie) : barre d'outils des fiches Commande client, Commande fournisseur et Arrivage,
--     et au bout de chaque ligne des listes Commandes clients, Achats fournisseurs et Arrivages. Copie comme
--     Axelor (nouvelle pièce en brouillon, nouveau numéro, mêmes lignes), enregistrée et ouverte. Commande
--     client : lots / arrivages des lignes à rechoisir ; achat et arrivage : nouveau lot AE par ligne ;
--     arrivage copié « à embarquer », sans lien avec la commande d'achat d'origine.
--   - Listes Commandes Clients : 4 KPI en haut (Commandes en cours, CA HT du mois, % Marge du mois,
--     À livrer aujourd'hui + en retard)
-- Sources : livrables/ui/commande-client-search-form.xml ; écrit par livrables/outils/gen_prod68_dupliquer_kpi.py
-- Prérequis : code avec LvmeDuplicationController (recompiler) ; PROD_63 (fiche commande client p30).
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

UPDATE meta_view SET xml = regexp_replace(xml, '</grid>\s*$', '  ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="action-lvme-dupliquer-cde-client"/>' || '
</grid>
', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-commande-client-grid' AND module IS NULL AND xml NOT LIKE '%lvmeDupliquerBtn%';
UPDATE meta_view SET xml = regexp_replace(xml, '</grid>\s*$', '  ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="action-lvme-dupliquer-cde-achat"/>' || '
</grid>
', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-achat-grid' AND module IS NULL AND xml NOT LIKE '%lvmeDupliquerBtn%';
UPDATE meta_view SET xml = regexp_replace(xml, '</grid>\s*$', '  ' || '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="action-lvme-dupliquer-arrivage"/>' || '
</grid>
', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-arrivage-grid' AND module IS NULL AND xml NOT LIKE '%lvmeDupliquerBtn%';

DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-dupliquer-cde-client', 'action-lvme-dupliquer-cde-achat', 'action-lvme-dupliquer-arrivage', 'action-lvme-cde-client-kpi');
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
(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-kpi', 'action-attrs', NULL,
'<action-attrs name="action-lvme-cde-client-kpi">
  <attribute name="value" for="$kpiEnCours" expr="eval: __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3)'').count().toString()"/>
  <attribute name="value" for="$kpiEnCoursDetail" expr="eval: __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (1, 2)'').count() + '' devis en préparation''"/>
  <attribute name="value" for="$kpiCaMois" expr="eval: def d1 = __date__.withDayOfMonth(1); def d2 = __date__.withDayOfMonth(__date__.lengthOfMonth()); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, d2).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); f.format(ca.setScale(0, java.math.RoundingMode.HALF_UP)) + '' €''"/>
  <attribute name="value" for="$kpiCaMoisDetail" expr="eval: def d1 = __date__.withDayOfMonth(1); def d2 = __date__.withDayOfMonth(__date__.lengthOfMonth()); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, d2).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); l.size() + '' commande(s) depuis le '' + d1.format(java.time.format.DateTimeFormatter.ofPattern(''dd/MM''))"/>
  <attribute name="value" for="$kpiMarge" expr="eval: def d1 = __date__.withDayOfMonth(1); def d2 = __date__.withDayOfMonth(__date__.lengthOfMonth()); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, d2).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP).toString().replace(''.'', '','') + '' %'' : ''n.d.''"/>
  <attribute name="value" for="$kpiMargeDetail" expr="eval: def d1 = __date__.withDayOfMonth(1); def d2 = __date__.withDayOfMonth(__date__.lengthOfMonth()); def l = __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2'', d1, d2).fetch(); def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); ''Marge HT : '' + f.format(mg.setScale(0, java.math.RoundingMode.HALF_UP)) + '' €''"/>
  <attribute name="value" for="$kpiALivrer" expr="eval: __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.estimatedDeliveryDate = ?1'', __date__).count().toString()"/>
  <attribute name="value" for="$kpiRetard" expr="eval: __repo__(com.axelor.apps.sale.db.SaleOrder).all().filter(''self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3) AND self.estimatedDeliveryDate &lt; ?1'', __date__).count() + '' en retard''"/>
</action-attrs>', false, false, 0);

COMMIT;

SELECT name, priority, position('lvmeDupliquerBtn' IN xml) > 0 AS dupliquer, position('kpiCdeClientPanel' IN xml) > 0 AS kpi
FROM meta_view WHERE module IS NULL AND name IN ('sale-order-form', 'purchase-order-form', 'lvme-arrivage-form',
  'lvme-commande-client-grid', 'lvme-achat-grid', 'lvme-arrivage-grid', 'lvme-commande-client-search-form')
ORDER BY name;

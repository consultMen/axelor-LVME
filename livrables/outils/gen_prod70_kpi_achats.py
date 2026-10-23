"""Écrit livrables/PROD_70_kpi_achats.sql et met à jour livrables/ui/achat-search-form.xml : KPI et alertes en haut
de « liste des achats fournisseurs », comme les commandes clients (PROD_68) :
  cartes : Commandes en cours (+ montant HT), Flottants en mer (+ poids), Achats HT du mois (+ tendance),
           À recevoir sous 7 jours (+ en retard) ;
  boutons d'alerte (filtrent la liste) : réceptions en retard, brouillons de plus de 15 jours, à embarquer depuis
           plus de 30 jours ; « Aucune alerte » sinon.
Montants en devise de la société (companyExTaxTotal) : les commandes en dollars sont converties.
Usage : python livrables/outils/gen_prod70_kpi_achats.py   (depuis la racine du dépôt)
"""
import os

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UI = os.path.join(RACINE, 'livrables', 'ui')
DST = os.path.join(RACINE, 'livrables', 'PROD_70_kpi_achats.sql')

PO = 'com.axelor.apps.purchase.db.PurchaseOrder'
SM = 'com.axelor.apps.stock.db.StockMove'
EN_COURS = "self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4))"
FMT = "java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE)"
MOIS = ("def d1 = __date__.withDayOfMonth(1); "
        "def l = __repo__(%s).all().filter('self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2', d1, __date__).fetch(); "
        "def ach = ((l.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); "
        "def lp = __repo__(%s).all().filter('self.statusSelect IN (3, 4) AND self.orderDate BETWEEN ?1 AND ?2', "
        "d1.minusMonths(1), __date__.minusMonths(1)).fetch(); "
        "def achp = ((lp.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); " % (PO, PO))
KPI = [
    ('$kpaEnCours', "__repo__(%s).all().filter('%s').count().toString()" % (PO, EN_COURS)),
    ('$kpaEnCoursDetail', "def l = __repo__(%s).all().filter('%s').fetch(); %s.format(((l.collect { it.companyExTaxTotal ?: 0 }.sum() ?: 0) "
     "as BigDecimal).setScale(0, java.math.RoundingMode.HALF_UP)) + ' € HT en cours'" % (PO, EN_COURS, FMT)),
    ('$kpaFlottants', "__repo__(%s).all().filter('self.typeSelect = 3 AND self.statusSelect = 2 AND self.nature = 2').count().toString()" % SM),
    ('$kpaFlottantsDetail', "def l = __repo__(%s).all().filter('self.typeSelect = 3 AND self.statusSelect = 2 AND self.nature = 2').fetch(); "
     "%s.format(((l.collect { it.poidsTotal ?: 0 }.sum() ?: 0) as BigDecimal).setScale(0, java.math.RoundingMode.HALF_UP)) + ' kg en mer'" % (SM, FMT)),
    ('$kpaAchatsMois', MOIS + "%s.format(ach.setScale(0, java.math.RoundingMode.HALF_UP)) + ' €'" % FMT),
    ('$kpaAchatsMoisDetail', MOIS + "l.size() + ' commande(s) depuis le ' + d1.format(java.time.format.DateTimeFormatter.ofPattern('dd/MM'))"),
    ('$kpaAchatsEvol', MOIS + "def v = achp.signum() == 0 ? null : ((ach - achp) * 100 / achp).setScale(0, java.math.RoundingMode.HALF_UP); "
     "v == null ? 'Pas de comparaison' : (v.signum() &gt;= 0 ? '▲ +' : '▼ ') + v + ' % vs mois dernier'"),
    ('$kpaAchatsHausse', MOIS + "ach &gt;= achp ? 'true' : null"),
    ('$kpaARecevoir', "__repo__(%s).all().filter('%s AND self.estimatedReceiptDate BETWEEN ?1 AND ?2', __date__, __date__.plusDays(7)).count().toString()" % (PO, EN_COURS)),
    ('$kpaARecevoirDetail', "__repo__(%s).all().filter('%s AND self.estimatedReceiptDate &lt; ?1', __date__).count() + ' en retard'" % (PO, EN_COURS)),
    # alertes : texte si l'alerte existe, rien sinon
    ('$alaRetard', "def n = __repo__(%s).all().filter('%s AND self.estimatedReceiptDate &lt; ?1', __date__).count(); "
     "n &gt; 0 ? n + ' réception(s) en retard' : null" % (PO, EN_COURS)),
    ('$alaBrouillons', "def n = __repo__(%s).all().filter('self.statusSelect IN (1, 2) AND self.orderDate &lt; ?1', __date__.minusDays(15)).count(); "
     "n &gt; 0 ? n + ' commande(s) en brouillon depuis plus de 15 jours' : null" % PO),
    ('$alaAEmbarquer', "def n = __repo__(%s).all().filter('self.statusSelect = 3 AND self.nature = 1 AND self.orderDate &lt; ?1', __date__.minusDays(30)).count(); "
     "n &gt; 0 ? n + ' commande(s) à embarquer depuis plus de 30 jours' : null" % PO),
]
ALERTES = ['$alaRetard', '$alaBrouillons', '$alaAEmbarquer']
KPI.append(('$alaAucune', '[' + ', '.join('{ -> %s }' % e for k, e in KPI if k in ALERTES)
            + "].every { it() == null } ? 'Aucune alerte' : null"))
BOUTONS = [('$alaRetard', 'lvmeAlaRetardBtn', 'lvme-alerte-rouge', 'retard', '⚠'),
           ('$alaBrouillons', 'lvmeAlaBrouillonsBtn', 'lvme-alerte-jaune', 'brouillons', '⏳'),
           ('$alaAEmbarquer', 'lvmeAlaAEmbarquerBtn', 'lvme-alerte-jaune', 'a-embarquer', '⏳')]


def tuile(titre, degrade, icone, valeur, detail, extra=''):
    return ("            <Box style={{ position: 'relative', overflow: 'hidden', background: %s, color: '#fff', "
            "borderRadius: 14, boxShadow: '0 6px 16px rgba(20,30,60,.25)', padding: '14px 16px', minHeight: 128 }}>\n"
            "              <Box style={{ position: 'absolute', right: -28, top: -28, width: 110, height: 110, borderRadius: 55, "
            "background: 'rgba(255,255,255,.14)' }}></Box>\n"
            "              <Box style={{ position: 'absolute', right: 30, bottom: -40, width: 80, height: 80, borderRadius: 40, "
            "background: 'rgba(255,255,255,.08)' }}></Box>\n"
            "              <Box d=\"flex\" style={{ justifyContent: 'space-between', alignItems: 'center', position: 'relative' }}>\n"
            "                <Box style={{ fontSize: 12, fontWeight: 700, letterSpacing: '.06em', textTransform: 'uppercase', "
            "opacity: .9 }}>%s</Box>\n"
            "                <Box style={{ width: 40, height: 40, borderRadius: 20, background: 'rgba(255,255,255,.25)', display: 'flex', "
            "alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>%s</Box>\n"
            "              </Box>\n"
            "              <Box style={{ fontSize: 32, fontWeight: 800, lineHeight: 1.2, marginTop: 4, position: 'relative' }}>{%s}</Box>\n"
            "              <Box style={{ fontSize: 12, opacity: .9, position: 'relative' }}>{%s}</Box>\n"
            "%s"
            "            </Box>\n") % (degrade, titre, icone, valeur, detail, extra)


EVOL = ("              <Box style={{ display: 'inline-block', position: 'relative', marginTop: 6, fontSize: 12, fontWeight: 700, "
        "padding: '2px 10px', borderRadius: 12, background: 'rgba(255,255,255,.95)', "
        "color: $kpaAchatsHausse ? '#0f5132' : '#b02a37' }}>{$kpaAchatsEvol}</Box>\n")

panneau = ('  <!-- LVME : KPI et alertes des achats (calculés à l\'ouverture, action-lvme-achat-kpi) -->\n'
           '  <panel name="kpiAchatPanel" showTitle="false" colSpan="12">\n'
           + ''.join('    <field name="%s" type="string" hidden="true"/>\n' % k for k, _ in KPI)
           + '    <field name="$kpaTuiles" showTitle="false" readonly="true" colSpan="12" type="string">\n'
           '      <viewer depends="%s"><![CDATA[\n' % ','.join(k for k, _ in KPI)
           + '        <>\n'
           "          <Box d=\"grid\" style={{ gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>\n"
           + tuile('Commandes en cours', "'linear-gradient(135deg, #1e6fe8, #0a3d91)'", '📋', '$kpaEnCours', '$kpaEnCoursDetail')
           + tuile('Flottants (en mer)', "'linear-gradient(135deg, #17a2b8, #0b5f6d)'", '🚢', '$kpaFlottants', '$kpaFlottantsDetail')
           + tuile('Achats HT du mois', "'linear-gradient(135deg, #22a565, #0d6b3d)'", '💶', '$kpaAchatsMois', '$kpaAchatsMoisDetail', EVOL)
           + tuile('À recevoir sous 7 jours', "'linear-gradient(135deg, #ff9a3c, #d9580d)'", '📦', '$kpaARecevoir', '$kpaARecevoirDetail')
           + '          </Box>\n'
           '        </>\n'
           '      ]]></viewer>\n'
           '    </field>\n'
           '    <field name="$alerteAchat" type="string" hidden="true"/>\n'
           '    <panel name="lvmeAlertesAchatPanel" showTitle="false" colSpan="12">\n'
           + ''.join('      <button name="%s" title=" " css="%s" hidden="true" colSpan="3" onClick="action-lvme-achat-alerte-%s"/>\n'
                     % (btn, css, code) for k, btn, css, code, ic in BOUTONS)
           + '      <button name="lvmeAlaAucuneBtn" title="✔ Aucune alerte" css="lvme-alerte-vert" hidden="true" readonly="true" colSpan="3"'
           ' onClick="action-lvme-achat-alerte-aucune"/>\n'
           '      <button name="lvmeAlaRetirerBtn" title="✖ Retirer le filtre alerte" css="lvme-alerte-gris" showIf="$alerteAchat" colSpan="3"'
           ' onClick="action-lvme-achat-alerte-aucune"/>\n'
           '    </panel>\n'
           '  </panel>\n')

p = os.path.join(UI, 'achat-search-form.xml')
f = open(p, encoding='utf-8').read().replace('\r\n', '\n')
if 'kpiAchatPanel' in f:  # nouvelle version du panneau : l'ancien est retiré (fin au niveau 2)
    i = f.index('  <!-- LVME : KPI')
    j = f.index('\n  </panel>\n', f.index('name="kpiAchatPanel"')) + len('\n  </panel>\n')
    f = f[:i] + f[j:]
else:
    f = f.replace('onNew="action-lvme-achat-defaults"', 'onNew="action-lvme-achat-defaults,action-lvme-achat-kpi"', 1)
i = f.index('  <panel name="rechercheAchatPanel"')
f = f[:i] + panneau + f[i:]
open(p, 'w', encoding='utf-8', newline='\n').write(f)

EXPR = dict(KPI)
kpi_xml = ('<action-attrs name="action-lvme-achat-kpi">\n'
           + ''.join('  <attribute name="value" for="%s" expr="eval: %s"/>\n' % (k, e) for k, e in KPI)
           + ''.join('  <attribute name="title" for="%s" expr="eval: \'%s \' + ({ -> %s }() ?: \'\')"/>\n'
                     '  <attribute name="hidden" for="%s" expr="eval: { -> %s }() == null"/>\n'
                     % (btn, ic, EXPR[k], btn, EXPR[k]) for k, btn, css, code, ic in BOUTONS)
           + '  <attribute name="hidden" for="lvmeAlaAucuneBtn" expr="eval: { -> %s }() == null"/>\n' % EXPR['$alaAucune']
           + '</action-attrs>')

DASHLET = """<action-view name="action-lvme-achat-dashlet" title="Achats fournisseurs" model="com.axelor.apps.purchase.db.PurchaseOrder">
  <view type="grid" name="lvme-achat-grid"/>
  <view type="form" name="purchase-order-form"/>
  <view-param name="popup" value="true"/>
  <view-param name="popup-save" value="true"/>
  <view-param name="popup.maximized" value="true"/>
  <!-- sans alerte choisie : filtres de l'écran ; avec une alerte (bouton sous les KPI) : seulement les commandes
       en alerte, sans les autres filtres -->
  <domain>(:_alerte = '' AND self.statusSelect IN (3, 4)
    AND (:_dateFiltre = false OR self.orderDate BETWEEN :_dateDu AND :_dateAu)
    AND (:_arrFiltre = false OR self.estimatedReceiptDate BETWEEN :_arrDu AND :_arrAu)
    AND (:_fouDu = '' OR self.supplierPartner.name &gt;= :_fouDu) AND (:_fouAu = '' OR self.supplierPartner.name &lt;= :_fouAu)
    AND (:_transport = 0 OR self.shipmentMode.id = :_transport)
    AND ((:_nature = 1 AND self.nature = 3) OR (:_nature = 2 AND self.nature IN (1, 2)) OR :_nature = 3))
    OR (:_alerte = 'retard' AND self.statusSelect = 3 AND (self.nature IS NULL OR self.nature NOT IN (3, 4))
        AND self.estimatedReceiptDate &lt; :_aujourdhui)
    OR (:_alerte = 'brouillons' AND self.statusSelect IN (1, 2) AND self.orderDate &lt; :_date15)
    OR (:_alerte = 'a-embarquer' AND self.statusSelect = 3 AND self.nature = 1 AND self.orderDate &lt; :_date30)</domain>
  <context name="_alerte" expr="eval: alerteAchat ?: ''"/>
  <context name="_aujourdhui" expr="eval: __date__"/>
  <context name="_date15" expr="eval: __date__.minusDays(15)"/>
  <context name="_date30" expr="eval: __date__.minusDays(30)"/>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_arrFiltre" expr="eval: arriveeDu != null || arriveeAu != null"/>
  <context name="_arrDu" expr="eval: arriveeDu ? java.time.LocalDate.parse(arriveeDu.toString().substring(0, 10)) : java.time.LocalDate.of(1900, 1, 1)"/>
  <context name="_arrAu" expr="eval: arriveeAu ? java.time.LocalDate.parse(arriveeAu.toString().substring(0, 10)) : java.time.LocalDate.of(2999, 12, 31)"/>
  <context name="_fouDu" expr="eval: fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.name ?: '') : ''"/>
  <context name="_fouAu" expr="eval: fournisseurAu?.id ? (__repo__(Partner).find(fournisseurAu.id as Long)?.name ?: '') : (fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.name ?: '') : '')"/>
  <context name="_transport" expr="eval: (typeTransport?.id ?: 0) as Long"/>
  <context name="_nature" expr="eval: (natureAchat ?: 3) as Integer"/>
  <context name="_internalUser" expr="eval: __user__.id"/>
</action-view>"""
ACTIONS = [('action-lvme-achat-kpi', kpi_xml)]
for k, btn, css, code, ic in BOUTONS + [(None, None, None, 'aucune', None)]:
    val = 'null' if code == 'aucune' else "'%s'" % code
    ACTIONS.append(('action-lvme-achat-alerte-' + code,
                    '<action-attrs name="action-lvme-achat-alerte-%s">\n'
                    '  <attribute name="value" for="$alerteAchat" expr="eval: %s"/>\n'
                    '  <attribute name="refresh" for="achatsDashlet" expr="eval: true"/>\n'
                    '</action-attrs>' % (code, val)))
# « Lancer la recherche » retire le filtre alerte
ACTIONS.append(('action-lvme-achat-refresh', '<action-attrs name="action-lvme-achat-refresh">\n'
                '  <attribute name="value" for="$alerteAchat" expr="eval: null"/>\n'
                '  <attribute name="refresh" for="achatsDashlet" expr="eval: true"/>\n'
                '</action-attrs>'))
ACTIONS.append(('action-lvme-achat-dashlet', DASHLET))


def q(s):
    return s.replace("'", "''")


valeurs = ',\n'.join(
    "(nextval('meta_action_seq'), 0, now(), '%s', '%s', %s,\n'%s', false, false, 0)"
    % (n, 'action-view' if x.startswith('<action-view') else 'action-attrs',
       "'%s'" % PO if x.startswith('<action-view') else 'NULL', q(x)) for n, x in ACTIONS)

sql = '''-- =====================================================================
-- PROD étape 70 : KPI et alertes en haut de « liste des achats fournisseurs » (comme les commandes clients)
--   - cartes : Commandes en cours (+ montant HT), Flottants en mer (+ poids), Achats HT du mois (+ tendance vs
--     mois dernier), À recevoir sous 7 jours (+ en retard) ; montants en devise de la société
--   - boutons d'alerte qui filtrent la liste : réceptions en retard, brouillons de plus de 15 jours, à embarquer
--     depuis plus de 30 jours ; « Aucune alerte » ; « Retirer le filtre alerte » ; Lancer la recherche le retire aussi
-- Source : livrables/ui/achat-search-form.xml ; écrit par livrables/outils/gen_prod70_kpi_achats.py
-- Prérequis : css des boutons d'alerte (lvme.css, recompiler). Depuis la racine du dépôt. Relançable.
-- =====================================================================
\\set recherche `cat livrables/ui/achat-search-form.xml`
SELECT set_config('lvme.achat_recherche', :'recherche', false) IS NOT NULL AS fiche_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.achat_recherche'), updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = 'lvme-achat-search-form' AND module IS NULL;

DELETE FROM meta_action WHERE module IS NULL AND name IN (%s);
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
%s;

COMMIT;

SELECT name, position('kpiAchatPanel' IN xml) > 0 AS kpi FROM meta_view WHERE module IS NULL AND name = 'lvme-achat-search-form';
''' % (', '.join("'%s'" % n for n, _ in ACTIONS), valeurs)
open(DST, 'w', encoding='utf-8', newline='\n').write(sql)
print('ok', DST)

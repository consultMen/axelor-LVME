"""Écrit livrables/PROD_68_dupliquer_kpi_commandes.sql et met à jour livrables/ui/commande-client-search-form.xml :
  - bouton « Dupliquer » (icône copie) dans la barre d'outils des fiches Commande client, Commande fournisseur,
    Arrivage, et au bout de chaque ligne des listes Commandes clients, Achats fournisseurs, Arrivages ;
  - 4 KPI en haut de « Listes Commandes Clients » (Commandes en cours, CA HT du mois, % Marge du mois,
    À livrer aujourd'hui / en retard), cartes de couleur comme la Rotation des stocks.
Usage : python livrables/outils/gen_prod68_dupliquer_kpi.py   (depuis la racine du dépôt)
"""
import os

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UI = os.path.join(RACINE, 'livrables', 'ui')
DST = os.path.join(RACINE, 'livrables', 'PROD_68_dupliquer_kpi_commandes.sql')

# ---------- fiche de recherche des commandes clients : KPI en haut ----------
SO = 'com.axelor.apps.sale.db.SaleOrder'
EN_COURS = "self.template = false AND self.statusSelect = 3 AND (self.deliveryState IS NULL OR self.deliveryState != 3)"
MOIS = ("def d1 = __date__.withDayOfMonth(1); "
        "def l = __repo__(%s).all().filter('self.template = false AND self.statusSelect IN (3, 4) "
        "AND self.orderDate BETWEEN ?1 AND ?2', d1, __date__).fetch(); "
        "def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); "
        "def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); "
        "def pct = ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP) : null; "
        "def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); " % SO)
# même période du mois précédent (du 1er au même jour), pour la tendance du CA
PREC = ("def lp = __repo__(%s).all().filter('self.template = false AND self.statusSelect IN (3, 4) "
        "AND self.orderDate BETWEEN ?1 AND ?2', d1.minusMonths(1), __date__.minusMonths(1)).fetch(); "
        "def cap = ((lp.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); " % SO)
SEUIL_MARGE = 10  # % : en dessous, alerte « marge faible »
KPI = [
    ('$kpiEnCours', "__repo__(%s).all().filter('%s').count().toString()" % (SO, EN_COURS)),
    ('$kpiEnCoursDetail', "def l = __repo__(%s).all().filter('%s').fetch(); "
     "java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE).format(((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal)"
     ".setScale(0, java.math.RoundingMode.HALF_UP)) + ' € HT à livrer'" % (SO, EN_COURS)),
    ('$kpiCaMois', MOIS + "f.format(ca.setScale(0, java.math.RoundingMode.HALF_UP)) + ' €'"),
    ('$kpiCaMoisDetail', MOIS + "l.size() + ' commande(s) depuis le ' + d1.format(java.time.format.DateTimeFormatter.ofPattern('dd/MM'))"),
    ('$kpiCaEvol', MOIS + PREC + "def v = cap.signum() == 0 ? null : ((ca - cap) * 100 / cap).setScale(0, java.math.RoundingMode.HALF_UP); "
     "v == null ? 'Pas de comparaison' : (v.signum() &gt;= 0 ? '▲ +' : '▼ ') + v + ' % vs mois dernier'"),
    ('$kpiCaHausse', MOIS + PREC + "ca &gt;= cap ? 'true' : null"),
    ('$kpiMarge', MOIS + "pct != null ? pct.toString().replace('.', ',') + ' %' : 'n.d.'"),
    ('$kpiMargeDetail', MOIS + "'Marge HT : ' + f.format(mg.setScale(0, java.math.RoundingMode.HALF_UP)) + ' €'"),
    ('$kpiMargeFaible', MOIS + "pct != null &amp;&amp; pct &lt; %d ? 'true' : null" % SEUIL_MARGE),
    ('$kpiALivrer', "__repo__(%s).all().filter('%s AND self.estimatedDeliveryDate = ?1', __date__).count().toString()" % (SO, EN_COURS)),
    ('$kpiALivrerDetail', "__repo__(%s).all().filter('%s AND self.estimatedDeliveryDate = ?1', __date__.plusDays(1)).count() + ' à livrer demain'" % (SO, EN_COURS)),
    # alertes : texte si l'alerte existe, rien sinon
    ('$alRetard', "def n = __repo__(%s).all().filter('%s AND self.estimatedDeliveryDate &lt; ?1', __date__).count(); "
     "n &gt; 0 ? n + ' commande(s) en retard de livraison' : null" % (SO, EN_COURS)),
    ('$alMargeNeg', "def n = __repo__(%s).all().filter('%s AND self.totalGrossMargin &lt; 0').count(); "
     "n &gt; 0 ? n + ' commande(s) en cours à marge négative' : null" % (SO, EN_COURS)),
    ('$alMargeFaible', MOIS + "pct != null &amp;&amp; pct &lt; %d ? 'Marge du mois sous %d %%' : null" % (SEUIL_MARGE, SEUIL_MARGE)),
    ('$alDevis', "def n = __repo__(%s).all().filter('self.template = false AND self.statusSelect IN (1, 2) "
     "AND self.creationDate &lt; ?1', __date__.minusDays(15)).count(); "
     "n &gt; 0 ? n + ' devis de plus de 15 jours non confirmé(s)' : null" % SO),
]
ALERTES = ['$alRetard', '$alMargeNeg', '$alMargeFaible', '$alDevis']
# « Aucune alerte » : calculé en dernier, avec les mêmes requêtes que chaque alerte
KPI.append(('$alAucune', '[' + ', '.join('{ -> %s }' % e for k, e in KPI if k in ALERTES)
            + "].every { it() == null } ? 'Aucune alerte' : null"))


def tuile(titre, couleur, fond, icone, valeur, detail, extra='', couleur_valeur="'#1b2a4a'"):
    return ("            <Box style={{ background: '#fff', borderRadius: 10, borderTop: '4px solid %s', "
            "boxShadow: '0 1px 4px rgba(0,0,0,.15)', padding: '10px 14px' }}>\n"
            "              <Box d=\"flex\" style={{ justifyContent: 'space-between', alignItems: 'center' }}>\n"
            "                <Box style={{ fontSize: 12, color: '#555', fontWeight: 600, textTransform: 'uppercase' }}>%s</Box>\n"
            "                <Box style={{ width: 34, height: 34, borderRadius: 17, background: '%s', display: 'flex', "
            "alignItems: 'center', justifyContent: 'center', fontSize: 18 }}>%s</Box>\n"
            "              </Box>\n"
            "              <Box style={{ fontSize: 28, fontWeight: 700, color: %s }}>{%s}</Box>\n"
            "              <Box style={{ fontSize: 12, color: '#666' }}>{%s}</Box>\n"
            "%s"
            "            </Box>\n") % (couleur, titre, fond, icone, couleur_valeur, valeur, detail, extra)


def pastille(champ, fond, texte, icone):
    return ("            {%s && <Box style={{ background: '%s', color: '%s', borderRadius: 14, padding: '4px 12px', "
            "fontSize: 13, fontWeight: 600 }}>%s {%s}</Box>}\n") % (champ, fond, texte, icone, champ)


EVOL = ("              <Box style={{ display: 'inline-block', marginTop: 4, fontSize: 12, fontWeight: 600, padding: '2px 8px', "
        "borderRadius: 10, background: $kpiCaHausse ? '#d1e7dd' : '#f8d7da', color: $kpiCaHausse ? '#0f5132' : '#842029' }}>"
        "{$kpiCaEvol}</Box>\n")

panneau = ('  <!-- LVME : KPI et alertes des commandes clients (calculés à l\'ouverture, action-lvme-cde-client-kpi) -->\n'
           '  <panel name="kpiCdeClientPanel" showTitle="false" colSpan="12">\n'
           + ''.join('    <field name="%s" type="string" hidden="true"/>\n' % k for k, _ in KPI)
           + '    <field name="$kpiCdeTuiles" showTitle="false" readonly="true" colSpan="12" type="string">\n'
           '      <viewer depends="%s"><![CDATA[\n' % ','.join(k for k, _ in KPI)
           + '        <>\n'
           "          <Box d=\"grid\" style={{ gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>\n"
           + tuile('Commandes en cours', '#0d6efd', '#e7f1ff', '📦', '$kpiEnCours', '$kpiEnCoursDetail')
           + tuile('CA HT du mois', '#198754', '#e6f4ea', '💶', '$kpiCaMois', '$kpiCaMoisDetail', EVOL)
           + tuile('% Marge du mois', '#6f42c1', '#efe8fb', '📈', '$kpiMarge', '$kpiMargeDetail', '',
                   "$kpiMargeFaible ? '#dc3545' : '#1b2a4a'")
           + tuile("À livrer aujourd'hui", '#fd7e14', '#fff1e6', '🚚', '$kpiALivrer', '$kpiALivrerDetail')
           + '          </Box>\n'
           "          <Box d=\"flex\" style={{ flexWrap: 'wrap', gap: 8, marginTop: 10, alignItems: 'center' }}>\n"
           "            <Box style={{ fontSize: 13, fontWeight: 700, color: '#1b2a4a', marginRight: 4 }}>Alertes :</Box>\n"
           + pastille('$alRetard', '#f8d7da', '#842029', '⚠')
           + pastille('$alMargeNeg', '#f8d7da', '#842029', '⚠')
           + pastille('$alMargeFaible', '#fff3cd', '#664d03', '⚠')
           + pastille('$alDevis', '#fff3cd', '#664d03', '⏳')
           + pastille('$alAucune', '#d1e7dd', '#0f5132', '✔')
           + '          </Box>\n'
           '        </>\n'
           '      ]]></viewer>\n'
           '    </field>\n'
           '  </panel>\n')

p = os.path.join(UI, 'commande-client-search-form.xml')
f = open(p, encoding='utf-8').read()
if 'kpiCdeClientPanel' in f:  # nouvelle version du panneau : l'ancien est retiré
    i = f.index('  <!-- LVME : KPI')
    j = f.index('  </panel>\n', f.index('name="kpiCdeClientPanel"')) + len('  </panel>\n')
    f = f[:i] + f[j:]
else:
    f = f.replace('onNew="action-lvme-cde-client-defaults"', 'onNew="action-lvme-cde-client-defaults,action-lvme-cde-client-kpi"', 1)
i = f.index('  <panel name="rechercheCdePanel"')
f = f[:i] + panneau + f[i:]
open(p, 'w', encoding='utf-8', newline='\n').write(f)

kpi_xml = ('<action-attrs name="action-lvme-cde-client-kpi">\n'
           + ''.join('  <attribute name="value" for="%s" expr="eval: %s"/>\n' % (k, e) for k, e in KPI)
           + '</action-attrs>')


def q(s):
    return s.replace("'", "''")


BTN_FICHE = '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="save,%s"/>'
BTN_LISTE = '<button name="lvmeDupliquerBtn" title="Dupliquer" icon="content_copy" onClick="%s"/>'
fiches = [('sale-order-form', 30, 'action-lvme-dupliquer-cde-client'),
          ('purchase-order-form', 30, 'action-lvme-dupliquer-cde-achat'),
          ('lvme-arrivage-form', 20, 'action-lvme-dupliquer-arrivage')]
listes = [('lvme-commande-client-grid', 'action-lvme-dupliquer-cde-client'),
          ('lvme-achat-grid', 'action-lvme-dupliquer-cde-achat'),
          ('lvme-arrivage-grid', 'action-lvme-dupliquer-arrivage')]
methodes = [('action-lvme-dupliquer-cde-client', 'dupliquerCommandeClient'),
            ('action-lvme-dupliquer-cde-achat', 'dupliquerCommandeAchat'),
            ('action-lvme-dupliquer-arrivage', 'dupliquerArrivage')]

maj_fiches = ''.join(
    "UPDATE meta_view SET xml = CASE WHEN position('<toolbar>' IN xml) > 0\n"
    "    THEN regexp_replace(xml, '<toolbar>', '<toolbar>\n    ' || '%s', '')\n"
    "    ELSE regexp_replace(xml, '(<form\\s[^>]*>)', '\\1\n  <toolbar>\n    ' || '%s' || '\n  </toolbar>', '') END,\n"
    "  updated_on = now(), version = COALESCE(version, 0) + 1\n"
    "WHERE name = '%s' AND module IS NULL AND priority = %d AND xml NOT LIKE '%%lvmeDupliquerBtn%%';\n"
    % (q(BTN_FICHE % a), q(BTN_FICHE % a), n, p_) for n, p_, a in fiches)
maj_listes = ''.join(
    "UPDATE meta_view SET xml = regexp_replace(xml, '</grid>\\s*$', '  ' || '%s' || '\n</grid>\n', ''),\n"
    "  updated_on = now(), version = COALESCE(version, 0) + 1\n"
    "WHERE name = '%s' AND module IS NULL AND xml NOT LIKE '%%lvmeDupliquerBtn%%';\n"
    % (q(BTN_LISTE % a), n) for n, a in listes)
noms = [m for m, _ in methodes] + ['action-lvme-cde-client-kpi']
actions = ',\n'.join(
    "(nextval('meta_action_seq'), 0, now(), '%s', 'action-method', NULL,\n"
    "'<action-method name=\"%s\">\n  <call class=\"com.axelor.apps.supplychain.web.LvmeDuplicationController\" method=\"%s\"/>\n"
    "</action-method>', false, false, 0)" % (m, m, j) for m, j in methodes)
actions += (",\n(nextval('meta_action_seq'), 0, now(), 'action-lvme-cde-client-kpi', 'action-attrs', NULL,\n'%s', false, false, 0)"
            % q(kpi_xml))

sql = '''-- =====================================================================
-- PROD étape 68 : bouton « Dupliquer » et KPI des commandes clients
--   - Dupliquer (icône copie) : barre d'outils des fiches Commande client, Commande fournisseur et Arrivage,
--     et au bout de chaque ligne des listes Commandes clients, Achats fournisseurs et Arrivages. Copie comme
--     Axelor (nouvelle pièce en brouillon, nouveau numéro, mêmes lignes), enregistrée et ouverte. Commande
--     client : lots / arrivages des lignes à rechoisir ; achat et arrivage : nouveau lot AE par ligne ;
--     arrivage copié « à embarquer », sans lien avec la commande d'achat d'origine.
--   - Listes Commandes Clients : 4 KPI en haut (Commandes en cours, CA HT du mois, %% Marge du mois,
--     À livrer aujourd'hui + en retard)
-- Sources : livrables/ui/commande-client-search-form.xml ; écrit par livrables/outils/gen_prod68_dupliquer_kpi.py
-- Prérequis : code avec LvmeDuplicationController (recompiler) ; PROD_63 (fiche commande client p30).
-- À lancer depuis la racine du dépôt. Relançable.
-- =====================================================================
\\set recherche `cat livrables/ui/commande-client-search-form.xml`
SELECT set_config('lvme.cde_client_recherche', :'recherche', false) IS NOT NULL AS fiche_lue;

BEGIN;

UPDATE meta_view SET xml = current_setting('lvme.cde_client_recherche'), updated_on = now(),
  version = COALESCE(version, 0) + 1
WHERE name = 'lvme-commande-client-search-form' AND module IS NULL;

%s
%s
DELETE FROM meta_action WHERE module IS NULL AND name IN (%s);
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
%s;

COMMIT;

SELECT name, priority, position('lvmeDupliquerBtn' IN xml) > 0 AS dupliquer, position('kpiCdeClientPanel' IN xml) > 0 AS kpi
FROM meta_view WHERE module IS NULL AND name IN ('sale-order-form', 'purchase-order-form', 'lvme-arrivage-form',
  'lvme-commande-client-grid', 'lvme-achat-grid', 'lvme-arrivage-grid', 'lvme-commande-client-search-form')
ORDER BY name;
''' % (maj_fiches, maj_listes, ', '.join("'%s'" % n for n in noms), actions)
sql = sql.replace('%%', '%')
open(DST, 'w', encoding='utf-8', newline='\n').write(sql)
print('ok', DST)

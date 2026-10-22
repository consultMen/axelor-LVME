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
MOIS = ("def d1 = __date__.withDayOfMonth(1); def d2 = __date__.withDayOfMonth(__date__.lengthOfMonth()); "
        "def l = __repo__(%s).all().filter('self.template = false AND self.statusSelect IN (3, 4) "
        "AND self.orderDate BETWEEN ?1 AND ?2', d1, d2).fetch(); "
        "def ca = ((l.collect { it.exTaxTotal ?: 0 }.sum() ?: 0) as BigDecimal); "
        "def mg = ((l.collect { it.totalGrossMargin ?: 0 }.sum() ?: 0) as BigDecimal); "
        "def f = java.text.NumberFormat.getIntegerInstance(java.util.Locale.FRANCE); " % SO)
KPI = [
    ('$kpiEnCours', "__repo__(%s).all().filter('%s').count().toString()" % (SO, EN_COURS)),
    ('$kpiEnCoursDetail', "__repo__(%s).all().filter('self.template = false AND self.statusSelect IN (1, 2)').count() + ' devis en préparation'" % SO),
    ('$kpiCaMois', MOIS + "f.format(ca.setScale(0, java.math.RoundingMode.HALF_UP)) + ' €'"),
    ('$kpiCaMoisDetail', MOIS + "l.size() + ' commande(s) depuis le ' + d1.format(java.time.format.DateTimeFormatter.ofPattern('dd/MM'))"),
    ('$kpiMarge', MOIS + "ca.signum() != 0 ? (mg * 100 / ca).setScale(1, java.math.RoundingMode.HALF_UP).toString().replace('.', ',') + ' %' : 'n.d.'"),
    ('$kpiMargeDetail', MOIS + "'Marge HT : ' + f.format(mg.setScale(0, java.math.RoundingMode.HALF_UP)) + ' €'"),
    ('$kpiALivrer', "__repo__(%s).all().filter('%s AND self.estimatedDeliveryDate = ?1', __date__).count().toString()" % (SO, EN_COURS)),
    ('$kpiRetard', "__repo__(%s).all().filter('%s AND self.estimatedDeliveryDate &lt; ?1', __date__).count() + ' en retard'" % (SO, EN_COURS)),
]


def tuile(titre, couleur, valeur, detail, couleur_detail='#666'):
    return ('            <Box style={{ border: \'1px solid %s\', borderLeft: \'6px solid %s\', borderRadius: 8, padding: 12 }}>\n'
            '              <Box style={{ fontSize: 13, color: \'#666\' }}>%s</Box>\n'
            '              <Box style={{ fontSize: 26, fontWeight: \'bold\' }}>{%s}</Box>\n'
            '              <Box style={{ fontSize: 12, color: \'%s\' }}>{%s}</Box>\n'
            '            </Box>\n') % (couleur, couleur, titre, valeur, couleur_detail, detail)


panneau = ('  <!-- LVME : 4 KPI des commandes clients (calculés à l\'ouverture, action-lvme-cde-client-kpi) -->\n'
           '  <panel name="kpiCdeClientPanel" showTitle="false" colSpan="12">\n'
           + ''.join('    <field name="%s" type="string" hidden="true"/>\n' % k for k, _ in KPI)
           + '    <field name="$kpiCdeTuiles" showTitle="false" readonly="true" colSpan="12" type="string">\n'
           '      <viewer depends="%s"><![CDATA[\n' % ','.join(k for k, _ in KPI)
           + '        <>\n'
           '          <Box d="grid" style={{ gridTemplateColumns: \'repeat(4, 1fr)\', gap: 12 }}>\n'
           + tuile('Commandes en cours', '#0d6efd', '$kpiEnCours', '$kpiEnCoursDetail')
           + tuile('CA HT du mois', '#198754', '$kpiCaMois', '$kpiCaMoisDetail')
           + tuile('% Marge du mois', '#6f42c1', '$kpiMarge', '$kpiMargeDetail')
           + tuile("À livrer aujourd'hui", '#fd7e14', '$kpiALivrer', '$kpiRetard', '#dc3545')
           + '          </Box>\n'
           '        </>\n'
           '      ]]></viewer>\n'
           '    </field>\n'
           '  </panel>\n')

p = os.path.join(UI, 'commande-client-search-form.xml')
f = open(p, encoding='utf-8').read()
if 'kpiCdeClientPanel' not in f:
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

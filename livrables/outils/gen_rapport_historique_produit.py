"""Impression LVME de l'écran « Historique Produit » (GESCOM) : logo LVME en haut à gauche, bande lavande avec le
produit et la période, mouvements dans les colonnes de l'écran (lignes cyan clair / cyan), totaux dans des cases
bleues (Total colis, Stock Période, Poids Entrées, Poids Sorties).

Écrit axelor-supplychain/src/main/resources/reports/LvmeHistoriqueProduit.rptdesign (recompiler). Imprimé par le
bouton « Imprimer » de l'écran (LvmeHistoriqueProduitController.imprimer, PROD_84).
"""
import base64
import os
from xml.sax.saxutils import escape

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DST = os.path.join(RACINE, 'open-suite-webapp', 'modules', 'axelor-open-suite', 'axelor-supplychain', 'src', 'main',
                   'resources', 'reports', 'LvmeHistoriqueProduit.rptdesign')
LOGO = os.path.join(RACINE, 'open-suite-webapp', 'src', 'main', 'webapp', 'img', 'lvme-logo.png')

BLEU = '#3D3DBF'
LAVANDE = '#CFCFF5'
ENTETE = '#DBE3F3'
CYAN_CLAIR = '#C4F8F8'
CYAN = '#2EE6E6'
CASE_BLEUE = '#3D9BF0'
BORD = '#9DB3D6'

FILTRE = '''hp.product_id = ? AND hp.date_mvt BETWEEN CAST(? AS date) AND CAST(? AS date)'''

REQ_ENTETE = '''SELECT p.code AS produit_code, p.name AS produit_nom,
  to_char(CAST(? AS date), 'DD/MM/YYYY') AS du, to_char(CAST(? AS date), 'DD/MM/YYYY') AS au,
  COALESCE(t.colis, 0) AS total_colis, COALESCE(t.entrees, 0) AS poids_entrees, COALESCE(t.sorties, 0) AS poids_sorties,
  COALESCE(t.entrees, 0) - COALESCE(t.sorties, 0) AS stock_periode
FROM base_product p
LEFT JOIN LATERAL (SELECT sum(hp.nb_colis) AS colis, sum(hp.poids_entree) AS entrees, sum(hp.poids_sortie) AS sorties
  FROM lvme_historique_produit hp WHERE ''' + FILTRE + ''') t ON true
WHERE p.id = ?'''

REQ_LIGNES = '''SELECT hp.arrivage, hp.date_mvt, hp.lot_number, hp.libelle, hp.type_mvt, hp.ref_tiers, hp.prix_vente,
  hp.prix_revient, hp.poids_colis, hp.nb_colis, hp.poids_entree, hp.poids_sortie
FROM lvme_historique_produit hp
WHERE ''' + FILTRE + '''
ORDER BY hp.date_mvt, hp.id'''

# paramètres de chaque requête, dans l'ordre des « ? »
PARAMS_ENTETE = ['DateDu', 'DateAu', 'ProduitId', 'DateDu', 'DateAu', 'ProduitId']
PARAMS_LIGNES = ['ProduitId', 'DateDu', 'DateAu']

COLS_ENTETE = [('produit_code', 'string'), ('produit_nom', 'string'), ('du', 'string'), ('au', 'string'),
               ('total_colis', 'decimal'), ('poids_entrees', 'decimal'), ('poids_sorties', 'decimal'),
               ('stock_periode', 'decimal')]
COLS_LIGNES = [('arrivage', 'string'), ('date_mvt', 'date'), ('lot_number', 'string'), ('libelle', 'string'),
               ('type_mvt', 'string'), ('ref_tiers', 'string'), ('prix_vente', 'decimal'),
               ('prix_revient', 'decimal'), ('poids_colis', 'decimal'), ('nb_colis', 'decimal'),
               ('poids_entree', 'decimal'), ('poids_sortie', 'decimal')]

# colonnes de l'écran : (titre, colonne, largeur cm, format)
LIGNES = [
    ('Arrivage', 'arrivage', 1.7, None),
    ('Date', 'date_mvt', 1.7, 'date'),
    ('N° Lot', 'lot_number', 2.3, None),
    ('Libellé Mvts', 'libelle', 6.4, None),
    ('Type', 'type_mvt', 1.0, None),
    ('Référence Tiers', 'ref_tiers', 2.2, None),
    ('Prix Vente', 'prix_vente', 1.6, '#,##0.00'),
    ('Prix Revient', 'prix_revient', 1.6, '#,##0.00'),
    ('Poids du colis', 'poids_colis', 1.6, '#,##0'),
    ('Nb colis', 'nb_colis', 1.5, '#,##0'),
    ('Poids Entrées', 'poids_entree', 2.4, '#,##0.000'),
    ('Poids Sorties', 'poids_sortie', 2.4, '#,##0.000'),
]
SOMMES = ('nb_colis', 'poids_entree', 'poids_sortie')

_id = [1000]


def nid():
    _id[0] += 1
    return str(_id[0])


def prop(n, v):
    return '<property name="%s">%s</property>' % (n, escape(str(v)))


def bordure(couleur, epaisseur='0.5px'):
    return ''.join(prop('border%sStyle' % c, 'solid') + prop('border%sWidth' % c, epaisseur)
                   + prop('border%sColor' % c, couleur) for c in ('Top', 'Bottom', 'Left', 'Right'))


def padding(v='2px'):
    return ''.join(prop('padding%s' % c, v) for c in ('Top', 'Bottom', 'Left', 'Right'))


def fmt(f):
    if not f:
        return ''
    if f == 'date':
        return ('<structure name="dateTimeFormat">' + prop('category', 'Custom') + prop('pattern', 'dd/MM/yyyy')
                + '</structure>')
    return '<structure name="numberFormat">' + prop('category', 'Custom') + prop('pattern', f) + '</structure>'


def label(texte, couleur=None, taille='8pt', gras=False, align=None):
    s = '<label id="%s">' % nid() + prop('fontSize', taille)
    s += (prop('color', couleur) if couleur else '') + (prop('fontWeight', 'bold') if gras else '')
    s += prop('textAlign', align) if align else ''
    return s + '<text-property name="text">%s</text-property></label>' % escape(texte)


def data(col, f=None, taille='8pt', couleur=None, gras=False, align=None):
    s = '<data id="%s">' % nid() + prop('fontSize', taille)
    s += (prop('color', couleur) if couleur else '') + (prop('fontWeight', 'bold') if gras else '')
    s += prop('textAlign', align) if align else ''
    return s + fmt(f) + prop('resultSetColumn', col) + '</data>'


def cellule(contenu, style='', span=1):
    return '<cell id="%s">' % nid() + (prop('colSpan', span) if span > 1 else '') + style + contenu + '</cell>'


def grille(largeurs, lignes, style=''):
    s = '<grid id="%s">' % nid() + prop('width', '100%') + style
    s += ''.join('<column id="%s">%s</column>' % (nid(), prop('width', w) if w else '') for w in largeurs)
    s += ''.join('<row id="%s">' % nid() + ''.join(c) + '</row>' for c in lignes)
    return s + '</grid>'


def colonnes_liees(cols, extra=''):
    s = '<list-property name="boundDataColumns">'
    for nom, typ in cols:
        s += ('<structure>' + prop('name', nom) + '<expression name="expression" type="javascript">dataSetRow["%s"]'
              '</expression>' % nom + prop('dataType', typ) + '</structure>')
    return s + extra + '</list-property>'


def jeu(nom, requete, cols, params):
    ps = ''.join('<structure>' + prop('name', 'param_%d' % (i + 1)) + prop('paramName', p)
                 + prop('dataType', 'decimal' if p == 'ProduitId' else 'string')
                 + prop('nativeDataType', '-5' if p == 'ProduitId' else '12') + prop('position', i + 1)
                 + prop('isInput', 'true') + prop('isOutput', 'false') + '</structure>' for i, p in enumerate(params))
    rs = ''.join('<structure>' + prop('position', i + 1) + prop('name', c) + prop('dataType', t) + '</structure>'
                 for i, (c, t) in enumerate(cols))
    rs2 = ''.join('<structure>' + prop('position', i + 1) + prop('name', c) + prop('nativeName', c)
                  + prop('dataType', t) + '</structure>' for i, (c, t) in enumerate(cols))
    return ('<oda-data-set extensionID="org.eclipse.birt.report.data.oda.jdbc.JdbcSelectDataSet" name="%s" id="%s">'
            % (nom, nid()) + '<list-property name="parameters">' + ps + '</list-property>'
            + '<structure name="cachedMetaData"><list-property name="resultSet">' + rs + '</list-property></structure>'
            + prop('dataSource', 'Data Source') + '<list-property name="resultSet">' + rs2 + '</list-property>'
            + '<xml-property name="queryText"><![CDATA[%s]]></xml-property>' % requete + '</oda-data-set>')


def param(nom, typ='string', requis=False):
    return ('<scalar-parameter name="%s" id="%s">' % (nom, nid()) + prop('hidden', 'true')
            + prop('valueType', 'static') + (prop('isRequired', 'true') if requis else '') + prop('dataType', typ)
            + prop('distinct', 'true') + '<list-property name="selectionList"/>' + prop('paramType', 'simple')
            + prop('controlType', 'text-box') + '<structure name="format">' + prop('category', 'Unformatted')
            + '</structure></scalar-parameter>')


# ---------- en-tête : logo, titre, produit et période, totaux ----------
logo = ('<image id="%s">' % nid() + prop('height', '1.8cm') + prop('source', 'embed')
        + prop('imageName', 'lvme-logo.png') + '</image>')
entete = grille(['5cm', None, '6cm'], [[
    cellule(logo),
    cellule(label('Historique Produit', couleur=BLEU, taille='16pt', gras=True, align='center'),
            prop('verticalAlign', 'middle')),
    cellule(label('Document interne LVME', couleur='#808080', taille='7pt', align='right')),
]])
bande = grille(['2cm', '3cm', None, '2.4cm', '2.4cm', '0.8cm', '2.4cm'], [[
    cellule(label('Produit', couleur='#10204A')),
    cellule(data('produit_code', gras=True), bordure('#8C96A8') + prop('backgroundColor', '#FFFFFF') + padding()),
    cellule(data('produit_nom'), bordure('#8C96A8') + prop('backgroundColor', '#FFFFFF') + padding()),
    cellule(label('Entrée du', couleur='#10204A', align='right')),
    cellule(data('du'), bordure('#8C96A8') + prop('backgroundColor', '#FFFFFF') + padding()),
    cellule(label('au', couleur='#10204A', align='center')),
    cellule(data('au'), bordure('#8C96A8') + prop('backgroundColor', '#FFFFFF') + padding()),
]], prop('backgroundColor', LAVANDE) + padding('4px') + prop('marginTop', '4px'))


def case_bleue(lib, col, f):
    return [cellule(label(lib, couleur='#10204A', align='right'), prop('verticalAlign', 'middle') + padding()),
            cellule(data(col, f, gras=True, align='center'), prop('backgroundColor', CASE_BLEUE)
                    + bordure('#2A6FB5') + padding())]


totaux = grille([None, '2.6cm', None, '2.6cm', None, '2.6cm', None, '2.6cm'], [
    case_bleue('Total colis', 'total_colis', '#,##0') + case_bleue('Stock Période', 'stock_periode', '#,##0.000')
    + case_bleue('Poids Entrées', 'poids_entrees', '#,##0.000')
    + case_bleue('Poids Sorties', 'poids_sorties', '#,##0.000'),
], prop('backgroundColor', '#B9C7E6') + padding('4px') + prop('marginTop', '6px'))

liste_entete = ('<list id="%s">' % nid() + prop('dataSet', 'EnteteDS') + colonnes_liees(COLS_ENTETE)
                + '<detail>' + entete + bande + '</detail></list>')
liste_totaux = ('<list id="%s">' % nid() + prop('dataSet', 'EnteteDS') + colonnes_liees(COLS_ENTETE)
                + '<detail>' + totaux + '</detail></list>')

# ---------- mouvements ----------
CELL = bordure(BORD) + padding('1px')
tete = ''.join(cellule(label(t, taille='7pt', gras=True, couleur='#10204A', align='center'),
                       prop('backgroundColor', ENTETE) + CELL + prop('verticalAlign', 'bottom'))
               for t, _, _, _ in LIGNES)
detail = ''.join(cellule(data(col, f, taille='7pt', align='right' if f and f != 'date' else None), CELL)
                 for _, col, _, f in LIGNES)
couleurs = ('<list-property name="highlightRules">' + ''.join(
    '<structure>' + prop('operator', 'eq') + prop('backgroundColor', fond)
    + '<expression name="testExpr" type="javascript">row.__rownum % 2</expression>'
    + '<simple-property-list name="value1"><value type="javascript">%d</value></simple-property-list>' % reste
    + '</structure>' for reste, fond in ((0, CYAN_CLAIR), (1, CYAN))) + '</list-property>')
agregats = ''.join(
    '<structure>' + prop('name', 'total_' + c) + prop('dataType', 'decimal') + prop('aggregateFunction', 'SUM')
    + '<list-property name="arguments"><structure>' + prop('name', 'Expression')
    + '<expression name="value" type="javascript">row["%s"]</expression>' % c
    + '</structure></list-property>' + prop('allowExport', 'true') + '</structure>' for c in SOMMES)
pied = ''.join(cellule(data('total_' + col, f, taille='7pt', gras=True, align='right') if col in SOMMES else '',
                       CELL + prop('backgroundColor', ENTETE)) for _, col, _, f in LIGNES)
tableau = ('<table id="%s">' % nid() + prop('width', '100%') + prop('marginTop', '6px') + prop('dataSet', 'LignesDS')
           + colonnes_liees(COLS_LIGNES, agregats)
           + ''.join('<column id="%s">%s</column>' % (nid(), prop('width', '%scm' % w)) for _, _, w, _ in LIGNES)
           + '<header><row id="%s">%s</row></header>' % (nid(), tete)
           + '<detail><row id="%s">' % nid() + prop('backgroundColor', CYAN_CLAIR) + couleurs + detail
           + '</row></detail>'
           + '<footer><row id="%s">%s</row></footer>' % (nid(), pied) + '</table>')

LIAISONS = ''.join(
    '<structure>' + prop('name', n) + prop('id', '209')
    + '<expression name="value" type="javascript">params["%s"].value</expression></structure>' % p
    for n, p in (('odaURL', 'DBName'), ('odaUser', 'UserName'), ('odaPassword', 'Password'),
                 ('odaDriverClass', 'DefaultDriver')))
LOGO_B64 = base64.b64encode(open(LOGO, 'rb').read()).decode('ascii')

rapport = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<report xmlns="http://www.eclipse.org/birt/2005/design" version="3.2.23" id="1">'
           + '<list-property name="propertyBindings">' + LIAISONS + '</list-property>'
           + prop('units', 'cm') + prop('layoutPreference', 'auto layout')
           + '<parameters>' + param('ProduitId', 'decimal', True) + param('DateDu', 'string', True)
           + param('DateAu', 'string', True)
           + ''.join(param(p) for p in ('UserName', 'DBName', 'Password', 'DefaultDriver', 'AttachmentPath'))
           + '</parameters>'
           + '<data-sources><oda-data-source extensionID="org.eclipse.birt.report.data.oda.jdbc" name="Data Source" '
           'id="209">' + prop('odaDriverClass', 'org.postgresql.Driver')
           + prop('odaURL', 'jdbc:postgresql://localhost:5432/') + '</oda-data-source></data-sources>'
           + '<data-sets>' + jeu('EnteteDS', REQ_ENTETE, COLS_ENTETE, PARAMS_ENTETE)
           + jeu('LignesDS', REQ_LIGNES, COLS_LIGNES, PARAMS_LIGNES) + '</data-sets>'
           + '<page-setup><simple-master-page name="Simple MasterPage" id="2">' + prop('type', 'a4')
           + prop('orientation', 'landscape') + ''.join(prop(m, '0.8cm') for m in (
               'topMargin', 'leftMargin', 'bottomMargin', 'rightMargin'))
           + '<page-footer><grid id="%s">' % nid() + prop('width', '100%') + '<column id="%s"/>' % nid()
           + '<row id="%s"><cell id="%s">' % (nid(), nid()) + '<auto-text id="%s">' % nid()
           + prop('fontSize', '7pt') + prop('textAlign', 'right') + prop('type', 'page-number')
           + '</auto-text></cell></row></grid></page-footer></simple-master-page></page-setup>'
           + '<list-property name="images"><structure>' + prop('name', 'lvme-logo.png') + prop('type', 'image/png')
           + '<property name="data">%s</property>' % LOGO_B64 + '</structure></list-property>'
           + '<body>' + liste_entete + tableau + liste_totaux + '</body></report>\n')

open(DST, 'w', encoding='utf-8', newline='\n').write(rapport)
print('ok', DST, len(rapport))

"""Briques communes des impressions BIRT LVME en liste (logo LVME en haut à gauche, titre, filtres, tableau aux
couleurs GESCOM avec totaux). Utilisé par gen_rapports_listes.py."""
import base64
import os
import re
from xml.sax.saxutils import escape

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
REPORTS = os.path.join(RACINE, 'open-suite-webapp', 'modules', 'axelor-open-suite', 'axelor-supplychain', 'src', 'main',
                       'resources', 'reports')
LOGO = os.path.join(RACINE, 'open-suite-webapp', 'src', 'main', 'webapp', 'img', 'lvme-logo.png')
BLEU = '#3D3DBF'
BORD = '#B8B8B8'

_id = [1000]


def nid():
    _id[0] += 1
    return str(_id[0])


def prop(n, v):
    return '<property name="%s">%s</property>' % (n, escape(str(v)))


def bordure(couleur, epaisseur='0.5px'):
    return ''.join(prop('border%sStyle' % c, 'solid') + prop('border%sWidth' % c, epaisseur)
                   + prop('border%sColor' % c, couleur) for c in ('Top', 'Bottom', 'Left', 'Right'))


def padding(v='1px'):
    return ''.join(prop('padding%s' % c, v) for c in ('Top', 'Bottom', 'Left', 'Right'))


def fmt(f):
    if not f:
        return ''
    if f == 'date':
        return ('<structure name="dateTimeFormat">' + prop('category', 'Custom') + prop('pattern', 'dd/MM/yyyy')
                + '</structure>')
    return '<structure name="numberFormat">' + prop('category', 'Custom') + prop('pattern', f) + '</structure>'


def label(texte, couleur=None, taille='7pt', gras=False, align=None):
    s = '<label id="%s">' % nid() + prop('fontSize', taille)
    s += (prop('color', couleur) if couleur else '') + (prop('fontWeight', 'bold') if gras else '')
    s += prop('textAlign', align) if align else ''
    return s + '<text-property name="text">%s</text-property></label>' % escape(texte)


def data(col, f=None, taille='7pt', gras=False, align=None, couleur=None):
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


def requete(sql):
    """« :Nom » -> « ? » ; renvoie la requête et la liste des paramètres dans l'ordre des « ? »."""
    noms = re.findall(r':([A-Z][A-Za-z]*)', sql)
    return re.sub(r':[A-Z][A-Za-z]*', '?', sql), noms


def jeu(nom, sql, cols):
    q, noms = requete(sql)
    ps = ''.join('<structure>' + prop('name', 'param_%d' % (i + 1)) + prop('paramName', p) + prop('dataType', 'string')
                 + prop('nativeDataType', '12') + prop('position', i + 1) + prop('isInput', 'true')
                 + prop('isOutput', 'false') + '</structure>' for i, p in enumerate(noms))
    rs = ''.join('<structure>' + prop('position', i + 1) + prop('name', c) + prop('dataType', t) + '</structure>'
                 for i, (c, t) in enumerate(cols))
    rs2 = ''.join('<structure>' + prop('position', i + 1) + prop('name', c) + prop('nativeName', c)
                  + prop('dataType', t) + '</structure>' for i, (c, t) in enumerate(cols))
    return ('<oda-data-set extensionID="org.eclipse.birt.report.data.oda.jdbc.JdbcSelectDataSet" name="%s" id="%s">'
            % (nom, nid()) + '<list-property name="parameters">' + ps + '</list-property>'
            + '<structure name="cachedMetaData"><list-property name="resultSet">' + rs + '</list-property></structure>'
            + prop('dataSource', 'Data Source') + '<list-property name="resultSet">' + rs2 + '</list-property>'
            + '<xml-property name="queryText"><![CDATA[%s]]></xml-property>' % q + '</oda-data-set>'), set(noms)


def param(nom, typ='string'):
    return ('<scalar-parameter name="%s" id="%s">' % (nom, nid()) + prop('hidden', 'true')
            + prop('valueType', 'static') + prop('isRequired', 'false') + prop('dataType', typ) + prop('distinct', 'true')
            + '<list-property name="selectionList"/>' + prop('paramType', 'simple') + prop('controlType', 'text-box')
            + '<structure name="format">' + prop('category', 'Unformatted') + '</structure></scalar-parameter>')


def colonnes_liees(cols, extra=''):
    s = '<list-property name="boundDataColumns">'
    for nom, typ in cols:
        s += ('<structure>' + prop('name', nom) + '<expression name="expression" type="javascript">dataSetRow["%s"]'
              '</expression>' % nom + prop('dataType', typ) + '</structure>')
    return s + extra + '</list-property>'


def agregats(cols, fonction='SUM', prefixe='total_', groupe=None):
    s = ''
    for c in cols:
        s += ('<structure>' + prop('name', prefixe + c) + prop('dataType', 'decimal')
              + prop('aggregateFunction', fonction)
              + '<list-property name="arguments"><structure>' + prop('name', 'Expression')
              + '<expression name="value" type="javascript">row["%s"]</expression>' % c
              + '</structure></list-property>'
              + ('<simple-property-list name="aggregateOn"><value>%s</value></simple-property-list>' % groupe
                 if groupe else '')
              + prop('allowExport', 'true') + '</structure>')
    return s


def entete(titre, sous_titre_expr=None):
    """Logo LVME à gauche, titre bleu au centre, « Document interne LVME » et date d'impression à droite."""
    logo = ('<image id="%s">' % nid() + prop('height', '1.6cm') + prop('source', 'embed')
            + prop('imageName', 'lvme-logo.png') + '</image>')
    date = ('<text-data id="%s">' % nid() + prop('fontSize', '7pt') + prop('textAlign', 'right')
            + '<expression name="valueExpr">"Imprimé le " + new Date().toLocaleDateString("fr-FR")</expression>'
            + prop('contentType', 'plain') + '</text-data>')
    centre = label(titre, couleur=BLEU, taille='15pt', gras=True, align='center')
    if sous_titre_expr:
        centre += ('<text-data id="%s">' % nid() + prop('fontSize', '8pt') + prop('textAlign', 'center')
                   + prop('color', '#10204A') + '<expression name="valueExpr">%s</expression>' % escape(sous_titre_expr)
                   + prop('contentType', 'plain') + '</text-data>')
    return grille(['5cm', None, '6cm'], [[
        cellule(logo),
        cellule(centre, prop('verticalAlign', 'middle')),
        cellule(label('Document interne LVME', couleur='#808080', align='right') + date),
    ]])


def tableau(dataset, cols_ds, colonnes, couleurs, entete_style, sommes=(), groupe=None, extra_ligne=''):
    """colonnes : (titre, colonne, largeur cm, format, fond de cellule ou None) ; couleurs : (fond ligne paire,
    fond ligne impaire) ; groupe : (colonne de groupe, libellé de la ligne de totaux, couleur, sommes du groupe[,
    colonnes de la ligne d'en-tête du groupe]) : avec ces colonnes, chaque groupe commence par une ligne d'en-tête
    (comme les arrivages de la Synthèse GESCOM) et elles restent vides sur les lignes de détail[, colonnes reprises
    telles quelles sur la ligne de totaux[, colonnes reprises sur la ligne de totaux et vides sur les lignes de
    détail (ex. rang du produit)]]."""
    tete_g = groupe[4] if groupe and len(groupe) > 4 else ()
    vals_g = groupe[5] if groupe and len(groupe) > 5 else ()
    seul_total_g = groupe[6] if groupe and len(groupe) > 6 else ()
    vals_g = tuple(vals_g) + tuple(seul_total_g)
    tete_g = tuple(tete_g)
    vide_detail = tete_g + tuple(seul_total_g)
    cell = bordure('#C8C8C8') + padding()
    tete = ''.join(cellule(label(t, taille='6.5pt', gras=True, couleur='#10204A', align='center'),
                           entete_style + cell + prop('verticalAlign', 'bottom')) for t, _, _, _, _ in colonnes)
    detail = ''.join(cellule('' if c in vide_detail else data(c, f, taille='6.5pt',
                                                          align='right' if f and f != 'date' else None),
                             cell + (prop('backgroundColor', fond) if fond else '')) for _, c, _, f, fond in colonnes)
    regles = ('<list-property name="highlightRules">' + ''.join(
        '<structure>' + prop('operator', 'eq') + prop('backgroundColor', fond)
        + '<expression name="testExpr" type="javascript">row.__rownum % 2</expression>'
        + '<simple-property-list name="value1"><value type="javascript">%d</value></simple-property-list>' % reste
        + '</structure>' for reste, fond in ((0, couleurs[0]), (1, couleurs[1]))) + '</list-property>')
    agg = agregats(sommes)
    groupes = ''
    if groupe:
        col_g, lib_g, fond_g, sommes_g = groupe[:4]
        agg += agregats(sommes_g, prefixe='grp_', groupe='groupe')
        pied_g = ''
        for i, (_, c, _, f, _) in enumerate(colonnes):
            if c in vals_g:
                contenu = data(c, f, taille='6.5pt', gras=True, align='right' if f and f != 'date' else None)
            elif i == 0 and not tete_g:
                contenu = data(col_g, taille='6.5pt', gras=True)
            elif i == (0 if tete_g else 1):
                contenu = label(lib_g, taille='6.5pt', gras=True)
            elif c in sommes_g:
                contenu = data('grp_' + c, f, taille='6.5pt', gras=True, align='right')
            else:
                contenu = ''
            pied_g += cellule(contenu, cell + prop('backgroundColor', fond_g))
        en_tete_g = ''
        if tete_g:
            en_tete_g = '<header><row id="%s">%s</row></header>' % (nid(), ''.join(
                cellule(data(c, f, taille='6.5pt', gras=True) if c in tete_g else '', cell + prop('backgroundColor', '#FFFFFF'))
                for _, c, _, f, _ in colonnes))
        groupes = ('<group id="%s">' % nid() + prop('groupName', 'groupe')
                   + '<expression name="keyExpr" type="javascript">row["%s"]</expression>' % col_g
                   + en_tete_g + '<footer><row id="%s">%s</row></footer></group>' % (nid(), pied_g))
    pied = ''.join(cellule(data('total_' + c, f, taille='6.5pt', gras=True, align='right') if c in sommes else '',
                           cell + entete_style) for _, c, _, f, _ in colonnes)
    return ('<table id="%s">' % nid() + prop('width', '100%') + prop('marginTop', '4px') + prop('dataSet', dataset)
            + colonnes_liees(cols_ds, agg)
            + ''.join('<column id="%s">%s</column>' % (nid(), prop('width', '%scm' % w)) for _, _, w, _, _ in colonnes)
            + '<header><row id="%s">%s</row></header>' % (nid(), tete)
            + groupes
            + '<detail><row id="%s">' % nid() + regles + extra_ligne + detail + '</row></detail>'
            + '<footer><row id="%s">%s</row></footer>' % (nid(), pied) + '</table>')


def rapport(fichier, params, jeux, corps):
    """Assemble et écrit le rptdesign (A4 paysage, logo intégré, connexion passée par Axelor)."""
    liaisons = ''.join(
        '<structure>' + prop('name', n) + prop('id', '209')
        + '<expression name="value" type="javascript">params["%s"].value</expression></structure>' % p
        for n, p in (('odaURL', 'DBName'), ('odaUser', 'UserName'), ('odaPassword', 'Password'),
                     ('odaDriverClass', 'DefaultDriver')))
    logo_b64 = base64.b64encode(open(LOGO, 'rb').read()).decode('ascii')
    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<report xmlns="http://www.eclipse.org/birt/2005/design" version="3.2.23" id="1">'
           + '<list-property name="propertyBindings">' + liaisons + '</list-property>'
           + prop('units', 'cm') + prop('layoutPreference', 'auto layout')
           + '<parameters>' + ''.join(param(p) for p in sorted(params))
           + ''.join(param(p) for p in ('UserName', 'DBName', 'Password', 'DefaultDriver', 'AttachmentPath'))
           + '</parameters>'
           + '<data-sources><oda-data-source extensionID="org.eclipse.birt.report.data.oda.jdbc" name="Data Source" '
           'id="209">' + prop('odaDriverClass', 'org.postgresql.Driver')
           + prop('odaURL', 'jdbc:postgresql://localhost:5432/') + '</oda-data-source></data-sources>'
           + '<data-sets>' + ''.join(jeux) + '</data-sets>'
           + '<page-setup><simple-master-page name="Simple MasterPage" id="2">' + prop('type', 'a4')
           + prop('orientation', 'landscape') + ''.join(prop(m, '0.7cm') for m in (
               'topMargin', 'leftMargin', 'bottomMargin', 'rightMargin'))
           + '<page-footer><grid id="%s">' % nid() + prop('width', '100%') + '<column id="%s"/>' % nid()
           + '<row id="%s"><cell id="%s">' % (nid(), nid()) + '<auto-text id="%s">' % nid()
           + prop('fontSize', '7pt') + prop('textAlign', 'right') + prop('type', 'page-number')
           + '</auto-text></cell></row></grid></page-footer></simple-master-page></page-setup>'
           + '<list-property name="images"><structure>' + prop('name', 'lvme-logo.png') + prop('type', 'image/png')
           + '<property name="data">%s</property>' % logo_b64 + '</structure></list-property>'
           + '<body>' + corps + '</body></report>\n')
    chemin = os.path.join(REPORTS, fichier)
    open(chemin, 'w', encoding='utf-8', newline='\n').write(xml)
    print('ok', chemin, len(xml))

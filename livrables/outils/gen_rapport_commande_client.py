"""Impression LVME de la commande client (document interne), copie de la fiche Commande client :
logo LVME en haut à gauche, cadre Client (bordure bleue), cadre Commande (libellés violets), statut et cadre des
totaux gris, puis tableau des lignes dans l'ordre des colonnes de la fiche (lignes blanc / cyan, Colis Cdes et
Nb unités ou Poids cdés jaune pâle, Prix Vente jaune vif).

Écrit axelor-sale/src/main/resources/reports/LvmeCommandeClient.rptdesign (recompiler). Le modèle d'impression
« LVME Commande client » (PROD_78) pointe sur ce fichier.
"""
import base64
import os
from xml.sax.saxutils import escape

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DST = os.path.join(RACINE, 'open-suite-webapp', 'modules', 'axelor-open-suite', 'axelor-sale', 'src', 'main',
                   'resources', 'reports', 'LvmeCommandeClient.rptdesign')

BLEU = '#3D3DBF'
VIOLET = '#8B1A8B'
BLEU_STATUT = '#1A1AD6'
GRIS_CASE = '#E6E6E6'
GRIS_BORD = '#B8B8B8'
CYAN = '#CCFFFF'
JAUNE_PALE = '#FFFFC0'
JAUNE = '#FFFF00'
ENTETE_LIGNES = '#DBE8FB'

REQ_ENTETE = '''SELECT so.sale_order_seq, so.status_select, so.creation_date, so.estimated_delivery_date, so.external_reference,
  so.internal_note, so.cout_port_kg, so.port_paye, so.is_reservation, so.remise_facture, so.tauxrfa,
  so.lvme_frais_congelation, so.taux_commission, so.ex_tax_total, so.tax_total, so.in_tax_total, so.margin_rate,
  so.total_gross_margin,
  cli.partner_seq AS client_code, COALESCE(cli.simple_full_name, cli.name) AS client_nom, cli.fixed_phone AS client_tel,
  adr.addressl4 AS address_l4, adr.addressl5 AS address_l5, adr.zip, city.name AS ville, pays.name AS pays,
  grp.name AS groupement, COALESCE(com_p.full_name, com_u.name) AS commercial, ctc.simple_full_name AS contact,
  pm.name AS reglement, pc.name AS echeance, COALESCE(op_p.full_name, op_u.name) AS operateur,
  COALESCE(prep_p.full_name, prep_u.name) AS preparateur, car.simple_full_name AS transporteur,
  co.name AS societe, logo.file_path AS logo_path,
  COALESCE(lig.nb_colis, 0) AS nb_colis, COALESCE(lig.poids, 0) AS poids,
  CASE WHEN so.port_paye THEN 0 ELSE COALESCE(lig.poids, 0) * COALESCE(so.cout_port_kg, 0) END AS port_ht,
  CASE WHEN so.port_paye THEN 0 ELSE COALESCE(lig.poids, 0) * COALESCE(so.cout_port_kg, 0) * 0.20 END AS port_tva
FROM sale_sale_order so
LEFT JOIN base_partner cli ON cli.id = so.client_partner
LEFT JOIN base_address adr ON adr.id = so.main_invoicing_address
LEFT JOIN base_city city ON city.id = adr.city
LEFT JOIN base_country pays ON pays.id = adr.country
LEFT JOIN sale_groupement grp ON grp.id = cli.groupement
LEFT JOIN auth_user com_u ON com_u.id = so.commercial
LEFT JOIN base_partner com_p ON com_p.id = com_u.partner
LEFT JOIN base_partner ctc ON ctc.id = so.contact_partner
LEFT JOIN account_payment_mode pm ON pm.id = so.payment_mode
LEFT JOIN account_payment_condition pc ON pc.id = so.payment_condition
LEFT JOIN auth_user op_u ON op_u.id = so.salesperson_user
LEFT JOIN base_partner op_p ON op_p.id = op_u.partner
LEFT JOIN auth_user prep_u ON prep_u.id = so.lvme_preparateur
LEFT JOIN base_partner prep_p ON prep_p.id = prep_u.partner
LEFT JOIN base_partner car ON car.id = so.carrier_partner
LEFT JOIN base_company co ON co.id = so.company
LEFT JOIN meta_file logo ON logo.id = co.logo
LEFT JOIN LATERAL (SELECT sum(l.nb_colis) AS nb_colis, sum(l.poids_total_net) AS poids
  FROM sale_sale_order_line l WHERE l.sale_order = so.id) lig ON true
WHERE so.id = ?'''

REQ_LIGNES = '''SELECT p.code AS reference, l.product_name AS designation,
  (SELECT string_agg(DISTINCT replace(to_char(tl.value, 'FM990.00'), '.', ','), ', ') FROM sale_sale_order_line_tax_line_set s
    JOIN account_tax_line tl ON tl.id = s.tax_line_set WHERE s.sale_sale_order_line = l.id) AS taux_tva,
  lot.arrivages, lot.fournisseurs, lot.origines, lot.frigos, l.estimated_delivery_date AS date_livraison, lot.lots,
  lot.ddm, l.nb_unites_par_colis, lot.prix_achat, es.colis_rsv, es.colis_dispo, l.nb_colis, u.name AS unite,
  l.poids_total_net, l.qty, l.prix_revient, l.price_discounted, l.lvme_promo, l.ex_tax_total, l.sub_margin_rate,
  l.sub_total_gross_margin
FROM sale_sale_order_line l
LEFT JOIN base_product p ON p.id = l.product
LEFT JOIN base_unit u ON u.id = l.unit
LEFT JOIN LATERAL (
  SELECT string_agg(DISTINCT sm.stock_move_seq, ', ') AS arrivages, string_agg(DISTINCT pa.partner_seq, ', ') AS fournisseurs,
    string_agg(DISTINCT sml.origine, ', ') AS origines, string_agg(DISTINCT loc.name, ', ') AS frigos,
    string_agg(DISTINCT t.tracking_number_seq, ', ') AS lots, min(sml.dluo) AS ddm,
    round(max(sml.unit_price_untaxed), 4) AS prix_achat
  FROM supplychain_sale_order_line_lot x
  JOIN stock_tracking_number t ON t.id = x.tracking_number
  LEFT JOIN stock_stock_move_line sml ON sml.id = t.origin_stock_move_line
  LEFT JOIN stock_stock_move sm ON sm.id = sml.stock_move
  LEFT JOIN base_partner pa ON pa.id = sm.partner
  LEFT JOIN stock_stock_location loc ON loc.id = sml.to_stock_location
  WHERE x.sale_order_line = l.id) lot ON true
LEFT JOIN LATERAL (
  SELECT round(COALESCE(sum(e.nb_colis_cdes), 0), 3) AS colis_rsv,
    round(COALESCE(sum(e.nb_colis_stock - e.nb_colis_cdes), 0), 3) AS colis_dispo
  FROM lvme_etat_stock_lot e
  WHERE e.tracking_number_id IN (SELECT x.tracking_number FROM supplychain_sale_order_line_lot x
    WHERE x.sale_order_line = l.id)) es ON true
WHERE l.sale_order = ?
ORDER BY l.sequence, l.id'''

COLS_ENTETE = [
    ('sale_order_seq', 'string'), ('status_select', 'integer'), ('creation_date', 'date'),
    ('estimated_delivery_date', 'date'), ('external_reference', 'string'), ('internal_note', 'string'),
    ('cout_port_kg', 'decimal'), ('port_paye', 'boolean'), ('is_reservation', 'boolean'),
    ('remise_facture', 'decimal'), ('tauxrfa', 'decimal'), ('lvme_frais_congelation', 'decimal'),
    ('taux_commission', 'decimal'), ('ex_tax_total', 'decimal'), ('tax_total', 'decimal'),
    ('in_tax_total', 'decimal'), ('margin_rate', 'decimal'), ('total_gross_margin', 'decimal'),
    ('client_code', 'string'), ('client_nom', 'string'), ('client_tel', 'string'), ('address_l4', 'string'),
    ('address_l5', 'string'), ('zip', 'string'), ('ville', 'string'), ('pays', 'string'), ('groupement', 'string'),
    ('commercial', 'string'), ('contact', 'string'), ('reglement', 'string'), ('echeance', 'string'),
    ('operateur', 'string'), ('preparateur', 'string'), ('transporteur', 'string'), ('societe', 'string'),
    ('logo_path', 'string'), ('nb_colis', 'decimal'), ('poids', 'decimal'), ('port_ht', 'decimal'),
    ('port_tva', 'decimal')]

COLS_LIGNES = [
    ('reference', 'string'), ('designation', 'string'), ('taux_tva', 'string'), ('arrivages', 'string'),
    ('fournisseurs', 'string'), ('origines', 'string'), ('frigos', 'string'), ('date_livraison', 'date'),
    ('lots', 'string'), ('ddm', 'date'), ('nb_unites_par_colis', 'decimal'), ('prix_achat', 'decimal'),
    ('colis_rsv', 'decimal'), ('colis_dispo', 'decimal'), ('nb_colis', 'decimal'), ('unite', 'string'),
    ('poids_total_net', 'decimal'), ('qty', 'decimal'), ('prix_revient', 'decimal'), ('price_discounted', 'decimal'),
    ('lvme_promo', 'boolean'), ('ex_tax_total', 'decimal'), ('sub_margin_rate', 'decimal'),
    ('sub_total_gross_margin', 'decimal')]

# colonnes du tableau des lignes : (titre, colonne, largeur cm, format, fond)
NB2 = '#,##0.00'
NB3 = '#,##0.000'
LIGNES = [
    ('Référence', 'reference', 1.4, None, None),
    ('Désignation', 'designation', 3.2, None, None),
    ('Taux TVA', 'taux_tva', 0.8, None, None),
    ('Numéro Arrivage', 'arrivages', 1.5, None, None),
    ('Fourn.', 'fournisseurs', 1.0, None, None),
    ('Ori.', 'origines', 0.8, None, None),
    ('Frigo', 'frigos', 1.1, None, None),
    ('Date Livraison', 'date_livraison', 1.3, 'date', None),
    ('N° Lot', 'lots', 1.5, None, None),
    ('D.D.M.', 'ddm', 1.3, 'date', None),
    ('Unt/Pds du Colis', 'nb_unites_par_colis', 0.9, NB3, None),
    ('Prix Achat', 'prix_achat', 1.0, NB2, None),
    ('Colis Rsv', 'colis_rsv', 0.8, '#,##0', None),
    ('Colis Dispo', 'colis_dispo', 0.9, '#,##0', None),
    ('Colis Cdes', 'nb_colis', 0.9, '#,##0', JAUNE_PALE),
    ('Unité Vente', 'unite', 0.8, None, None),
    ('Poids en KG', 'poids_total_net', 1.0, NB3, None),
    ('Nb unités ou Poids cdés', 'qty', 1.1, NB3, JAUNE_PALE),
    ('Prix Revient', 'prix_revient', 1.0, '#,##0.0000', None),
    ('Prix Vente', 'price_discounted', 1.0, NB2, JAUNE),
    ('Promo', 'promo_txt', 0.8, None, None),
    ('Montant', 'ex_tax_total', 1.3, NB2, None),
    ('% Marge', 'sub_margin_rate', 0.9, NB2, None),
    ('Marge', 'sub_total_gross_margin', 1.1, NB2, None),
]

_id = [1000]


def nid():
    _id[0] += 1
    return str(_id[0])


def prop(n, v):
    return '<property name="%s">%s</property>' % (n, escape(str(v)))


def bordure(couleur, epaisseur='1px'):
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
    return ('<structure name="numberFormat">' + prop('category', 'Custom') + prop('pattern', f)
            + '</structure>')


def label(texte, couleur=None, taille='8pt', gras=False, align=None):
    s = '<label id="%s">' % nid() + prop('fontSize', taille)
    if couleur:
        s += prop('color', couleur)
    if gras:
        s += prop('fontWeight', 'bold')
    if align:
        s += prop('textAlign', align)
    return s + '<text-property name="text">%s</text-property></label>' % escape(texte)


def data(col, f=None, taille='8pt', couleur=None, gras=False, align=None, extra=''):
    s = '<data id="%s">' % nid() + prop('fontSize', taille)
    if couleur:
        s += prop('color', couleur)
    if gras:
        s += prop('fontWeight', 'bold')
    if align:
        s += prop('textAlign', align)
    s += fmt(f) + extra + prop('resultSetColumn', col)
    return s + '</data>'


def cellule(contenu, style='', span=1):
    s = '<cell id="%s">' % nid()
    if span > 1:
        s += prop('colSpan', span)
    return s + style + contenu + '</cell>'


def grille(largeurs, lignes, style=''):
    s = '<grid id="%s">' % nid() + prop('width', '100%') + style
    for w in largeurs:
        s += '<column id="%s">%s</column>' % (nid(), prop('width', w) if w else '')
    for cellules in lignes:
        s += '<row id="%s">' % nid() + ''.join(cellules) + '</row>'
    return s + '</grid>'


def colonnes_liees(cols, calculees=()):
    s = '<list-property name="boundDataColumns">'
    for nom, typ in cols:
        s += ('<structure>' + prop('name', nom) + '<expression name="expression" type="javascript">dataSetRow["%s"]'
              '</expression>' % nom + prop('dataType', typ) + '</structure>')
    for nom, typ, expr in calculees:
        s += ('<structure>' + prop('name', nom) + '<expression name="expression" type="javascript">%s</expression>'
              % escape(expr) + prop('dataType', typ) + '</structure>')
    return s + '</list-property>'


def jeu(nom, ident, requete, cols):
    rs = ''.join('<structure>' + prop('position', i + 1) + prop('name', c) + prop('dataType', t) + '</structure>'
                 for i, (c, t) in enumerate(cols))
    rs2 = ''.join('<structure>' + prop('position', i + 1) + prop('name', c) + prop('nativeName', c)
                  + prop('dataType', t) + '</structure>' for i, (c, t) in enumerate(cols))
    return ('<oda-data-set extensionID="org.eclipse.birt.report.data.oda.jdbc.JdbcSelectDataSet" name="%s" id="%s">'
            % (nom, ident)
            + '<list-property name="parameters"><structure>' + prop('name', 'param_1')
            + prop('paramName', 'SaleOrderId') + prop('dataType', 'decimal') + prop('nativeDataType', '-5')
            + prop('position', 1) + prop('isInput', 'true') + prop('isOutput', 'false') + '</structure></list-property>'
            + '<structure name="cachedMetaData"><list-property name="resultSet">' + rs + '</list-property></structure>'
            + prop('dataSource', 'Data Source')
            + '<list-property name="resultSet">' + rs2 + '</list-property>'
            + '<xml-property name="queryText"><![CDATA[%s]]></xml-property>' % requete
            + '</oda-data-set>')


def param(nom, typ='string', requis=False):
    return ('<scalar-parameter name="%s" id="%s">' % (nom, nid()) + prop('hidden', 'true')
            + prop('valueType', 'static') + (prop('isRequired', 'true') if requis else '')
            + prop('dataType', typ) + prop('distinct', 'true') + '<list-property name="selectionList"/>'
            + prop('paramType', 'simple') + prop('controlType', 'text-box')
            + '<structure name="format">' + prop('category', 'Unformatted') + '</structure></scalar-parameter>')


# ---------- en-tête : logo, titre ----------
STATUTS = ('({1: "Devis brouillon", 2: "Devis finalisé", 3: "Commande confirmée", 4: "Commande terminée", '
           '5: "Annulé"})[dataSetRow["status_select"]] || ""')
OUI_NON = '(dataSetRow["%s"] ? "Oui" : "Non")'
CALC_ENTETE = [
    ('titre', 'string', '"Commande client N° " + (dataSetRow["sale_order_seq"] || "")'),
    ('statut', 'string', STATUTS),
    ('client', 'string', '(dataSetRow["client_code"] || "") + " - " + (dataSetRow["client_nom"] || "")'),
    ('reservation_txt', 'string', OUI_NON % 'is_reservation'),
    ('port_paye_txt', 'string', OUI_NON % 'port_paye'),
]

# logo LVME de l'application (img/lvme-logo.png) intégré au modèle : imprimé même sans logo sur la fiche société
LOGO = os.path.join(RACINE, 'open-suite-webapp', 'src', 'main', 'webapp', 'img', 'lvme-logo.png')
LOGO_B64 = base64.b64encode(open(LOGO, 'rb').read()).decode('ascii')
logo = ('<image id="%s">' % nid() + prop('height', '1.8cm') + prop('source', 'embed')
        + prop('imageName', 'lvme-logo.png') + '</image>')
entete = grille(['5cm', None, '6cm'], [[
    cellule(logo),
    cellule(data('titre', taille='16pt', couleur=BLEU, gras=True, align='center')),
    cellule(label('Document interne LVME', couleur='#808080', taille='7pt', align='right')
            + data('societe', taille='9pt', gras=True, align='right')),
]])


def lib_val(lib, col, f=None, couleur_lib=None):
    return [cellule(label(lib, couleur=couleur_lib or '#505050', taille='7.5pt'), prop('verticalAlign', 'middle')),
            cellule(data(col, f), prop('verticalAlign', 'middle'))]


bloc_client = grille(['2.2cm', None, '2.4cm', None], [
    lib_val('Client', 'client') + lib_val('Commercial', 'commercial'),
    lib_val('Adresse', 'address_l4') + lib_val('contact', 'contact'),
    [cellule(''), cellule(data('address_l5'))] + lib_val('Téléphone', 'client_tel'),
    lib_val('Code postal', 'zip') + lib_val('Règlement', 'reglement'),
    lib_val('Ville', 'ville') + lib_val('Echéance', 'echeance'),
    lib_val('Code pays', 'pays') + lib_val('% Rem/Fact.', 'remise_facture', '#,##0.00'),
    lib_val('Groupement', 'groupement') + lib_val('% RFA', 'tauxrfa', '#,##0.00'),
    lib_val('% Frais Cong.', 'lvme_frais_congelation', '#,##0.00')
    + lib_val('% Frais Commission', 'taux_commission', '#,##0.00'),
], bordure(BLEU, '2px') + padding('4px'))

commentaire = ('<text-data id="%s">' % nid() + prop('fontSize', '8pt')
               + '<expression name="valueExpr">row["internal_note"] || ""</expression>'
               + prop('contentType', 'html') + '</text-data>')
bloc_commande = grille(['2.4cm', None, '2.4cm', None], [
    lib_val('Commande N°', 'sale_order_seq', couleur_lib=VIOLET) + lib_val('Préparateur', 'preparateur',
                                                                          couleur_lib=VIOLET),
    lib_val('Opérateur', 'operateur', couleur_lib=VIOLET) + lib_val('Date Commande', 'creation_date', 'date',
                                                                   couleur_lib=VIOLET),
    lib_val('Réservation', 'reservation_txt', couleur_lib=VIOLET) + lib_val('Date Livraison',
                                                                           'estimated_delivery_date', 'date',
                                                                           couleur_lib=VIOLET),
    lib_val('Ref Cde', 'external_reference', couleur_lib=VIOLET) + lib_val('Transporteur', 'transporteur',
                                                                          couleur_lib=VIOLET),
    lib_val('Coût port/kg', 'cout_port_kg', '#,##0.0000', couleur_lib=VIOLET) + lib_val('Port Payé',
                                                                                       'port_paye_txt',
                                                                                       couleur_lib=VIOLET),
    [cellule(label('< Commentaire >', couleur=VIOLET, taille='7.5pt'), prop('verticalAlign', 'top')),
     cellule(commentaire, bordure(GRIS_BORD) + padding('2px'), span=3)],
], padding('4px'))

blocs = grille(['15cm', '0.4cm', None], [[cellule(bloc_client), cellule(''), cellule(bloc_commande)]])


def case_totale(lib, col, f):
    return [cellule(label(lib, taille='7.5pt', align='right'), padding('2px') + prop('verticalAlign', 'middle')),
            cellule(data(col, f, align='right'), prop('backgroundColor', GRIS_CASE) + bordure(GRIS_BORD)
                    + padding('2px') + prop('verticalAlign', 'middle'))]


totaux = grille([None, '1.8cm', None, '1.8cm', None, '2cm', None, '2cm'], [
    case_totale('Nb Colis', 'nb_colis', '#,##0') + case_totale('Port HT', 'port_ht', NB2)
    + case_totale('Total TTC', 'in_tax_total', NB2) + case_totale('% Marge Totale', 'margin_rate', NB2),
    case_totale('Poids', 'poids', '#,##0.0') + case_totale('Port TVA', 'port_tva', NB2)
    + case_totale('Total HT', 'ex_tax_total', NB2) + case_totale('Total marge', 'total_gross_margin', NB2),
], prop('backgroundColor', '#F2F2F2') + bordure(GRIS_BORD))
ligne_totaux = grille([None, '15cm'], [[
    cellule(data('statut', taille='11pt', couleur=BLEU_STATUT, align='center'), prop('verticalAlign', 'middle')),
    cellule(totaux)]])

liste_entete = ('<list id="%s">' % nid() + prop('dataSet', 'EnteteDS') + colonnes_liees(COLS_ENTETE, CALC_ENTETE)
                + '<detail>' + entete + blocs + ligne_totaux + '</detail></list>')

# ---------- tableau des lignes ----------
CALC_LIGNES = [('promo_txt', 'string', '(dataSetRow["lvme_promo"] ? "Oui" : "")')]
CELL_BORD = bordure('#9DB3D6', '0.5px') + padding('1px')
tete = ''.join(cellule(label(t, taille='6.5pt', gras=True), prop('backgroundColor', ENTETE_LIGNES) + CELL_BORD
                       + prop('verticalAlign', 'bottom')) for t, _, _, _, _ in LIGNES)
detail = ''
for t, col, w, f, fond in LIGNES:
    align = 'right' if f and f != 'date' else None
    style = CELL_BORD + (prop('backgroundColor', fond) if fond else '')
    detail += cellule(data(col, f, taille='7pt', align=align), style)
cyan = ('<list-property name="highlightRules"><structure>' + prop('operator', 'eq')
        + prop('backgroundColor', CYAN)
        + '<expression name="testExpr" type="javascript">row.__rownum % 2</expression>'
        + '<simple-property-list name="value1"><value type="javascript">1</value></simple-property-list>'
        + '</structure></list-property>')
SOMMES = ('nb_colis', 'poids_total_net', 'qty', 'ex_tax_total', 'sub_total_gross_margin')
agregats = ''.join(
    '<structure>' + prop('name', 'total_' + c) + prop('dataType', 'decimal') + prop('aggregateFunction', 'SUM')
    + '<list-property name="arguments"><structure>' + prop('name', 'Expression')
    + '<expression name="value" type="javascript">row["%s"]</expression>' % c
    + '</structure></list-property>' + prop('allowExport', 'true') + '</structure>' for c in SOMMES)
pied = ''
for t, col, w, f, fond in LIGNES:
    contenu = data('total_' + col, f, taille='7pt', gras=True, align='right') if col in SOMMES else ''
    pied += cellule(contenu, CELL_BORD + prop('backgroundColor', '#F2F2F2'))
colonnes = colonnes_liees(COLS_LIGNES, CALC_LIGNES).replace('</list-property>', agregats + '</list-property>')
tableau = ('<table id="%s">' % nid() + prop('width', '100%') + prop('marginTop', '6px') + prop('dataSet', 'LignesDS')
           + colonnes
           + ''.join('<column id="%s">%s</column>' % (nid(), prop('width', '%scm' % w)) for _, _, w, _, _ in LIGNES)
           + '<header><row id="%s">%s</row></header>' % (nid(), tete)
           + '<detail><row id="%s">%s%s</row></detail>' % (nid(), cyan, detail)
           + '<footer><row id="%s">%s</row></footer>' % (nid(), pied)
           + '</table>')

# ---------- rapport ----------
LIAISONS = ''.join(
    '<structure>' + prop('name', n) + prop('id', '209')
    + '<expression name="value" type="javascript">params["%s"].value</expression></structure>' % p
    for n, p in (('odaURL', 'DBName'), ('odaUser', 'UserName'), ('odaPassword', 'Password'),
                 ('odaDriverClass', 'DefaultDriver')))

rapport = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<report xmlns="http://www.eclipse.org/birt/2005/design" version="3.2.23" id="1">'
           + '<list-property name="propertyBindings">' + LIAISONS + '</list-property>'
           + prop('units', 'cm') + prop('layoutPreference', 'auto layout')
           + '<parameters>' + param('SaleOrderId', 'decimal', True)
           + ''.join(param(p) for p in ('UserName', 'DBName', 'Password', 'DefaultDriver', 'AttachmentPath'))
           + '</parameters>'
           + '<data-sources><oda-data-source extensionID="org.eclipse.birt.report.data.oda.jdbc" name="Data Source" '
           'id="209">' + prop('odaDriverClass', 'org.postgresql.Driver')
           + prop('odaURL', 'jdbc:postgresql://localhost:5432/') + '</oda-data-source></data-sources>'
           + '<data-sets>' + jeu('EnteteDS', nid(), REQ_ENTETE, COLS_ENTETE) + jeu('LignesDS', nid(), REQ_LIGNES,
                                                                                 COLS_LIGNES) + '</data-sets>'
           + '<page-setup><simple-master-page name="Simple MasterPage" id="2">' + prop('type', 'a4')
           + prop('orientation', 'landscape') + ''.join(prop(m, '0.8cm') for m in (
               'topMargin', 'leftMargin', 'bottomMargin', 'rightMargin'))
           + '<page-footer><grid id="%s">' % nid() + prop('width', '100%') + '<column id="%s"/>' % nid()
           + '<row id="%s"><cell id="%s">' % (nid(), nid())
           + '<auto-text id="%s">' % nid() + prop('fontSize', '7pt') + prop('textAlign', 'right')
           + prop('type', 'page-number') + '</auto-text></cell></row></grid></page-footer>'
           + '</simple-master-page></page-setup>'
           + '<list-property name="images"><structure>' + prop('name', 'lvme-logo.png')
           + prop('type', 'image/png') + '<property name="data">%s</property>' % LOGO_B64
           + '</structure></list-property>'
           + '<body>' + liste_entete + tableau + '</body></report>\n')

open(DST, 'w', encoding='utf-8', newline='\n').write(rapport)
print('ok', DST, len(rapport))

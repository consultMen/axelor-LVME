"""Construit livrables/ui/ligne-commande-client-form.xml : fiche Ligne de commande client copiée sur la
fenêtre « Lignes Commandes » de GESCOM, à partir de la fiche Axelor assemblée sale-order-line-form
(livrables/ui/origine/sale-order-line-form-computed.xml). Publiée en fiche admin sale-order-line-form
(priorité 30) par PROD_64.

  bloc GESCOM (fond bleu) : article, désignation, gencode, nom scientifique ; n° arrivage, frigo, congélation,
  conditionnement, coef ; n° lot, origine, D.L.U.O., marque, colis/palette ; frais de stockage, % RFA,
  zone pêche, colis/couche, prix promo ; puis les quantités et les prix (cases de saisie jaunes)
  boutons à droite : Historique Lot, Commandes/Lot, Commandes/Art., Sélect Arrivage, F1 : Historique Prix
  dessous, inchangés : lots disponibles, lots sélectionnés, arrivages, réservations stocks, stock physique…
  onglets inchangés (livraison, facturation, analytique, budget, blocages)
Aucun champ retiré : tout ce qui n'est pas dans le bloc GESCOM reste à sa place.
Usage : python livrables/outils/gen_ligne_commande_client_gescom.py   (depuis la racine du dépôt)
"""
import os
import re

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(RACINE, 'livrables', 'ui', 'origine', 'sale-order-line-form-computed.xml')
DST = os.path.join(RACINE, 'livrables', 'ui', 'ligne-commande-client-form.xml')

x = open(SRC, encoding='utf-8').read().replace('\r\n', '\n').replace('\r', '')
x = re.sub(r'\n[ \t]*\n', '\n', x)
A = r'(?:[^>"]|"[^"]*")'


def blk(name, tag='panel', within=None):
    s = x if within is None else within
    m = re.search(r'<' + tag + r'\b(?=' + A + r'*?\sname="' + re.escape(name) + r'")', s)
    assert m, name
    i = m.start()
    one = re.match(r'<' + tag + r'\b' + A + r'*?/>', s[i:])
    if one:
        return one.group(0)
    depth = 0
    for t in re.finditer(r'<(/?)' + tag + r'\b' + A + r'*?(/?)>', s[i:]):
        if t.group(1):
            depth -= 1
        elif not t.group(2):
            depth += 1
        if depth == 0:
            return s[i:i + t.end()]
    raise AssertionError(name)


def el(name, within):
    pat = re.compile(r'<(field|button)\b(?=' + A + r'*?\sname="' + re.escape(name) + r'")' + A + r'*?(/>|>.*?</\1>)', re.S)
    found = [m.group(0) for m in pat.finditer(within)]
    assert len(found) == 1, (name, len(found))
    return found[0]


def seta(e, attr, val):
    head = re.match(r'<[\w-]+\b' + A + r'*', e).group(0)
    if re.search(r'\s%s="[^"]*"' % attr, head):
        new = re.sub(r'(\s)%s="[^"]*"' % attr, lambda m: m.group(1) + '%s="%s"' % (attr, val), head, count=1)
    else:
        new = re.sub(r'^<([\w-]+)', lambda m: '<%s %s="%s"' % (m.group(1), attr, val), head, count=1)
    return e.replace(head, new, 1)


def dela(e, attr):
    head = re.match(r'<[\w-]+\b' + A + r'*', e).group(0)
    return e.replace(head, re.sub(r'\s%s="[^"]*"' % attr, '', head), 1)


info = blk('informationsPanel')
reste = info  # ce qui n'est pas repris dans le bloc GESCOM reste en place, dans l'ordre d'origine
pris = {}


def prendre(name, cs, title=None, css=None):
    global reste
    e = el(name, reste)
    reste = reste.replace(e, '', 1)
    e = seta(e, 'colSpan', cs)
    if title is not None:
        e = seta(e, 'title', title)
    if css:
        e = seta(e, 'css', css)
    if name == 'priceDiscounted':  # P.V - Rem. : caché par Axelor, affiché comme dans GESCOM
        e = dela(e, 'hidden')
    pris[name] = e
    return '        ' + e


def ro(name, title, cs, extra=''):
    return '        <field name="%s" title="%s" readonly="true" colSpan="%s"%s/>' % (name, title, cs, extra)


# ligne 1 : le panneau Axelor de l'article (badges, article, désignation, gel des champs) gardé tel quel,
# avec Gencode et Nom Scientifique ajoutés au bout
prod = blk('productInfoPanel', within=info)
reste = reste.replace(prod, '', 1)
prod_new = prod
for e in re.findall(r'<field\b(?=' + A + r'*?\sname="product")' + A + r'*?/>', prod):
    prod_new = prod_new.replace(e, seta(seta(e, 'colSpan', '3'), 'title', 'Article'), 1)
pn = el('productName', prod)
prod_new = prod_new.replace(pn, seta(seta(pn, 'colSpan', '5'), 'title', ''), 1)
fin = prod_new.rindex('</panel>')
prod_new = (prod_new[:fin]
            + '  <field name="product.gencode" title="Gencode" readonly="true" colSpan="2"/>\n'
            + '        <field name="product.nomScientifique" title="Nom Scientifique" readonly="true" colSpan="2"/>\n      '
            + prod_new[fin:])
prod_new = seta(prod_new, 'colSpan', '12')

Q = 'lvme-case'  # cases de saisie jaunes de GESCOM
QV = 'lvme-case lvme-cde-violet'  # case jaune à libellé violet (Nb Colis Commandés, Qtes Commandées, Prix Vente)
bloc = '\n'.join([
    '      <!-- LVME : copie de la fenêtre « Lignes Commandes » GESCOM -->',
    '      <panel name="lvmeLigneCdeGescomPanel" colSpan="10" css="lvme-cde-client">',
    '        ' + prod_new,
    ro('lvmeArrivages', 'N° Arrivage', 2),
    ro('lvmeFrigo', 'Frigo', 3),
    ro('lvmeDateCongelation', 'Congélation', 2),
    prendre('conditionnement', 4, 'Conditionnement'),
    prendre('coefPoidsNet', 1, 'Coef.'),
    ro('lvmeLots', 'N° Lot', 2),
    ro('lvmeOrigine', 'Origine', 3),
    ro('lvmeDdm', 'D.L.U.O.', 2),
    ro('lvmeMarque', 'Marque', 3),
    ro('lvmeColisPalette', 'Nb Colis / Palette', 2),
    prendre('fraisCongelation', 2, 'Frais de Stockage'),
    prendre('tauxRFA', 3, '% RFA sur Produits'),
    ro('lvmeZonePeche', 'Zone pêche', 3),
    ro('lvmeColisCouche', 'Colis / Couche', 2),
    '        <field name="lvmePromo" title="Prix Promo" colSpan="2"/>',
    '        <!-- ligne du bas GESCOM, même ordre : Taux TVA, quantités puis prix (2 lignes de 12 colonnes) -->',
    prendre('taxLineSet', 2, 'Taux TVA'),
    prendre('nbUnitesParColis', 2, 'Nb unités ou Poids du Colis'),
    ro('lvmeColisRsv', 'Nb Colis Réservé', 1),
    ro('lvmeColisDispo', 'Nb Colis Dispo', 1),
    prendre('nbColis', 2, 'Nb Colis Commandés', QV),
    ro('lvmeQteDispo', 'Qtes Dispo', 1),
    prendre('qty', 2, 'Qtes Commandées', QV),
    prendre('unit', 1, ' ', Q),
    prendre('poidsTotalNet', 2, 'Poids en Kg'),
    prendre('prixRevient', 2, 'Prix Revient'),
    prendre('price', 2, 'Prix Vente', QV),
    prendre('inTaxPrice', 2, 'Prix Vente', QV),  # à la place de Prix Vente quand la commande est en TTC
    prendre('exTaxTotal', 2, 'Montant HT'),
    prendre('priceDiscounted', 1, 'P.V - Rem.'),
    prendre('prixRevientNet', 1, 'P.R. net'),
    prendre('subMarginRate', 2, '% Marge'),
    '      </panel>',
    '',
    '      <panel name="lvmeLigneCdeBoutonsPanel" colSpan="2" itemSpan="12">',
    '        <button name="lvmeHistoriqueLotBtn" title="Historique lot" icon="clock-history" showIf="saleOrderLineLotList &amp;&amp; saleOrderLineLotList.length" onClick="action-lvme-ligne-cde-historique-lot"/>',
    '        <button name="lvmeCdesClientLotBtn" title="Commandes/Lot" icon="cart" showIf="saleOrderLineLotList &amp;&amp; saleOrderLineLotList.length" onClick="action-lvme-ligne-cde-cdes-client-lot"/>',
    '        <button name="lvmeCdesClientProduitBtn" title="Commandes/Art." icon="cart-fill" showIf="product" onClick="action-lvme-ligne-cdes-client-produit"/>',
    '        <button name="lvmeSelectArrivageBtn" title="Sélect Arrivage" icon="truck" showIf="product" onClick="action-view-sale-order-line-add-arrivage"/>',
    '        <button name="lvmeHistoriquePrixBtn" title="F1 : Historique Prix" icon="clock" css="btn-warning" showIf="product" onClick="action-lvme-ligne-cde-historique-prix"/>',
    '      </panel>',
])

# le reste du panneau (colis, réservation, stocks, lots, arrivages…) reste dessous, dans l'ordre d'origine
reste_head = re.match(r'<panel\b' + A + r'*?>', reste).group(0)
reste_corps = reste[len(reste_head):reste.rindex('</panel>')]
info_new = (seta(seta(reste_head, 'title', 'Ligne'), 'css', 'lvme-gescom-fond') + '\n' + bloc + '\n' + reste_corps + '</panel>')
out = x.replace(info, info_new, 1)
out = out.replace('title="SO line"', 'title="Ligne de commande"', 1)
open(DST, 'w', encoding='utf-8', newline='\r\n').write(out)
print('ok', DST, len(out), 'champs repris :', len(pris))

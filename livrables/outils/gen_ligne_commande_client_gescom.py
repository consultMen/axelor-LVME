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
    prod_new = prod_new.replace(e, seta(seta(seta(e, 'colSpan', '2'), 'title', 'Article'), 'target-name', 'code'), 1)
pn = el('productName', prod)
prod_new = prod_new.replace(pn, seta(seta(pn, 'colSpan', '4'), 'title', ''), 1)
# oldQty (champ technique caché) prenait 6 colonnes et renvoyait Gencode / Nom Scientifique à la ligne :
# repoussé à la fin du panneau ; Article, désignation, Gencode et Nom Scientifique sur une seule ligne
oq = el('oldQty', prod_new)
prod_new = prod_new.replace(oq, '', 1)
# « Figer les champs » et « Type » n'existent pas dans GESCOM : sortis de la ligne 1, remis à la fin du bloc
deplaces = []
for nom in ('enableFreezeFields', 'typeSelect'):
    e = el(nom, prod_new)
    prod_new = prod_new.replace(e, '', 1)
    deplaces.append('        ' + seta(e, 'colSpan', '2'))
fin = prod_new.rindex('</panel>')
prod_new = (prod_new[:fin]
            + '  <field name="product.gencode" title="Gencode" readonly="true" colSpan="3"/>\n'
            + '        <field name="product.nomScientifique" title="Nom Scientifique" readonly="true" colSpan="3"/>\n'
            + '        ' + oq + '\n      '
            + prod_new[fin:])
prod_new = seta(prod_new, 'colSpan', '12')

# Taux TVA affiché en chiffre comme GESCOM (5,50) dans la ligne du bas ($tauxTva, calculé par
# action-lvme-ligne-cde-taux-tva) ; le champ TVA d'Axelor reste modifiable plus bas, avec Figer les champs et Type
TVA = 'action-lvme-ligne-cde-taux-tva'


def ajout_onchange(e, action):
    if re.search(r'\sonChange="', e):
        return re.sub(r'(\sonChange=")([^"]*)"', lambda m: m.group(1) + m.group(2) + ',' + action + '"', e, count=1)
    return seta(e, 'onChange', action)


deplaces.append(ajout_onchange(prendre('taxLineSet', 2, 'Taux TVA'), TVA))
Q = 'lvme-case'  # cases de saisie jaunes de GESCOM
QV = 'lvme-case lvme-cde-violet'  # case jaune à libellé violet (Nb Colis Commandés, Qtes Commandées, Prix Vente)
bloc = '\n'.join([
    '      <!-- LVME : copie de la fenêtre « Lignes Commandes » GESCOM -->',
    '      <panel name="lvmeLigneCdeGescomPanel" colSpan="10" css="lvme-cde-client lvme-ligne-cde lvme-compact">',
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
    prendre('tauxRFA', 2, '% RFA sur Produits'),
    prendre('tauxCommission', 2, '% Commission'),  # à côté de % RFA (PROD_77)
    ro('lvmeZonePeche', 'Zone pêche', 2),
    ro('lvmeColisCouche', 'Colis / Couche', 2),
    '        <field name="lvmePromo" title="Prix Promo" colSpan="2"/>',
    '        <!-- ligne du bas GESCOM sur une seule ligne, même ordre, chaque case encadrée (css lvme-ligne-bas :',
    '             grille de 14 colonnes au lieu de 12) -->',
    '        <panel name="lvmeLigneBasPanel" colSpan="12" css="lvme-ligne-bas">',
    '        <field name="$tauxTva" title="Taux TVA" type="decimal" readonly="true" x-scale="2" colSpan="1"/>',
    prendre('nbUnitesParColis', 1, 'Nb unités ou Poids du Colis'),
    ro('lvmeColisRsv', 'Nb Colis Réservé', 1),
    ro('lvmeColisDispo', 'Nb Colis Dispo', 1),
    prendre('nbColis', 1, 'Nb Colis Commandés', QV),
    ro('lvmeQteDispo', 'Qtes Dispo', 1),
    prendre('qty', 1, 'Qtes Commandées', QV),
    prendre('unit', 1, ' ', Q),
    prendre('poidsTotalNet', 1, 'Poids en Kg'),
    prendre('prixRevient', 1, 'Prix Revient'),
    prendre('price', 1, 'Prix Vente', QV),
    prendre('inTaxPrice', 1, 'Prix Vente', QV),  # à la place de Prix Vente quand la commande est en TTC
    prendre('exTaxTotal', 1, 'Montant HT'),
    prendre('priceDiscounted', 1, 'P.V - Rem.'),
    prendre('prixRevientNet', 1, 'P.R. net'),
    prendre('subMarginRate', 1, '% Marge'),
    '        </panel>',
] + deplaces + [
    '      </panel>',
    '',
    '      <panel name="lvmeLigneCdeBoutonsPanel" colSpan="2" itemSpan="12" css="lvme-ligne-cde lvme-compact">',
    '        <button name="lvmeHistoriqueLotBtn" title="Historique Lot" css="lvme-btn-gris" onClick="action-lvme-ligne-cde-historique-lot"/>',
    '        <button name="lvmeCdesClientLotBtn" title="Commandes/Lot" css="lvme-btn-gris" onClick="action-lvme-ligne-cde-cdes-client-lot"/>',
    '        <button name="lvmeCdesClientProduitBtn" title="Commandes/Art." css="lvme-btn-gris" showIf="product" onClick="action-lvme-ligne-cdes-client-produit"/>',
    # Sélect Arrivage : bouton comme GESCOM ; il ouvre la « Sélection Arrivage » (arrivages / lots de l'article) par le
    # sélecteur du champ caché $selArrivage (js/lvme.js) ; le lot choisi est ajouté aux lots sélectionnés de la ligne
    # (action-lvme-ligne-cde-group-sel-arrivage, PROD_66)
    '        <button name="lvmeSelectArrivageBtn" title="Sélect Arrivage" css="lvme-btn-lilas" showIf="product" onClick="action-lvme-ligne-cde-sel-arrivage-vider"/>',
    '        <field name="$selArrivage" title="Sélection Arrivage" type="many-to-one" target="com.axelor.apps.supplychain.db.EtatStockLot" target-name="lotNumber" css="lvme-sel-arrivage-cache" canNew="false" canEdit="false" canView="false" grid-view="lvme-selection-arrivage-grid" domain="self.product = :product AND self.lotArchive IS NOT TRUE" onChange="action-lvme-ligne-cde-group-sel-arrivage"/>',
    '        <button name="lvmeHistoriquePrixBtn" title="F1 : Historique Prix" css="lvme-btn-orange" showIf="product" onClick="action-lvme-ligne-cde-historique-prix"/>',
    '      </panel>',
])

# le reste du panneau (colis, réservation, stocks, lots, arrivages…) reste dessous, dans l'ordre d'origine
# panneau « Conditionnement / Colis » : absent de GESCOM, ses champs utiles sont dans le bloc GESCOM ; masqué
# (pas supprimé : poids par colis, poids net et qté sachet restent dans la ligne pour les calculs)
colis = blk('colisPanel', within=reste)
reste = reste.replace(colis, seta(dela(colis, 'showIf'), 'hidden', 'true'), 1)
# description et commentaire de production : après les panneaux personnalisés (lots, arrivages, stocks…)
fin_panneaux = []
for nom in ('descriptionPanel', 'lineProductionCommentPanel'):
    b = blk(nom, within=reste)
    reste = reste.replace(b, '', 1)
    fin_panneaux.append('      ' + b)
k = reste.rindex('</panel>')
reste = reste[:k] + '\n'.join(fin_panneaux) + '\n    ' + reste[k:]
reste_head = re.match(r'<panel\b' + A + r'*?>', reste).group(0)
reste_corps = reste[len(reste_head):reste.rindex('</panel>')]
info_new = (seta(seta(reste_head, 'title', 'Ligne'), 'css', 'lvme-gescom-fond') + '\n' + bloc + '\n' + reste_corps + '</panel>')
out = x.replace(info, info_new, 1)
out = out.replace('title="SO line"', 'title="Lignes Commandes"', 1)
# css lvme-ligne-cde : fenêtre en pleine largeur, fond bleu GESCOM (lvme.css)
out = re.sub(r'^<form\b', '<form css="lvme-ligne-cde"', out, count=1)
# Taux TVA (chiffre) recalculé à l'ouverture et au choix de l'article
out = re.sub(r'^(<form\b[^>]*?\sonLoad=")([^"]*)"', lambda m: m.group(1) + m.group(2) + ',' + TVA + '"', out, count=1)
# changement d'article : lots sélectionnés, valeurs du lot et prix revient remis à zéro AVANT les calculs de
# l'article (comme GESCOM) ; puis Taux TVA en chiffre
REINIT = 'action-lvme-ligne-cde-reinit-article,action-method-sale-order-line-persist-lot-selection'
for e in re.findall(r'<field\b(?=' + A + r'*?\sname="product")' + A + r'*?/>', out):
    e2 = re.sub(r'(\sonChange=")', lambda m: m.group(1) + REINIT + ',', e, count=1)
    out = out.replace(e, ajout_onchange(e2, TVA), 1)
# valeurs du lot (N° Lot, Arrivage, Frigo, Congélation, Origine, D.L.U.O., Marque, Zone pêche, colis…) remplies dès
# le choix du lot, comme GESCOM, sans attendre l'enregistrement de la ligne
for e in re.findall(r'<panel-related\b(?=' + A + r'*?\sfield="saleOrderLineLotList")' + A + r'*?/?>', out):
    out = out.replace(e, ajout_onchange(e, 'action-lvme-ligne-cde-valeurs-lot'), 1)
open(DST, 'w', encoding='utf-8', newline='\r\n').write(out)
print('ok', DST, len(out), 'champs repris :', len(pris))

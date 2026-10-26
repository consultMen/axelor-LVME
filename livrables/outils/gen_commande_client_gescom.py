"""Construit livrables/ui/commande-client-form.xml : fiche Commande client copiée sur la « Fiche Commande
client » GESCOM, à partir de la fiche admin sale-order-form (priorité 30) d'origine
(livrables/ui/origine/sale-order-form-p30-avant-PROD63.xml).

  en haut   : Client (encadré bleu) | Commande | boutons
  dessous   : cadre des totaux (Nb Colis, Poids, Total HT, Total TTC, % Marge Totale, Total marge)
  puis      : le tableau des lignes de commande (remonté de l'onglet « Contenu »)
  en bas    : les onglets (Contenu, Réservation, Livraison, Paramètres, Taxes, Facturation… Suivi)
Barre de statuts conservée ; plus de barre latérale ; aucun champ retiré.
Usage : python livrables/outils/gen_commande_client_gescom.py   (depuis la racine du dépôt)
"""
import os
import re

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(RACINE, 'livrables', 'ui', 'origine', 'sale-order-form-p30-avant-PROD63.xml')
DST = os.path.join(RACINE, 'livrables', 'ui', 'commande-client-form.xml')
SOMME = 'action-lvme-commande-client-attrs-somme'

x = open(SRC, encoding='utf-8').read().replace('\r\n', '\n').replace('\r', '')
x = re.sub(r'\n[ \t]*\n', '\n', x)
A = r'(?:[^>"]|"[^"]*")'


def blk(name, tag='panel', extra='', within=None):
    s = x if within is None else within
    m = re.search(r'<' + tag + r'\b(?=' + A + r'*?\sname="' + re.escape(name) + r'"' + extra + r')', s)
    assert m, name
    i = m.start()
    if re.match(r'<' + tag + r'\b' + A + r'*?/>', s[i:]):
        return re.match(r'<' + tag + r'\b' + A + r'*?/>', s[i:]).group(0)
    depth = 0
    for t in re.finditer(r'<(/?)' + tag + r'\b' + A + r'*?(/?)>', s[i:]):
        if t.group(1):
            depth -= 1
        elif not t.group(2):
            depth += 1
        if depth == 0:
            return s[i:i + t.end()]
    raise AssertionError(name)


def els(name, within):
    pat = re.compile(r'<(field|button)\b(?=' + A + r'*?\sname="' + re.escape(name) + r'")' + A + r'*?(/>|>.*?</\1>)', re.S)
    found = [m.group(0) for m in pat.finditer(within)]
    assert found, name
    return found


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


def F(e, cs, title=None, ind='        '):
    e = seta(e, 'colSpan', cs)
    if title is not None:
        e = seta(e, 'title', title)
    return ind + e


def ro(name, title, cs, extra=''):
    return '        <field name="%s" title="%s" readonly="true" colSpan="%s"%s/>' % (name, title, cs, extra)


main = blk('mainPanel')
tabs = blk('mainPanelTab', 'panel-tabs')
head_form = x[:x.index('<panel name="mainPanel"')]
mail = blk('mailPanel', 'panel-mail')
client = blk('lvmeClientPanel')
cde = blk('lvmeCommandePanel')
resa = blk('lvmeReservationPanel')
livr = blk('lvmeLivraisonPanel')
devise = blk('lvmeDevisePanel')
general = blk('generalInfoPanel')
details = blk('detailsPanel')
actions = blk('actionsPanel')
intax = blk('inTaxTotalPanel')
margin = blk('marginPanel')
side_names = ['globalDiscountPanel', 'salesFollowUpPanel', 'characteristicsPanel', 'referencePanel', 'datesPanel']
sides = {n: (blk(n, extra=' title="Dates"') if n == 'datesPanel' else blk(n)) for n in side_names}
other_infos = blk('otherInfosPanel')
attrs_panel = blk('attrsPanel')
content = blk('contentPanel')

# haut Axelor (blocage encours, statuts, n°) gardé tel quel, puis badges de livraison / facturation
top = main[main.index('>') + 1:main.index(details)]
entre = main[main.index(details) + len(details):main.index(devise)]
entre_fields = re.findall(r'<field\b' + A + r'*?(?:/>|>.*?</field>)', entre, re.S)
info_client = els('clientPartner.saleOrderInformation', main)[0]

c1 = lambda n: els(n, client)[0]
d1 = lambda n: els(n, cde)[0]

# ---------- bloc Client (encadré bleu), deux colonnes comme GESCOM ----------
adr = els('mainInvoicingAddress', client)[0]
client_new = '\n'.join([
    '    <panel name="lvmeClientPanel" colSpan="6" css="lvme-cde-client lvme-gescom-box">',
    '      <panel name="lvmeClientGauche" colSpan="6" itemSpan="12" showTitle="false">',
    F(c1('clientPartner'), 12, 'Client'),
    F(adr, 12, 'Adresse'),
    ro('mainInvoicingAddress.addressL4', 'Adresse', 12, ' showIf="mainInvoicingAddress"'),
    ro('mainInvoicingAddress.addressL5', '', 12, ' showIf="mainInvoicingAddress.addressL5"'),
    ro('mainInvoicingAddress.zip', 'Code postal', 4),
    ro('mainInvoicingAddress.city.name', 'Ville', 8),
    ro('mainInvoicingAddress.country', 'Code pays', 12),
    F(c1('clientPartner.groupement'), 12, 'Groupement'),
    '      </panel>',
    '      <panel name="lvmeClientDroite" colSpan="6" itemSpan="12" showTitle="false">',
    F(c1('commercial'), 12, 'Commercial'),
    F(c1('contactPartner'), 12, 'contact'),
    F(c1('clientPartner.fixedPhone'), 12, 'Téléphone'),
    F(c1('paymentMode'), 12, 'Règlement'),
    F(c1('paymentCondition'), 12, 'Echéance'),
    F(c1('remiseFacture'), 6, '% Rem/Fact.'),
    F(c1('tauxRFA'), 6, '% RFA'),
    '        <field name="lvmeFraisCongelation" title="% Frais Cong." colSpan="6"/>',
    F(c1('tauxCommission'), 6, '% Frais Commission'),
    '      </panel>',
    '    </panel>'])

# ---------- bloc Commande ----------
resa_case = dela(els('isReservation', resa)[0], 'widget')
cde_new = '\n'.join([
    '    <panel name="lvmeCommandePanel" colSpan="4" itemSpan="6" css="lvme-cde-client lvme-cde-violet">',
    '        <field name="saleOrderSeq" title="Commande N°" readonly="true" colSpan="6"/>',
    '        <field name="lvmePreparateur" title="Préparateur" colSpan="6" canNew="false" canEdit="false" canView="false"/>',
    F(d1('salespersonUser'), 4, 'Opérateur'),
    F(d1('creationDate'), 4, 'Date Commande'),
    F(d1('estimatedDeliveryDate'), 4, 'Date Livraison'),
    F(resa_case, 4, 'Réservation'),
    F(d1('externalReference'), 8, 'Ref Cde'),
    F(d1('carrierPartner'), 8, 'Transporteur'),
    F(d1('portPaye'), 4, 'Port Payé'),
    # commentaire sur toute la largeur du cadre, coût du port juste dessous (comme GESCOM)
    F(seta(d1('internalNote'), 'height', '2'), 12, '&lt; Commentaire &gt;'),
    F(d1('coutPortKg'), 4, 'Coût port/kg'),
    '    </panel>'])

# ---------- boutons (ancienne barre latérale) à droite, en premier Imprimer commande ----------
act_buttons = re.findall(r'<button\b' + A + r'*?/>', actions, re.S)
act_fields = re.findall(r'<field\b' + A + r'*?/>', actions, re.S)
boutons = '\n'.join(
    ['    <panel name="actionsPanel" colSpan="2" itemSpan="12">',
     '      <button name="lvmeFermerBtn" title="Fermer" icon="x-circle" css="btn-danger" onClick="close"/>',
     '      <button name="lvmeImprimerCommandeBtn" title="Imprimer commande" icon="printer" '
     'showIf="id" onClick="save,action-sale-order-view-reports-wizard"/>']
    + ['      ' + (seta(b, 'title', 'Confirmation Commande') if 'name="confirmOrderBtn"' in b else b) for b in act_buttons] + ['      ' + f for f in act_fields] + ['    </panel>'])

# ---------- cadre des totaux, gris comme GESCOM ----------
NUM = '(+%s || 0).toLocaleString("fr-FR", { minimumFractionDigits: %d, maximumFractionDigits: %d })'
CASE = ('style={{ background: "#e6e6e6", border: "1px solid #b8b8b8", textAlign: "right", padding: "1px 6px", '
        'minWidth: 62 }}')
LIB = 'style={{ paddingLeft: 8, paddingRight: 4, whiteSpace: "nowrap", textAlign: "right", fontSize: 12 }}'


def paire(lib, var, dec):
    return '<td %s>%s</td><td %s>{%s}</td>' % (LIB, lib, CASE, NUM % (var, dec, dec))


totaux = '''    <panel name="lvmeTotauxPanel" colSpan="12">
      <field name="statusSelect" showTitle="false" readonly="true" colSpan="3" css="lvme-cde-statut">
        <viewer depends="statusSelect"><![CDATA[<>{$fmt("statusSelect")}</>]]></viewer>
      </field>
      <field name="$lvmeTotaux" type="string" showTitle="false" readonly="true" colSpan="9">
        <viewer depends="$sommeColis,$sommePoids,$portHt,$portTva,exTaxTotal,inTaxTotal,marginRate,totalGrossMargin"><![CDATA[
          <>
            <table style={{ borderCollapse: "separate", borderSpacing: 3, fontSize: 13, border: "1px solid #b8b8b8", background: "#f4f4f4", marginLeft: "auto" }}>
              <tbody>
                <tr>%s%s%s%s</tr>
                <tr>%s%s%s%s</tr>
              </tbody>
            </table>
          </>
        ]]></viewer>
      </field>
      <field name="$sommeColis" type="decimal" hidden="true"/>
      <field name="$sommePoids" type="decimal" hidden="true"/>
      <field name="$portHt" type="decimal" hidden="true"/>
      <field name="$portTva" type="decimal" hidden="true"/>
    </panel>''' % (paire('Nb Colis', '$sommeColis', 0), paire('Port HT', '$portHt', 2), paire('Total TTC', 'inTaxTotal', 2),
                   paire('% Marge Totale', 'marginRate', 2),
                   paire('Poids', '$sommePoids', 1), paire('Port TVA', '$portTva', 2), paire('Total HT', 'exTaxTotal', 2),
                   paire('Total marge', 'totalGrossMargin', 2))

# ---------- lignes : remontées de l'onglet Contenu, juste sous l'en-tête ----------
lignes = [blk(n, tag) for n, tag in [('displayMultiLinesButtonPanel', 'panel'), ('detailLinesPanel', 'panel-related'),
                                      ('saleOrderLineEditableTreePanel', 'panel-related'),
                                      ('editableDetailLinesPanel', 'panel-related')]]


def onchange(t):
    if not t.startswith('<panel-related'):
        return t
    head = re.match(r'<panel-related\b' + A + r'*?/?>', t).group(0)
    if 'onChange="' in head:
        new = re.sub(r'onChange="([^"]*)"', lambda q: 'onChange="%s,%s"' % (q.group(1), SOMME), head, count=1)
    else:
        new = head.replace('<panel-related ', '<panel-related onChange="%s" ' % SOMME, 1)
    new = seta(new, 'title', 'Lignes commande') if 'title="' in new else new
    if 'css="' not in new:
        new = new.replace('<panel-related ', '<panel-related css="lvme-gescom-grid lvme-cde-grid" ', 1)
    return t.replace(head, new, 1)


lignes_xml = '\n'.join('  ' + onchange(t) for t in lignes)
content_reste = content
for t in lignes:
    content_reste = content_reste.replace(t, '')

# ---------- onglets : Contenu (sans les lignes), puis Réservation / Livraison / Paramètres, puis le reste ----------
resa_tab = re.sub(r'\s*<field\b(?=' + A + r'*?\sname="isReservation")' + A + r'*?/>', '', resa, count=1)
resa_tab = dela(dela(seta(resa_tab, 'colSpan', '12'), 'canCollapse'), 'collapseIf')
livr_tab = dela(dela(seta(livr, 'colSpan', '12'), 'canCollapse'), 'collapseIf')
param_tab = ('    <panel name="lvmeParametresPanel" title="Paramètres">\n'
             + ''.join('      ' + f + '\n' for f in entre_fields)
             + '      ' + devise + '\n      ' + general + '\n    </panel>')
suivi = ['    <!-- LVME : ancienne barre latérale -->', '    <panel name="lvmeSuiviPanel" title="Suivi">']
for n in side_names + ['marginPanel']:
    p = sides.get(n) or margin
    for a in ['sidebar', 'hideIf', 'canCollapse', 'collapseIf']:
        p = dela(p, a)
    suivi.append('      ' + seta(p, 'colSpan', '6'))
suivi.append('    </panel>')
content_reste = seta(content_reste, 'title', 'Commentaire')
resa_tab = seta(resa_tab, 'showIf', 'isReservation')
tabs = tabs.replace(content, content_reste + '\n    ' + resa_tab + '\n' + param_tab, 1)
# livraison LVME (tiers livré, adresse, frigo, dates…) en tête de l'onglet Livraison d'Axelor
delivery = blk('deliveryInformationPanel', within=tabs)
d_head = re.match(r'<panel\b' + A + r'*?>', delivery).group(0)
livr_in = dela(seta(livr_tab, 'showTitle', 'false'), 'title')
tabs = tabs.replace(delivery, delivery.replace(d_head, d_head + '\n      ' + livr_in, 1), 1)
tabs = tabs[:tabs.rindex('</panel-tabs>')] + '\n'.join(suivi) + '\n  </panel-tabs>'

# ---------- champs techniques ----------
intax_fields = re.findall(r'<field\b' + A + r'*?/>', intax, re.S)
tech = ('  <panel name="lvmeTechPanel" hidden="true" colSpan="12">\n'
        + ''.join('    ' + dela(f, 'hidden') + '\n' for f in intax_fields if 'name="inTaxTotal"' not in f)
        + '    <field name="inTaxTotal"/>\n'
        + ''.join('    ' + dela(dela(e, 'hideIf'), 'showIf') + '\n' for e in els('mainInvoicingAddressStr', client))
        + '  </panel>\n')

new_main = ('  <!-- LVME : copie de la « Fiche Commande client » GESCOM : Client | Commande | boutons, totaux, puis le\n'
            '       tableau des lignes ; statuts conservés ; réservation, livraison, paramètres en onglets -->\n'
            '  <panel name="mainPanel" colSpan="12" css="lvme-compact lvme-cde-serre lvme-cde-entete">\n' + top.rstrip() + '\n    ' + details + '\n  </panel>\n'
            '  <panel name="lvmeGescomPanel" colSpan="12" css="lvme-cde-client lvme-cde-fond lvme-compact lvme-cde-serre">\n'
            + client_new + '\n' + cde_new + '\n' + boutons + '\n' + totaux + '\n'
            '    ' + info_client + '\n'
            '  </panel>\n' + lignes_xml + '\n')

out = head_form + new_main + tech + '  ' + tabs + '\n  ' + attrs_panel + '\n  ' + other_infos + '\n  ' + mail + '\n</form>\n'
m = re.search(r'\sonLoad="([^"]*)"', out[:out.index('>')])
out = out.replace('onLoad="%s"' % m.group(1), 'onLoad="%s,%s"' % (m.group(1), SOMME), 1)
open(DST, 'w', encoding='utf-8', newline='\r\n').write(out)
print('ok', DST, len(out))

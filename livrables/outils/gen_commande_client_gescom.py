"""Construit livrables/ui/commande-client-form.xml : fiche Commande client condensée comme la « Fiche Commande
client » GESCOM (Client | Commande | Totaux | boutons, sans barre latérale), à partir de la fiche admin
sale-order-form (priorité 30). Barre de statuts et onglets du bas conservés ; rien n'est retiré."""
import re, sys

src, dst = sys.argv[1], sys.argv[2]
x = open(src, encoding='utf-8').read().replace('\r\n', '\n').replace('\r', '')
x = re.sub(r'\n[ \t]*\n', '\n', x)
A = r'(?:[^>"]|"[^"]*")'


def blk(name, tag='panel', extra=''):
    m = re.search(r'<' + tag + r'\b(?=' + A + r'*?\sname="' + re.escape(name) + r'"' + extra + r')', x)
    assert m, name
    i = m.start()
    depth = 0
    for t in re.finditer(r'<(/?)' + tag + r'\b' + A + r'*?(/?)>', x[i:]):
        if t.group(1):
            depth -= 1
        elif not t.group(2):
            depth += 1
        if depth == 0:
            return x[i:i + t.end()]
    raise AssertionError(name)


def el(name, within, extra=None):
    pat = re.compile(r'<(field|button)\b(?=' + A + r'*?\sname="' + re.escape(name) + r'")' + A + r'*?(/>|>.*?</\1>)', re.S)
    found = [m.group(0) for m in pat.finditer(within) if extra is None or extra in m.group(0)]
    assert found, name
    return found


def seta(e, attr, val):
    head = re.match(r'<\w+\b' + A + r'*', e).group(0)
    if re.search(r'\s%s="[^"]*"' % attr, head):
        return e.replace(head, re.sub(r'(\s)%s="[^"]*"' % attr, r'\1%s="%s"' % (attr, val), head, count=1), 1)
    return re.sub(r'^<(\w+)', r'<\1 %s="%s"' % (attr, val), e, count=1)


def dela(e, attr):
    head = re.match(r'<\w+\b' + A + r'*', e).group(0)
    return e.replace(head, re.sub(r'\s%s="[^"]*"' % attr, '', head), 1)


def F(e, cs, title=None, ind='      '):
    e = seta(e, 'colSpan', cs)
    if title:
        e = seta(e, 'title', title)
    return ind + e


main = blk('mainPanel')
tabs = blk('mainPanelTab', 'panel-tabs')
head_form = x[:x.index('<panel name="mainPanel"')]
mail = x[x.index('<panel-mail name="mailPanel">'):x.index('</panel-mail>') + len('</panel-mail>')]
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

# haut de la fiche Axelor (blocage encours, statuts, n°) : tout ce qui précède detailsPanel, gardé tel quel
top = main[main.index('>') + 1:main.index(details)]
# champs entre detailsPanel et lvmeDevisePanel (vente ponctuelle, noms commerciaux) : gardés dans Paramètres
entre = main[main.index(details) + len(details):main.index(devise)]
entre_fields = re.findall(r'<field\b' + A + r'*?(?:/>|>.*?</field>)', entre, re.S)

# --- bloc Client (encadré bleu), libellés GESCOM
c = lambda n, extra=None: el(n, client, extra)[0]
client_new = ['    <panel name="lvmeClientPanel" colSpan="5" itemSpan="6" css="lvme-gescom lvme-gescom-box">',
              F(c('clientPartner'), 6, 'Client'), F(c('commercial'), 6, 'Commercial')]
client_new += [F(e, 6, 'Adresse') for e in el('mainInvoicingAddress', client)]
client_new += [F(e, 6, 'Adresse') for e in el('mainInvoicingAddressStr', client)]
client_new += [F(c('contactPartner'), 6, 'contact'), F(c('clientPartner.fixedPhone'), 6, 'Téléphone'),
               F(c('clientPartner.groupement'), 6, 'Groupement'),
               F(c('paymentMode'), 6, 'Règlement'), F(c('paymentCondition'), 6, 'Echéance'),
               F(c('remiseFacture'), 4, '% Rem/Fact.'), F(c('tauxRFA'), 4, '% RFA'),
               F(c('tauxCommission'), 4, '% Frais Commission'),
               '    </panel>']

# --- bloc Commande
d = lambda n: el(n, cde)[0]
seq = el('saleOrderSeq', top)[0]
cde_new = ['    <panel name="lvmeCommandePanel" colSpan="4" itemSpan="6" css="lvme-gescom">',
           '      <field name="saleOrderSeq" title="Commande N°" readonly="true" colSpan="6"/>',
           F(d('salespersonUser'), 6, 'Opérateur'),
           F(d('creationDate'), 6, 'Date Commande'), F(d('estimatedDeliveryDate'), 6, 'Date Livraison'),
           F(el('isReservation', resa)[0].replace(' widget="boolean-switch"', ''), 6, 'Réservation'),
           F(d('externalReference'), 6, 'Ref Cde'),
           F(d('carrierPartner'), 8, 'Transporteur'), F(d('portPaye'), 4, 'Port Payé'),
           F(d('coutPortKg'), 4, 'Coût port/kg'),
           F(seta(d('internalNote'), 'height', '2'), 8, '&lt; Commentaire &gt;'),
           '    </panel>']

# --- bloc Totaux (Nb Colis / Poids calculés par le serveur sur toutes les lignes ; totaux de la commande)
NUM = '(+%s || 0).toLocaleString("fr-FR", { minimumFractionDigits: %d, maximumFractionDigits: %d })'
CASE = 'style={{ background: "#ffffc4", color: "#1a1ad6", border: "1px solid #c8c8c8", textAlign: "right", padding: "1px 6px", minWidth: 70 }}'
LIB = 'style={{ color: "#333", paddingRight: 6, whiteSpace: "nowrap", textAlign: "right" }}'
def ligne_tot(l1, v1, d1, l2, v2, d2):
    return ('<tr><td %s>%s</td><td %s>{%s}</td><td %s>%s</td><td %s>{%s}</td></tr>'
            % (LIB, l1, CASE, NUM % (v1, d1, d1), LIB, l2, CASE, NUM % (v2, d2, d2)))
totaux = '''    <panel name="lvmeTotauxPanel" colSpan="4" css="lvme-gescom lvme-gescom-box">
      <field name="$lvmeTotaux" type="string" showTitle="false" readonly="true" colSpan="12">
        <viewer depends="$sommeColis,$sommePoids,exTaxTotal,inTaxTotal,marginRate,totalGrossMargin"><![CDATA[
          <>
            <table style={{ borderCollapse: "separate", borderSpacing: 3, fontSize: 13 }}>
              <tbody>
                %s
                %s
                %s
              </tbody>
            </table>
          </>
        ]]></viewer>
      </field>
      <field name="$sommeColis" type="decimal" hidden="true"/>
      <field name="$sommePoids" type="decimal" hidden="true"/>
    </panel>''' % (ligne_tot('Nb Colis', '$sommeColis', 0, 'Total HT', 'exTaxTotal', 2),
                   ligne_tot('Poids', '$sommePoids', 1, 'Total TTC', 'inTaxTotal', 2),
                   ligne_tot('% Marge Totale', 'marginRate', 2, 'Total marge', 'totalGrossMargin', 2))

# --- boutons (barre latérale) à droite, avec Imprimer commande
act_buttons = re.findall(r'<button\b' + A + r'*?/>', actions, re.S)
act_fields = re.findall(r'<field\b' + A + r'*?/>', actions, re.S)
boutons = (['    <panel name="actionsPanel" hideIf="clientPartner == null" colSpan="3" itemSpan="12">',
            '      <button name="lvmeImprimerCommandeBtn" title="Imprimer commande" icon="printer" '
            'onClick="save,action-sale-order-view-reports-wizard"/>']
           + ['      ' + b for b in act_buttons] + ['      ' + f for f in act_fields] + ['    </panel>'])

# --- en-tête : statuts Axelor + 4 blocs ; réservation, livraison, paramètres repliés dessous
def replie(p, titre=None):
    p = re.sub(r'^(<panel\b' + A + r'*?)>', lambda m: m.group(1) + ' canCollapse="true" collapseIf="true">', p, count=1) \
        if 'canCollapse' not in p[:p.index('>')] else p
    return p
new_main = ('  <!-- LVME : fiche Commande client copiée sur la « Fiche Commande client » GESCOM : Client | Commande |\n'
            '       Totaux | boutons, sans barre latérale ; statuts, réservation, livraison et onglets conservés -->\n'
            '  <panel name="mainPanel" colSpan="12">\n' + top.rstrip() + '\n    ' + details + '\n'
            '  <panel name="lvmeGescomPanel" colSpan="12" css="lvme-gescom">\n'
            + '\n'.join(client_new) + '\n' + '\n'.join(cde_new) + '\n' + totaux + '\n' + '\n'.join(boutons) + '\n'
            '  </panel>\n'
            '    ' + re.sub(r'\s*<field name="isReservation"' + A + r'*?/>', '', replie(resa), count=1) + '\n'
            '    ' + replie(livr) + '\n'
            '    <panel name="lvmeParametresPanel" title="Paramètres" colSpan="12" canCollapse="true" collapseIf="true">\n'
            + ''.join('      ' + f + '\n' for f in entre_fields)
            + '      ' + devise + '\n      ' + general + '\n    </panel>\n'
            + '    ' + el('clientPartner.saleOrderInformation', main)[0] + '\n'
            '  </panel>\n')

# champs techniques de la barre latérale des totaux (cachés), gardés pour les conditions et calculs
intax_fields = re.findall(r'<field\b' + A + r'*?/>', intax, re.S)
tech = ('  <panel name="lvmeTotauxTechPanel" hidden="true" colSpan="12">\n'
        + '\n'.join('    ' + dela(f, 'hidden') for f in intax_fields if 'name="inTaxTotal"' not in f)
        + '\n    <field name="inTaxTotal"/>\n  </panel>\n')

# barre latérale restante (remise globale, suivi, caractéristiques, références, marge, dates) : onglet « Suivi »
suivi = ['    <!-- LVME : ancienne barre latérale -->', '    <panel name="lvmeSuiviPanel" title="Suivi">']
for n in side_names + ['marginPanel']:
    p = sides.get(n) or margin
    for a in ['sidebar', 'hideIf', 'canCollapse', 'collapseIf']:
        p = dela(p, a)
    suivi.append('      ' + seta(p, 'colSpan', '6'))
suivi.append('    </panel>')
tabs = tabs[:tabs.rindex('</panel-tabs>')] + '\n'.join(suivi) + '\n  </panel-tabs>'

out = (head_form + new_main + tech + '  ' + tabs + '\n  ' + attrs_panel + '\n  ' + other_infos + '\n  ' + mail + '\n</form>\n')
m = re.search(r'\sonLoad="([^"]*)"', out[:out.index('>')])
out = out.replace('onLoad="%s"' % m.group(1), 'onLoad="%s,action-lvme-commande-client-attrs-somme"' % m.group(1), 1)
# totaux recalculés à chaque changement des lignes
SOMME = 'action-lvme-commande-client-attrs-somme'
def onchange(mm):
    t = mm.group(0)
    if 'onChange="' in t:
        return re.sub(r'onChange="([^"]*)"', lambda q: 'onChange="' + q.group(1) + ',' + SOMME + '"', t, count=1)
    return t.replace('<panel-related ', '<panel-related onChange="' + SOMME + '" ', 1)
out = re.sub(r'<panel-related\s(?=' + A + r'*?field="saleOrderLineList")' + A + r'*?>', onchange, out)
open(dst, 'w', encoding='utf-8', newline='\r\n').write(out)
print('ok', len(out))

"""Construit les vues des statuts BL (livraison client) façon LVME : Brouillon, En cours de préparation, Flottant,
Réalisé, Annulé, à partir des vues Axelor assemblées :
  livrables/ui/origine/stock-move-form-computed.xml -> livrables/ui/stock-move-form-bl.xml (fiche admin p30)
  livrables/ui/origine/stock-move-out-grid.xml      -> livrables/ui/stock-move-out-grid-bl.xml (liste admin p30)
Pour un BL (typeSelect == 2) seulement : barre des statuts LVME (champ lvmeEtapeBl), boutons Flottant et
retour En cours de préparation ; les autres mouvements (arrivages, internes) gardent la barre Axelor.
Publiées par PROD_67. Usage : python livrables/outils/gen_bl_statuts.py   (depuis la racine du dépôt)
"""
import os

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UI = os.path.join(RACINE, 'livrables', 'ui')

f = open(os.path.join(UI, 'origine', 'stock-move-form-computed.xml'), encoding='utf-8').read()
old = '<field name="statusSelect" showTitle="false" colSpan="7" widget="NavSelect"/>'
assert f.count(old) == 1, 'statusSelect'
f = f.replace(old, '<field name="statusSelect" showTitle="false" colSpan="7" widget="NavSelect" hideIf="typeSelect == 2"/>\n'
              '        <!-- LVME : statuts d\'un BL (Brouillon, En cours de préparation, Flottant, Réalisé, Annulé) -->\n'
              '        <field name="lvmeEtapeBl" showTitle="false" colSpan="7" widget="NavSelect" readonly="true" showIf="typeSelect == 2"/>\n'
              '        <field name="lvmeBlFlottant" hidden="true"/>')
i = f.index('<button name="realizeBtn"')
f = (f[:i]
     + '<button name="lvmeBlFlottantBtn" title="Flottant" icon="fa-truck" '
       'showIf="typeSelect == 2 &amp;&amp; statusSelect == 2 &amp;&amp; !lvmeBlFlottant" '
       'onClick="save,action-lvme-bl-record-flottant,save"/>\n'
     + '      <button name="lvmeBlPreparationBtn" title="Flottant -&gt; En cours de préparation" '
       'showIf="typeSelect == 2 &amp;&amp; statusSelect == 2 &amp;&amp; lvmeBlFlottant" '
       'onClick="save,action-lvme-bl-record-preparation,save"/>\n      '
     + f[i:])
open(os.path.join(UI, 'stock-move-form-bl.xml'), 'w', encoding='utf-8', newline='\n').write(f)

g = open(os.path.join(UI, 'origine', 'stock-move-out-grid.xml'), encoding='utf-8').read()
old = '<field name="statusSelect" widget="single-select"/>'
assert g.count(old) == 1, 'grille statusSelect'
g = g.replace(old, '<field name="lvmeEtapeBl" title="Statut" widget="single-select"/>\n  <field name="statusSelect" hidden="true"/>')
open(os.path.join(UI, 'stock-move-out-grid-bl.xml'), 'w', encoding='utf-8', newline='\n').write(g)
print('ok')

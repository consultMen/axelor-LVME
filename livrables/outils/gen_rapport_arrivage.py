# Génère axelor-stock/src/main/resources/reports/LvmeArrivage.rptdesign (BIRT) :
# impression de l'écran Arrivage GESCOM (en-tête Fournisseur / Arrivage / Devise + lignes + Somme).
# Usage : python livrables/outils/gen_rapport_arrivage.py   (depuis la racine du dépôt)
import html
import os

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(RACINE, "open-suite-webapp", "modules", "axelor-open-suite", "axelor-stock",
                   "src", "main", "resources", "reports", "LvmeArrivage.rptdesign")


def num(expr, dec=2):
    """Nombre au format français : 198 300,00"""
    # séparateurs littéraux (indépendants de la langue du serveur) puis passage au format français
    fmt = "FM999,999,999,990" + ("." + "0" * dec if dec else "")
    return f"replace(replace(to_char({expr}, '{fmt}'), ',', ' '), '.', ',')"


def h(x):
    """Échappement HTML côté SQL"""
    return f"replace(replace(replace(COALESCE(({x})::text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;')"


def ligne(label, x):
    return (f"'<tr><td style=\"color:#666;padding-right:6px\">{label}</td><td><b>' || "
            f"{h(x)} || '</b></td></tr>'")


def bloc(titre, items):
    return ("'<div style=\"font-weight:bold;border-bottom:1px solid #999;margin-bottom:2px\">" + titre
            + "</div><table style=\"font-size:8pt\">' || "
            + " || ".join(ligne(l, x) for l, x in items) + " || '</table>'")


QTE = "CASE WHEN sm.status_select = 3 THEN l.real_qty ELSE l.qty END"

ENTETE_SQL = f"""
SELECT
  sm.stock_move_seq AS numero,
  {bloc('Fournisseur', [
     ('Fournisseur', 'p.full_name'),
     ('Code', 'p.partner_seq'),
     ('Adresse', "replace(COALESCE(sm.from_address_str, ''), chr(10), ' ')"),
     ('Contact', 'ct.full_name'),
     ('Tél.', 'p.fixed_phone'),
     ('Email', 'em.address'),
     ('Règlement', 'pm.name'),
     ('Échéance', 'pc.name')])} AS bloc1,
  {bloc('Arrivage', [
     ('Opérateur', 'bu.full_name'),
     ('Arrivage N°', 'sm.stock_move_seq'),
     ('Du', "to_char(sm.created_on, 'DD/MM/YYYY')"),
     ('Nature', "CASE sm.nature WHEN 1 THEN 'Flottant - à embarquer' WHEN 2 THEN 'Flottant' WHEN 3 THEN 'Réel' WHEN 4 THEN 'Annulé' ELSE 'Brouillon' END"),
     ('Commande', 'po.purchase_order_seq'),
     ('Date Départ', "to_char(sm.supplier_shipment_date, 'DD/MM/YYYY')"),
     ('Arrivée', "to_char(COALESCE(sm.real_date, sm.estimated_date), 'DD/MM/YYYY')"),
     ('Type transport', 'shm.name'),
     ('Bateau', 'bt.name'),
     ('Containers', "(SELECT string_agg(c.name, ', ') FROM stock_stock_move_container_set cs JOIN stock_container c ON c.id = cs.container_set WHERE cs.stock_stock_move = sm.id)"),
     ('Transitaire', 'fw.full_name'),
     ('Frigo', 'fr.name')])} AS bloc2,
  {bloc('Devise', [
     ('Devise', 'cur.code'),
     ('Cours', num('sm.lvme_cours', 4)),
     ('Couvert', num('sm.lvme_couvert', 4)),
     ('Flottant', num('sm.lvme_flottant', 4)),
     ('Réel', num('sm.lvme_reel', 4)),
     ('Mt Achat HT', num('sm.ex_tax_total') + " || ' ' || COALESCE(cur.code, '')"),
     ('Équivalent', "CASE WHEN cur.id IS DISTINCT FROM co.currency THEN "
      + num(f"(SELECT SUM(CASE WHEN sm.status_select = 3 THEN l.real_qty ELSE l.qty END * COALESCE(l.company_unit_price_untaxed, 0)) FROM stock_stock_move_line l WHERE l.stock_move = sm.id)")
      + " || ' ' || COALESCE(ccur.code, '') END"),
     ('Nb Colis', num('sm.nb_colis_total', 0)),
     ('Poids Total', num('sm.poids_total', 3))])} AS bloc3
FROM stock_stock_move sm
LEFT JOIN base_partner p ON p.id = sm.partner
LEFT JOIN message_email_address em ON em.id = p.email_address
LEFT JOIN stock_stock_move_purchase_order_set r ON r.stock_stock_move = sm.id
LEFT JOIN purchase_purchase_order po ON po.id = r.purchase_order_set
LEFT JOIN base_partner ct ON ct.id = po.contact_partner
LEFT JOIN base_company co ON co.id = sm.company
LEFT JOIN base_currency cur ON cur.id = COALESCE(po.currency, co.currency)
LEFT JOIN base_currency ccur ON ccur.id = co.currency
LEFT JOIN account_payment_mode pm ON pm.id = po.payment_mode
LEFT JOIN account_payment_condition pc ON pc.id = po.payment_condition
LEFT JOIN auth_user bu ON bu.id = po.buyer_user
LEFT JOIN stock_shipment_mode shm ON shm.id = sm.shipment_mode
LEFT JOIN stock_bateau bt ON bt.id = sm.bateau
LEFT JOIN base_partner fw ON fw.id = sm.forwarder_partner
LEFT JOIN stock_stock_location fr ON fr.id = sm.to_stock_location
WHERE sm.id = ?
LIMIT 1
"""

# (nom, titre, expression SQL, largeur en pouces, aligné à droite)
COLS = [
    ('produit', 'Produit', 'pr.code', 0.9, False),
    ('designation', 'Désignation', 'l.product_name', 2.0, False),
    ('frigo', 'Frigo', 'fr.name', 0.7, False),
    ('lot', 'N° Lot', 'tn.tracking_number_seq', 0.9, False),
    ('origine', 'Origine', 'l.origine', 0.6, False),
    ('cond', 'Conditionn.', "COALESCE(NULLIF(cd.label, ''), cd.code)", 1.0, False),
    ('pa', 'Prix Achat', num('l.unit_price_untaxed', 2), 0.6, True),
    ('pr', 'Prix Revient', num('l.pr_kg', 2), 0.6, True),
    ('unite', 'Unité', 'u.name', 0.6, False),
    ('colis', 'Nb Colis', num('l.nb_colis', 0), 0.55, True),
    ('parcolis', 'Nb unt ou Poids /Colis', num('COALESCE(NULLIF(l.nb_unites_par_colis, 0), l.poids_par_colis)', 0), 0.65, True),
    ('qte', 'Nb unités ou poids', num(QTE, 0), 0.7, True),
    ('poids', 'Poids Kg', num('l.poids_total_net', 0), 0.6, True),
    ('montant', 'Montant ht', num(f'COALESCE(NULLIF(l.montant_reel, 0), ({QTE}) * l.unit_price_untaxed)', 2), 0.85, True),
    ('dluo', 'D.L.C. / D.L.U.O', "to_char(l.dluo, 'DD/MM/YYYY')", 0.75, False),
    ('zone', 'Zone pêche', 'l.zone_peche', 0.9, False),
]
TOTAL = {
    'colis': num('SUM(l.nb_colis)', 0),
    'qte': num(f'SUM({QTE})', 0),
    'poids': num('SUM(l.poids_total_net)', 0),
    'montant': num(f'SUM(COALESCE(NULLIF(l.montant_reel, 0), ({QTE}) * l.unit_price_untaxed))', 2),
}
JOINS = """FROM stock_stock_move_line l
JOIN stock_stock_move sm ON sm.id = l.stock_move
LEFT JOIN base_product pr ON pr.id = l.product
LEFT JOIN stock_stock_location fr ON fr.id = COALESCE(l.to_stock_location, sm.to_stock_location)
LEFT JOIN stock_tracking_number tn ON tn.id = l.tracking_number
LEFT JOIN purchase_purchase_order_line pol ON pol.id = l.purchase_order_line
LEFT JOIN purchase_conditionnement cd ON cd.id = pol.conditionnement
LEFT JOIN base_unit u ON u.id = l.unit
WHERE l.stock_move = ?"""
SEL_DETAIL = ",\n  ".join(f"({c[2]})::text AS {c[0]}" for c in COLS)
SEL_TOTAL = ",\n  ".join(
    ((f"({TOTAL[c[0]]})::text" if c[0] in TOTAL else ("'Somme'" if c[0] == 'produit' else "NULL::text"))
     + f" AS {c[0]}") for c in COLS)
LIGNES_SQL = f"""SELECT * FROM (
SELECT 0 AS ordre, l.sequence AS seq, '0' AS is_total,
  {SEL_DETAIL}
{JOINS}
UNION ALL
SELECT 1, 0, '1',
  {SEL_TOTAL}
{JOINS}
) x ORDER BY ordre, seq"""

_id = [100]


def nid():
    _id[0] += 1
    return _id[0]


def resultset(names):
    return "\n".join(f"""                <structure>
                    <property name="position">{i + 1}</property>
                    <property name="name">{n}</property>
                    <property name="nativeName">{n}</property>
                    <property name="dataType">string</property>
                    <property name="nativeDataType">12</property>
                </structure>""" for i, n in enumerate(names))


def dataset(name, names, sql, nparams):
    params = "\n".join(f"""                <structure>
                    <property name="name">param_{i + 1}</property>
                    <property name="paramName">StockMoveId</property>
                    <property name="dataType">decimal</property>
                    <property name="nativeDataType">2</property>
                    <property name="position">{i + 1}</property>
                    <property name="isInput">true</property>
                    <property name="isOutput">false</property>
                </structure>""" for i in range(nparams))
    meta = "\n".join(f"""                    <structure>
                        <property name="position">{i + 1}</property>
                        <property name="name">{n}</property>
                        <property name="dataType">string</property>
                    </structure>""" for i, n in enumerate(names))
    return f"""        <oda-data-set extensionID="org.eclipse.birt.report.data.oda.jdbc.JdbcSelectDataSet" name="{name}" id="{nid()}">
            <list-property name="parameters">
{params}
            </list-property>
            <structure name="cachedMetaData">
                <list-property name="resultSet">
{meta}
                </list-property>
            </structure>
            <property name="dataSource">Data Source</property>
            <list-property name="resultSet">
{resultset(names)}
            </list-property>
            <xml-property name="queryText"><![CDATA[{sql}]]></xml-property>
        </oda-data-set>"""


def bound(names):
    return "\n".join(f"""                <structure>
                    <property name="name">{n}</property>
                    <expression name="expression" type="javascript">dataSetRow["{n}"]</expression>
                    <property name="dataType">string</property>
                </structure>""" for n in names)


def cell(content, style=""):
    return f"""                    <cell id="{nid()}">{style}
{content}
                    </cell>"""


BORDER = """
                        <property name="borderBottomStyle">solid</property>
                        <property name="borderBottomWidth">thin</property>
                        <property name="borderBottomColor">#BBBBBB</property>
                        <property name="paddingTop">1pt</property>
                        <property name="paddingBottom">1pt</property>
                        <property name="paddingLeft">2pt</property>
                        <property name="paddingRight">2pt</property>"""

ENT_NAMES = ['numero', 'bloc1', 'bloc2', 'bloc3']
LIG_NAMES = ['is_total'] + [c[0] for c in COLS]


def textdata(col):
    return f"""                        <text-data id="{nid()}">
                            <expression name="valueExpr">row["{col}"]</expression>
                            <property name="contentType">html</property>
                        </text-data>"""


def data(col, right):
    al = '\n                            <property name="textAlign">right</property>' if right else ''
    return f"""                        <data id="{nid()}">{al}
                            <property name="resultSetColumn">{col}</property>
                        </data>"""


def label(txt, right):
    al = '\n                            <property name="textAlign">right</property>' if right else ''
    return f"""                        <label id="{nid()}">
                            <property name="fontWeight">bold</property>{al}
                            <text-property name="text">{html.escape(txt)}</text-property>
                        </label>"""


def build():
    entete_table = f"""        <table id="{nid()}">
            <property name="width">100%</property>
            <property name="dataSet">Entete</property>
            <list-property name="boundDataColumns">
{bound(ENT_NAMES)}
            </list-property>
            <column id="{nid()}"><property name="width">36%</property></column>
            <column id="{nid()}"><property name="width">34%</property></column>
            <column id="{nid()}"><property name="width">30%</property></column>
            <detail>
                <row id="{nid()}">
                    <cell id="{nid()}">
                        <property name="colSpan">3</property>
                        <property name="paddingBottom">6pt</property>
                        <text-data id="{nid()}">
                            <expression name="valueExpr">"&lt;span style='font-size:15pt;font-weight:bold'&gt;ARRIVAGE N° " + row["numero"] + "&lt;/span&gt;"</expression>
                            <property name="contentType">html</property>
                        </text-data>
                    </cell>
                </row>
                <row id="{nid()}">
{cell(textdata('bloc1'))}
{cell(textdata('bloc2'))}
{cell(textdata('bloc3'))}
                </row>
            </detail>
        </table>"""
    # largeurs en % de la page (A4 paysage) : les poids relatifs de COLS sont ramenés à 100 %
    poids = sum(c[3] for c in COLS)
    col_defs = "\n".join(f'            <column id="{nid()}"><property name="width">{round(c[3] * 100 / poids, 2)}%</property></column>' for c in COLS)
    hdr_cells = "\n".join(cell(label(c[1], c[4]), BORDER + '\n                        <property name="backgroundColor">#E8E8E8</property>') for c in COLS)
    det_cells = "\n".join(cell(data(c[0], c[4]), BORDER) for c in COLS)
    lignes_table = f"""        <table id="{nid()}">
            <property name="marginTop">8pt</property>
            <property name="width">100%</property>
            <property name="fontSize">6.5pt</property>
            <property name="dataSet">Lignes</property>
            <list-property name="boundDataColumns">
{bound(LIG_NAMES)}
            </list-property>
{col_defs}
            <header>
                <row id="{nid()}">
{hdr_cells}
                </row>
            </header>
            <detail>
                <row id="{nid()}">
                    <list-property name="highlightRules">
                        <structure>
                            <property name="operator">eq</property>
                            <property name="fontWeight">bold</property>
                            <property name="backgroundColor">#FFF5CC</property>
                            <expression name="testExpr" type="javascript">row["is_total"]</expression>
                            <simple-property-list name="value1">
                                <value type="javascript">"1"</value>
                            </simple-property-list>
                        </structure>
                    </list-property>
{det_cells}
                </row>
            </detail>
        </table>"""
    datasets = dataset('Entete', ENT_NAMES, ENTETE_SQL, 1) + "\n" + dataset('Lignes', ['ordre', 'seq'] + LIG_NAMES, LIGNES_SQL, 2)
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<report xmlns="http://www.eclipse.org/birt/2005/design" version="3.2.23" id="1">
    <property name="createdBy">LVME</property>
    <property name="units">in</property>
    <text-property name="title">Arrivage</text-property>
    <parameters>
        <scalar-parameter name="StockMoveId" id="2">
            <property name="hidden">true</property>
            <property name="valueType">static</property>
            <property name="isRequired">true</property>
            <property name="dataType">decimal</property>
            <property name="paramType">simple</property>
            <property name="controlType">text-box</property>
            <structure name="format">
                <property name="category">Unformatted</property>
            </structure>
        </scalar-parameter>
    </parameters>
    <data-sources>
        <oda-data-source extensionID="org.eclipse.birt.report.data.oda.jdbc" name="Data Source" id="3">
            <property name="odaDriverClass">org.postgresql.Driver</property>
            <property name="odaURL">jdbc:postgresql://localhost:5432/</property>
        </oda-data-source>
    </data-sources>
    <data-sets>
{datasets}
    </data-sets>
    <styles>
        <style name="report" id="4">
            <property name="fontFamily">sans-serif</property>
            <property name="fontSize">8pt</property>
        </style>
    </styles>
    <page-setup>
        <simple-master-page name="Simple MasterPage" id="5">
            <property name="type">a4</property>
            <property name="orientation">landscape</property>
            <property name="topMargin">0.3in</property>
            <property name="leftMargin">0.3in</property>
            <property name="bottomMargin">0.3in</property>
            <property name="rightMargin">0.3in</property>
            <page-footer>
                <text id="6">
                    <property name="fontSize">7pt</property>
                    <property name="textAlign">right</property>
                    <property name="contentType">html</property>
                    <text-property name="content"><![CDATA[Page <value-of>pageNumber</value-of> / <value-of>totalPage</value-of>]]></text-property>
                </text>
            </page-footer>
        </simple-master-page>
    </page-setup>
    <body>
{entete_table}
{lignes_table}
    </body>
</report>
"""


if __name__ == "__main__":
    xml = build()
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    # requêtes de contrôle pour tester le SQL sur un arrivage (remplacer 33 par l'id voulu)
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "rapport_arrivage_test.sql"), "w", encoding="utf-8") as f:
        f.write(ENTETE_SQL.replace("?", "33") + ";\n" + LIGNES_SQL.replace("?", "33") + ";\n")
    print("ok", OUT, len(xml))

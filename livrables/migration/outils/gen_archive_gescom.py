"""Archive GESCOM : charge chaque export CSV de GESCOM (séparateur ';', noms des colonnes en 1re ligne) tel quel dans
le schéma « gescom » de la base Axelor, une table par fichier, toutes les colonnes en texte. Rien n'est transformé ni
perdu ; les scripts MIG_NN lisent ensuite ces tables pour remplir Axelor.

Usage : python gen_archive_gescom.py <dossier des CSV> <fichier .sql à produire>
Le .sql produit est autonome (données comprises) : psql -U axelor -d <base> -v ON_ERROR_STOP=1 -f <fichier .sql>
Relançable : chaque table de l'archive est recréée.
"""
import csv
import os
import re
import sys

# noms de fichiers exportés -> nom de la table GESCOM (fautes de frappe et suffixe « OCT » de l'export d'octobre)
NOMS = {
    'famille_artciles': 'famille_articles',
    'sfamillearticles': 'sfamille_articles',
    'unitevente': 'unite_vente',
    'gencode_articles': 'gencod_articles',
    'modepeche': 'modepeche',
    'zonepeche': 'zone_peche',
}


def nom_table(fichier):
    base = os.path.splitext(os.path.basename(fichier))[0].lower()
    base = re.sub(r'oct$', '', base).strip('_ ')
    base = re.sub(r'[^a-z0-9_]+', '_', base)
    return NOMS.get(base, base)


def nom_colonne(titre, vus):
    c = titre.strip().lower()
    c = c.replace('°', '').replace('é', 'e').replace('è', 'e').replace('ê', 'e').replace('à', 'a')
    c = re.sub(r'[^a-z0-9]+', '_', c).strip('_') or 'col'
    if c[0].isdigit():
        c = 'c_' + c
    n, i = c, 2
    while n in vus:
        n, i = '%s_%d' % (c, i), i + 1
    vus.add(n)
    return n


def main(dossier, sortie):
    fichiers = sorted(f for f in os.listdir(dossier) if f.lower().endswith('.csv'))
    with open(sortie, 'w', encoding='utf-8', newline='\n') as out:
        out.write("-- Archive GESCOM générée par gen_archive_gescom.py depuis %s\n" % dossier)
        out.write("SET client_encoding = 'UTF8';\n\\set ON_ERROR_STOP on\nBEGIN;\n")
        out.write("CREATE SCHEMA IF NOT EXISTS gescom;\n")
        # conversions utiles aux scripts MIG : nombres « 1 234,50 » et dates « jj/mm/aaaa » (01/01/1900 = vide)
        out.write(r"""CREATE OR REPLACE FUNCTION gescom.num(v text) RETURNS numeric LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE WHEN btrim(coalesce(v, '')) = '' THEN NULL
    ELSE replace(regexp_replace(v, '[\s\u00a0\u202f]', '', 'g'), ',', '.')::numeric END $f$;
CREATE OR REPLACE FUNCTION gescom.dt(v text) RETURNS date LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE WHEN btrim(coalesce(v, '')) IN ('', '01/01/1900', '00/00/0000') THEN NULL
    ELSE to_date(btrim(v), 'DD/MM/YYYY') END $f$;
CREATE OR REPLACE FUNCTION gescom.txt(v text) RETURNS text LANGUAGE sql IMMUTABLE AS $f$
  SELECT NULLIF(btrim(coalesce(v, '')), '') $f$;
CREATE TABLE IF NOT EXISTS gescom.fichiers (nom_table text PRIMARY KEY, fichier text, lignes integer, colonnes integer,
  charge_le timestamp);
""")
        for f in fichiers:
            chemin = os.path.join(dossier, f)
            with open(chemin, encoding='utf-8-sig', newline='') as fh:
                lignes = list(csv.reader(fh, delimiter=';'))
            if not lignes:
                continue
            vus = set()
            cols = [nom_colonne(t, vus) for t in lignes[0]]
            table = nom_table(f)
            out.write("\n-- %s (%d lignes)\nDROP TABLE IF EXISTS gescom.%s;\n" % (f, len(lignes) - 1, table))
            out.write("CREATE TABLE gescom.%s (%s);\n" % (table, ', '.join('"%s" text' % c for c in cols)))
            out.write("COPY gescom.%s FROM STDIN WITH (FORMAT csv, DELIMITER ';', NULL '\\N');\n" % table)
            w = csv.writer(out, delimiter=';', lineterminator='\n')
            for r in lignes[1:]:
                r = (r + [''] * len(cols))[:len(cols)]
                w.writerow(r)
            out.write("\\.\n")
            out.write("INSERT INTO gescom.fichiers VALUES ('%s', '%s', %d, %d, now()) ON CONFLICT (nom_table) DO UPDATE "
                      "SET fichier = EXCLUDED.fichier, lignes = EXCLUDED.lignes, colonnes = EXCLUDED.colonnes, "
                      "charge_le = now();\n" % (table, f.replace("'", "''"), len(lignes) - 1, len(cols)))
            print('ok %-32s -> gescom.%-22s %7d lignes %4d colonnes' % (f, table, len(lignes) - 1, len(cols)))
        out.write("\nCOMMIT;\nSELECT nom_table, lignes, colonnes, fichier FROM gescom.fichiers ORDER BY nom_table;\n")


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])

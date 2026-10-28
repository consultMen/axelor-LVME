"""Archive GESCOM : charge chaque export CSV de GESCOM (séparateur ';', noms des colonnes en 1re ligne) tel quel dans
le schéma « gescom » de la base Axelor, une table par fichier, toutes les colonnes en texte. Rien n'est transformé ni
perdu ; les scripts MIG_NN lisent ensuite ces tables pour remplir Axelor.

Usage : python gen_archive_gescom.py <dossier des CSV> <fichier .sql à produire>
Le .sql produit est autonome (données comprises) : psql -U axelor -d <base> -v ON_ERROR_STOP=1 -f <fichier .sql>
Relançable : chaque table de l'archive est recréée.
"""
import csv
import io
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
    # gros fichiers exportés en morceaux (CCE1..CCE4, CCD1..CCD7, CCD5a…) : une seule table
    base = re.sub(r'^(cce|ccd)_?[0-9]+[a-z]?$', r'\1', base)
    return NOMS.get(base, base)


def lire_csv(chemin):
    """Exports du Centre de Contrôle HFSQL : UTF-8, sinon encodage Windows (cp1252) selon l'export."""
    brut = open(chemin, 'rb').read()
    try:
        texte = brut.decode('utf-8-sig')
    except UnicodeDecodeError:
        texte = brut.decode('cp1252')
    return list(csv.reader(io.StringIO(texte, newline=''), delimiter=';'))


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
CREATE OR REPLACE FUNCTION gescom.dt(v text) RETURNS date LANGUAGE plpgsql IMMUTABLE AS $f$
BEGIN
  -- date GESCOM jj/mm/aaaa ; vide, 01/01/1900 ou illisible (ex. ##/##/####, 31/02/2020) = pas de date
  IF btrim(coalesce(v, '')) !~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' OR btrim(v) = '01/01/1900' THEN
    RETURN NULL;
  END IF;
  RETURN to_date(btrim(v), 'DD/MM/YYYY');
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END $f$;
CREATE OR REPLACE FUNCTION gescom.txt(v text) RETURNS text LANGUAGE sql IMMUTABLE AS $f$
  SELECT NULLIF(btrim(coalesce(v, '')), '') $f$;
CREATE TABLE IF NOT EXISTS gescom.fichiers (nom_table text PRIMARY KEY, fichier text, lignes integer, colonnes integer,
  charge_le timestamp);
""")
        # fichiers regroupés par table (morceaux d'un même fichier GESCOM : mêmes colonnes)
        tables = {}
        for f in fichiers:
            tables.setdefault(nom_table(f), []).append(f)
        for table, morceaux in sorted(tables.items()):
            lignes = []
            entete = None
            for f in morceaux:
                contenu = lire_csv(os.path.join(dossier, f))
                if not contenu:
                    continue
                if entete is None:
                    entete = contenu[0]
                elif contenu[0] != entete:
                    raise SystemExit('colonnes différentes entre les morceaux de %s : %s' % (table, f))
                lignes.extend(contenu[1:])
            if entete is None:
                continue
            vus = set()
            cols = [nom_colonne(t, vus) for t in entete]
            noms = ', '.join(morceaux)
            out.write("\n-- %s (%d lignes)\nDROP TABLE IF EXISTS gescom.%s;\n" % (noms, len(lignes), table))
            out.write("CREATE TABLE gescom.%s (%s);\n" % (table, ', '.join('"%s" text' % c for c in cols)))
            out.write("COPY gescom.%s FROM STDIN WITH (FORMAT csv, DELIMITER ';', NULL '\\N');\n" % table)
            w = csv.writer(out, delimiter=';', lineterminator='\n')
            for r in lignes:
                r = (r + [''] * len(cols))[:len(cols)]
                w.writerow(r)
            out.write("\\.\n")
            out.write("INSERT INTO gescom.fichiers VALUES ('%s', '%s', %d, %d, now()) ON CONFLICT (nom_table) DO UPDATE "
                      "SET fichier = EXCLUDED.fichier, lignes = EXCLUDED.lignes, colonnes = EXCLUDED.colonnes, "
                      "charge_le = now();\n" % (table, noms.replace("'", "''"), len(lignes), len(cols)))
            print('ok %-40s -> gescom.%-22s %7d lignes %4d colonnes' % (noms[:40], table, len(lignes), len(cols)))
        out.write("\nCOMMIT;\nSELECT nom_table, lignes, colonnes, fichier FROM gescom.fichiers ORDER BY nom_table;\n")


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])

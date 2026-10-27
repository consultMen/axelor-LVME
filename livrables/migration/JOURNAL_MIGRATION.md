# Journal de la migration GESCOM → LVME (Axelor)

Base du rapport de migration remis au client. Tenu au fil des étapes : fichiers reçus, correspondances, règles,
décisions, contrôles, points ouverts.

## 1. Préparation (27/10/2026)

- **Purge des données de test** (PROD_90), en prod et en local. Sont supprimés les commandes, arrivages, BL, lots,
  stock, factures de test, tiers, articles et familles. Le paramétrage est gardé (société, utilisateurs, frigos,
  vues, menus, impressions, taxes, comptes) et les compteurs sont remis à 1.
  - Données supprimées en prod : 1 790 + 3 504 tiers, 1 852 articles, 80 familles, 6 838 commandes fournisseurs,
    6 874 arrivages et BL, 18 046 lots, 55 commandes clients, 6 factures de test.
- **Listes de référence gardées et complétées** depuis GESCOM, sans doublon (décision du 27/10) : conditionnements,
  groupements, bateaux, containers, marques, zones de pêche, origines, modes de pêche, unités.
- **Source :** les données GESCOM d'octobre 2026 (dossier `pi_sofrimar_data`), au format HFSQL Classic, 243 tables
  et 2,9 Go. Le travail se fait sur une copie, l'original reste intact.
  - Le dossier ne contient pas de fichier d'analyse (`.WDD`), donc pas d'export automatique possible.
  - Les tables sont exportées une par une en CSV (`;`, UTF-8, noms des colonnes en 1re ligne) depuis le Centre de
    Contrôle HFSQL.
- **Archive :** chaque CSV est chargé tel quel dans le schéma `gescom` de la base (une table par fichier, toutes les
  colonnes), avec la liste des fichiers chargés dans `gescom.fichiers`. Aucune donnée GESCOM n'est perdue, même
  sans équivalent dans Axelor.
  - Outil : `livrables/migration/outils/gen_archive_gescom.py`.
  - Script produit : `MIG_00_archive_gescom.sql`.

## 2. Fichiers reçus

| Fichier exporté | Table archive | Lignes | Remarque |
|---|---|---|---|
| ARTICLESOCT.csv | gescom.articles | 1 872 | 103 colonnes |
| FAMILLE_ARTCILESOCT.csv | gescom.famille_articles | 66 | |
| SFAMILLEARTICLESOCT.csv | gescom.sfamille_articles | 14 | |
| UNITEVENTEOCT.csv | gescom.unite_vente | 16 | |
| marqueOCT.csv | gescom.marque | 355 | |
| ORIGINEOCT.csv | gescom.origine | 121 | |
| zonepecheoct.csv | gescom.zone_peche | 33 | |
| ModePECHEOCT.csv | gescom.modepeche | 8 | |
| table_baseOCT.csv | gescom.table_base | 993 | table des paramètres GESCOM (TVA, modes de règlement…) |
| GENCODE_ARTICLESOCT.csv | gescom.gencod_articles | 66 | **à refaire** : copie exacte du fichier des familles |

PARAMETRES_TAXES : table vide dans GESCOM. Les taux de TVA sont dans `table_base`.

## 3. Étape 01 : unités, familles, articles (`MIG_01_articles.sql`)

| GESCOM | Axelor |
|---|---|
| ARCLEUNIK | clé GESCOM `import_id = GESCOM-ART-<n>` (sert à relier les lots, commandes et arrivages) |
| REF | code article |
| DESI | désignation ; nom complet `[REF] DESI` |
| IDFAMART (FAMILLE_ARTICLES) | catégorie d'article (famille), avec code et libellé GESCOM |
| uve / UVA | unité de vente / d'achat (UNITE_VENTE complète la liste des unités) |
| PDSCOLIS (sinon poi) | poids colis |
| PVENTE / PVENTE_TTC / PACHAT / PXREVT | prix de vente HT / TTC, prix d'achat, prix de revient |
| GENCOD | gencode (les « 0000000000000 » sont ignorés) |
| REFDOUANE / REFFOU / NOM_SCIEN | réf. douanière / réf. fournisseur / nom scientifique |
| RETIRE | article archivé |
| FOCLEUNIK | fournisseur habituel, relié à l'étape des tiers |

**Règles appliquées :**
- Réglages d'un article créé à l'écran : stockable, vendable, achetable, lot automatique à l'achat, famille comptable
  « Produit surgelé », euro.
- Unité : unité de vente, sinon unité d'achat, sinon KG.
  - 1 132 articles n'ont pas d'unité de vente dans GESCOM. Tous sont anciens (aucune réception depuis 2024) et 781
    n'ont aucun prix.
- 151 articles n'ont pas de famille dans GESCOM (IDFAMART = 0). Ils restent sans famille.
- Unités : 15 unités GESCOM ajoutées ; « Sac » existait et sert pour SAC.
- Restent seulement dans l'archive `gescom.articles` : marque, origine, zone de pêche, conditionnement (COND),
  durabilité, stock mini, promos, mémos de prix, cdv, sous-famille (IDSFAMART, 56 articles).
  - Dans LVME, marque, origine, zone et conditionnement se saisissent sur les lignes d'achat et d'arrivage.

**Contrôle (essai local, annulé) :** 1 872 articles GESCOM → 1 872 articles Axelor ; 66 familles ; 0 article sans
unité.

## 4. Points ouverts à faire préciser par le client

- **cdv** (931 articles, ex. 100 403 ; 210 322) : signification inconnue. Pas trouvé dans `table_base`. Gardé dans
  l'archive.
- **CODE = ART / DEF / DIV** sur les articles : signification à confirmer. Tous sont repris.
- **TVA** : dans GESCOM, tous les articles sont à 5,5 %.
  - `tva` = 4 → TVAPRO1 « ventes marchandises 5,5 % » ; `tva` = 382 → TVAPRO8 « R.R.R. accordées 5,5 % ».
  - Dans Axelor, la famille comptable « Produit surgelé » applique la « TVA taux normal ».
  - Paramétrage comptable à vérifier avec le client (non modifié par la migration).

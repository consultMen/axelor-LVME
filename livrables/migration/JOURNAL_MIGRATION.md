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
| GENCODE_ARTICLESOCT.csv | — | — | écarté : copie du fichier des familles ; GENCOD_ARTICLES et CLIENT_GENCOD sont vides dans GESCOM (gencode des articles repris depuis ARTICLES.GENCOD) |

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

**Contrôle (base locale, 27/10/2026) :** identique entre GESCOM et Axelor : 1 872 articles, dont 884 avec prix de
vente, 343 avec gencode, 217 avec réf. douanière, 487 avec nom scientifique ; 66 familles ; 15 unités ajoutées ;
0 article sans unité.

## 3 bis. Étape 02 : tiers (`MIG_02_tiers.sql`)

**Fichiers :**
- CLIENTS (2 186), clientAD (110 adresses de livraison), FOU (1 371), TRANSPORTEUR (50), commercial (33) ;
- SECTEUR (16), groupement (55), FAMILLES_CLIENTS (9), pays (41), clientcoditour (71) ;
- table_base (conditions RGT… et modes MODRGT…).
- Tables vides dans GESCOM : CODE_RGT, MODE_RGT (les règlements sont dans table_base) et rfa_client (le % RFA est
  dans CLIENT.rfa).

**Listes complétées :** 34 pays, 16 secteurs, 9 catégories de clients, 55 groupements (avec % RFA), 35 conditions de
paiement (n jours date de facture ou fin de mois, jour d'échéance « le 10 »…).

**Modes de paiement** (Axelor existants) :
- VIREMENT → Enc. Virement ; CHÈQUE → Enc. Chèque ; ESPÈCES → Enc. Espèces ; CB → Enc. Carte bancaire ;
- TRAITE, TRAITE DIRECTE, BILLET À ORDRE → Enc. LCR ;
- PAIEMENT LIVRAISON, SANS RÈGLEMENT → Enc. Autre ;
- fournisseurs : VIREMENT → Déc. Virement.

**Commerciaux :** les 33 commerciaux GESCOM deviennent des utilisateurs Axelor, avec le code `com<code GESCOM>`
(ex. com03 = MICHELE BARTOLINI), bloqués et sans mot de passe utilisable (décision du 27/10). À activer pour ceux qui
se connecteront.

**Clients :**

| GESCOM | Axelor |
|---|---|
| CLCLEUNIK | clé GESCOM `GESCOM-CLI-<n>` |
| REFCPT | code client (les deux codes sont conservés, décision du 27/10) |
| LIBELLE, ADR1-3, CODP, VILLE, CODPAY | nom, adresse principale, pays |
| TEL, PORTABLE, ADEMAIL | téléphone, portable, e-mail |
| FAX, NOTES, CODE_NAF | dans la description |
| HORAIRE | commentaire de livraison |
| SIRET (hors 000…), TVAINTRA | SIRET, n° TVA intracom. |
| SECTEUR / FAMILLECLT / GROUP_1 | secteur / catégorie / groupement |
| rfa / POURC_COMM / REMMAX | % RFA / % commission / % remise facture |
| MODREGT / REGL1 | condition / mode de paiement ; MODREGT = COMPTANT → case « Client comptant » (266) |
| TRANSPORTEUR / COMMERCIAL | transporteur / commercial (utilisateur) |
| PORT_PAYE, RETIRE | port payé, client archivé (258) |
| DEV = 66 | dollar |
| NOMRESP | contact du client (1 768) |
| clientcoditour | code Coditour |
| clientAD | adresses de livraison (110) |

**Fournisseurs :** code (REFCPT), nom, pays, adresse et contacts quand ils existent (peu remplis dans GESCOM),
condition / mode de paiement, devise, SIRET, TVA.
- 173 codes fournisseurs étaient déjà pris par un client (même REFCPT). Ils sont repris en `F-<code>`.
- Le fournisseur habituel est relié à 1 548 articles (FOCLEUNIK).

**Transporteurs :** nom, adresse, téléphones, e-mail, contact. EN_ACTIVITE vaut 0 pour les 50 transporteurs GESCOM
(champ non utilisé : GXO sert à 557 clients) ; il n'est donc pas repris, aucun transporteur n'est archivé.

**Villes :** la liste des villes Axelor est complétée avec 1 214 villes (nom, code postal, pays) et reliée aux
adresses migrées (listes Clients / Fournisseurs, recherche par ville, impressions).

**Contacts des fournisseurs :** CONTACT et CONTACT_CIAL de FOU deviennent des contacts. Il n'y en a que 2 : ces
colonnes sont presque vides dans GESCOM.

**Chaque client et fournisseur** est rattaché à la société LVME, avec les comptes client / fournisseur par défaut de
la configuration comptable.

**Restent dans l'archive :** encours, plafond de crédit, client payeur / central, RIB / IBAN / BIC, domiciliation,
tournée, tarif, type de BL, périodicité de facturation, GROUP_2, % frais congélation (2 clients, 1,5 % : le taux se
règle sur la commande).

**Contrôle (essai local, annulé) :**
- identique entre GESCOM et Axelor : 2 186 clients, 1 371 fournisseurs, 50 transporteurs, 110 adresses de
  livraison, 266 clients comptant, 33 commerciaux ;
- d'après GESCOM : 98 clients sans secteur, 22 sans groupement et 92 sans adresse.

## 4. Points ouverts à faire préciser par le client

- **cdv** (931 articles, ex. 100 403 ; 210 322) : signification inconnue. Pas trouvé dans `table_base`. Gardé dans
  l'archive.
- **CODE = ART / DEF / DIV** sur les articles : signification à confirmer. Tous sont repris.
- **TVA** : dans GESCOM, tous les articles sont à 5,5 %.
  - `tva` = 4 → TVAPRO1 « ventes marchandises 5,5 % » ; `tva` = 382 → TVAPRO8 « R.R.R. accordées 5,5 % ».
  - Dans Axelor, la famille comptable « Produit surgelé » applique la « TVA taux normal ».
  - Paramétrage comptable à vérifier avec le client (non modifié par la migration).
- **Conditions de paiement** : les échéances (n jours date de facture / fin de mois, jour « le 10 ») ont été
  traduites en conditions Axelor. Le calcul des échéances est à vérifier avec le client sur une facture test.
- **Modes de paiement** traite / billet à ordre : repris en « LCR » dans Axelor, à confirmer.
- **Commerciaux** : indiquer lesquels doivent pouvoir se connecter (activation et mot de passe).

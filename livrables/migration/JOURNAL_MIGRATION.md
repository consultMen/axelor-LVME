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

## 3 ter. Étape 03 : listes des lignes d'achat / d'arrivage (`MIG_03_listes_achat.sql`)

| GESCOM | Axelor | Résultat (essai local) |
|---|---|---|
| CONDITIONNEMENT (626) | conditionnements (code, libellé), liste complétée | 626 (3 existaient) |
| MARQUE (355) | liste de choix « Marque » des lignes | 351 (« ??? » et doublons écartés) |
| ORIGINE (121) | listes de choix « Origine » des lignes et des filtres | 121 |
| ZONE_PECHE (33) | liste de choix « Zone de pêche » | 30 (libellés en double) |
| MODEPECHE (8) | liste de choix « Mode de pêche » | 8 |
| NOMSCIENTIFIQUE (2 979) | nom scientifique des articles qui n'en avaient pas | 1 060 articles (487 avant) |

- Avant cette étape, Marque, Origine, Zone et Mode de pêche étaient en texte libre dans Axelor : les listes
  n'existaient pas.
- La valeur enregistrée est le libellé GESCOM (VIETNAM, CHALUTS…), lisible dans les écrans et les impressions.
- Les origines sont reprises telles quelles, y compris quelques valeurs à revoir avec le client (« - », « 990232 »).

## 3 quater. Étape 04 : frigos (`MIG_04_frigos.sql`)

- **Décision du 27/10 :** les 87 frigos GESCOM (chambres froides, entrepôts et transitaires comme CAPGEL ou
  EUROFREEZE, et « états » comme A EMBARQUER ou FLOT-FRIPACK) deviennent des emplacements de stock internes de LVME.
- **Réglages :** comme FRIPACK (valorisés, utilisables en achat et en vente) ; code GESCOM = n° de l'emplacement.
- **Adresse :** reprise pour les 3 frigos qui en ont une.
- **FRIPACK** existait déjà : il est réutilisé.
- **Frigo sans nom** (code X) : son code sert de nom. **Second « DIVERS »** (code XXXXXXX) : repris aussi.
- **Contrôle (essai local, annulé) :** 87 frigos GESCOM → 87 emplacements reliés ; 94 emplacements au total.

## 3 quinquies. Étape 05 : arrivages, lots et stock (`MIG_05_arrivages_lots_stock.sql`)

**Fichiers :** ARR_ENTETE (7 444 arrivages), ARR_LIGNE (19 586 lignes), ARTICLES_LOT (19 591 lots). Décisions du
27/10 : historique complet ; lots en stock négatif gardés négatifs.

**Arrivages :**
- Dans GESCOM, l'arrivage est aussi la commande fournisseur. Chaque arrivage donne dans Axelor une commande
  fournisseur et un arrivage, avec le même n° que dans GESCOM.
- Statut : « Réel » si une ligne a un lot réel (7 255 arrivages), sinon « Flottant ».
- En-tête : fournisseur, dates (départ, arrivée, livraison), devise, taux flottant / réel / couvert, frais d'approche,
  bateau (camion ou navire, liste des bateaux complétée), containers (liste complétée), montant, colis, poids.
  Transitaire et gestionnaire sont mis en note.
- 46 arrivages sans fournisseur dans GESCOM sont rattachés à « FOURNISSEUR INCONNU (GESCOM) ».

**Lignes :**
- article, lot, frigo ;
- quantité : quantité entrée du lot, sinon colis × poids colis ;
- colis, poids colis, prix d'achat, prix de revient, montant ;
- conditionnement, origine, zone de pêche, marque, mode de pêche (libellés des listes de l'étape 03) ;
- DLC, date de congélation, lot fournisseur.

**Lots et lots fournisseur :**
- les lots reprennent le n° interne, le lot fournisseur, la DLC, le prix de revient, le fournisseur et « lot vérifié » ;
- les lots fournisseur sont créés par fournisseur + article + n° de lot fournisseur.

**Stock :**
- Pour chaque lot, entrées − sorties GESCOM (QENT − QSOR), dans le frigo de son arrivage.
- Les sorties apparaissent donc dans Axelor (entrées − stock) sans reprendre tout de suite l'historique des BL.
- 680 lots ont du stock, dont 26 en négatif (gardés). Valeur au prix de revient : **6 793 063 €, identique à GESCOM**.

**Stock en mer (lots flottants), décision du 28/10/2026 :**
- Comme dans GESCOM, le stock d'un lot flottant (marchandise partie, quel que soit le transport) = entrées − sorties.
  Les sorties sont les ventes et réservations déjà faites sur le lot.
- L'écran État des stocks (PROD_97) affiche le flottant ainsi, avec ses sorties et ses commandes.
- La ligne de lot d'un flottant porte (entrées − sorties) − quantité de l'arrivage. À la réception dans Axelor, la
  quantité reçue s'y ajoute et le stock en frigo devient entrées − sorties.
- Les lignes d'arrivage sans frigo dans GESCOM vont dans FRIGO. Les lots sans ligne d'arrivage vont dans le frigo de
  leur arrivage GESCOM.
- **Contrôle lot par lot (essai local, annulé) :** 0 écart sur 19 591 lots entre l'écran et GESCOM (entrées −
  sorties). Valeur au prix de revient : 6 790 986 € des deux côtés.

**Articles :** ceux qui n'ont ni prix d'achat, ni prix de revient, ni poids colis sont complétés avec leur dernier
arrivage réel. Les valeurs déjà présentes ne sont pas touchées.

**Cas particuliers GESCOM, tous repris (lots entièrement vendus, sans stock) :**
- **Article FILBROZZ160** : il n'existe plus dans ARTICLES (arrivage 140335, lot 1371205). Il est créé archivé,
  avec la mention « supprimé dans GESCOM ».
- **Deux lots en double** dans ARTICLES_LOT : SEIENESP402 lot 2510 et COQTEL000 lot « 2978 NSF », dont un avec un
  espace en trop. Les deux exemplaires sont gardés, le second avec « (2) » ajouté au n°.

**Réel / Flottant :**
- Dans GESCOM, une ligne n'a un lot réel (`LOT_REEL`) qu'après la réception. Avant, elle n'a qu'un lot flottant
  (`LOT_FL`).
- Les 7 255 arrivages avec au moins un lot réel sont donc « Réel », les 189 autres « Flottant ».
- Les mettre tous en Flottant fausserait la Synthèse des Arrivages, l'État des stocks, l'Historique produit et la
  Rotation (réceptions depuis 2014 vues comme jamais arrivées). C'est à confirmer avec le client.

**Arrivages flottants (189), vérifiés le 28/10 :**
- **155 sont vides dans GESCOM** : un en-tête sans aucune ligne dans ARR_LIGNE, avec des totaux à 0. Ils datent de 2014
  à 2026, 81 sans date : sans doute créés puis jamais remplis ou abandonnés. Ils sont repris tels quels (Flottant,
  0). Le client doit dire s'il faut les passer en « Annulé ».
- **34 ont des lignes** (94 lignes avec quantité, prix et lot). GESCOM laisse à 0 les totaux de l'en-tête d'un
  flottant : ils sont calculés à partir des lignes (colis, poids, montant HT), comme Axelor à l'enregistrement. Les
  totaux GESCOM non nuls restent prioritaires.

**Écran des lignes d'arrivage (vérifié le 28/10) :**
- Les lignes sont de type « Standard » : une première version les avait mises en « Titre » et elles s'ouvraient comme
  un simple libellé.
- La colonne « Prix Revient » (prix de revient au kg) et « Nb unt ou Poids / Colis » sont remplies.

**Fiche « Ligne d'arrivage » complétée (28/10) :**
- colis par couche (11 492 lignes) et par palette (14 091) ;
- unités total ;
- taux de TVA 5,5 % (TVA déductible, R2_D) sur les 11 705 lignes où GESCOM l'indique ;
- lot fournisseur de la ligne GESCOM quand le lot n'en avait pas : 15 585 lignes ont maintenant un lot fournisseur.
- La ligne « Flottant » de la fiche n'est affichée que pour un arrivage non réalisé ; pour un arrivage réel, seule la
  ligne « Réel » est remplie (fonctionnement de l'écran).

**Mode de transport :**
- Il vient du type d'arrivage GESCOM (`typ_arrivage` : 379 = CAMION, 380 = BATEAU, 381 = AVION ; mode « Avion »
  ajouté).
- À défaut, il vient de la colonne bateau.
- Résultat : 3 241 camion, 1 649 bateau, 1 avion, 2 553 anciens arrivages sans information.

**Contrôle (essai local, annulé) :**

| | GESCOM | Axelor |
|---|---|---|
| Arrivages | 7 444 | 7 444 (7 255 réels) |
| Lignes | 19 586 | 19 586 |
| Lots | 19 591 | 19 591 |
| Valeur du stock | 6 793 063 € | 6 793 063 € |

Durée de l'essai : 1 min 30.

## 3 sexies. Années mal saisies dans GESCOM (corrigées le 28/10/2026, `MIG_05`)

Des dates des fichiers GESCOM ont une année impossible (faute de frappe). Décision : corriger les années évidentes ;
l'archive `gescom` garde les dates d'origine.

- **Règle 1, année 21xx** (siècle mal tapé) : moins 90 ans. Exemple : congélation 11/02/2103 → 11/02/2013, DLC
  31/01/2105 → 31/01/2015.
  - Concerne 23 lots des arrivages 131218 à 150627 (DLC et congélation) et le lot 190777A (entrée 22/07/2109 →
    22/07/2019, DLC 12/07/2111 → 12/07/2021).
- **Règle 2, date d'arrivage, de départ, de livraison ou de congélation en 2030 ou après** : année de l'arrivage
  (deux premiers chiffres de son numéro).

  | Arrivage / lot | Date GESCOM | Date reprise |
  |---|---|---|
  | 260822, livraison | 18/08/2260 | 18/08/2026 |
  | 260643, départ | 19/06/2260 | 19/06/2026 |
  | 251101, départ | 25/01/2062 | 25/01/2025 |
  | 250553, livraison | 30/08/2050 | 30/08/2025 |
  | 240659, départ | 28/06/2040 | 28/06/2024 |
  | 240234 (lot 4039/240234), congélation | 24/02/2040 | 24/02/2024 |
  | lot 250531, entrée | 25/05/2031 | non reprise (la date d'entrée vient de l'arrivage 250531) |

- **Non corrigées, à vérifier par le client** (la bonne valeur n'est pas évidente) :
  - DLC 15/02/2060 (lot 4094/240219, congelé le 15/02/2024) et 01/10/2040 (lot 3930/240421) ;
  - congélation 12/07/2027 (arrivage 190532, DLC 01/07/2029) et 21/04/2028 (arrivage 260121) ;
  - congélation 01/10/1962 (arrivage 210638, lots 11140595B et 2691).

## 3 septies. Étape 06 : commandes clients (`MIG_06_commandes_clients.sql`, 28/10/2026)

Fichiers : CCE (en-têtes, 55 304, exporté en 4 morceaux), CCD (lignes, 366 395, exporté en 9 morceaux par année),
CLIENT_RESERV (239). Les morceaux sont regroupés en une table dans l'archive (`gescom.cce`, `gescom.ccd`).

- **Structure GESCOM** : chaque vente est enregistrée deux fois.
  - TYPE_FACTURE 2 = la commande / le BL (27 730, + 2 de type 1). Le n° de BL est le n° de commande.
  - TYPE_FACTURE 3 = la facture (27 572) : n° de facture, date, échéance ; elle regroupe les lignes d'une ou
    plusieurs commandes (champ IDPOSITION de la commande).
  - POSITION n'est pas un état mais une zone de clientèle : 1 France, 2 Corse, 5 étranger, 0 cas isolés.
  - Lignes : P produit, T texte (« Cde n° … du … »), M correction manuelle (prix, avoir), D (6 lignes).
- **Décisions** : tout l'historique ; factures **non recréées** en factures Axelor (option b, pas d'écritures
  comptables en double) : n° de facture, date et échéance notés sur la commande ; le détail reste dans l'archive.
- **Reprise** :

  | Élément | GESCOM | LVME |
  |---|---|---|
  | Commandes (état Terminée) | 27 732 | 27 732 (27 727 avec n° de facture) |
  | Lignes | 183 166 | 183 166, dont 154 554 avec leur lot |
  | BL réalisés (n° « BL » + n° de commande) | — | 25 771, 154 575 lignes |
  | Chiffre d'affaires HT | 114 557 356 € | 114 557 356 € |

  - Les BL repris ne modifient pas le stock (déjà celui de GESCOM : 6 790 986 € inchangé) ; ils donnent les
    sorties de l'Historique Produit et le n° de BL de la liste des commandes.
  - Ventes à montant négatif : commande marquée « Avoir ».
  - **Marge** : GESCOM ne l'enregistre pas. Elle est calculée par LVME avec sa formule habituelle (montant HT −
    P.R. × quantité), le P.R. étant le prix de revient enregistré par GESCOM au moment de la vente (décision du
    28/10/2026). Historique : 16,0 M€ de marge, soit 13,97 % du CA.
  - Paiement, transporteur, % RFA / commission, coût du port, remise et une note (contact, téléphone, e-mail, zone,
    saisi par, affacturage, colis, poids) sont repris sur la commande ; fournisseur et coefficient de poids net sur
    les lignes. 146 commandes de clients sans adresse dans GESCOM n'ont pas de ville.
  - Rapport d'incohérences : les écarts « livré ≠ facturé » et « reçu ≠ facturé » ne portent plus sur l'historique
    GESCOM (factures restées dans GESCOM) ; ils signalaient 19 436 faux écarts (`PROD_102`).
- **Gardés dans l'archive seulement** : les factures (type 3) et CLIENT_RESERV (client livré → client de
  réservation : pas de champ équivalent dans LVME pour l'instant).
- **À noter** : 133 numéros de CCE n'ont aucune ligne dans CCD ; 1 fournisseur créé par l'étape 05 pour un
  arrivage dont le fournisseur manque dans FOU (1 372 fournisseurs pour 1 371 dans FOU) ; dernière commande
  GESCOM le 17/09/2026.

## 3 octies. Étape 07 : règles de RFA par produit (`MIG_07_rfa_articles.sql`, 28/10/2026)

- RFA_ART : 50 règles reprises sur 50, écran « Règles RFA par produit ». Toutes de type client + article, à 2,5 %, du
  01/04/2026 au 30/06/2026 : SOBRAG1 (Relais d'Or Côte d'Azur) 26 articles, LJM13 16, RPDA26 8.
- La « Liste des RFA par produit / facture » se calcule sur les factures LVME : vide pour l'historique (factures
  GESCOM non recréées, option b) ; elle se remplira avec les factures faites dans LVME.

## 3 nonies. Étape 08 : prix négociés (`MIG_08_prix_negocies.sql`, 28/10/2026)

- PRIX_NEGOC : suivi des prix négociés par client et article (suite du palmarès « pour établissement prix ») : ventes
  de la période étudiée (2023 à 2025 : colis, quantité, poids, CA, dernière vente, dernier prix au kg, rang, dernier
  conditionnement), prix négocié et sa période de validité. 2 193 lignes reprises sur 2 194 (1 ligne vide dans
  GESCOM : ni client ni article), dont 1 558 avec un prix négocié ; 162 en vigueur au 28/10/2026 (8 clients).
- PRIX_NEGOCE_COUT : % RFA, % commission, congélation, coût du port, remise, par client, article et période de validité
  du prix : 83 rattachés à leur prix, 8 repris en ligne à part ; 1 non repris (client « 8.6 » inconnu dans GESCOM).
- Écran Ventes > Prix négociés (liste, fiche, impression). Décision : le prix négocié n'est pas encore proposé
  automatiquement sur la ligne de commande client (à décider plus tard).

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

# Déploiement prod LVME — RFA (MIG_07), prix négociés (MIG_08, PROD_105), liste Articles (PROD_107), listes sur 2 mois (PROD_108), totaux de l'État des stocks (PROD_109)

Déjà en prod : jusqu'à PROD_104, PROD_106 et MIG_06. Code à déployer (recompiler) : modèle PrixNegocie, impression
« Prix négociés », F2 nouvelle ligne et liste Articles en un clic (js/lvme.js, css/lvme.css), recherche d'article par
désignation / référence fournisseur / gencode (Product.fullName), totaux de l'État des stocks par lots, impressions
des listes en PDF et en Excel (.xlsx, bouton « Excel » à côté de chaque impression ; devis, commandes et bons d'arrivage en PDF).
**Correctif urgent** : bouton Dupliquer en erreur sur les commandes reprises de GESCOM (« numberOfPeriods ») → code
LvmeDuplicationService + PROD_110 (peut être lancé seul tout de suite, sans redémarrage).

1. **PC** : `git push origin main`
2. **Serveur** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_avant_mig08_$(date +%F_%H%M).dump`
3. Re-clone et build comme d'habitude (`git clone …`, `./gradlew war -x test`) ; `git log --oneline -1`.
4. `sudo systemctl stop axelor-tomcat`
5. Depuis `~/src/axelor-LVME` :
   `for f in livrables/migration/MIG_07_rfa_articles.sql livrables/migration/MIG_08_prix_negocies.sql livrables/PROD_105_prix_negocies.sql livrables/PROD_107_liste_articles_gescom.sql livrables/PROD_108_listes_periode_2_mois.sql livrables/PROD_109_etat_stock_totaux_excel.sql livrables/PROD_110_commandes_gescom_duree_periode.sql livrables/PROD_111_article_designation_fournisseur_inconnu.sql livrables/PROD_112_fournisseur_type_europe_international.sql livrables/PROD_113_kanban_achats_par_dossier.sql livrables/PROD_114_loupes_fournisseurs_clients_gescom.sql livrables/PROD_115_impressions_pdf_et_excel.sql livrables/PROD_116_periode_2_mois_stocks_historique.sql; do psql -U axelor -d axelor -v ON_ERROR_STOP=1 -f $f || break; done`
   → `rfa_gescom = rfa_axelor = 50` ; `prix_gescom 2194 / prix_axelor 2193`, `avec_prix_negocie 1558` ; PROD_105 :
   `vues 3, menu 1, actions 5` ; PROD_107 : `2, 1, 1` liste GESCOM ; PROD_108 : 3 × `t` ; PROD_109 : `action-method`,
   `barre_totaux t` ; PROD_110 : `commandes_sans_duree 0` ; PROD_111 : `article_code_seul 0`, inconnu `archived t` ; PROD_112 : `2 | t | t` ; PROD_113 : `sans_ordre 0` ; PROD_114 : `9 | 8` ; PROD_115 : `14 | 14` ; PROD_116 : `3 | t`. (L'archive MIG_00 sur le serveur contient déjà RFA_ART et PRIX_NEGOC.)
6. Bascule du war (avec `~/axelor-config.prod.properties`), `sudo systemctl start axelor-tomcat && sudo systemctl restart nginx`.

---

# Déploiement prod LVME — commandes clients GESCOM (MIG_06), PROD_102 à PROD_104 du 28/10/2026

Déjà en prod : PROD_94 à 101, MIG_00 à MIG_05. Code à déployer (recompiler) : impressions État des stocks / Fournisseur
et sur une ligne (Java + 2 modèles BIRT), corrections Historique Produit et Aides aux Réapprovisionnements.

| Script | Contenu |
|---|---|
| MIG_00 | Nouvelle archive GESCOM (134 Mo, 34 tables avec CCE, CCD, CLIENT_RESERV) |
| MIG_06 | Commandes clients GESCOM : 27 732 commandes, 183 166 lignes, 25 771 BL, marge, n° de facture (≈ 15 min) |
| PROD_102 | Rapport d'incohérences sans l'historique GESCOM |
| PROD_103 | Rapport d'incohérences présenté comme les écrans GESCOM |
| PROD_104 | Cession depuis Opérations Diverses + fenêtre CESSION de Stock comme GESCOM ; 3 impressions en bas de l'État des stocks |

1. **PC** : `git push origin main` ; envoyer `MIG_00_archive_gescom.sql` dans `/home/axelor/` (remplace l'ancienne).
2. **Serveur** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_avant_mig06_$(date +%F_%H%M).dump`
3. Re-clone et build comme d'habitude (`git clone …`, `./gradlew war -x test`) ; `git log --oneline -1`.
4. `sudo systemctl stop axelor-tomcat`
5. Depuis `~/src/axelor-LVME` :
   `psql -U axelor -d axelor -v ON_ERROR_STOP=1 -f ~/MIG_00_archive_gescom.sql && for f in livrables/migration/MIG_06_commandes_clients.sql livrables/PROD_102_incoherences_hors_gescom.sql livrables/PROD_103_incoherences_ecran_gescom.sql livrables/PROD_104_cession_od_impressions_etat_stock.sql; do psql -U axelor -d axelor -v ON_ERROR_STOP=1 -f $f || break; done`
   (≈ 15 min, ne pas interrompre) → commandes 27 732 / 27 732, lignes 183 166 / 183 166, ca_gescom = ca_axelor =
   114 557 356. MIG_01 à 05 ne sont pas à relancer.
6. Bascule du war (avec `~/axelor-config.prod.properties`), `sudo systemctl start axelor-tomcat && sudo systemctl restart nginx`.

---

# Déploiement prod LVME — écrans PROD_94 à 101 puis migration GESCOM (MIG_00 à MIG_05) du 28/10/2026

Déjà en prod : jusqu'à PROD_93 + purge PROD_90. Code à déployer : tout `main` (commit 1b03686 ou plus récent).

| Script | Contenu |
|---|---|
| PROD_94 | Listes Clients / Fournisseurs / Transporteurs comme GESCOM |
| PROD_95 | RFA par produit (règles) et liste des RFA par produit / facture |
| PROD_96 | Palmarès Client / Produits (impression) |
| PROD_97 | État des stocks : lots flottants comme GESCOM |
| PROD_98 | Interrogation Produit |
| PROD_99 | Opérations Diverses sur les Stocks / Lots (+ emplacement OPERATIONS DIVERSES) |
| PROD_100 | Aides aux Réapprovisionnements, Etat des besoins (impression) |
| PROD_101 | Historique Produit sans produit = tous les produits |
| MIG_00 | Archive GESCOM (schéma `gescom`) : **fichier hors dépôt**, `MIG_00_archive_gescom.sql` (18,5 Mo, données clients) |
| MIG_01 à 05 | Articles, tiers, listes d'achat, frigos, arrivages / lots / stock |

Ordre : les écrans d'abord (les vues SQL doivent exister avant le 1er démarrage du nouveau code), un démarrage pour
qu'Axelor ajoute les nouvelles colonnes, puis la migration Tomcat arrêté.

1. **PC** : `git push origin main` ; envoyer `C:\Users\zakar\Documents\migration_lvme\sql\MIG_00_archive_gescom.sql`
   sur le serveur dans `/home/axelor/` (fenêtre SSH : ⚙ « Importer un fichier », ou `scp`).
2. **Serveur — sauvegarde** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_avant_migration_$(date +%F_%H%M).dump`
3. **Base vide ?** `psql -U axelor -d axelor -c "SELECT (SELECT count(*) FROM base_product) produits, (SELECT count(*) FROM base_partner) tiers, (SELECT count(*) FROM purchase_purchase_order) achats, (SELECT count(*) FROM sale_sale_order) ventes"`
   → presque tout à 0 (purge) ; sinon s'arrêter et m'envoyer le résultat.
4. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME && git log --oneline -1`
5. **Build** : `cd ~/src/axelor-LVME/open-suite-webapp && chmod +x gradlew && ./gradlew war -x test`
6. **Arrêt** : `sudo systemctl stop axelor-tomcat`
7. **Écrans, depuis `~/src/axelor-LVME`** :
   `for n in 94 95 96 97 98 99 100 101; do psql -U axelor -d axelor -v ON_ERROR_STOP=1 -f $(ls livrables/PROD_${n}_*.sql) || break; done`
8. **Bascule** (comme d'habitude) : war dézippé, **`~/axelor-config.prod.properties` recopié**, ancien `ROOT` mis de côté,
   nouveau `ROOT`, `sudo systemctl start axelor-tomcat` ; attendre que le site réponde (Axelor ajoute les colonnes).
9. **Arrêt pour la migration** : `sudo systemctl stop axelor-tomcat`
10. **Migration, depuis `~/src/axelor-LVME`** (≈ 5 min) :
    `psql -U axelor -d axelor -v ON_ERROR_STOP=1 -f ~/MIG_00_archive_gescom.sql && for n in 01 02 03 04 05; do psql -U axelor -d axelor -v ON_ERROR_STOP=1 -f $(ls livrables/migration/MIG_${n}_*.sql) || break; done`
    → fin de MIG_05 attendue : arrivages 7444 / 7444, lignes 19586 / 19586, lots 19591 / 19591,
    `valeur_stock_totale` = `valeur_stock_gescom` = 6 790 986. Toute erreur : s'arrêter et m'envoyer la sortie.
11. **Démarrage** : `sudo systemctl start axelor-tomcat && sudo systemctl restart nginx` ; Ctrl + F5.
12. **Vérifier** : Clients 2 186, Fournisseurs 1 371, Transporteurs 50, Articles 1 872, État des stocks par lots,
    Interrogation Produit, Historique Produit, Synthèse des Arrivages.

Retour arrière : `sudo systemctl stop axelor-tomcat`, `dropdb -U axelor axelor && createdb -U axelor axelor && pg_restore -U axelor -d axelor --no-owner ~/sauvegarde_avant_migration_*.dump`, remettre l'ancien `ROOT`, redémarrer.

---

# Déploiement prod LVME — écrans GESCOM (PROD_91 à 93) puis purge des données (PROD_90) avant la migration

Déjà en prod : jusqu'à PROD_89. Code à déployer : tout `main` (dernier commit affiché à l'étape 3).
Code : impression Synthèse des Arrivages (Java + reports/LvmeSyntheseArrivages.rptdesign), case `lvmeClientComptant`
sur le tiers, `css/lvme.css` et `js/lvme.js` (F12 sur tous les boutons Fermer / Quitter).

| Script | Contenu |
|---|---|
| PROD_91 | Synthèse des Arrivages comme GESCOM sur un seul écran + bouton « Synthèse » (impression) |
| PROD_92 | Listes Dossiers et Lots Vérifiés comme GESCOM sur un seul écran |
| PROD_93 | Filtres Secteur et Client en compte / comptant de Listes Dossiers (+ colonne `lvme_client_comptant`) |
| PROD_90 | **Purge de toutes les données** (commandes, arrivages, BL, lots, stock, factures de test, tiers, articles, familles) ; paramétrage gardé, compteurs remis à 1 |

1. **PC** : `git push origin main`
2. **Serveur — sauvegarde** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_avant_purge_$(date +%F_%H%M).dump`
3. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME && git log --oneline -1`
4. **Build** : `cd ~/src/axelor-LVME/open-suite-webapp && chmod +x gradlew && ./gradlew war -x test`
5. **Répétition de la purge sur une copie** (la prod n'est pas touchée) :
   `createdb -U axelor axelor_copie && pg_restore -U axelor -d axelor_copie --no-owner ~/sauvegarde_avant_purge_*.dump && cd ~/src/axelor-LVME && psql -U axelor -d axelor_copie -f livrables/PROD_90_purge_donnees.sql`
   → fin attendue : tout à 0 sauf `tiers_gardes` = 1 ; si « Purge arrêtée », ne pas continuer, m'envoyer le message.
   Puis `dropdb -U axelor axelor_copie`.
6. **Arrêt** : `sudo systemctl stop axelor-tomcat`
7. **Scripts, depuis `~/src/axelor-LVME`** :
   `for n in 91 92 93 90; do psql -U axelor -d axelor -v ON_ERROR_STOP=1 -f $(ls livrables/PROD_${n}_*.sql) || break; done`
8. **Bascule** : war de `open-suite-webapp/build/libs/`, dézippé, **`~/axelor-config.prod.properties` recopié**, ancien `ROOT` mis de côté (`mv`), nouveau `ROOT`, `sudo systemctl start axelor-tomcat && sudo systemctl restart nginx`.
9. **Ctrl + F5** ; vérifier : listes vides (commandes, arrivages, articles, clients), Synthèse des Arrivages, Listes Dossiers, Lots Vérifiés, F12.

---

# Déploiement prod LVME — correctifs Kanban, filtres de suivi, corbeille des listes, rotation par transport (PROD_73 à PROD_89)

Déjà en prod : PROD_63 à PROD_72. Code à déployer : tout `main` (Java : lecture de la colonne d'arrivée des Kanban,
annulation d'une commande d'achat par sa fiche, suppression de plusieurs lignes cochées).

| Script | Contenu |
|---|---|
| PROD_73 | Filtres tout prêts des 3 écrans « Suivi des … » ; le bouton « Suivi » garde les filtres de la liste ; corbeille dans l'en-tête des listes des écrans de recherche (contrôle brouillon / annulé pour commandes et arrivages) |
| PROD_74 | Rotation des stocks par lot : filtre Transport (Camion = Europe, Bateau = International) et colonne Transport en couleur |
| PROD_75 | Etat des stocks par lots et liste des achats aux couleurs GESCOM (colonnes GESCOM + Dispo, lignes alternées, cadres de dates ; Numéro Arrivage dans la liste des achats) |
| PROD_76 | Fiche Commande client resserrée pour tenir à l'écran à 100 % (libellés à gauche dans le bloc Client, couleurs du tableau des lignes) ; Finaliser / Confirmation Commande au-dessus de Fermer |
| PROD_77 | Fenêtre Lignes Commandes : % Commission à côté de % RFA sur Produits ; fiche Commande client : « < Commentaire > » recopié aussitôt dans l'onglet Commentaire |
| PROD_78 | Impression interne LVME de la commande client (bouton « Imprimer commande ») : logo LVME, cadres Client / Commande, totaux et lignes aux couleurs de la fiche ; **prérequis : code** (LvmeImpressionController, reports/LvmeCommandeClient.rptdesign) |
| PROD_79 | Écran « Historique prix » GESCOM (F1 de la ligne de commande client) : filtres période / client / produit, colonnes GESCOM (B.L. ou Cde, date, origine, conditionnement, poids, colis, P.V. net, montant) ; **prérequis : code** (SaleOrderLine.lvmeHistoPiece / lvmeHistoDate) |
| PROD_80 | Plus d'emojis dans les écrans LVME : KPI commandes clients / achats (pastilles retirées), boutons d'alerte, cartes des 3 Kanban (texte à la place) |
| PROD_81 | Liste « Commandes clients » sur un seul écran comme GESCOM : recherche sur une bande, boutons Suivi / Nouvelle commande à droite (resserrage dans css/lvme.css) |
| PROD_82 | Liste « Commandes clients » : colonnes N° BL et Préparateur, couleurs GESCOM ; **prérequis : code** (SaleOrder.lvmeNumeroBl) |
| PROD_83 | Écran « Historique Produit » aux couleurs et tailles GESCOM sur un seul écran (repère de l'écran ; présentation dans css/lvme.css) |
| PROD_84 | Bouton « Imprimer » de l'écran Historique Produit : impression LVME avec logo, colonnes et totaux de l'écran ; **prérequis : code** (LvmeHistoriqueProduitController.imprimer, reports/LvmeHistoriqueProduit.rptdesign) |
| PROD_85 | Listes Arrivages (Lancer sous le fournisseur, boutons à droite) et Rotation des stocks (repères) sur un seul écran comme GESCOM ; couleurs GESCOM des arrivages, de la rotation et des achats (css/lvme.css) |
| PROD_86 | Rotation des stocks par lot aux couleurs GESCOM : colonne Nb colis Stock jaune (lignes de totaux jaunes dans css/lvme.css) |
| PROD_87 | Boutons d'impression des listes comme GESCOM : « Imprimer » (achats), « Editer » (arrivages), « Liste des Rotations » (rotation) ; **prérequis : code** (LvmeImpressionListesController, reports/LvmeListe*.rptdesign) |
| PROD_88 | Bouton « Imprimer » de la liste des commandes clients ; listes Articles (ventes / achats) comme GESCOM sur un seul écran ; **prérequis : code** (LvmeImpressionListesController.imprimerCommandesClients, reports/LvmeListeCommandesClients.rptdesign) |
| PROD_89 | Boutons « Imprimer » de l'Historique prix et de l'État des stocks par lots (logo LVME, colonnes et filtres de l'écran, sommes) ; **prérequis : code** (LvmeImpressionListesController.imprimerHistoriquePrix / imprimerEtatStock, reports/LvmeHistoriquePrix.rptdesign, LvmeEtatStockLots.rptdesign) |

Même procédure que ci-dessous (sauvegarde, clone, build, **scripts PROD_73 à 89**, bascule, redémarrage) :
`for n in 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89; do psql -U axelor -d axelor -v ON_ERROR_STOP=1 -f $(ls livrables/PROD_${n}_*.sql) || break; done`

---

# Déploiement prod LVME — lot « Commandes clients GESCOM, Kanban, KPI » du 23/10/2026 (PROD_63 à PROD_72)

Déjà en prod : jusqu'à PROD_62 (+ PROD_60, 61). **PROD_52, 53, 54 (fiches Produit / Fournisseur) NE PAS lancer.**
Code à déployer : tout `main` (dernier commit affiché à l'étape 3). Tous les scripts sont relançables.
**Ordre obligatoire : scripts AVANT le démarrage de Tomcat sur le nouveau code** (colonnes ajoutées par PROD_63, 67, 69, 71).

| Script | Contenu |
|---|---|
| PROD_63 | Fiche Commande client copiée sur GESCOM (+ colonnes `lvme_preparateur`, `lvme_frais_congelation`, `lvme_promo`) ; tableau des lignes GESCOM |
| PROD_64 | Fenêtre « Lignes Commandes » GESCOM (bloc bleu, ligne du bas, boutons, F1, valeurs du lot au choix du lot, Taux TVA, remise à zéro au changement d'article) |
| PROD_65 | Bouton Historique Lot = « Liste des Mouvements de Stock » GESCOM |
| PROD_66 | Bouton Sélect Arrivage = « Sélection Arrivage » GESCOM (le lot choisi remplit la ligne) |
| PROD_67 | Statuts des BL : Brouillon, En cours de préparation, Flottant, Réalisé, Annulé (+ colonne `lvme_bl_flottant`) |
| PROD_68 | Dupliquer / Supprimer (fiches et listes Commandes clients, Achats, Arrivages) ; KPI et alertes des commandes clients |
| PROD_69 | Kanban « Suivi des arrivages » / « Suivi des commandes d'achat » (+ colonnes `lvme_kanban_seq`) |
| PROD_70 | KPI et alertes de la liste des achats fournisseurs |
| PROD_71 | Kanban « Suivi des commandes clients » (+ colonne `lvme_kanban_seq`) |
| PROD_72 | Fiche Commande fournisseur : statuts Brouillon / À embarquer / Flottant / En stock / Annulée |

Code (sans script) : champs calculés (valeurs du lot sur la ligne de commande client, Colis Entrés / Sortis, Colis
Dispo, étapes et retards des Kanban), Java Dupliquer / Supprimer / déplacement des cartes Kanban, `css/lvme.css` et
`js/lvme.js` (F1, Sélect Arrivage, couleurs des fenêtres GESCOM, boutons).

1. **PC** : `git push origin main`
2. **Serveur — sauvegarde** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
3. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME && git log --oneline -1`
4. **Build** : `cd ~/src/axelor-LVME/open-suite-webapp && chmod +x gradlew && ./gradlew war -x test`
5. **Scripts, depuis `~/src/axelor-LVME`**, dans l'ordre, chacun avec `psql -U axelor -d axelor -v ON_ERROR_STOP=1 -f livrables/PROD_N_….sql` :
   PROD_63, 64, 65, 66, 67, 68, 69, 70, 71, 72 (s'arrêter au premier ERREUR et me l'envoyer)
6. **Bascule** : war de `open-suite-webapp/build/libs/`, dézippé, **`~/axelor-config.prod.properties` recopié**, ancien `ROOT` mis de côté (`mv`), nouveau `ROOT`, redémarrage Tomcat + nginx.
7. **Ctrl + F5** ; vérifier : Listes Commandes Clients (KPI, alertes, Dupliquer / Supprimer, Suivi des commandes
   clients), une commande client et une ligne (bloc bleu, F1, Sélect Arrivage, Historique Lot), un BL (statuts, Flottant),
   liste des achats (KPI, Suivi des commandes d'achat), Arrivages (Suivi des arrivages, déplacement d'une carte).

---

# Déploiement prod LVME — lot « Détail des lignes GESCOM » du 15/10/2026 (PROD_50, 51, 55 à 59)

Déjà en prod : PROD_37 à PROD_49. **PROD_52, 53, 54 (fiches Produit / Fournisseur) NE PAS lancer** : en attente des
écrans GESCOM du client. Code à déployer : tout `main` (dernier commit affiché à l'étape 3).

| Script | Contenu |
|---|---|
| PROD_50 | Lot automatique à l'achat sur tous les articles stockables (s'arrête sans rien modifier s'il n'y a pas exactement 1 configuration auto) |
| PROD_51 | Lignes de commande d'achat / d'arrivage : 3 décimales (code : champs vides au lieu de 0, poids total brut à 0) |
| PROD_55 | Détail de la commande fournisseur : intitulés GESCOM, totaux sous les lignes (commande et arrivage) |
| PROD_56 | Colonne Prix Revient = prix de revient saisi ; bouton « Flottant -> A Embarquer » sur l'arrivage |
| PROD_57 | Totaux sous les lignes calculés par le serveur (toutes les lignes, après duplication aussi) |
| PROD_58 | Lignes d'arrivage dans l'ordre GESCOM ; tableau des totaux |
| PROD_59 | Montant ht des lignes d'arrivage = prix d'achat x quantité (code : champ calculé) |

Code (sans script) : impression Arrivage alignée sur la fiche, tableau Flottant / Réel comme GESCOM (Flottant toujours
affiché), Frais Appr. au kg, montant ht des lignes d'arrivage, feuille de style (intitulés de colonnes en entier).

1. **PC** : `git push origin main`
2. **Serveur — sauvegarde** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
3. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME && git log --oneline -1`
4. **Build** : `cd ~/src/axelor-LVME/open-suite-webapp && chmod +x gradlew && ./gradlew war -x test`
5. **Scripts, depuis `~/src/axelor-LVME`** (`cd ~/src/axelor-LVME`) : PROD_50, 51, 55, 56, 57, 58, 59 dans cet ordre
6. **Bascule** : war de `open-suite-webapp/build/libs/`, dézippé, **`~/axelor-config.prod.properties` recopié**, ancien `ROOT` mis de côté (`mv`), nouveau `ROOT`, redémarrage Tomcat + nginx.
7. **Ctrl + F5** ; vérifier une commande fournisseur (détail, totaux, prix revient) et un arrivage (colonnes, montant ht, totaux, Flottant / Réel, Frais Appr., Editer).

---|---|
| PROD_50 | Configuration de lot automatique à l'achat sur tous les articles stockables (articles repris) ; s'arrête sans rien modifier s'il n'y a pas exactement 1 configuration auto |
| PROD_51 | Lignes de commande d'achat / d'arrivage : 3 décimales max à l'affichage (avec le code : champs LVME vides au lieu de 0, poids total brut à 0 par défaut) |

1. **PC** : `git push origin main`
2. **Serveur — sauvegarde** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
3. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME && git log --oneline -1`
4. **Build** : `cd ~/src/axelor-LVME/open-suite-webapp && chmod +x gradlew && ./gradlew war -x test`
5. **Scripts, depuis `~/src/axelor-LVME`** : PROD_50 puis PROD_51 (voir les commandes ci-dessous)
6. **Bascule** : war de `open-suite-webapp/build/libs/`, dézippé, **`~/axelor-config.prod.properties` recopié**, ancien `ROOT` mis de côté (`mv`), nouveau `ROOT`, redémarrage Tomcat + nginx.
7. **Ctrl + F5**, vérifier une nouvelle ligne de commande d'achat (champs vides, 3 décimales, lot AE proposé).

---

# Déploiement prod LVME — lot « Fiches GESCOM » du 14/10/2026 (PROD_37 à PROD_49)

Déjà en prod : PROD_31 à PROD_36. PROD_37 à PROD_41 (lot ci-dessous) sont repris ici : tous relançables,
sans effet s'ils sont déjà passés.
Code à déployer : tout `main` (dernier commit affiché par `git log --oneline -1` à l'étape 3).

Code (sans script) : comme avant, l'arrivage créé au passage de la commande en « Flottant » est **à embarquer**
(lots AE + n°) ; il passe en Flottant (lots FL) par son bouton « A Embarquer -> flottant », puis en Réel à la saisie du réel.
Fiche Arrivage : barre des statuts remise en haut. Lignes de commande client : champs calculés N° Lot / N° Arrivage. Fond bleu des fenêtres de ligne (`css/lvme.css`). Frais d'approche de l'arrivage arrondis à 2 décimales (plus d'erreur « Validation failed … lvmeFraisApproche » à l'annulation).

| Script | Contenu |
|---|---|
| PROD_37 à PROD_41 | voir le lot « Arrivages GESCOM » ci-dessous (lots AE/FL, n° d'arrivage 6 chiffres, fiche Arrivage GESCOM…) |
| PROD_42 | Fiche « Ligne d'arrivage » copie de « Lignes Arrivages » GESCOM + **colonne `nom_scientifique`** sur l'article |
| PROD_43 | N° des arrivages repris de GESCOM sans « RO- » (n°, libellé, origine des lots) ; s'arrête sans rien modifier si un n° existe déjà |
| PROD_44 | Boutons « Historique produit » / « État des stocks par lots » de la ligne, ouverts sur l'article de la ligne |
| PROD_45 | Fiche « Ligne de commande d'achat » copie de « Lignes Arrivages » GESCOM |
| PROD_46 | **Colonne `ref_douaniere`** : « Réf. douanière » saisie sur l'article, affichée sur les deux fiches de ligne |
| PROD_47 | Fiche Commande d'achat condensée comme l'Arrivage (sans barre latérale ni « Paramètres », onglet « Suivi ») |
| PROD_48 | Boutons « Cdes client / Lot » et « Cdes client / produit » sur les deux fenêtres de ligne (écran « Commandes Clients » GESCOM) + fond bleu GESCOM |
| PROD_49 | Fiche Arrivage : barre des étapes Brouillon / A embarquer / Flottant / Réel / Annulé (même présentation que la commande fournisseur) |

1. **PC** : `git push origin main`
2. **Serveur — sauvegarde** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
3. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME && git log --oneline -1` (dernier commit poussé)
4. **Build d'abord** (l'ancienne appli tourne pendant ce temps) : `cd open-suite-webapp && chmod +x gradlew && ./gradlew war -x test && cd ..`
5. **Scripts, depuis `~/src/axelor-LVME`, juste avant la bascule** (enchaîner aussitôt avec l'étape 6) :
   ```
   for f in PROD_37_lot_cree_depuis_achat PROD_38_appliquer_frigo_arrivage PROD_39_lots_ae_fl PROD_40_numero_arrivage_6_chiffres PROD_41_arrivage_condense PROD_42_ligne_arrivage_gescom PROD_43_numero_arrivage_sans_ro PROD_44_boutons_ligne_arrivage PROD_45_ligne_achat_gescom PROD_46_ref_douaniere_article PROD_47_commande_achat_condensee PROD_48_cdes_client_ligne PROD_49_etapes_arrivage; do echo "== $f"; PGOPTIONS='-c lock_timeout=10s' psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/$f.sql > /tmp/$f.log 2>&1 || { echo "ERREUR, voir /tmp/$f.log"; break; }; tail -4 /tmp/$f.log; done
   ```
   - chaque script finit par ses contrôles : des `t` partout ; PROD_43 : `restent_avec_ro` = 0
   - en cas d'arrêt : le message est dans `/tmp/<script>.log`, ne pas basculer, me l'envoyer
6. **Bascule** : dézipper le war dans `~/src/axelor-version_app`, **recopier `~/axelor-config.prod.properties`** dans `WEB-INF/classes/axelor-config.properties`,
   `sudo systemctl stop axelor-tomcat`, remplacer `ROOT` (garder l'ancien de côté), `sudo systemctl start axelor-tomcat && sudo systemctl restart nginx`.
7. **Utilisateurs** : **Ctrl + F5**.
8. **Vérifications** : fiche Arrivage et sa ligne (tableau Flottant / Réel, boutons historique / stocks) ; commande d'achat
   condensée (blocs, totaux sous les boutons, onglets du bas) et sa ligne ; article : Nom scientifique + Réf. douanière ;
   n° d'arrivages repris sans « RO- » ; taux de change EUR → USD présent (Configuration › Devises) pour la contre-valeur en €.
9. **Retour arrière** : `pg_restore` de la sauvegarde de l'étape 2 et redéploiement du `ROOT` gardé de côté.

---

# Déploiement prod LVME — lot « Arrivages GESCOM » du 14/10/2026 (PROD_37 à PROD_41)

Déjà en prod : lot « Retours client scénario 1 » (PROD_31 à PROD_36, code 252154c).
Code à déployer : tout `main` jusqu'au commit 759cd6d (ou plus récent).

| Script | Contenu |
|---|---|
| PROD_37 | N° Lot : créer un lot depuis la ligne de commande fournisseur (rattaché au produit) |
| PROD_38 | Arrivage : bouton « Frigo → toutes les lignes », titre « Lignes d'arrivage » (relance PROD_9) |
| PROD_39 | **Colonne `lvme_numero_base` sur les lots** + compteur des lots générés à l'achat au format GESCOM (8 chiffres, repart après le dernier n° GESCOM) |
| PROD_40 | N° Arrivage sur 6 chiffres : année + mois + compteur remis à zéro chaque mois (ex. 261001) |
| PROD_41 | Fiche Arrivage copie de l'écran GESCOM (relance PROD_9) |

Code (sans script) : lots AE + n° (à embarquer) / FL + n° (flottant) / n° seul (réel), même lot renommé ;
ligne d'achat avec lot ni découpée ni regénérée à l'arrivage ; arrivage créé « Flottant » quand la commande
passe en Flottant ; champs calculés Contact / Règlement / Echéance / Frais Appr. ; couleurs GESCOM (`css/lvme.css`).

1. **PC** : `git push origin main`
2. **Serveur — sauvegarde** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
3. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME && git log --oneline -1` (759cd6d ou plus récent)
4. **Build d'abord** (l'ancienne appli tourne pendant ce temps) : `cd open-suite-webapp && chmod +x gradlew && ./gradlew war -x test && cd ..`
   (pas d'avertissement « LVME : poignée de réorganisation non déplacée »)
5. **Scripts, juste avant la bascule** (la fiche Arrivage utilise des champs du nouveau code : enchaîner aussitôt avec l'étape 6) :
   ```
   for f in PROD_37_lot_cree_depuis_achat PROD_38_appliquer_frigo_arrivage PROD_39_lots_ae_fl PROD_40_numero_arrivage_6_chiffres PROD_41_arrivage_condense; do echo "== $f"; PGOPTIONS='-c lock_timeout=10s' psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/$f.sql || break; done
   ```
   - PROD_39 affiche à la fin les configurations de lot automatique et le **prochain n° de lot** : vérifier qu'il suit le dernier lot GESCOM (tableau vide = aucun article en lot automatique à l'achat, à configurer sur les articles concernés)
   - PROD_40 affiche la numérotation des réceptions : préfixe `%YY%FM`, 2 chiffres, version arrêtée à la fin du mois précédent
6. **Bascule** : dézipper le war dans `~/src/axelor-version_app`, **recopier `~/axelor-config.prod.properties`** dans `WEB-INF/classes/axelor-config.properties`,
   `sudo systemctl stop axelor-tomcat`, remplacer `ROOT` (garder l'ancien de côté), `sudo systemctl start axelor-tomcat && sudo systemctl restart nginx`.
7. **Utilisateurs** : **Ctrl + F5** (nouvelle feuille de style GESCOM).
8. **Vérifications** (article sans des milliers de mouvements) :
   - commande fournisseur, article en lot automatique : N° Lot = AE + n° ; A embarquer -> Flottant : arrivage « Flottant », n° du type 261001, lot FL + n°
   - Saisie Réel : lot = n° seul ; même lot dans État des stocks par lots
   - fiche Arrivage : blocs Fournisseur / Arrivage / Devise + tableau Flottant / Réel, lignes visibles sans défiler, champs jaunes
   - bouton « Frigo → toutes les lignes » ; « Lignes d'arrivage »
9. **Retour arrière** : `pg_restore` de la sauvegarde de l'étape 2 et redéploiement du `ROOT` gardé de côté.

---

# Déploiement prod LVME — lot « Retours client scénario 1 » du 13/10/2026 (PROD_30 à PROD_36)

Déjà en prod : lot « Arrivages + archivage » (PROD_26 à PROD_29, code e2a217c) et PROD_30 (nom complet des articles).
Code à déployer : tout `main` jusqu'au commit 54c11d9.

| Script | Contenu |
|---|---|
| PROD_30 | (déjà passé le 08/10, relançable) nom complet des articles `[référence] désignation` |
| PROD_31 | Cours vides (0 -> vide), modes de livraison Bateau / Camion, colonne « Code Produit » |
| PROD_32 | Dupliquer une ligne de commande fournisseur sans enregistrer à la main |
| PROD_33 | Dupliquer une ligne de commande client (action au nom corrigé) |
| PROD_34 | Icône « Dupliquer » en tête de ligne (achats et ventes) |
| PROD_35 | Statuts / boutons commande fournisseur : Brouillon / A embarquer / Flottant / En Stock |
| PROD_36 | N° Lot sur la ligne de commande fournisseur — **ajoute une colonne : AVANT de démarrer le nouveau code** |

Code (sans script) : champs à saisir vides (nullable), montant HT recalculé sur Nb Colis / conditionnement,
plus d'erreur « Validation failed » à la fermeture d'une ligne, poignée de réorganisation en première colonne
(retouche de l'interface dans `build.gradle`), lot repris sur l'arrivage.

1. **PC** : `git push origin main`
2. **Serveur — sauvegarde** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
3. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME && git log --oneline -1` (doit afficher 54c11d9 ou plus récent)
4. **Scripts, dans cet ordre, AVANT la bascule Tomcat** (l'ancienne appli peut tourner ; en cas de blocage le script abandonne après 10 s, relancer hors heures d'utilisation) :
   ```
   for f in PROD_31_cours_transport_code_produit PROD_32_dupliquer_ligne_achat PROD_33_dupliquer_ligne_vente PROD_34_bouton_dupliquer_a_gauche PROD_35_statuts_commande_fournisseur PROD_36_lot_commande_fournisseur; do echo "== $f"; PGOPTIONS='-c lock_timeout=10s' psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/$f.sql || break; done
   ```
5. **Build + bascule** : `cd open-suite-webapp && chmod +x gradlew && ./gradlew war -x test`
   (le build doit afficher la tâche copyWebapp sans l'avertissement « LVME : poignée de réorganisation non déplacée »),
   dézipper dans `~/src/axelor-version_app`, **recopier `~/axelor-config.prod.properties`** dans `WEB-INF/classes/axelor-config.properties`,
   `sudo systemctl stop axelor-tomcat`, remplacer `ROOT` (garder l'ancien de côté), `sudo systemctl start axelor-tomcat && sudo systemctl restart nginx`.
6. **Utilisateurs** : **Ctrl + F5** dans le navigateur (nouvelle interface : poignée et icône Dupliquer à gauche).
7. **Vérifications** (commande fournisseur de test, PAS sur un article à très nombreux mouvements) :
   - nouvelle commande : Cours vides ; Type transport propose Bateau / Camion ; statuts Brouillon / A embarquer / Flottant / En Stock
   - nouvelle ligne : Nb Colis, PA devise, PR, colis/couche, colis/palette vides ; « Code Produit » ; champ N° Lot
   - Nb Colis puis prix : montant HT calculé tout de suite ; fermer / rouvrir une ligne : aucun message d'erreur
   - Dupliquer une ligne sans enregistrer (achat et vente) : la copie apparaît au premier clic
   - A embarquer -> Flottant : l'arrivage reprend le N° Lot de chaque ligne
8. **Retour arrière** : `pg_restore` de la sauvegarde de l'étape 2 et redéploiement du `ROOT` gardé de côté.

---

# Déploiement prod LVME — lot « Arrivages + archivage » du 05/10/2026 (PROD_26 à PROD_29)

Déjà en prod : lot « Recette phase 1 » (PROD_17 à PROD_25, code jusqu'à c54de29).
Code à déployer : tout `main` jusqu'au commit 957a2da.

| Script | Contenu |
|---|---|
| PROD_26 | Arrivage / commande d'achat : Nature comme GESCOM (Flottant + À embarquer), champs Cours / Couvert / Flottant / Réel (archivage), équivalent en € ; relance PROD_8, PROD_9, PROD_10 |
| PROD_27 | Impression de l'arrivage (bouton « Editer », rapport LvmeArrivage) ; filtre « N° Arrivage » ; relance PROD_9 |
| PROD_28 | Archiver / désarchiver depuis les listes Arrivages, Clients, Fournisseurs, Articles ; relance PROD_9, PROD_11, PROD_12 |
| PROD_29 | Archiver / désarchiver les lots depuis État des stocks par lots (option « Lots archivés ») — **vue SQL** |

1. **PC** : `git push origin main`
2. **Serveur — sauvegarde** : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
3. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME && git log --oneline -1` (doit afficher 957a2da ou plus récent)
4. **Scripts, dans cet ordre, AVANT la bascule Tomcat** :
   ```
   for f in PROD_26_arrivage_nature_cours PROD_27_impression_arrivage PROD_28_archivage PROD_29_archivage_lots; do echo "== $f"; psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/$f.sql || break; done
   ```
5. **Build + bascule** : `cd open-suite-webapp && chmod +x gradlew && ./gradlew war -x test`, dézipper dans `~/src/axelor-version_app`,
   **recopier `~/axelor-config.prod.properties`** dans `WEB-INF/classes/axelor-config.properties`, `sudo systemctl stop axelor-tomcat`,
   remplacer `ROOT` (garder l'ancien de côté), `sudo systemctl start axelor-tomcat && sudo systemctl restart nginx`.
6. **Vérifications** : Achats > Arrivages (Nature, À embarquer, N° Arrivage, Arrivages Archivés, Archiver / Désarchiver, fiche : Cours, bouton Editer → PDF) ;
   commande d'achat (Cours, équivalent € sur une commande USD) ; Ventes > Clients / Articles (case Archivés, Archiver / Désarchiver) ;
   Stocks > État des stocks par lots (option Lots archivés, Archiver / Désarchiver). Liste aux mauvaises colonnes : engrenage > « Réinitialiser ».

---

# Déploiement prod LVME — lot « Recette phase 1 » du 01/10/2026 (PROD_17 à PROD_25)

Vérifié en prod le 01/10 (lecture seule) : PROD_17 à PROD_25 **pas encore passés**. Ce lot remplace le lot
« PROD_17, 18, 19 » ci-dessous (jamais déployé).
Code à déployer : tout `main` jusqu'au commit a6342fd.

| Script | Contenu | Recette |
|---|---|---|
| PROD_17 | Écrans de recherche : la fiche s'ouvre en fenêtre par-dessus la liste | — |
| PROD_18 | Commande fournisseur : réceptions ouvertes sur la fiche Arrivage (+ Java) | — |
| PROD_19 | État des stocks par lots : filtre DLUO, boutons lots périmés / DLUO proche | — |
| PROD_20 | Envoi automatique des factures clients par email à la ventilation | REC-011 |
| PROD_7 (relance) | Fiche commande client : panneau Réservation + contrôle des droits à l'enregistrement | REC-009 |
| PROD_21 | Commandes de réservation : colonnes, actions, état « Réservations », client « Sous contrat » | REC-009 |
| PROD_22 | Rotation de Stock par lot (GESCOM) + 4 KPI ; palmarès dans le menu Ventes — **vue SQL** | REC-012 |
| PROD_23 | Ventes > Listes Dossiers (BL / factures, vue transporteur) | REC-012 |
| PROD_24 | Ventes > Rapport d'incohérences — **vue SQL** | REC-012 |
| PROD_25 | Chrono mensuelle (FC/AC/SO + AAMM), périodes 2026 mois par mois, droits de clôture | REC-010 |

**Avant** : créer le compte email d'envoi (Administration > Comptes email, SMTP + mot de passe) — sinon
la ventilation passe mais l'email de facture ne part pas (PROD_20).

1. **PC** : `git push origin main`
2. **Serveur — sauvegarde** :
   `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
3. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME`
4. **Scripts, dans cet ordre, AVANT de basculer Tomcat** (l'ancienne appli tourne encore ; PROD_22 et PROD_24
   créent des vues SQL qui doivent exister avant le démarrage, sinon Axelor crée des tables vides) :
   ```
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_17_fiches_en_fenetre.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_18_commande_fournisseur_arrivages.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_19_filtre_dluo.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_20_email_factures.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_7_ui_commande_client.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_21_reservations.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_22_rotation_lots.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_23_listes_dossiers.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_24_rapport_incoherences.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_25_chrono_mensuelle.sql
   ```
   Chaque script est une seule transaction : en cas d'erreur rien n'est écrit, on s'arrête et on m'envoie le message.
5. **Build + bascule** (procédure habituelle) : `cd open-suite-webapp && ./gradlew war`, dézipper dans
   `~/src/axelor-version_app`, **recopier `~/axelor-config.prod.properties`** dans `WEB-INF/classes/axelor-config.properties`,
   `systemctl stop axelor-tomcat`, remplacer `ROOT`, redémarrer axelor-tomcat + nginx.
   **Ne pas lancer `gradlew database --update`.**
6. **Vérifications** (se reconnecter ; si une liste n'a pas les bonnes colonnes : engrenage > « Réinitialiser ») :
   - Ventes > Commandes clients : fiche avec panneau « Réservation » ; liste, état « Réservations »
   - Ventes > Listes Dossiers ; Ventes > Rapport d'incohérences ; Ventes > Palmarès des ventes / par commercial
   - Stocks > Rotation des stocks : 4 KPI + « Par lot » ; Stocks > État des stocks par lots : filtre DLUO
   - Comptabilité > Configuration > Périodes : 12 mois en 2026, boutons de clôture visibles
   - Prochain devis finalisé : n° SO + AAMM + 0001 ; prochaine facture ventilée : FC + AAMM + 0001
7. **Retour arrière** : `pg_restore` de la sauvegarde de l'étape 2 et redéploiement du war précédent.

---

# Déploiement prod LVME — lot du 01/10/2026 (PROD_17, 18, 19)

Déjà en prod (vérifié le 01/10) : PROD_7 à PROD_16 (Historique Produit, Synthèse des Arrivages et dates comprises).
À déployer : le code jusqu'au commit ba344e1 (arrondis des totaux, Java de PROD_18) + les 3 scripts ci-dessous.

| Script | Contenu |
|---|---|
| PROD_17 | Écrans de recherche : la fiche s'ouvre en fenêtre par-dessus la liste |
| PROD_18 | Commande fournisseur : réceptions ouvertes sur la fiche Arrivage (+ Java) |
| PROD_19 | État des stocks par lots : filtre DLUO, boutons « Voir les lots périmés / à DLUO proche » |

1. **PC** : `git push origin main`
2. **Serveur** : sauvegarde `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
3. `cd ~/src && rm -rf axelor-LVME && git clone https://github.com/consultMen/axelor-LVME.git && cd axelor-LVME`
4. Scripts, **avant** de basculer Tomcat (l'ancienne appli tourne encore) :
   ```
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_17_fiches_en_fenetre.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_18_commande_fournisseur_arrivages.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_19_filtre_dluo.sql
   ```
5. Build + bascule Tomcat (procédure habituelle) : `cd open-suite-webapp && ./gradlew war`, dézipper,
   **recopier `~/axelor-config.prod.properties`**, `systemctl stop axelor-tomcat`, remplacer ROOT, redémarrer.
   Ne pas lancer `gradlew database --update`.

---

# Déploiement prod LVME — lot « Historique Produit / Synthèse des Arrivages » (PROD_14, PROD_15)

| Script | Écran GESCOM |
|---|---|
| PROD_14 | Stocks > Historique Produit (diapo 11) : vue SQL lvme_historique_produit, écran, liste, détail |
| PROD_15 | Stocks > Arrivages > Synthèse des Arrivages (diapo 24) : vue SQL lvme_synthese_arrivage, écran, liste, détail |

**Ordre impératif** : les deux scripts passent AVANT que Tomcat démarre sur le nouveau code
(sinon Axelor crée des tables vides à la place des vues).
1. Sauvegarde : `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
2. `cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git`
3. Depuis `~/src/axelor-LVME` (l'ancienne appli tourne encore) :
   ```
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_14_historique_produit.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_15_synthese_arrivages.sql
   ```
4. `cd open-suite-webapp && ./gradlew war`, dézipper, **recopier `~/axelor-config.prod.properties`**, bascule Tomcat
   (procédure habituelle, cf. lot ci-dessous).

---

# Déploiement prod LVME — lot « écrans GESCOM » du 30/09/2026 (PROD_7 à PROD_13)

## Contenu du lot (validé en local)
| Script | Écran GESCOM |
|---|---|
| PROD_7  | Fiche Commande client : en-tête GESCOM + grille des lignes |
| PROD_8  | Fiche Commande fournisseur : en-tête (devises, blocs Fournisseur / Arrivage, Nature) + grille des lignes |
| PROD_9  | Arrivages : menu, recherche, liste, fiche Arrivage, lignes, référentiels Bateaux / Containers |
| PROD_10 | Liste des achats fournisseurs + Listes Commandes Clients (filtres, totaux, Nature des commandes) |
| PROD_11 | Listes Clients / Fournisseurs / Articles + Gencode, Réf. fournisseur, Poids Colis, P.Vente TTC |
| PROD_12 | « Recherche rapide par » Clients / Fournisseurs / Articles (prérequis : PROD_11) |
| PROD_13 | Stocks > Lots Vérifiés (+ vue lvme_etat_stock_lot mise à jour) |

**Hors lot** : PROD_14 (Historique Produit), pas encore testé ; son code n'est pas commité.
Ne pas le déployer seul : sans son script, Axelor créerait une table à la place de la vue.

## Ordre de déploiement
0. **Sur le PC** : `git push` (les commits du lot doivent être sur `origin/main`).
1. **Sauvegarde de la base prod** :
   `pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump`
2. **Sur le serveur**, dans `~/src/axelor-LVME` : `git pull`, puis build comme d'habitude
   (`./gradlew build -x test -x :modules:axelor-human-resource:buildFront`). Axelor n'est pas encore redémarré.
3. **Contrôle (lecture seule)** :
   `psql -U axelor axelor -f livrables/PROD_7-13_controle_avant.sql`
   → « manquant » doit être vide ; sale-order-form, purchase-order-form, product-form trouvées. Sinon, on s'arrête.
4. **Scripts, dans l'ordre**, depuis la racine du dépôt (chacun en une transaction : en cas d'erreur, rien n'est écrit
   et on s'arrête là) :
   ```
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_7_ui_commande_client.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_8_ui_commande_fournisseur.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_9_arrivages.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_10_listes_achats_commandes.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_11_listes_tiers_articles.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_12_recherche_tiers_articles.sql
   psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_13_lots_verifies.sql
   ```
5. **Redémarrer Axelor** (obligatoire : cache des vues ; création des tables Bateaux / Containers et des nouvelles colonnes).
   **Ne pas lancer `gradlew database --update`.**
6. **Vérifications** après connexion : Ventes > Commandes clients (liste + une fiche), Achats > Commandes fournisseurs
   (liste + une fiche), Stocks > Arrivages, Stocks > Configuration > Bateaux / Containers, listes Clients /
   Fournisseurs / Articles, Stocks > Lots Vérifiés.
   Si une liste n'a pas les bonnes colonnes pour un utilisateur : engrenage de la liste > « Réinitialiser ».
7. **Retour arrière** si besoin : restaurer la sauvegarde de l'étape 1 (`pg_restore`) et revenir au commit précédent.

Règle : ne jamais réenregistrer ces vues depuis l'écran d'administration (Axelor régénérerait une vue calculée).

---

# Déploiement prod LVME — lot du 29/09/2026

## Contenu du lot
- **BL client** : colisage, lot, lot fournisseur, DLUO, traçabilité (origine, pêche, marque,
  congélation), PR, P.R. Net et marge recopiés de la commande ; livraison partielle et reliquat
  proratisés (colis, poids, unités, marge).
- **Marge** : marge de ligne = Total HT − P.R. Net × qté (formule LVME, aussi à l'enregistrement) ;
  marge commerciale = somme des marges de lignes.
- **Duplication de ligne** (vente et achat).
- **REC-038** État des stocks par lots, **REC-003** Rotation des stocks (4 KPI).
- **REC-040** requête Superset suivi des confirmations.

## Ordre de déploiement
1. **Sauvegarde de la base prod** (pg_dump) avant toute chose.
2. Exécuter les vues SQL **avant** le redémarrage (ddl = update) :
   - `axelor-supplychain/src/main/resources/sql/lvme_age_lot.sql`
   - `axelor-supplychain/src/main/resources/sql/lvme_rotation_stock.sql`
   - `axelor-supplychain/src/main/resources/sql/lvme_etat_stock_lot.sql`
3. Déployer le code (`git pull`, build `.\gradlew build -x test -x :modules:axelor-human-resource:buildFront`), redémarrer.
   Le redémarrage crée les colonnes `stock_stock_move_line.marge_ht` et `taux_marge`.
   **Ne pas lancer `gradlew database --update`** (écrase les vues admin).
4. Listes de choix : `admin-export/selections_admin.sql` (idempotent), ou `REC-003_selections.sql`
   et `REC-038_selections.sql`.
5. Vues / actions / menus admin : recréer dans Administration à partir de
   - `REC-003_admin_rotation_stock.xml`, `REC-038_admin_etat_stock_lots.xml`
   - `admin-export/vues/` et `admin-export/actions/` (export complet de la base locale ; nom de
     fichier = `nom__pPriorité__module__type`). `admin-export/menus/menus_admin.csv` liste les menus.
   Vues modifiées dans ce lot :
   - `stock-move-line-form` : `saleOrderLine.conditionnement` (BL) + champs `margeHt`, `tauxMarge`
   - `stock-move-form` : symbole de devise, mise en page sans onglets
   - `purchase-order-form` : devise d'achat / devise comptable
   - `purchase-order-line-form` : suppression du hilite rouge sur le PA/kg
   - `sale-order-line-grid`, `purchase-order-line-purchase-order-grid` : bouton dupliquer
   Règle : modifier la vue **calculée (bleue)** pour l'effet immédiat + une vue extension séparée.
6. Rattrapage des données existantes (à valider avant exécution) : marges des commandes
   (ré-enregistrement ou script) et BL planifiés (colisage, lot, marge).

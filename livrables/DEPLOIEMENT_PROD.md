# Déploiement prod LVME — lot « Lignes vides / lots auto » du 14/10/2026 (PROD_50, PROD_51)

Déjà en prod : PROD_37 à PROD_49. Code à déployer : tout `main` (37c7f7b ou plus récent).

| Script | Contenu |
|---|---|
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

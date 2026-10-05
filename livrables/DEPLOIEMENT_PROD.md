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

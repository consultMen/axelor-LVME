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

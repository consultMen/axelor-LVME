# Récap projet LVME Sofrimar (Axelor) – état au 12/10/2026

Document de passation : contexte, règles de travail, ce qui est fait, ce qui reste.

## 1. Contexte

- **Client** : LVME Sofrimar (négoce de produits de la mer surgelés). Intégrateur : Accur Group.
- **Logiciel** : Axelor Open Suite (AOS) sur Axelor Open Platform **7.4**. Remplace l'ancien logiciel **GESCOM** : les écrans doivent reprendre la présentation et les libellés de GESCOM.
- **Référentiels** : cahier de recette (scénarios REC-xxx) et « Document Suivi Projet LVME 16052025.pdf ».
- **Dépôt** : GitHub `consultMen/axelor-LVME`, branche `main`. Dernier commit : `4cf95d1`.
- **Code** : `open-suite-webapp/modules/axelor-open-suite/axelor-*` (surtout `axelor-base`, `axelor-stock`, `axelor-supplychain`, `axelor-purchase`, `axelor-sale`).
- **Livrables SQL** : `livrables/PROD_N_*.sql` (vues, actions, menus, données). La procédure de chaque lot est en tête de `livrables/DEPLOIEMENT_PROD.md`.

## 2. Environnements

| | Local (PC Windows) | Production |
|---|---|---|
| URL | http://localhost:8080/axelor-erp | https://www.lvme-erp.com |
| Base | PostgreSQL 18, base `axelor_local` | base `axelor` (`psql -U axelor axelor`) |
| Lancement | `gradlew.bat run -x test -x :modules:axelor-human-resource:buildFront` dans `open-suite-webapp` | Tomcat (`axelor-tomcat`) + nginx, VM Google Cloud `axelor-erp-v2` |
| Code sur le serveur | | `/home/axelor/src/axelor-LVME` (utilisateur `axelor`) |

**Configuration prod** : le dépôt pointe sur `axelor_local`. La vraie configuration prod est dans `~/axelor-config.prod.properties` sur le serveur. Il faut la recopier dans le war à chaque déploiement.

## 3. Règles de travail (demandées par l'utilisateur)

1. **Conception d'abord** : proposer et faire valider avant de coder.
2. **Périmètre strict** : ne livrer que ce que demandent le cahier de recette ou l'écran GESCOM, sans ajouts.
3. **Vues, menus et actions** : paramétrés en base (vues « admin », `module IS NULL`, priorité 20/30), livrés sous forme de scripts SQL `PROD_N` relançables. Le Java est livré dans le code.
4. **Tester en local**, puis passer en prod.
5. **La prod est la vraie base du client** :
   - aucune écriture sans accord ;
   - les scripts sont lancés par l'utilisateur sur le serveur, après un `pg_dump` ;
   - jamais `gradlew database --update` ;
   - ne pas réenregistrer les vues admin depuis l'interface.
6. **Lecture seule possible en prod** : appels REST `/ws/rest/.../search` et `/ws/meta/fields/...` depuis un onglet connecté.
7. **L'utilisateur saisit lui-même** ses identifiants et pousse lui-même sur GitHub.

## 4. Procédure de déploiement prod

1. **PC** : `git push origin main`.
2. **Sauvegarde** sur le serveur :
   ```
   pg_dump -U axelor -Fc axelor > ~/sauvegarde_axelor_$(date +%F_%H%M).dump
   ```
3. **Récupérer le code** :
   ```
   cd ~/src && rm -rf axelor-LVME axelor-version_app axelor-version_app.war && git clone https://github.com/consultMen/axelor-LVME.git
   ```
4. **Scripts** : `psql -U axelor axelor -v ON_ERROR_STOP=1 -f livrables/PROD_N.sql`.
   - À lancer depuis la racine du dépôt (certains scripts en incluent d'autres avec `\i`).
   - À lancer AVANT le redémarrage (les vues SQL doivent exister au démarrage).
5. **Construire le war** : `cd open-suite-webapp && chmod +x gradlew && ./gradlew war -x test`.
6. **Installer le war** :
   - le dézipper dans `~/src/axelor-version_app` ;
   - copier `~/axelor-config.prod.properties` vers `WEB-INF/classes/axelor-config.properties`.
7. **Bascule** :
   - `sudo systemctl stop axelor-tomcat` ;
   - déplacer `~/opt/default-tomcat/webapps/ROOT` de côté, puis mettre la nouvelle version à la place ;
   - `sudo systemctl start axelor-tomcat && sudo systemctl restart nginx`.
8. **Si seules des vues ou actions changent** : script + `sudo systemctl restart axelor-tomcat` (cache des vues).

## 5. Pièges techniques Axelor 7.4 rencontrés

**Modèles et champs calculés**
- **Modèles adossés à des vues SQL** : `RotationLot` (`lvme_rotation_lot`), `Incoherence` (`lvme_incoherence`), `EtatStockLot` (`lvme_etat_stock_lot`). Les fichiers sont dans `axelor-supplychain/src/main/resources/sql/`. La vue doit exister avant le démarrage de Tomcat.
- **Champs calculés (`formula`)** :
  - jamais de JOIN, car Hibernate préfixe la table jointe : utiliser des sous-requêtes `IN` avec les noms de tables complets ;
  - une colonne sans préfixe désigne l'entité courante.
- **Colonnes « a.b »** : souvent vides dans les dashlets. Les remplacer par des champs calculés.

**Dashlets**
- La barre `<toolbar>` d'une grille n'apparaît pas dans un dashlet. Solution : un bouton qui ouvre la même action en popup ; les lignes cochées arrivent alors dans `_ids`.
- **Fiches archivées** : invisibles par défaut. Ajouter `<view-param name="showArchived" value="true"/>` **après le dernier `<view>`** de l'action, sinon l'action est cassée. Ne pas utiliser `dashlet.canSearch`.

**Écriture des scripts SQL**
- Les scripts modifient le XML des vues avec `position()` et `regexp_replace`.
- Pour la référence arrière `\1`, écrire `chr(92) || '1'` (un générateur Python avait transformé `\\1` en `\x01`).

**Impression**
- Impression BIRT : un PrintingTemplate « Arrivage LVME » utilise le rapport `axelor-stock/src/main/resources/reports/LvmeArrivage.rptdesign`, généré par `livrables/outils/gen_rapport_arrivage.py`.
- Pour ouvrir le PDF par-dessus la fiche : vue html + paramètres `popup`, `popup.maximized` et `show-toolbar=false`.

**Données**
- **Numérotation mensuelle** : FC/AC/SO + AAMM + compteur, remis à zéro chaque mois.
- **Nom complet des articles** : `full_name` = `[code] name`. Axelor le recalcule à l'enregistrement de l'article. La reprise GESCOM avait mis l'ancien n° interne, corrigé par PROD_30.

## 6. Ce qui est fait et déployé en prod

| Lot | Scripts | Contenu |
|---|---|---|
| Socle | PROD_1 à 16 | Vues SQL, écrans de recherche à la GESCOM (commandes, arrivages, clients, fournisseurs, articles), État des stocks par lots, lots vérifiés, historique produit, synthèse des arrivages |
| Recette phase 1 (01/10) | PROD_17 à 25 | Fiches ouvertes en fenêtre, commande fournisseur → arrivages, filtre DLUO. **REC-011** : envoi auto des factures par email. **REC-009** : réservations, client « Sous contrat ». **REC-012** : Rotation de stock par lot + 4 KPI, Listes Dossiers, Rapport d'incohérences, palmarès. **REC-010** : numérotation mensuelle, périodes 2026, droits de clôture (rôle `lvme.comptable`) |
| Évolutions client (05/10) | PROD_26 à 29 | Nature d'arrivage comme GESCOM (Flottant + case « À embarquer », plus de « En cours de production », sens unique à embarquer → flottant). Champs Cours / Couvert / Flottant / Réel (archive, aucun calcul). Équivalent € au taux officiel. Bouton « Editer » (impression arrivage). Filtre « N° Arrivage ». Archiver / désarchiver depuis les listes (arrivages, clients, fournisseurs, articles, lots) |
| Correctif (08/10) | PROD_30 | Nom complet des 1846 articles recalculé (`[référence] désignation`) |

**Guide de recette pour le client** : doc en ligne https://claude.ai/code/artifact/317afd09-3b1a-4732-a238-128e39b156c5 et PDF `livrables/Guide de recette LVME Sofrimar - Phase 1.pdf`. Le PDF n'est pas commité.

## 7. Incident en cours : prod injoignable (08/10)

- La VM Google Cloud a redémarré seule. Son IP publique éphémère est passée de **104.155.56.111** à **35.205.173.98**.
- Le DNS de `lvme-erp.com` pointe encore sur l'ancienne IP. nginx et Tomcat tournent bien.
- **À faire** :
  1. Réseau VPC > Adresses IP : passer l'IP en **statique**.
  2. Mettre à jour les enregistrements A `lvme-erp.com` et `www` chez le registrar.
  3. Vérifier https://www.lvme-erp.com.

## 8. Ce qui reste à faire

### 8.1 Anomalies remontées par le client (scénario 1, achats / arrivages)

**Faits en local, testés, commités, PAS encore en prod** (déploiement : code jusqu'à 54c11d9 + scripts PROD_31 à PROD_36 — PROD_36 ajoute une colonne, à lancer AVANT de démarrer le nouveau code — puis Ctrl+F5 chez les utilisateurs) :
- 12 : fait (confirmé par l'utilisateur)
- 13 : N° Lot sur la ligne de commande fournisseur (`trackingNumber`, domaine supplychain), proposé au choix du produit si lot automatique (`LvmeLotCommandeAchatController`), repris sur la ligne d'arrivage sans génération/découpage (`StockMoveLineServiceSupplychainImpl`) (54c11d9, PROD_36)
- 7 (version finale) : `PurchaseOrderController.compute` appelle les 4 étapes de calcul hors transaction (9466705) — la 1re version (transaction annulée à la main) laissait une connexion « idle in transaction »
- Local : l'article SAUMON-ATL a 7 008 mouvements planifiés de test → passage en Flottant interminable ; tester avec 987 / 1718 / 1719
- 1, 2, 3 : cours vides, Bateau/Camion, « Code Produit » (bb3732c, PROD_31)
- 4 : champs à saisir vides — `nullable="true"` dans les domaines PurchaseOrderLine / SaleOrderLineColis (cca9c8a)
- 5 : montant HT recalculé sur Nb Colis / conditionnement, formule d'origine inchangée (9a3d4f4)
- 6 : duplication sans enregistrer à la main, achats (PROD_32) et ventes (PROD_33, action au nom corrigé), icône en tête de ligne (PROD_34)
- 7 : « Validation failed » — `PurchaseOrderController.compute` dans une transaction toujours annulée (62ff38c)
- 9 : réglé par PROD_30 (références d'articles)
- 10 : poignée de réorganisation en première colonne — retouche de l'interface Axelor dans `build.gradle` (tâche copyWebapp) (5a753c3)
- 11 : statuts/boutons commande fournisseur (PROD_35)
- Restent : 8 (totaux du détail — capture GESCOM à obtenir), 14 (présentation — capture Trello à obtenir)

Texte complet reçu le 12/10. Il manque encore : la capture de l'erreur (7), la capture GESCOM du « détail » (8) et la capture Trello (14).

| # | Remarque client (texte exact) | Piste technique |
|---|---|---|
| 1 | Cours USD : les champs sont à « 0,0000 », les mettre vides dès le départ (perte de temps à effacer les zéros) | `lvmeCours/Couvert/Flottant/Reel` (PurchaseOrder.xml supplychain + StockMove.xml stock) sont des `decimal` non nullables, donc 0 par défaut : ajouter `nullable="true"` (+ ALTER des colonnes) |
| 2 | « Type transport » doit pouvoir sélectionner « Bateau / Camion » | Sur la commande d'achat, « Type transport » = champ `shipmentMode` (relation vers la table des modes de livraison, Stocks > Configuration). Créer les enregistrements Bateau et Camion (données), vérifier qu'ils sont proposés |
| 3 | Ligne de commande d'achat : « Code fournisseur » est un intitulé erroné, doit être « Code Produit » | Renommer le libellé du champ dans la vue admin de la ligne de commande d'achat |
| 4 | Enlever systématiquement les « 0,000 » à 6 décimales, laisser vide pour saisir vite | Champs standard AOS (quantité, prix) non nullables : solution à concevoir (vider au focus, ou valeur nulle à la création de ligne). À valider |
| 5 | Montant HT ne fonctionne toujours pas | À reproduire (commande d'achat ?) |
| 6 | Dupliquer ligne commande ne fonctionne toujours pas | Livré le 29/09 en local : services `PurchaseOrderLineDuplicateService` / `SaleOrderLineDuplicateLvmeService`, boutons créés dans l'admin LOCAL (à vérifier en prod). Le bouton ne marche que commande enregistrée ; l'option native AOS « duplication de ligne » copie mal |
| 7 | Message erreur « Validation failed for class » | Erreur Hibernate (champ obligatoire / contrainte) : capture + écran nécessaires |
| 8 | Menu « détail » : voir total nombre de cartons, montant HT, poids… comme sur la capture envoyée | Totaux en pied de liste, comme GESCOM |
| 9 | Clic sur « Produit » dans le détail : trier par numéro de produit comme dans GESCOM | Tri de la colonne sur la référence produit |
| 10 | Bouger l'option de réorganisation des lignes au début des colonnes et pas à la fin | Poignée de tri des lignes (grille éditable) |
| 11 | Intitulés de suivi de la commande fournisseur : « Brouillon - A embarquer - Flottant - En Stock » | Aujourd'hui : Brouillon / Demandée / Validée / Terminée / Annulée. Correspondance à valider (Demandée → A embarquer ? Validée → Flottant ? Terminée → En stock ?) |
| 12 | Changer les conditionnements pour des commandes déjà établies : la ligne n'est pas modifiée, faut-il ressaisir la ligne ? | Comportement normal : la ligne copie les valeurs de l'article à la saisie. Répondre au client (resélectionner l'article sur la ligne) ou proposer un bouton « Mettre à jour depuis l'article » |
| 13 | Pas de numéro de lot attribué dans l'arrivage (commande fournisseur) | Prioritaire : vérifier la configuration de suivi par lot des articles (génération auto à la réception) |
| 14 | La présentation graphique ne met pas assez en avant les produits et leurs informations, voir capture Trello | Conception sur la base de la capture Trello |

Ordre proposé : anomalies (5, 6, 7, 12, 13), puis corrections simples (1, 2, 3, 4, 10, 11), puis évolutions (8, 9, 14) avec conception validée.

### 8.2 Filtres « Secteur » et « Client en compte / comptant »

Validés par le patron. Écrans : **Listes Dossiers** et **Listes Commandes Clients**. Questions posées à l'utilisateur, **réponses en attente** :

- **A.** Le « secteur commercial » (GMS…) est dans la **Catégorie** du client (`partnerCategory` : GROSSISTE 943, SUPERMARCHES 490, NEGOCE 122, NON DEFINI 114, TRAITEUR 113, MAREYEURS 56). Le champ `industrySector` contient des **régions** (PACA, OUEST…). Filtrer sur la Catégorie ?
- **B.** Catégories 22000 / 23000 / 65000 / 300000 (162 clients) : probable erreur de reprise. Que faire ?
- **C.** Comptant = condition de paiement « COMPTANT PIMER » (263 clients) ou « Comptant » ; en compte = toutes les autres ; les 12 clients sans condition n'apparaissent qu'avec « Tous ». Validé ?
- **D.** Prendre la condition de paiement du document (recommandé) ou celle de la fiche client ?

Écran prévu : filtre Secteur (vide = tous) + filtre Client (Tous / En compte / Comptant), combinés avec les filtres existants.

### 8.3 Lots bloqués à la vente

Validé par le patron.
- Nouveau rôle spécifique (proposition : `lvme.lots_bloques`), affecté aux utilisateurs selon le besoin.
- S'applique **uniquement à la commande client** (pas au BL ni à la préparation) : les lots bloqués sont masqués dans le choix de lot et refusés à l'enregistrement, sauf pour ce rôle.
- Blocage / déblocage depuis « État des stocks par lots ».
- À confirmer : est-ce le même rôle qui bloque et débloque ?

### 8.4 Divers

- Créer le compte email d'envoi en prod (Administration > Comptes email), indispensable pour REC-011.
- Prévenir le client de la nouvelle numérotation (FC2610xxxx, SO2610xxxx).
- Deux articles vides en prod (id 2197 et 2198, sans référence ni désignation) : à vérifier, puis archiver.
- Guide client : vérifier les chemins de menu « Stocks > Arrivages » (ou Achats ?), « Achats > Commandes fournisseurs », « Stocks > État des stocks par lots » et le nom du bouton de facturation depuis la commande.
- Fichiers locaux non commités : `.vscode/settings.json`, `livrables/outils/rapport_arrivage_test.sql`, `SaleOrder.rptdesign.bak` (à ignorer ou supprimer).

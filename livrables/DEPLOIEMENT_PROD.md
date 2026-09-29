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

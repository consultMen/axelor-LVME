# LVME — Simplification des menus

Appliqué par le script **`livrables/PROD_61_simplification_menus.sql`** (relançable, s'arrête sans rien modifier si un menu
est introuvable). À la main sinon : Administration > Gestion des vues > Tous les menus, changer **Parent** et **Ordre**,
ou cocher **Caché**.

Les ordres négatifs placent les fiches en tête du sous-menu Configuration.

## Ventes → Ventes > Configuration (`sc-root-sale-conf`)

| Menu | Nom technique | Nouveau parent | Ordre |
|---|---|---|---|
| Clients | `sc-root-sale-customers` | `sc-root-sale-conf` | -40 |
| Contacts | `sc-root-sale-contacts` | `sc-root-sale-conf` | -30 |
| Produits & services | `sc-root-sale-products` | `sc-root-sale-conf` | -20 |
| Analyse ABC | `sc-root-abc-analysis` | `sc-root-sale-conf` | 1100 |

## Achats → Achats > Configuration (`sc-root-purchase-conf`)

| Menu | Nom technique | Nouveau parent | Ordre |
|---|---|---|---|
| Fournisseurs | `sc-root-purchase-suppliers` | `sc-root-purchase-conf` | -40 |
| Contacts | `sc-root-purchase-contacts` | `sc-root-purchase-conf` | -30 |
| Produits & services | `sc-root-purchase-products` | `sc-root-purchase-conf` | -20 |
| Conditionnement | `Conditionnement` | `sc-root-purchase-conf` | -10 |
| Facturation de masse fournisseur | `stock-multi-purchase-invoicing` | `sc-root-purchase-conf` | 300 |
| Analyse ABC | `purchase-root-abc-analysis` | `sc-root-purchase-conf` | 400 |
| État en-cours fournisseur (remonté) | `lvme-menu-encours-fournisseur` | `sc-root-purchase` | 1250 |

## Stock → Stock > Configuration (`stock-root-conf`)

| Menu | Nom technique | Nouveau parent | Ordre |
|---|---|---|---|
| Produits | `stock-root-products` | `stock-root-conf` | -20 |
| Emplacements de stock | `stock-root-stock-location` | `stock-root-conf` | -10 |
| Recherche n° de suivi | `stock-root-search` | `stock-root-conf` | 1300 |

## CRM → CRM > Configuration (`crm-conf`)

| Menu | Nom technique | Nouveau parent | Ordre |
|---|---|---|---|
| Clients | `crm-root-customers` | `crm-conf` | -20 |
| Contacts | `crm-root-contacts` | `crm-conf` | -10 |

## Comptabilité : états remontés hors Configuration

| Menu | Nom technique | Nouveau parent | Ordre |
|---|---|---|---|
| Synthèse risques clients | `lvme-menu-synthese-risque-client` | `account-root-accounting` | 400 |
| Export Coditour | `lvme-menu-coditour-export` | `account-root-accounting` | 500 |

## Menus masqués (cocher « Caché »)

| Menu | Nom technique |
|---|---|
| MRP (Achats) | `purchase-mrp` |
| MRP (Stock) | `stock-mrp` |

## Inchangés

Tableaux de bord et Listes Dossiers restent dans les menus métier. Facturation : rien à déplacer.

## Après chaque déploiement

Les menus standard Axelor (tous sauf `Conditionnement` et `lvme-*`) sont définis dans les XML des modules :
une mise à jour de module peut leur rendre leur parent d'origine. Vérifier qu'ils sont toujours dans Configuration.
Recharger la page (F5) après modification pour voir le nouveau menu.

package com.axelor.apps.supplychain.service;

import com.axelor.apps.base.db.Partner;
import com.axelor.apps.base.db.Product;
import com.axelor.apps.purchase.db.PurchaseOrder;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.purchase.db.SupplierCatalog;
import com.axelor.apps.purchase.db.repo.SupplierCatalogRepository;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.StockMoveLine;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.google.inject.Inject;
import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * LVME : catalogue fournisseurs (repris de GESCOM FOUART) tenu à jour comme dans GESCOM, en
 * consultation seule (le prix n'est jamais proposé sur les lignes de commande d'achat).
 *
 * <ul>
 *   <li>validation d'une commande d'achat : pour chaque article, prix d'achat et devise de la
 *       commande, date de commande, réf. fournisseur, conditionnement, origine, zone, marque, poids
 *       colis et unité de la ligne ;
 *   <li>« Saisie Réel » d'un arrivage : prix de revient saisi (PR réel €/kg) de chaque article.
 * </ul>
 *
 * Une ligne de catalogue par fournisseur et article, créée si elle n'existe pas encore.
 */
public class LvmeCatalogueFournisseurService {

  protected final SupplierCatalogRepository supplierCatalogRepository;

  @Inject
  public LvmeCatalogueFournisseurService(SupplierCatalogRepository supplierCatalogRepository) {
    this.supplierCatalogRepository = supplierCatalogRepository;
  }

  public void majDepuisCommande(PurchaseOrder commande) {
    Partner fournisseur = commande.getSupplierPartner();
    if (fournisseur == null || commande.getPurchaseOrderLineList() == null) {
      return;
    }
    LocalDate date = commande.getOrderDate() != null ? commande.getOrderDate() : LocalDate.now();
    for (PurchaseOrderLine ligne : commande.getPurchaseOrderLineList()) {
      if (ligne.getProduct() == null || Boolean.TRUE.equals(ligne.getIsTitleLine())) {
        continue;
      }
      SupplierCatalog catalogue = ligneCatalogue(fournisseur, ligne.getProduct());
      catalogue.setPrice(ligne.getPrice());
      catalogue.setCurrency(commande.getCurrency());
      catalogue.setUpdateDate(date);
      if (ligne.getProductCode() != null && !ligne.getProductCode().isBlank()) {
        catalogue.setProductSupplierCode(ligne.getProductCode());
      }
      if (ligne.getUnit() != null) {
        catalogue.setUnit(ligne.getUnit());
      }
      if (ligne.getConditionnement() != null) {
        catalogue.setConditionnement(ligne.getConditionnement());
      }
      if (ligne.getOrigine() != null) {
        catalogue.setOrigine(ligne.getOrigine());
      }
      if (ligne.getZonePeche() != null) {
        catalogue.setZonePeche(ligne.getZonePeche());
      }
      if (ligne.getMarque() != null) {
        catalogue.setMarque(ligne.getMarque());
      }
      if (positif(ligne.getPoidsParColis())) {
        catalogue.setPoidsColis(ligne.getPoidsParColis());
      }
      supplierCatalogRepository.save(catalogue);
    }
  }

  public void majDepuisArrivage(StockMove arrivage) {
    Partner fournisseur = arrivage.getPartner();
    if (arrivage.getTypeSelect() != StockMoveRepository.TYPE_INCOMING
        || Boolean.TRUE.equals(arrivage.getIsReversion())
        || fournisseur == null
        || !Boolean.TRUE.equals(fournisseur.getIsSupplier())
        || arrivage.getStockMoveLineList() == null) {
      return;
    }
    for (StockMoveLine ligne : arrivage.getStockMoveLineList()) {
      if (ligne.getProduct() == null || !positif(ligne.getPrixRevientReel())) {
        continue;
      }
      SupplierCatalog catalogue = ligneCatalogue(fournisseur, ligne.getProduct());
      catalogue.setPrixRevient(ligne.getPrixRevientReel());
      if (catalogue.getId() == null) {
        // arrivage sans commande d'achat : la ligne du catalogue reprend celle de l'arrivage
        PurchaseOrderLine achat = ligne.getPurchaseOrderLine();
        catalogue.setPrice(achat != null ? achat.getPrice() : ligne.getUnitPriceUntaxed());
        catalogue.setCurrency(
            achat != null && achat.getPurchaseOrder() != null
                ? achat.getPurchaseOrder().getCurrency()
                : arrivage.getCompany() != null ? arrivage.getCompany().getCurrency() : null);
        catalogue.setUnit(ligne.getUnit());
        catalogue.setOrigine(ligne.getOrigine());
        catalogue.setZonePeche(ligne.getZonePeche());
        catalogue.setMarque(ligne.getMarque());
        catalogue.setPoidsColis(positif(ligne.getPoidsParColis()) ? ligne.getPoidsParColis() : null);
        catalogue.setUpdateDate(
            arrivage.getRealDate() != null ? arrivage.getRealDate() : LocalDate.now());
      }
      supplierCatalogRepository.save(catalogue);
    }
  }

  /** Ligne du catalogue de ce fournisseur pour cet article, nouvelle si elle n'existe pas. */
  protected SupplierCatalog ligneCatalogue(Partner fournisseur, Product article) {
    SupplierCatalog catalogue =
        supplierCatalogRepository
            .all()
            .filter("self.supplierPartner = ?1 AND self.product = ?2", fournisseur, article)
            .order("-updateDate")
            .order("-id")
            .fetchOne();
    if (catalogue == null) {
      catalogue = new SupplierCatalog();
      catalogue.setSupplierPartner(fournisseur);
      catalogue.setProduct(article);
      catalogue.setMinQty(BigDecimal.ONE);
    }
    return catalogue;
  }

  private static boolean positif(BigDecimal valeur) {
    return valeur != null && valeur.signum() > 0;
  }
}

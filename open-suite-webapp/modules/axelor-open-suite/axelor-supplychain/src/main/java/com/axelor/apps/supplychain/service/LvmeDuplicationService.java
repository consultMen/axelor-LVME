package com.axelor.apps.supplychain.service;

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.base.db.Company;
import com.axelor.apps.base.db.Partner;
import com.axelor.apps.base.db.Product;
import com.axelor.apps.base.service.ProductCompanyService;
import com.axelor.apps.purchase.db.PurchaseOrder;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.purchase.db.repo.PurchaseOrderRepository;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.db.repo.SaleOrderRepository;
import com.axelor.apps.stock.db.Nature;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.StockMoveLine;
import com.axelor.apps.stock.db.TrackingNumber;
import com.axelor.apps.stock.db.TrackingNumberConfiguration;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.axelor.apps.stock.db.repo.TrackingNumberRepository;
import com.axelor.apps.stock.service.TrackingNumberCreateService;
import com.google.inject.Inject;
import com.google.inject.persist.Transactional;
import java.time.LocalDate;

/**
 * LVME : bouton « Dupliquer » des commandes clients, commandes d'achat et arrivages (fiche et liste),
 * comme la copie native d'Axelor (même client / fournisseur, mêmes lignes, nouvelle pièce en
 * brouillon avec un nouveau numéro), enregistrée pour être ouverte tout de suite.
 *
 * <ul>
 *   <li>commande client : lots et arrivages choisis sur les lignes non repris (à rechoisir) ;
 *   <li>commande d'achat et arrivage : chaque ligne copiée reçoit un nouveau lot « AE » si l'article
 *       génère ses lots à l'achat, sinon pas de lot (comme la duplication d'une ligne d'achat) ;
 *   <li>arrivage : repart « à embarquer », sans lien avec les lignes de la commande d'achat d'origine
 *       (pour ne pas recompter les quantités reçues de cette commande).
 * </ul>
 */
public class LvmeDuplicationService {

  @Inject protected SaleOrderRepository saleOrderRepository;
  @Inject protected PurchaseOrderRepository purchaseOrderRepository;
  @Inject protected StockMoveRepository stockMoveRepository;
  @Inject protected TrackingNumberRepository trackingNumberRepository;
  @Inject protected TrackingNumberCreateService trackingNumberCreateService;
  @Inject protected ProductCompanyService productCompanyService;

  @Transactional(rollbackOn = {Exception.class})
  public SaleOrder dupliquerCommandeClient(SaleOrder saleOrder) {
    SaleOrder copie = saleOrderRepository.copy(saleOrder, true);
    if (copie.getSaleOrderLineList() != null) {
      for (SaleOrderLine line : copie.getSaleOrderLineList()) {
        if (line.getSaleOrderLineLotList() != null) {
          line.getSaleOrderLineLotList().clear();
        }
        if (line.getSaleOrderLineArrivageList() != null) {
          line.getSaleOrderLineArrivageList().clear();
        }
      }
    }
    return saleOrderRepository.save(copie);
  }

  @Transactional(rollbackOn = {Exception.class})
  public PurchaseOrder dupliquerCommandeAchat(PurchaseOrder purchaseOrder) throws AxelorException {
    PurchaseOrder copie = purchaseOrderRepository.save(purchaseOrderRepository.copy(purchaseOrder, true));
    if (copie.getPurchaseOrderLineList() != null) {
      LocalDate date = copie.getOrderDate() != null ? copie.getOrderDate() : LocalDate.now();
      for (PurchaseOrderLine line : copie.getPurchaseOrderLineList()) {
        if (line.getTrackingNumber() != null) {
          line.setTrackingNumber(
              nouveauLot(
                  line.getProduct(),
                  copie.getCompany(),
                  date,
                  copie.getPurchaseOrderSeq(),
                  copie.getSupplierPartner()));
        }
      }
    }
    return purchaseOrderRepository.save(copie);
  }

  @Transactional(rollbackOn = {Exception.class})
  public StockMove dupliquerArrivage(StockMove arrivage) throws AxelorException {
    StockMove copie = stockMoveRepository.copy(arrivage, true);
    copie.setNature(Nature.EN_COURS_DE_PRODUCTION);
    copie.setOrigin(null);
    // sinon la nature de la copie serait recopiée sur la commande d'achat d'origine
    if (copie.getPurchaseOrderSet() != null) {
      copie.getPurchaseOrderSet().clear();
    }
    copie = stockMoveRepository.save(copie);
    if (copie.getStockMoveLineList() != null) {
      LocalDate date = LocalDate.now();
      for (StockMoveLine line : copie.getStockMoveLineList()) {
        line.setPurchaseOrderLine(null);
        if (line.getTrackingNumber() != null) {
          TrackingNumber lot =
              nouveauLot(
                  line.getProduct(),
                  copie.getCompany(),
                  date,
                  copie.getStockMoveSeq(),
                  copie.getPartner());
          line.setTrackingNumber(lot);
          if (lot != null && lot.getOriginStockMoveLine() == null) {
            lot.setOriginStockMoveLine(line);
          }
        }
      }
    }
    return stockMoveRepository.save(copie);
  }

  /** Nouveau lot « AE » + numéro si l'article génère ses lots à l'achat, sinon aucun lot. */
  protected TrackingNumber nouveauLot(
      Product product, Company company, LocalDate date, String origine, Partner fournisseur)
      throws AxelorException {
    if (product == null || company == null) {
      return null;
    }
    TrackingNumberConfiguration configuration =
        (TrackingNumberConfiguration)
            productCompanyService.get(product, "trackingNumberConfiguration", company);
    if (configuration == null
        || !configuration.getIsPurchaseTrackingManaged()
        || !configuration.getGeneratePurchaseAutoTrackingNbr()) {
      return null;
    }
    TrackingNumber lot =
        trackingNumberCreateService.getTrackingNumber(product, company, date, origine, fournisseur);
    if (lot.getLvmeNumeroBase() != null) {
      lot.setTrackingNumberSeq("AE" + lot.getLvmeNumeroBase());
      trackingNumberRepository.save(lot);
    }
    return lot;
  }
}

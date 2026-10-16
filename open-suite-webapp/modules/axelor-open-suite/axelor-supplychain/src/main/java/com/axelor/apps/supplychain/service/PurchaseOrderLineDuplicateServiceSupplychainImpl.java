package com.axelor.apps.supplychain.service;

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.base.db.Company;
import com.axelor.apps.base.db.Product;
import com.axelor.apps.base.service.ProductCompanyService;
import com.axelor.apps.purchase.db.PurchaseOrder;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.purchase.db.repo.PurchaseOrderLineRepository;
import com.axelor.apps.purchase.db.repo.PurchaseOrderRepository;
import com.axelor.apps.purchase.service.PurchaseOrderLineDuplicateServiceImpl;
import com.axelor.apps.purchase.service.PurchaseOrderService;
import com.axelor.apps.stock.db.TrackingNumber;
import com.axelor.apps.stock.db.TrackingNumberConfiguration;
import com.axelor.apps.stock.db.repo.TrackingNumberRepository;
import com.axelor.apps.stock.service.TrackingNumberCreateService;
import com.google.inject.Inject;
import com.google.inject.persist.Transactional;
import java.time.LocalDate;

/**
 * LVME : une ligne dupliquée ne garde pas le lot de la ligne d'origine (la copie diffère en général
 * par un détail, ex. le conditionnement). Si l'article génère ses lots à l'achat, un nouveau lot
 * « AE » + numéro est créé pour la copie, comme au choix de l'article ; sinon le lot de la copie
 * reste vide et l'utilisateur le choisit ou le crée.
 */
public class PurchaseOrderLineDuplicateServiceSupplychainImpl
    extends PurchaseOrderLineDuplicateServiceImpl {

  protected ProductCompanyService productCompanyService;
  protected TrackingNumberCreateService trackingNumberCreateService;
  protected TrackingNumberRepository trackingNumberRepository;

  @Inject
  public PurchaseOrderLineDuplicateServiceSupplychainImpl(
      PurchaseOrderLineRepository purchaseOrderLineRepository,
      PurchaseOrderRepository purchaseOrderRepository,
      PurchaseOrderService purchaseOrderService,
      ProductCompanyService productCompanyService,
      TrackingNumberCreateService trackingNumberCreateService,
      TrackingNumberRepository trackingNumberRepository) {
    super(purchaseOrderLineRepository, purchaseOrderRepository, purchaseOrderService);
    this.productCompanyService = productCompanyService;
    this.trackingNumberCreateService = trackingNumberCreateService;
    this.trackingNumberRepository = trackingNumberRepository;
  }

  @Override
  @Transactional(rollbackOn = {Exception.class})
  public PurchaseOrderLine duplicateLine(PurchaseOrderLine purchaseOrderLine)
      throws AxelorException {
    PurchaseOrderLine copy = super.duplicateLine(purchaseOrderLine);
    if (copy.getTrackingNumber() != null) {
      copy.setTrackingNumber(createLot(copy));
      purchaseOrderLineRepository.save(copy);
    }
    return copy;
  }

  /** Nouveau lot « AE » + numéro si l'article génère ses lots à l'achat, sinon aucun lot. */
  protected TrackingNumber createLot(PurchaseOrderLine line) throws AxelorException {
    PurchaseOrder purchaseOrder = line.getPurchaseOrder();
    Product product = line.getProduct();
    Company company = purchaseOrder != null ? purchaseOrder.getCompany() : null;
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
    LocalDate date =
        purchaseOrder.getOrderDate() != null ? purchaseOrder.getOrderDate() : LocalDate.now();
    TrackingNumber lot =
        trackingNumberCreateService.getTrackingNumber(
            product,
            company,
            date,
            purchaseOrder.getPurchaseOrderSeq(),
            purchaseOrder.getSupplierPartner());
    // commande pas encore partie : lot « à embarquer », renommé ensuite par l'arrivage
    if (lot.getLvmeNumeroBase() != null) {
      lot.setTrackingNumberSeq("AE" + lot.getLvmeNumeroBase());
      trackingNumberRepository.save(lot);
    }
    return lot;
  }
}

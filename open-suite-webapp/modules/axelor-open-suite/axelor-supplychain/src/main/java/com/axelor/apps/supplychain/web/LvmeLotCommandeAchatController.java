package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.db.Company;
import com.axelor.apps.base.db.Partner;
import com.axelor.apps.base.db.Product;
import com.axelor.apps.base.db.repo.CompanyRepository;
import com.axelor.apps.base.db.repo.PartnerRepository;
import com.axelor.apps.base.db.repo.ProductRepository;
import com.axelor.apps.base.service.ProductCompanyService;
import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.purchase.db.PurchaseOrder;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.stock.db.TrackingNumber;
import com.axelor.apps.stock.db.TrackingNumberConfiguration;
import com.axelor.apps.stock.service.TrackingNumberCreateService;
import com.axelor.db.JPA;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.axelor.rpc.Context;
import java.time.LocalDate;

/**
 * LVME : lot de la ligne de commande fournisseur. Au choix du produit, si l'article est configuré
 * pour générer ses lots à l'achat, un nouveau lot est créé et proposé ; sinon l'utilisateur choisit
 * ou crée le lot lui-même. Le lot est ensuite repris tel quel sur la ligne d'arrivage.
 */
public class LvmeLotCommandeAchatController {

  public void proposerLot(ActionRequest request, ActionResponse response) {
    try {
      Context context = request.getContext();
      PurchaseOrderLine line = context.asType(PurchaseOrderLine.class);
      TrackingNumber lot = line.getTrackingNumber();
      Long productId = line.getProduct() != null ? line.getProduct().getId() : null;

      // lot déjà adapté au produit : on n'y touche pas
      if (lot != null
          && productId != null
          && lot.getProduct() != null
          && productId.equals(lot.getProduct().getId())) {
        return;
      }
      if (productId == null) {
        if (lot != null) {
          response.setValue("trackingNumber", null);
        }
        return;
      }

      Context parent = context.getParent();
      PurchaseOrder purchaseOrder =
          parent != null && PurchaseOrder.class.equals(parent.getContextClass())
              ? parent.asType(PurchaseOrder.class)
              : line.getPurchaseOrder();
      if (purchaseOrder == null || purchaseOrder.getCompany() == null) {
        response.setValue("trackingNumber", null);
        return;
      }
      Long companyId = purchaseOrder.getCompany().getId();
      Long supplierId =
          purchaseOrder.getSupplierPartner() != null
              ? purchaseOrder.getSupplierPartner().getId()
              : null;
      String origin = purchaseOrder.getPurchaseOrderSeq();
      LocalDate date =
          purchaseOrder.getOrderDate() != null ? purchaseOrder.getOrderDate() : LocalDate.now();

      // contexte de l'écran (commande incomplète) écarté avant la création du lot, pour que
      // seule la création du lot soit enregistrée
      JPA.em().clear();
      Product product = Beans.get(ProductRepository.class).find(productId);
      Company company = Beans.get(CompanyRepository.class).find(companyId);
      Partner supplier =
          supplierId != null ? Beans.get(PartnerRepository.class).find(supplierId) : null;

      TrackingNumberConfiguration configuration =
          (TrackingNumberConfiguration)
              Beans.get(ProductCompanyService.class)
                  .get(product, "trackingNumberConfiguration", company);
      if (configuration == null
          || !configuration.getIsPurchaseTrackingManaged()
          || !configuration.getGeneratePurchaseAutoTrackingNbr()) {
        // pas de lot automatique : l'utilisateur choisit le lot
        response.setValue("trackingNumber", null);
        return;
      }

      TrackingNumber newLot =
          Beans.get(TrackingNumberCreateService.class)
              .getTrackingNumber(product, company, date, origin, supplier);
      response.setValue("trackingNumber", newLot);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

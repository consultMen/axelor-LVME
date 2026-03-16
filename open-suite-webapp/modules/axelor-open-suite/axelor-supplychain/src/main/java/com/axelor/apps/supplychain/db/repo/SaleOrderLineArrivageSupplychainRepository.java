package com.axelor.apps.supplychain.db.repo;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.supplychain.db.SaleOrderLineArrivage;
import com.axelor.apps.supplychain.service.SaleOrderLineArrivageService;
import com.axelor.inject.Beans;
import java.util.List;

public class SaleOrderLineArrivageSupplychainRepository extends SaleOrderLineArrivageRepository {

  public List<SaleOrderLineArrivage> findBySaleOrderLine(SaleOrderLine sol) {
    return all().filter("self.saleOrderLine = :sol").bind("sol", sol).fetch();
  }

  public List<SaleOrderLineArrivage> findByPurchaseOrderLine(PurchaseOrderLine pol) {
    return all().filter("self.purchaseOrderLine = :pol").bind("pol", pol).fetch();
  }

  public List<SaleOrderLineArrivage> findByPOLOrderedFIFO(PurchaseOrderLine pol) {
    return all()
        .filter("self.purchaseOrderLine = :pol AND self.qtyAllocated > self.qtyReceived")
        .bind("pol", pol)
        .order("saleOrderLine.saleOrder.confirmationDateTime")
        .fetch();
  }

  @Override
  public void remove(SaleOrderLineArrivage entity) {
    try {
      Beans.get(SaleOrderLineArrivageService.class).deallocate(entity);
    } catch (Exception e) {
      TraceBackService.trace(e);
    }
    super.remove(entity);
  }
}

package com.axelor.apps.supplychain.web;

import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.stock.db.StockLocation;
import com.axelor.apps.supplychain.service.SaleOrderLineStockLocationService;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;

public class SaleOrderStockLocationLvmeController {

  /** Met à jour l'emplacement affiché dans le formulaire, sans attendre l'enregistrement. */
  public void refreshStockLocation(ActionRequest request, ActionResponse response) {
    SaleOrder so = request.getContext().asType(SaleOrder.class);
    if (so.getId() == null) {
      return;
    }
    StockLocation candidate =
        Beans.get(SaleOrderLineStockLocationService.class)
            .computeSaleOrderStockLocation(so.getId(), null);
    if (candidate != null
        && (so.getStockLocation() == null
            || !candidate.getId().equals(so.getStockLocation().getId()))) {
      response.setValue("stockLocation", candidate);
    }
  }
}

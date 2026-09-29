package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.db.repo.SaleOrderLineRepository;
import com.axelor.apps.supplychain.service.saleorderline.SaleOrderLineDuplicateLvmeService;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;

public class SaleOrderLineDuplicateLvmeController {

  /** LVME : duplique la ligne de commande client cliquée, juste sous la ligne d'origine. */
  public void duplicateLine(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
      if (saleOrderLine.getId() == null) {
        return;
      }
      Beans.get(SaleOrderLineDuplicateLvmeService.class)
          .duplicateLine(Beans.get(SaleOrderLineRepository.class).find(saleOrderLine.getId()));
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

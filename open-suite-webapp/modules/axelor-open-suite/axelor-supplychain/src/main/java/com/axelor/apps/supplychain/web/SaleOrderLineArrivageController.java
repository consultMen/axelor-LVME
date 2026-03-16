package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.purchase.db.repo.PurchaseOrderLineRepository;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.db.repo.SaleOrderLineRepository;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.StockMoveLine;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.axelor.apps.supplychain.db.SaleOrderLineArrivage;
import com.axelor.apps.supplychain.service.ReservedQtyService;
import com.axelor.apps.supplychain.service.SaleOrderLineArrivageService;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.google.inject.Singleton;
import java.math.BigDecimal;

@Singleton
public class SaleOrderLineArrivageController {

  public void addArrivage(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLineArrivage arrivage = request.getContext().asType(SaleOrderLineArrivage.class);

      // POL sélectionnée dans le wizard → find depuis repo
      PurchaseOrderLine pol =
          Beans.get(PurchaseOrderLineRepository.class)
              .find(arrivage.getPurchaseOrderLine().getId());

      // SOL parente via _saleOrderLineId passé dans le contexte du popup
      Object solIdObj = request.getContext().get("_saleOrderLineId");
      if (solIdObj == null) {
        response.setError("Veuillez sauvegarder la commande vente avant d'ajouter un arrivage.");
        return;
      }

      // Gérer les cas String, Integer, Long
      Long solId;
      if (solIdObj instanceof Number) {
        solId = ((Number) solIdObj).longValue();
      } else {
        solId = Long.parseLong(solIdObj.toString().replaceAll("[^0-9]", ""));
      }

      SaleOrderLine sol = Beans.get(SaleOrderLineRepository.class).find(solId);
      if (sol == null) {
        response.setError("Ligne de vente introuvable.");
        return;
      }

      BigDecimal qty = arrivage.getQtyAllocated();
      if (qty == null || qty.compareTo(BigDecimal.ZERO) <= 0) {
        response.setError("Veuillez saisir une quantité valide.");
        return;
      }

      Beans.get(SaleOrderLineArrivageService.class).allocateFromPurchaseOrderLine(sol, pol, qty);
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void recomputeQties(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine sol = request.getContext().asType(SaleOrderLine.class);
      sol = Beans.get(SaleOrderLineRepository.class).find(sol.getId());
      Beans.get(SaleOrderLineArrivageService.class).recomputeQties(sol);
      response.setValue("qtyFromArrivage", sol.getQtyFromArrivage());
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void onQtyFromStockChange(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine sol = request.getContext().asType(SaleOrderLine.class);
      BigDecimal qtyFromStock =
          sol.getQtyFromStock() == null ? BigDecimal.ZERO : sol.getQtyFromStock();
      sol = Beans.get(SaleOrderLineRepository.class).find(sol.getId());
      // Synchronise requestedReservedQty = qtyFromStock
      Beans.get(ReservedQtyService.class).updateRequestedReservedQty(sol, qtyFromStock);
      response.setValue("requestedReservedQty", qtyFromStock);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void transferArrivagesToStock(ActionRequest request, ActionResponse response) {
    try {
      StockMove stockMove = request.getContext().asType(StockMove.class);
      stockMove = Beans.get(StockMoveRepository.class).find(stockMove.getId());
      for (StockMoveLine line : stockMove.getStockMoveLineList()) {
        if (line.getPurchaseOrderLine() != null && line.getRealQty() != null) {
          Beans.get(SaleOrderLineArrivageService.class)
              .transferArrivagesToStockReservations(line.getPurchaseOrderLine(), line.getRealQty());
        }
      }
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

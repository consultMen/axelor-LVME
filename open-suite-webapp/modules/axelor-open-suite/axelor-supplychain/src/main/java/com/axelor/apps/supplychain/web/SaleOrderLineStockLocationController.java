package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.db.repo.SaleOrderLineRepository;
import com.axelor.apps.stock.db.StockLocation;
import com.axelor.apps.stock.db.repo.StockLocationRepository;
import com.axelor.apps.supplychain.db.SaleOrderLineStockLocation;
import com.axelor.apps.supplychain.service.SaleOrderLineStockLocationService;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.google.inject.Singleton;
import java.math.BigDecimal;
import java.util.Map;

@Singleton
public class SaleOrderLineStockLocationController {

  public void addStockLocation(ActionRequest request, ActionResponse response) {
    try {
      // Comme l'arrivage — asType sur le model du wizard
      SaleOrderLineStockLocation item =
              request.getContext().asType(SaleOrderLineStockLocation.class);

      // Récupérer stockLocation
      Object slObj = request.getContext().get("stockLocation");
      if (slObj == null) {
        response.setError("Veuillez sélectionner un emplacement.");
        return;
      }
      Long slId;
      if (slObj instanceof Map) {
        slId = Long.valueOf(((Map<?, ?>) slObj).get("id").toString());
      } else if (slObj instanceof StockLocation) {
        slId = ((StockLocation) slObj).getId();
      } else {
        slId = Long.valueOf(slObj.toString().replaceAll("[^0-9]", ""));
      }
      StockLocation stockLocation =
              Beans.get(StockLocationRepository.class).find(slId);
      if (stockLocation == null) {
        response.setError("Emplacement introuvable.");
        return;
      }

      // Récupérer SOL via _saleOrderLineId
      Object solIdObj = request.getContext().get("_saleOrderLineId");
      if (solIdObj == null) {
        response.setError(
                "Veuillez sauvegarder la commande avant d'ajouter un emplacement.");
        return;
      }
      Long solId;
      if (solIdObj instanceof Number) {
        solId = ((Number) solIdObj).longValue();
      } else {
        solId = Long.valueOf(solIdObj.toString().replaceAll("[^0-9]", ""));
      }
      SaleOrderLine sol =
              Beans.get(SaleOrderLineRepository.class).find(solId);
      if (sol == null) {
        response.setError("Ligne de vente introuvable.");
        return;
      }

      // Récupérer qty
      BigDecimal qty = item.getQty();
      if (qty == null || qty.compareTo(BigDecimal.ZERO) <= 0) {
        response.setError("Veuillez saisir une quantité valide.");
        return;
      }

      // Allocate
      Beans.get(SaleOrderLineStockLocationService.class)
              .allocate(sol, stockLocation,
                      qty.setScale(4, java.math.RoundingMode.HALF_UP));

      // ✅ Comme l'arrivage — juste setReload !
      response.setReload(true);

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void recomputeQtyFromStock(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine sol = request.getContext().asType(SaleOrderLine.class);
      if (sol != null && sol.getId() != null) {
        sol = Beans.get(SaleOrderLineRepository.class).find(sol.getId());
        Beans.get(SaleOrderLineStockLocationService.class)
                .recomputeQtyFromStock(sol);
        response.setValue("qtyFromStock", sol.getQtyFromStock());
      }
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}
package com.axelor.apps.supplychain.web;

import com.axelor.apps.stock.db.CessionStock;
import com.axelor.apps.supplychain.service.FraisStockageService;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;

public class FraisStockageController {

  /** Appelé par le bouton "Appliquer" sur une Cession FRAIS_STOCKAGE. */
  public void appliquerFraisStockage(ActionRequest request, ActionResponse response) {
    try {
      CessionStock cession = request.getContext().asType(CessionStock.class);
      String result = Beans.get(FraisStockageService.class).appliquerCession(cession);
      response.setNotify(result);
      response.setReload(true);
    } catch (Exception e) {
      response.setError("Erreur : " + e.getMessage());
    }
  }
}

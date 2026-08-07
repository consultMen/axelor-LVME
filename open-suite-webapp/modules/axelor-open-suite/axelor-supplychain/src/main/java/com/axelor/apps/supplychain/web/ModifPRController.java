package com.axelor.apps.supplychain.web;

import com.axelor.apps.stock.db.CessionStock;
import com.axelor.apps.stock.db.TrackingNumber;
import com.axelor.apps.supplychain.service.ModifPRService;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import java.math.BigDecimal;

public class ModifPRController {

  /** Bouton "Appliquer la modification PR". */
  public void appliquerModifPR(ActionRequest request, ActionResponse response) {
    try {
      CessionStock cession = request.getContext().asType(CessionStock.class);
      String result = Beans.get(ModifPRService.class).appliquerModifPR(cession);
      response.setNotify(result);
      response.setReload(true);
    } catch (Exception e) {
      response.setError("Erreur : " + e.getMessage());
    }
  }

  /** onChange lotSource : charger l'ancien PR automatiquement. */
  public void loadAncienPR(ActionRequest request, ActionResponse response) {
    try {
      CessionStock cession = request.getContext().asType(CessionStock.class);
      TrackingNumber lot = cession.getLotSource();
      if (lot != null) {
        BigDecimal ancienPR = Beans.get(ModifPRService.class).getAncienPRFromLot(lot);
        response.setValue("ancienPR", ancienPR);
      } else {
        response.setValue("ancienPR", BigDecimal.ZERO);
      }
    } catch (Exception e) {
      response.setError("Erreur : " + e.getMessage());
    }
  }
}

package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.stock.db.TrackingNumber;
import com.axelor.apps.stock.db.repo.TrackingNumberRepository;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.google.inject.persist.Transactional;
import java.util.Map;

/** LVME : écran « Lots Vérifiés » (GESCOM) — marque un lot comme vérifié ou non vérifié. */
public class LvmeLotVerifieController {

  @Transactional(rollbackOn = {Exception.class})
  public void valider(ActionRequest request, ActionResponse response) {
    try {
      Object lot = request.getContext().get("lotAVerifier");
      if (!(lot instanceof Map) || ((Map<?, ?>) lot).get("id") == null) {
        response.setInfo("Choisissez le N° Lot à vérifier.");
        return;
      }
      Long lotId = Long.valueOf(((Map<?, ?>) lot).get("id").toString());
      Object choix = request.getContext().get("verification");
      boolean verifie = choix == null || Integer.parseInt(choix.toString()) == 1;

      TrackingNumberRepository repo = Beans.get(TrackingNumberRepository.class);
      TrackingNumber trackingNumber = repo.find(lotId);
      if (trackingNumber == null) {
        return;
      }
      trackingNumber.setLotVerifie(verifie);
      repo.save(trackingNumber);

      response.setAttr("lotsDashlet", "refresh", true);
      response.setNotify(
          "Lot "
              + trackingNumber.getTrackingNumberSeq()
              + (verifie ? " marqué vérifié." : " marqué non vérifié."));
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.db.Partner;
import com.axelor.apps.base.db.repo.PartnerRepository;
import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.db.JPA;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import java.util.Map;

/**
 * LVME : écran Ventes > Réservations : rattacher le client livré choisi au compte de réservation
 * choisi, ou l'en détacher (lien CLIENT_RESERV de GESCOM, Partner.lvmeCompteReservation).
 */
public class LvmeReservationController {

  public void rattacher(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      Partner compte = partenaire(c.get("compte"));
      Partner client = partenaire(c.get("client"));
      if (compte == null || client == null) {
        response.setInfo("Choisissez le compte de réservation et le client livré à rattacher.");
        return;
      }
      if (compte.equals(client)) {
        response.setInfo("Un compte de réservation ne peut pas être rattaché à lui-même.");
        return;
      }
      JPA.runInTransaction(() -> client.setLvmeCompteReservation(compte));
      response.setNotify(client.getName() + " rattaché à " + compte.getName() + ".");
      rafraichir(response);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void detacher(ActionRequest request, ActionResponse response) {
    try {
      Partner client = partenaire(request.getContext().get("client"));
      if (client == null || client.getLvmeCompteReservation() == null) {
        response.setInfo("Choisissez un client livré rattaché à un compte de réservation.");
        return;
      }
      String compte = client.getLvmeCompteReservation().getName();
      JPA.runInTransaction(() -> client.setLvmeCompteReservation(null));
      response.setNotify(client.getName() + " détaché de " + compte + ".");
      rafraichir(response);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  private static void rafraichir(ActionResponse response) {
    response.setAttr("comptesDashlet", "refresh", true);
    response.setAttr("lignesDashlet", "refresh", true);
    response.setAttr("clientsDashlet", "refresh", true);
  }

  /** Tiers d'un champ many-to-one du contexte (Map avec « id »), sinon null. */
  private static Partner partenaire(Object valeur) {
    if (valeur instanceof Map && ((Map<?, ?>) valeur).get("id") != null) {
      return Beans.get(PartnerRepository.class)
          .find(Long.valueOf(((Map<?, ?>) valeur).get("id").toString()));
    }
    return null;
  }
}

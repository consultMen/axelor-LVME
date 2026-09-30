package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.db.JPA;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;
import javax.persistence.Query;

/** LVME : écran « Historique Produit » (GESCOM) — totaux du bas de l'écran et rafraîchissement. */
public class LvmeHistoriqueProduitController {

  public void valider(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> context = request.getContext();
      Object produit = context.get("produit");
      Long produitId =
          produit instanceof Map && ((Map<?, ?>) produit).get("id") != null
              ? Long.valueOf(((Map<?, ?>) produit).get("id").toString())
              : 0L;
      LocalDate du = toDate(context.get("entreeDu"), LocalDate.of(1900, 1, 1));
      LocalDate au = toDate(context.get("entreeAu"), LocalDate.of(2999, 12, 31));

      Query query =
          JPA.em()
              .createQuery(
                  "SELECT SUM(self.nbColis), SUM(self.poidsEntree), SUM(self.poidsSortie)"
                      + " FROM HistoriqueProduit self"
                      + " WHERE self.product.id = :prod"
                      + " AND self.dateMvt BETWEEN :du AND :au");
      query.setParameter("prod", produitId);
      query.setParameter("du", du);
      query.setParameter("au", au);
      Object[] row = (Object[]) query.getSingleResult();

      BigDecimal entrees = orZero(row[1]);
      BigDecimal sorties = orZero(row[2]);
      response.setValue("$totalColis", orZero(row[0]));
      response.setValue("$poidsEntrees", entrees);
      response.setValue("$poidsSorties", sorties);
      response.setValue("$stockPeriode", entrees.subtract(sorties));
      response.setAttr("historiqueDashlet", "refresh", true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  private static LocalDate toDate(Object value, LocalDate defaultValue) {
    if (value == null || value.toString().length() < 10) {
      return defaultValue;
    }
    return LocalDate.parse(value.toString().substring(0, 10));
  }

  private static BigDecimal orZero(Object value) {
    return value == null ? BigDecimal.ZERO : new BigDecimal(value.toString());
  }
}

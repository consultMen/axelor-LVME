package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.supplychain.db.PalmaresCommercial;
import com.axelor.apps.supplychain.db.PalmaresCommercialWizard;
import com.axelor.db.JPA;
import com.axelor.meta.schema.actions.ActionView;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.axelor.rpc.Context;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import javax.persistence.EntityManager;
import javax.persistence.Query;

public class PalmaresCommercialController {

  public void generate(ActionRequest request, ActionResponse response) throws AxelorException {
    Context context = request.getContext();
    PalmaresCommercialWizard wizard = context.asType(PalmaresCommercialWizard.class);
    LocalDate dateDe = wizard.getDateDe();
    LocalDate dateA = wizard.getDateA();

    JPA.runInTransaction(() -> computeAndPersist(dateDe, dateA));

    response.setView(
        ActionView.define("Palmarès par commercial")
            .model(PalmaresCommercial.class.getName())
            .add("grid", "palmares-commercial-grid")
            .add("form", "palmares-commercial-form")
            .map());
  }

  private void computeAndPersist(LocalDate dateDe, LocalDate dateA) {
    EntityManager em = JPA.em();
    em.createNativeQuery("DELETE FROM supplychain_palmares_commercial").executeUpdate();

    String sql =
        "SELECT so.commercial AS commercial_id, "
            + "COALESCE(SUM(il.ex_tax_total), 0) AS ca_ht, "
            + "COALESCE(SUM(il.ex_tax_total * COALESCE(so.taux_commission,0) / 100), 0) AS commission "
            + "FROM account_invoice_line il "
            + "JOIN account_invoice inv ON inv.id = il.invoice "
            + "JOIN sale_sale_order_line sol ON sol.id = il.sale_order_line "
            + "JOIN sale_sale_order so ON so.id = sol.sale_order "
            + "WHERE inv.status_select = 3 "
            + "AND inv.invoice_date BETWEEN :dateDe AND :dateA "
            + "GROUP BY so.commercial";

    Query query = em.createNativeQuery(sql);
    query.setParameter("dateDe", dateDe);
    query.setParameter("dateA", dateA);

    List<Object[]> results = query.getResultList();

    for (Object[] row : results) {
      Long commercialId = row[0] != null ? ((Number) row[0]).longValue() : null;
      BigDecimal caHt = ((BigDecimal) row[1]).setScale(2, RoundingMode.HALF_UP);
      BigDecimal commission = ((BigDecimal) row[2]).setScale(2, RoundingMode.HALF_UP);

      PalmaresCommercial pc = new PalmaresCommercial();
      if (commercialId != null) {
        pc.setCommercial(em.find(com.axelor.auth.db.User.class, commercialId));
      }
      pc.setCaHt(caHt);
      pc.setMontantCommission(commission);
      em.persist(pc);
    }
  }
}

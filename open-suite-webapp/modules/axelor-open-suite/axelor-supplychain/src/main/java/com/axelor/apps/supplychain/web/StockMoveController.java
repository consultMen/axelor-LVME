/*
 * Axelor Business Solutions
 *
 * Copyright (C) 2005-2025 Axelor (<http://axelor.com>).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.ResponseMessageType;
import com.axelor.apps.base.db.Company;
import com.axelor.apps.base.db.repo.PartnerLinkTypeRepository;
import com.axelor.apps.base.service.PartnerLinkService;
import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.supplychain.db.SupplyChainConfig;
import com.axelor.apps.supplychain.exception.SupplychainExceptionMessage;
import com.axelor.apps.supplychain.service.StockMoveReservedQtyService;
import com.axelor.apps.supplychain.service.StockMoveServiceSupplychain;
import com.axelor.apps.supplychain.service.app.AppSupplychainService;
import com.axelor.apps.supplychain.service.config.SupplyChainConfigService;
import com.axelor.i18n.I18n;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;

public class StockMoveController {

  public void verifyProductStock(ActionRequest request, ActionResponse response) {
    try {
      StockMove stockMove = request.getContext().asType(StockMove.class);
      if (stockMove.getPickingIsEdited() && !stockMove.getAvailabilityRequest()) {
        response.setValue("availabilityRequest", true);
        response.setInfo(
            I18n.get(SupplychainExceptionMessage.STOCK_MOVE_AVAILABILITY_REQUEST_NOT_UPDATABLE));
        return;
      }
      Beans.get(StockMoveServiceSupplychain.class).verifyProductStock(stockMove);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
      response.setValue("availabilityRequest", false);
    }
  }

  /**
   * Called from stock move form view, on available qty boolean change. Only called if the user
   * accepted to allocate everything. Call {@link
   * StockMoveReservedQtyService#allocateAll(StockMove)}.
   *
   * @param request
   * @param response
   */
  public void allocateAll(ActionRequest request, ActionResponse response) {
    try {
      StockMove stockMove = request.getContext().asType(StockMove.class);
      Company company = stockMove.getCompany();
      if (company == null) {
        return;
      }

      SupplyChainConfig supplyChainConfig =
          Beans.get(SupplyChainConfigService.class).getSupplyChainConfig(company);
      if (!Beans.get(AppSupplychainService.class).getAppSupplychain().getManageStockReservation()
          || !stockMove.getAvailabilityRequest()
          || !supplyChainConfig.getAutoAllocateOnAvailabilityRequest()) {
        return;
      }
      Beans.get(StockMoveReservedQtyService.class).allocateAll(stockMove);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    } finally {
      response.setReload(true);
    }
  }

  public void isAllocatedStockMoveLineRemoved(ActionRequest request, ActionResponse response) {
    StockMove stockMove = request.getContext().asType(StockMove.class);
    if (stockMove.getId() != null
        && Beans.get(StockMoveServiceSupplychain.class)
            .isAllocatedStockMoveLineRemoved(stockMove)) {
      response.setValue("stockMoveLineList", stockMove.getStockMoveLineList());
      response.setInfo(
          I18n.get(SupplychainExceptionMessage.ALLOCATED_STOCK_MOVE_LINE_DELETED_ERROR));
    }
  }

  /**
   * Called from stock move form view, on delivered partner select. Call {@link
   * PartnerLinkService#computePartnerFilter}
   *
   * @param request
   * @param response
   */
  public void setInvoicedPartnerDomain(ActionRequest request, ActionResponse response) {
    try {
      StockMove stockMove = request.getContext().asType(StockMove.class);
      String strFilter =
          Beans.get(PartnerLinkService.class)
              .computePartnerFilter(
                  stockMove.getPartner(), PartnerLinkTypeRepository.TYPE_SELECT_INVOICED_TO);

      response.setAttr("invoicedPartner", "domain", strFilter);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void setDefaultInvoicedPartner(ActionRequest request, ActionResponse response) {
    try {
      StockMove stockMove = request.getContext().asType(StockMove.class);
      Beans.get(StockMoveServiceSupplychain.class).setDefaultInvoicedPartner(stockMove);
      response.setValues(stockMove);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void checkInvoiceStatus(ActionRequest request, ActionResponse response) {
    try {
      StockMove stockMove = request.getContext().asType(StockMove.class);
      Beans.get(StockMoveServiceSupplychain.class).checkInvoiceStatus(stockMove);
    } catch (Exception e) {
      TraceBackService.trace(response, e, ResponseMessageType.WARNING);
    }
  }

  public void setInvoicingStatusInvoicedDelayed(ActionRequest request, ActionResponse response) {
    StockMove stockMove = request.getContext().asType(StockMove.class);
    Beans.get(StockMoveServiceSupplychain.class).setInvoicingStatusInvoicedDelayed(stockMove);
    response.setReload(true);
  }

  public void setInvoicingStatusInvoicedValidated(ActionRequest request, ActionResponse response) {
    StockMove stockMove = request.getContext().asType(StockMove.class);
    Beans.get(StockMoveServiceSupplychain.class).setInvoicingStatusInvoicedValidated(stockMove);
    response.setReload(true);
  }

  public void fillRealQuantities(ActionRequest request, ActionResponse response) {
    try {
      StockMove stockMove = request.getContext().asType(StockMove.class);

      Beans.get(StockMoveServiceSupplychain.class).fillRealQuantities(stockMove);

      response.setValue("stockMoveLineList", stockMove.getStockMoveLineList());

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 LVME - Restaurer les calculs PR/Marge apr\u00e8s r\u00e9alisation BL
  // R\u00e9sout : Axelor \u00e9crase PR/Marge apr\u00e8s realize stock move
  // ==================================================================

  @com.google.inject.persist.Transactional(rollbackOn = {Exception.class})
  public void restoreCalculsAfterRealize(ActionRequest request, ActionResponse response) {
    try {
      StockMove stockMove = request.getContext().asType(StockMove.class);

      if (stockMove.getId() == null) return;

      StockMove smDb =
          Beans.get(com.axelor.apps.stock.db.repo.StockMoveRepository.class)
              .find(stockMove.getId());

      if (smDb == null || smDb.getSaleOrderSet() == null) return;

      int totalUpdated = 0;
      for (com.axelor.apps.sale.db.SaleOrder saleOrder : smDb.getSaleOrderSet()) {
        if (saleOrder.getSaleOrderLineList() == null) continue;

        for (com.axelor.apps.sale.db.SaleOrderLine line : saleOrder.getSaleOrderLineList()) {
          // R\u00e9cup\u00e9rer le lot via JPQL
          java.util.List<com.axelor.apps.supplychain.db.SaleOrderLineLot> lots =
              com.axelor
                  .db
                  .JPA
                  .em()
                  .createQuery(
                      "SELECT lot FROM SaleOrderLineLot lot "
                          + "WHERE lot.saleOrderLine.id = :solId "
                          + "AND lot.trackingNumber IS NOT NULL "
                          + "ORDER BY lot.id DESC",
                      com.axelor.apps.supplychain.db.SaleOrderLineLot.class)
                  .setParameter("solId", line.getId())
                  .getResultList();

          if (lots.isEmpty()) continue;

          com.axelor.apps.stock.db.TrackingNumber tn = lots.get(0).getTrackingNumber();
          if (tn == null) continue;

          // R\u00e9cup\u00e9rer le PR depuis StockMoveLine
          java.math.BigDecimal pr = java.math.BigDecimal.ZERO;
          java.util.List<com.axelor.apps.stock.db.StockMoveLine> smls =
              Beans.get(com.axelor.apps.stock.db.repo.StockMoveLineRepository.class)
                  .all()
                  .filter(
                      "self.trackingNumber.id = ?1 AND self.prKg IS NOT NULL AND self.prKg > 0",
                      tn.getId())
                  .order("-id")
                  .fetch();

          if (!smls.isEmpty()) {
            pr = smls.get(0).getPrKg().setScale(3, java.math.RoundingMode.HALF_UP);
          }

          if (pr.signum() == 0) continue;

          // R\u00e9cup\u00e9rer les autres valeurs
          java.math.BigDecimal fraisCong =
              line.getFraisCongelation() != null
                  ? line.getFraisCongelation()
                  : java.math.BigDecimal.ZERO;
          java.math.BigDecimal tauxRFA =
              line.getTauxRFA() != null ? line.getTauxRFA() : java.math.BigDecimal.ZERO;
          java.math.BigDecimal tauxComm =
              line.getTauxCommission() != null
                  ? line.getTauxCommission()
                  : java.math.BigDecimal.ZERO;
          java.math.BigDecimal qty =
              line.getQty() != null ? line.getQty() : java.math.BigDecimal.ZERO;
          java.math.BigDecimal exTaxTotal =
              line.getExTaxTotal() != null ? line.getExTaxTotal() : java.math.BigDecimal.ZERO;

          // Recalculer PR Net + Marge
          java.math.BigDecimal coefficient =
              java.math.BigDecimal.ONE.add(
                  tauxRFA
                      .add(tauxComm)
                      .divide(new java.math.BigDecimal("100"), 6, java.math.RoundingMode.HALF_UP));

          java.math.BigDecimal prixRevientNet =
              pr.add(fraisCong).multiply(coefficient).setScale(4, java.math.RoundingMode.HALF_UP);

          java.math.BigDecimal coutTotal =
              prixRevientNet.multiply(qty).setScale(2, java.math.RoundingMode.HALF_UP);
          java.math.BigDecimal margeBrute =
              exTaxTotal.subtract(coutTotal).setScale(2, java.math.RoundingMode.HALF_UP);

          java.math.BigDecimal tauxMarge = java.math.BigDecimal.ZERO;
          if (exTaxTotal.signum() != 0) {
            tauxMarge =
                margeBrute
                    .multiply(new java.math.BigDecimal("100"))
                    .divide(exTaxTotal, 2, java.math.RoundingMode.HALF_UP);
          }

          java.math.BigDecimal tauxMarkup = java.math.BigDecimal.ZERO;
          if (coutTotal.signum() != 0) {
            tauxMarkup =
                margeBrute
                    .multiply(new java.math.BigDecimal("100"))
                    .divide(coutTotal, 2, java.math.RoundingMode.HALF_UP);
          }

          // UPDATE SQL direct
          com.axelor
              .db
              .JPA
              .em()
              .createNativeQuery(
                  "UPDATE sale_sale_order_line SET "
                      + "sub_total_cost_price = :pr, "
                      + "prix_revient_net = :prNet, "
                      + "sub_total_gross_margin = :marge, "
                      + "sub_margin_rate = :tauxMarge, "
                      + "sub_total_markup = :markup "
                      + "WHERE id = :id")
              .setParameter("pr", pr)
              .setParameter("prNet", prixRevientNet)
              .setParameter("marge", margeBrute)
              .setParameter("tauxMarge", tauxMarge)
              .setParameter("markup", tauxMarkup)
              .setParameter("id", line.getId())
              .executeUpdate();

          totalUpdated++;
          System.out.println(
              "=== RESTORE AFTER REALIZE === \u2705 Ligne "
                  + line.getId()
                  + " : PR="
                  + pr
                  + " | Marge="
                  + margeBrute);
        }
      }

      System.out.println(
          "=== RESTORE AFTER REALIZE === \u2705 Termin\u00e9 ("
              + totalUpdated
              + " ligne(s) restaur\u00e9es)");

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

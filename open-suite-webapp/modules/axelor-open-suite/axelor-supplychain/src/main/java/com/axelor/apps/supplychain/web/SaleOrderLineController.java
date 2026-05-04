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

import com.axelor.apps.account.service.analytic.AnalyticGroupService;
import com.axelor.apps.base.AxelorException;
import com.axelor.apps.base.ResponseMessageType;
import com.axelor.apps.base.db.Blocking;
import com.axelor.apps.base.db.Partner;
import com.axelor.apps.base.db.Product;
import com.axelor.apps.base.db.repo.BlockingRepository;
import com.axelor.apps.base.db.repo.TraceBackRepository;
import com.axelor.apps.base.service.BlockingService;
import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.db.repo.SaleOrderLineRepository;
import com.axelor.apps.sale.service.saleorderline.SaleOrderLineContextHelper;
import com.axelor.apps.supplychain.exception.SupplychainExceptionMessage;
import com.axelor.apps.supplychain.model.AnalyticLineModel;
import com.axelor.apps.supplychain.service.AnalyticLineModelService;
import com.axelor.apps.supplychain.service.ReservedQtyService;
import com.axelor.apps.supplychain.service.saleorderline.SaleOrderLineCheckSupplychainService;
import com.axelor.apps.supplychain.service.saleorderline.SaleOrderLineDomainSupplychainService;
import com.axelor.apps.supplychain.service.saleorderline.SaleOrderLineServiceSupplyChain;
import com.axelor.apps.supplychain.service.saleorderline.view.SaleOrderLineOnSaleSupplyChangeService;
import com.axelor.apps.supplychain.service.saleorderline.view.SaleOrderLineViewSupplychainService;
import com.axelor.db.mapper.Mapper;
import com.axelor.i18n.I18n;
import com.axelor.inject.Beans;
import com.axelor.meta.schema.actions.ActionView;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.axelor.rpc.Context;
import com.axelor.utils.helpers.ContextHelper;
import com.google.common.base.Strings;
import com.google.inject.Singleton;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Singleton
public class SaleOrderLineController {

  public void createAnalyticDistributionWithTemplate(
      ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
      SaleOrder saleOrder =
          ContextHelper.getContextParent(request.getContext(), SaleOrder.class, 1);

      AnalyticLineModel analyticLineModel = new AnalyticLineModel(saleOrderLine, saleOrder);

      Beans.get(AnalyticLineModelService.class)
          .createAnalyticDistributionWithTemplate(analyticLineModel);

      response.setValue("analyticMoveLineList", analyticLineModel.getAnalyticMoveLineList());
    } catch (Exception e) {
      TraceBackService.trace(response, e, ResponseMessageType.ERROR);
    }
  }

  /**
   * Called from sale order line request quantity wizard view. Call {@link
   * ReservedQtyService#updateReservedQty(SaleOrderLine, BigDecimal)}.
   *
   * @param request
   * @param response
   */
  public void changeReservedQty(ActionRequest request, ActionResponse response) {
    SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
    BigDecimal newReservedQty = saleOrderLine.getReservedQty();
    try {
      saleOrderLine = Beans.get(SaleOrderLineRepository.class).find(saleOrderLine.getId());
      Product product = saleOrderLine.getProduct();
      if (product == null || !product.getStockManaged()) {
        throw new AxelorException(
            TraceBackRepository.CATEGORY_INCONSISTENCY,
            I18n.get(SupplychainExceptionMessage.SALE_ORDER_LINE_PRODUCT_NOT_STOCK_MANAGED));
      }
      Beans.get(ReservedQtyService.class).updateReservedQty(saleOrderLine, newReservedQty);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void changeRequestedReservedQty(ActionRequest request, ActionResponse response) {
    SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
    BigDecimal newReservedQty = saleOrderLine.getRequestedReservedQty();
    try {
      saleOrderLine = Beans.get(SaleOrderLineRepository.class).find(saleOrderLine.getId());
      Beans.get(ReservedQtyService.class).updateRequestedReservedQty(saleOrderLine, newReservedQty);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /**
   * Called from sale order line form view, on request qty click. Call {@link
   * ReservedQtyService#requestQty(SaleOrderLine)}
   *
   * @param request
   * @param response
   */
  public void requestQty(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
      saleOrderLine = Beans.get(SaleOrderLineRepository.class).find(saleOrderLine.getId());
      Product product = saleOrderLine.getProduct();
      if (product == null || !product.getStockManaged()) {
        throw new AxelorException(
            TraceBackRepository.CATEGORY_INCONSISTENCY,
            I18n.get(SupplychainExceptionMessage.SALE_ORDER_LINE_PRODUCT_NOT_STOCK_MANAGED));
      }
      Beans.get(ReservedQtyService.class).requestQty(saleOrderLine);
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /**
   * Called from sale order line form view, on request qty click. Call {@link
   * ReservedQtyService#cancelReservation(SaleOrderLine)}
   *
   * @param request
   * @param response
   */
  public void cancelReservation(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
      saleOrderLine = Beans.get(SaleOrderLineRepository.class).find(saleOrderLine.getId());
      Product product = saleOrderLine.getProduct();
      if (product == null || !product.getStockManaged()) {
        throw new AxelorException(
            TraceBackRepository.CATEGORY_INCONSISTENCY,
            I18n.get(SupplychainExceptionMessage.SALE_ORDER_LINE_PRODUCT_NOT_STOCK_MANAGED));
      }
      Beans.get(ReservedQtyService.class).cancelReservation(saleOrderLine);
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /**
   * Called from sale order line form. Set domain for supplier partner.
   *
   * @param request
   * @param response
   */
  public void supplierPartnerDomain(ActionRequest request, ActionResponse response) {
    SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
    String domain = "self.isContact = false AND self.isSupplier = true";
    Product product = saleOrderLine.getProduct();
    if (product != null) {
      List<Long> authorizedPartnerIdsList =
          Beans.get(SaleOrderLineServiceSupplyChain.class).getSupplierPartnerList(saleOrderLine);
      if (authorizedPartnerIdsList.isEmpty()) {
        response.setAttr("supplierPartner", "domain", "self.id IN (0)");
        return;
      } else {
        domain +=
            String.format(
                " AND self.id IN (%s)",
                authorizedPartnerIdsList.stream()
                    .map(Object::toString)
                    .collect(Collectors.joining(",")));
      }
    }
    SaleOrder saleOrder = saleOrderLine.getSaleOrder();
    if (saleOrder == null) {
      Context parentContext = request.getContext().getParent();
      if (parentContext == null) {
        response.setAttr("supplierPartner", "domain", domain);
        return;
      }
      saleOrder = parentContext.asType(SaleOrder.class);
      if (saleOrder == null) {
        response.setAttr("supplierPartner", "domain", domain);
        return;
      }
    }
    String blockedPartnerQuery =
        Beans.get(BlockingService.class)
            .listOfBlockedPartner(saleOrder.getCompany(), BlockingRepository.PURCHASE_BLOCKING);

    if (!Strings.isNullOrEmpty(blockedPartnerQuery)) {
      domain += String.format(" AND self.id NOT in (%s)", blockedPartnerQuery);
    }

    if (saleOrder.getCompany() != null) {
      domain += " AND " + saleOrder.getCompany().getId() + " in (SELECT id FROM self.companySet)";
    }

    response.setAttr("supplierPartner", "domain", domain);
  }

  /**
   * Called from sale order line form, on product change and on sale supply select change
   *
   * @param request
   * @param response
   */
  public void supplierPartnerDefault(ActionRequest request, ActionResponse response) {
    SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
    if (saleOrderLine.getSaleSupplySelect() != SaleOrderLineRepository.SALE_SUPPLY_PURCHASE) {
      return;
    }

    SaleOrder saleOrder = saleOrderLine.getSaleOrder();
    if (saleOrder == null) {
      Context parentContext = request.getContext().getParent();
      if (parentContext == null) {
        return;
      }
      saleOrder = parentContext.asType(SaleOrder.class);
    }
    if (saleOrder == null) {
      return;
    }

    Partner supplierPartner = null;
    if (saleOrderLine.getProduct() != null) {
      supplierPartner = saleOrderLine.getProduct().getDefaultSupplierPartner();
    }

    if (supplierPartner != null) {
      Blocking blocking =
          Beans.get(BlockingService.class)
              .getBlocking(
                  supplierPartner, saleOrder.getCompany(), BlockingRepository.PURCHASE_BLOCKING);
      if (blocking != null) {
        supplierPartner = null;
      }
    }

    response.setValue("supplierPartner", supplierPartner);
  }

  /**
   * Called from sale order form view, on clicking allocateAll button on one sale order line. Call
   * {@link ReservedQtyService#allocateAll(SaleOrderLine)}.
   *
   * @param request
   * @param response
   */
  public void allocateAll(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
      saleOrderLine = Beans.get(SaleOrderLineRepository.class).find(saleOrderLine.getId());
      Product product = saleOrderLine.getProduct();
      if (product == null || !product.getStockManaged()) {
        throw new AxelorException(
            TraceBackRepository.CATEGORY_INCONSISTENCY,
            I18n.get(SupplychainExceptionMessage.SALE_ORDER_LINE_PRODUCT_NOT_STOCK_MANAGED));
      }
      Beans.get(ReservedQtyService.class).allocateAll(saleOrderLine);
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /**
   * Called from sale order form view, on clicking deallocate button on one sale order line. Call
   * {@link ReservedQtyService#updateReservedQty(SaleOrderLine, BigDecimal.ZERO)}.
   *
   * @param request
   * @param response
   */
  public void deallocateAll(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
      saleOrderLine = Beans.get(SaleOrderLineRepository.class).find(saleOrderLine.getId());
      Beans.get(ReservedQtyService.class).updateReservedQty(saleOrderLine, BigDecimal.ZERO);
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /**
   * Called from sale order line, on desired delivery date change. Call {@link
   * SaleOrderLineServiceSupplyChain#updateStockMoveReservationDateTime(SaleOrderLine)}.
   *
   * @param request
   * @param response
   */
  public void updateReservationDate(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
      saleOrderLine = Beans.get(SaleOrderLineRepository.class).find(saleOrderLine.getId());
      Beans.get(SaleOrderLineServiceSupplyChain.class)
          .updateStockMoveReservationDateTime(saleOrderLine);
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void setAxisDomains(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
      SaleOrder saleOrder =
          ContextHelper.getContextParent(request.getContext(), SaleOrder.class, 1);

      if (saleOrder == null) {
        return;
      }

      AnalyticLineModel analyticLineModel = new AnalyticLineModel(saleOrderLine, saleOrder);
      response.setAttrs(
          Beans.get(AnalyticGroupService.class)
              .getAnalyticAxisDomainAttrsMap(analyticLineModel, saleOrder.getCompany()));
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void createAnalyticAccountLines(ActionRequest request, ActionResponse response) {
    try {
      SaleOrder saleOrder =
          ContextHelper.getContextParent(request.getContext(), SaleOrder.class, 1);

      if (saleOrder == null) {
        return;
      }

      SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
      AnalyticLineModel analyticLineModel = new AnalyticLineModel(saleOrderLine, saleOrder);

      if (Beans.get(AnalyticLineModelService.class)
          .analyzeAnalyticLineModel(analyticLineModel, saleOrder.getCompany())) {
        response.setValue("analyticMoveLineList", analyticLineModel.getAnalyticMoveLineList());
      }
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void printAnalyticAccounts(ActionRequest request, ActionResponse response) {
    try {
      SaleOrder saleOrder =
          ContextHelper.getContextParent(request.getContext(), SaleOrder.class, 1);

      if (saleOrder == null || saleOrder.getCompany() == null) {
        return;
      }

      SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
      AnalyticLineModel analyticLineModel = new AnalyticLineModel(saleOrderLine, saleOrder);

      response.setValues(
          Beans.get(AnalyticGroupService.class)
              .getAnalyticAccountValueMap(analyticLineModel, saleOrder.getCompany()));
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void setSaleOrderLineListToInvoice(ActionRequest request, ActionResponse response) {
    try {
      List<Long> selectedLinesIDs =
          (Optional.ofNullable((List<Integer>) request.getContext().get("_ids")))
              .stream()
                  .flatMap(List::stream)
                  .mapToLong(Integer::longValue)
                  .boxed()
                  .collect(Collectors.toList());
      List<SaleOrderLine> selectedSaleOrderLineList =
          Beans.get(SaleOrderLineRepository.class).findByIds(selectedLinesIDs);
      List<Map<String, Object>> selectedSaleOrderLineMapList =
          selectedSaleOrderLineList.stream().map(Mapper::toMap).collect(Collectors.toList());
      response.setView(
          ActionView.define(I18n.get("SOL to invoice"))
              .model(SaleOrderLine.class.getName())
              .add("form", "sale-order-line-multi-invoicing-form")
              .param("popup", "true")
              .param("popup-save", "false")
              .context("_saleOrderLineListToInvoice", selectedSaleOrderLineMapList)
              .map());

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void saleSupplySelectOnChange(ActionRequest request, ActionResponse response)
      throws AxelorException {
    SaleOrderLine saleOrderLine = request.getContext().asType(SaleOrderLine.class);
    SaleOrder saleOrder =
        SaleOrderLineContextHelper.getSaleOrder(request.getContext(), saleOrderLine);
    SaleOrderLineOnSaleSupplyChangeService saleOrderLineOnSaleSupplyChangeService =
        Beans.get(SaleOrderLineOnSaleSupplyChangeService.class);
    response.setAttrs(
        saleOrderLineOnSaleSupplyChangeService.onSaleSupplyChangeAttrs(saleOrderLine, saleOrder));
    response.setValues(
        saleOrderLineOnSaleSupplyChangeService.onSaleSupplyChangeValues(saleOrderLine, saleOrder));

    // Check
    Beans.get(SaleOrderLineCheckSupplychainService.class)
        .saleSupplySelectOnChangeCheck(saleOrderLine, saleOrder);
  }

  public void getAnalyticDistributionTemplateDomain(
      ActionRequest request, ActionResponse response) {
    Context context = request.getContext();
    SaleOrderLine saleOrderLine = context.asType(SaleOrderLine.class);
    SaleOrder saleOrder = SaleOrderLineContextHelper.getSaleOrder(context, saleOrderLine);
    response.setAttr(
        "analyticDistributionTemplate",
        "domain",
        Beans.get(SaleOrderLineDomainSupplychainService.class)
            .getAnalyticDistributionTemplateDomain(saleOrder));
  }

  public void setDistributionLineReadonly(ActionRequest request, ActionResponse response) {
    Context context = request.getContext();
    SaleOrderLine saleOrderLine = context.asType(SaleOrderLine.class);
    SaleOrder saleOrder = SaleOrderLineContextHelper.getSaleOrder(context, saleOrderLine);
    response.setAttrs(
        Beans.get(SaleOrderLineViewSupplychainService.class)
            .setDistributionLineReadonly(saleOrder));
  }

  /**
   * M2 - Calcule le frais de cong\u00e9lation selon la r\u00e8gle LVME (priorit\u00e9
   * d\u00e9croissante) :
   *
   * <p>1. Si un lot est s\u00e9lectionn\u00e9 avec dateArrivage \u2192 calcul par \u00e2ge : < 3
   * mois : 0 \u20ac/kg \u2265 3 mois : 0.15 + (mois - 3) \u00d7 0.05 \u20ac/kg 2. Sinon \u2192
   * fallback sur la valeur saisie sur le produit
   */
  public void setFraisCongelationFromLot(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      // === LOGIQUE 1 : Calcul par \u00e2ge si lot s\u00e9lectionn\u00e9 ===
      java.math.BigDecimal fraisFromLot = computeFraisFromLot(line);
      if (fraisFromLot != null) {
        System.out.println(
            "=== FRAIS LVME === Calcul par \u00e2ge du lot : " + fraisFromLot + " \u20ac/kg");
        response.setValue("fraisCongelation", fraisFromLot);
        return;
      }

      // === LOGIQUE 2 : Fallback sur le frais du produit ===
      Product product = line.getProduct();
      if (product != null && product.getId() != null) {
        product =
            Beans.get(com.axelor.apps.base.db.repo.ProductRepository.class).find(product.getId());
        java.math.BigDecimal fraisProduit = product.getFraisCongelation();
        System.out.println("=== FRAIS LVME === Fallback produit : " + fraisProduit + " \u20ac/kg");
        response.setValue(
            "fraisCongelation", fraisProduit != null ? fraisProduit : java.math.BigDecimal.ZERO);
      } else {
        response.setValue("fraisCongelation", java.math.BigDecimal.ZERO);
      }

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /**
   * Calcule le frais selon l'\u00e2ge du 1er lot s\u00e9lectionn\u00e9. Convention LVME : 1 seul
   * lot par ligne.
   *
   * @return Le frais calcul\u00e9 (\u20ac/kg), ou null si aucun lot exploitable
   */
  private java.math.BigDecimal computeFraisFromLot(SaleOrderLine line) {
    java.util.List<com.axelor.apps.supplychain.db.SaleOrderLineLot> lotList =
        line.getSaleOrderLineLotList();

    if (lotList == null || lotList.isEmpty()) {
      return null;
    }

    // Convention LVME : 1 seul lot par ligne. On prend le 1er valide.
    for (com.axelor.apps.supplychain.db.SaleOrderLineLot solLot : lotList) {
      if (solLot.getTrackingNumber() != null
          && solLot.getTrackingNumber().getDateArrivage() != null) {

        java.time.LocalDate dateArrivage = solLot.getTrackingNumber().getDateArrivage();
        long ageEnMois =
            java.time.temporal.ChronoUnit.MONTHS.between(dateArrivage, java.time.LocalDate.now());

        // R\u00e8gle LVME
        if (ageEnMois < 3) {
          return java.math.BigDecimal.ZERO.setScale(4, java.math.RoundingMode.HALF_UP);
        }

        // 0.15 + (mois - 3) \u00d7 0.05
        return new java.math.BigDecimal("0.15")
            .add(new java.math.BigDecimal(ageEnMois - 3).multiply(new java.math.BigDecimal("0.05")))
            .setScale(4, java.math.RoundingMode.HALF_UP);
      }
    }

    return null; // Aucun lot avec dateArrivage
  }

  // ==================================================================
  // M2 - Recopie tauxRFA + tauxCommission depuis SaleOrder vers la ligne
  // ==================================================================

  /** Recopie tauxRFA + tauxCommission depuis le SaleOrder parent vers la ligne. */
  public void copyTauxFromSaleOrder(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);
      SaleOrder saleOrder = SaleOrderLineContextHelper.getSaleOrder(request.getContext(), line);

      if (saleOrder != null) {
        java.math.BigDecimal tauxRFA =
            saleOrder.getTauxRFA() != null ? saleOrder.getTauxRFA() : java.math.BigDecimal.ZERO;
        java.math.BigDecimal tauxComm =
            saleOrder.getTauxCommission() != null
                ? saleOrder.getTauxCommission()
                : java.math.BigDecimal.ZERO;

        System.out.println(
            "=== TAUX LVME === Recopie : RFA=" + tauxRFA + "% Commission=" + tauxComm + "%");

        response.setValue("tauxRFA", tauxRFA);
        response.setValue("tauxCommission", tauxComm);
      } else {
        System.out.println("=== TAUX LVME === SaleOrder null, aucune recopie possible");
      }
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 - R\u00e9cup\u00e9rer le PR du lot s\u00e9lectionn\u00e9 (depuis l'achat
  // d'origine)
  // ==================================================================

  /**
   * R\u00e9cup\u00e8re le PR du lot s\u00e9lectionn\u00e9 et le met dans subTotalCostPrice.
   *
   * <p>Logique : 1. Prendre le 1er lot s\u00e9lectionn\u00e9 (convention LVME : 1 lot/ligne) 2. Le
   * TrackingNumber a un lien vers son PurchaseOrderLine d'origine 3. Lire le prKg du
   * PurchaseOrderLine 4. Le mettre dans subTotalCostPrice
   */
  // ==================================================================
  // M2 - R\u00e9cup\u00e9rer le PR du lot s\u00e9lectionn\u00e9 (3
  // strat\u00e9gies en cascade)
  // ==================================================================

  public void setPrFromLot(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      java.util.List<com.axelor.apps.supplychain.db.SaleOrderLineLot> lotList =
          line.getSaleOrderLineLotList();

      if (lotList == null || lotList.isEmpty()) {
        System.out.println("=== PR LVME === Aucun lot s\u00e9lectionn\u00e9");
        return;
      }

      com.axelor.apps.stock.db.TrackingNumber tn = lotList.get(0).getTrackingNumber();
      if (tn == null) return;

      // STRAT\u00c9GIE 1 : StockMoveLine d'entr\u00e9e
      java.util.List<com.axelor.apps.stock.db.StockMoveLine> stockMoveLines =
          Beans.get(com.axelor.apps.stock.db.repo.StockMoveLineRepository.class)
              .all()
              .filter(
                  "self.trackingNumber.id = ?1 AND self.stockMove.typeSelect = 1 "
                      + "AND self.prKg IS NOT NULL AND self.prKg > 0",
                  tn.getId())
              .order("-id")
              .fetch();

      if (!stockMoveLines.isEmpty()) {
        java.math.BigDecimal prKg =
            stockMoveLines
                .get(0)
                .getPrKg()
                .setScale(3, java.math.RoundingMode.HALF_UP); // \u2b50 ARRONDI
        System.out.println(
            "=== PR LVME === Lot "
                + tn.getTrackingNumberSeq()
                + " : PR="
                + prKg
                + " \u20ac/kg (StockMoveLine entr\u00e9e)");
        response.setValue("subTotalCostPrice", prKg);
        return;
      }

      // STRAT\u00c9GIE 2 : Fallback SML
      stockMoveLines =
          Beans.get(com.axelor.apps.stock.db.repo.StockMoveLineRepository.class)
              .all()
              .filter(
                  "self.trackingNumber.id = ?1 AND self.prKg IS NOT NULL AND self.prKg > 0",
                  tn.getId())
              .order("-id")
              .fetch();

      if (!stockMoveLines.isEmpty()) {
        java.math.BigDecimal prKg =
            stockMoveLines
                .get(0)
                .getPrKg()
                .setScale(3, java.math.RoundingMode.HALF_UP); // \u2b50 ARRONDI
        System.out.println(
            "=== PR LVME === Lot "
                + tn.getTrackingNumberSeq()
                + " : PR="
                + prKg
                + " \u20ac/kg (fallback SML)");
        response.setValue("subTotalCostPrice", prKg);
        return;
      }

      // STRAT\u00c9GIE 3 : Fallback Product
      com.axelor.apps.base.db.Product product = line.getProduct();
      if (product != null && product.getId() != null) {
        product =
            Beans.get(com.axelor.apps.base.db.repo.ProductRepository.class).find(product.getId());
        java.math.BigDecimal pp = product.getPurchasePrice();
        if (pp != null && pp.signum() > 0) {
          pp = pp.setScale(3, java.math.RoundingMode.HALF_UP); // \u2b50 ARRONDI
          System.out.println(
              "=== PR LVME === Lot "
                  + tn.getTrackingNumberSeq()
                  + " : PR="
                  + pp
                  + " \u20ac/kg (fallback Product)");
          response.setValue("subTotalCostPrice", pp);
          return;
        }
      }

      System.out.println("=== PR LVME === Aucun PR trouv\u00e9");

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 - Calcul du Prix de Revient Net (formule N7 spec)
  // PR Net = (PR + FraisCong) \u00d7 (1 + (RFA + Commission) / 100)
  // ==================================================================

  public void computePrixRevientNet(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      // 1. R\u00e9cup\u00e9rer le PR (subTotalCostPrice)
      java.math.BigDecimal pr =
          line.getSubTotalCostPrice() != null
              ? line.getSubTotalCostPrice()
              : java.math.BigDecimal.ZERO;

      // 2. R\u00e9cup\u00e9rer le frais de cong\u00e9lation
      java.math.BigDecimal fraisCong =
          line.getFraisCongelation() != null
              ? line.getFraisCongelation()
              : java.math.BigDecimal.ZERO;

      // 3. R\u00e9cup\u00e9rer RFA et Commission
      java.math.BigDecimal tauxRFA =
          line.getTauxRFA() != null ? line.getTauxRFA() : java.math.BigDecimal.ZERO;
      java.math.BigDecimal tauxComm =
          line.getTauxCommission() != null ? line.getTauxCommission() : java.math.BigDecimal.ZERO;

      // 4. Calcul : PR Net = (PR + FraisCong) \u00d7 (1 + (RFA + Comm) / 100)
      java.math.BigDecimal coefficient =
          java.math.BigDecimal.ONE.add(
              tauxRFA
                  .add(tauxComm)
                  .divide(new java.math.BigDecimal("100"), 6, java.math.RoundingMode.HALF_UP));

      java.math.BigDecimal prixRevientNet =
          pr.add(fraisCong).multiply(coefficient).setScale(4, java.math.RoundingMode.HALF_UP);

      System.out.println(
          "=== PR NET LVME === PR="
              + pr
              + " + FraisCong="
              + fraisCong
              + " | RFA="
              + tauxRFA
              + "% Comm="
              + tauxComm
              + "%"
              + " \u2192 PR Net="
              + prixRevientNet);

      response.setValue("prixRevientNet", prixRevientNet);

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 - Recalcul de la marge avec PR Net (au lieu du PR)
  // ==================================================================

  @com.google.inject.persist.Transactional(rollbackOn = {Exception.class})
  public void recomputeMargeWithPrNet(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      // 1. R\u00e9cup\u00e9rer les valeurs n\u00e9cessaires
      java.math.BigDecimal exTaxTotal =
          line.getExTaxTotal() != null ? line.getExTaxTotal() : java.math.BigDecimal.ZERO;
      java.math.BigDecimal prixRevientNet =
          line.getPrixRevientNet() != null ? line.getPrixRevientNet() : java.math.BigDecimal.ZERO;
      java.math.BigDecimal qty = line.getQty() != null ? line.getQty() : java.math.BigDecimal.ZERO;

      // 2. Calculs
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

      System.out.println(
          "=== MARGE LVME === HT="
              + exTaxTotal
              + " - Co\u00fbt(PR Net \u00d7 Qty)="
              + coutTotal
              + " \u2192 Marge="
              + margeBrute
              + " \u20ac ("
              + tauxMarge
              + "%)");

      // 3. Mettre \u00e0 jour le contexte UI
      response.setValue("subTotalGrossMargin", margeBrute);
      response.setValue("subMarginRate", tauxMarge);
      response.setValue("subTotalMarkup", tauxMarkup);

      // 4. \u2b50 PERSISTER EN BASE DIRECTEMENT
      if (line.getId() != null) {
        com.axelor.apps.sale.db.SaleOrderLine lineDb =
            Beans.get(com.axelor.apps.sale.db.repo.SaleOrderLineRepository.class)
                .find(line.getId());

        if (lineDb != null) {
          lineDb.setSubTotalGrossMargin(margeBrute);
          lineDb.setSubMarginRate(tauxMarge);
          lineDb.setSubTotalMarkup(tauxMarkup);

          // Persister aussi nos valeurs LVME au cas o\u00f9 elles auraient \u00e9t\u00e9
          // \u00e9cras\u00e9es
          if (line.getSubTotalCostPrice() != null && line.getSubTotalCostPrice().signum() > 0) {
            lineDb.setSubTotalCostPrice(
                line.getSubTotalCostPrice().setScale(3, java.math.RoundingMode.HALF_UP));
          }
          if (line.getPrixRevientNet() != null && line.getPrixRevientNet().signum() > 0) {
            lineDb.setPrixRevientNet(
                line.getPrixRevientNet().setScale(4, java.math.RoundingMode.HALF_UP));
          }
          if (line.getFraisCongelation() != null) {
            lineDb.setFraisCongelation(line.getFraisCongelation());
          }
          if (line.getTauxRFA() != null) {
            lineDb.setTauxRFA(line.getTauxRFA());
          }
          if (line.getTauxCommission() != null) {
            lineDb.setTauxCommission(line.getTauxCommission());
          }

          Beans.get(com.axelor.apps.sale.db.repo.SaleOrderLineRepository.class).save(lineDb);

          System.out.println(
              "=== MARGE LVME === \u2705 Persist\u00e9 en base : ID=" + lineDb.getId());
        }
      }

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

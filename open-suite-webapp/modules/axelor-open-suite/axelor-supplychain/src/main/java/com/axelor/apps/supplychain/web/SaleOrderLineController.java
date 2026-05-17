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

  // ==================================================================
  // M2 - Calcul frais cong\u00e9lation (V3 - LVME)
  // R\u00e8gles :
  // - Sans lot s\u00e9lectionn\u00e9 \u2192 affiche le taux soci\u00e9t\u00e9
  // brut
  // - Avec lot et \u00e2ge >= 3 mois \u2192 (mois - 3) \u00d7 taux
  // soci\u00e9t\u00e9
  // - Avec lot et \u00e2ge < 3 mois \u2192 taux soci\u00e9t\u00e9 brut (pas
  // encore p\u00e9nalisation)
  // ==================================================================

  public void setFraisCongelationFromLot(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      // 1. R\u00e9cup\u00e9rer la SaleOrder pour avoir la Company
      com.axelor.apps.sale.db.SaleOrder saleOrder =
          com.axelor.apps.sale.service.saleorderline.SaleOrderLineContextHelper.getSaleOrder(
              request.getContext(), line);

      if (saleOrder == null || saleOrder.getCompany() == null) {
        System.out.println("=== FRAIS LVME === Pas de soci\u00e9t\u00e9, frais = 0");
        response.setValue("fraisCongelation", java.math.BigDecimal.ZERO);
        return;
      }

      // 2. R\u00e9cup\u00e9rer le taux fraisCongelation depuis la Company
      com.axelor.apps.base.db.Company company =
          Beans.get(com.axelor.apps.base.db.repo.CompanyRepository.class)
              .find(saleOrder.getCompany().getId());

      java.math.BigDecimal tauxFraisCong = company.getFraisCongelation();
      if (tauxFraisCong == null) {
        tauxFraisCong = java.math.BigDecimal.ZERO;
      }
      // Arrondi pour respecter scale=4
      tauxFraisCong = tauxFraisCong.setScale(4, java.math.RoundingMode.HALF_UP);

      // 3. V\u00e9rifier s'il y a un lot s\u00e9lectionn\u00e9
      java.util.List<com.axelor.apps.supplychain.db.SaleOrderLineLot> lotList =
          line.getSaleOrderLineLotList();

      if (lotList == null || lotList.isEmpty()) {
        // \u2b50 SANS LOT : afficher le taux soci\u00e9t\u00e9 brut
        System.out.println(
            "=== FRAIS LVME === Sans lot : taux soci\u00e9t\u00e9 brut = "
                + tauxFraisCong
                + " \u20ac/kg");
        response.setValue("fraisCongelation", tauxFraisCong);
        return;
      }

      com.axelor.apps.stock.db.TrackingNumber tn = lotList.get(0).getTrackingNumber();
      if (tn == null || tn.getDateArrivage() == null) {
        // \u2b50 LOT SANS DATE : afficher le taux soci\u00e9t\u00e9 brut
        System.out.println(
            "=== FRAIS LVME === Lot sans dateArrivage : taux soci\u00e9t\u00e9 brut = "
                + tauxFraisCong
                + " \u20ac/kg");
        response.setValue("fraisCongelation", tauxFraisCong);
        return;
      }

      // 4. Calculer l'\u00e2ge en mois
      java.time.LocalDate dateArrivage = tn.getDateArrivage();
      java.time.LocalDate today = java.time.LocalDate.now();
      long moisAge = java.time.temporal.ChronoUnit.MONTHS.between(dateArrivage, today);

      // 5. Appliquer la formule LVME
      java.math.BigDecimal frais;
      if (moisAge < 3) {
        // \u2b50 LOT JEUNE (< 3 mois) : afficher le taux soci\u00e9t\u00e9 brut
        frais = tauxFraisCong;
        System.out.println(
            "=== FRAIS LVME === Lot "
                + tn.getTrackingNumberSeq()
                + " : \u00e2ge="
                + moisAge
                + " mois (< 3) \u2192 taux soci\u00e9t\u00e9 brut = "
                + frais
                + " \u20ac/kg");
      } else {
        // \u2b50 LOT ANCIEN (>= 3 mois) : appliquer la p\u00e9nalisation
        frais =
            new java.math.BigDecimal(moisAge - 3)
                .multiply(tauxFraisCong)
                .setScale(4, java.math.RoundingMode.HALF_UP);
        System.out.println(
            "=== FRAIS LVME === Lot "
                + tn.getTrackingNumberSeq()
                + " : dateArrivage="
                + dateArrivage
                + " | \u00e2ge="
                + moisAge
                + " mois"
                + " | taux soci\u00e9t\u00e9="
                + tauxFraisCong
                + " \u20ac/kg"
                + " | (mois-3)\u00d7"
                + tauxFraisCong
                + " = "
                + frais
                + " \u20ac/kg");
      }

      response.setValue("fraisCongelation", frais);

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

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
  // M2 - Recalcul de la marge avec PR Net (V3 - sans save direct)
  // ==================================================================

  public void recomputeMargeWithPrNet(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      java.math.BigDecimal exTaxTotal =
          line.getExTaxTotal() != null ? line.getExTaxTotal() : java.math.BigDecimal.ZERO;
      java.math.BigDecimal prixRevientNet =
          line.getPrixRevientNet() != null ? line.getPrixRevientNet() : java.math.BigDecimal.ZERO;
      java.math.BigDecimal qty = line.getQty() != null ? line.getQty() : java.math.BigDecimal.ZERO;

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

      response.setValue("subTotalGrossMargin", margeBrute);
      response.setValue("subMarginRate", tauxMarge);
      response.setValue("subTotalMarkup", tauxMarkup);

      // \u2b50 PR\u00c9SERVER LA LISTE DES LOTS pour qu'elle ne soit pas perdue
      if (line.getSaleOrderLineLotList() != null) {
        response.setValue("saleOrderLineLotList", line.getSaleOrderLineLotList());
        System.out.println(
            "=== MARGE LVME === Liste lots pr\u00e9serv\u00e9e ("
                + line.getSaleOrderLineLotList().size()
                + " lot(s))");
      }

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 - Rechargement HYBRIDE des valeurs LVME au onLoad
  // V2 : Lit la BD ET recalcule la marge dynamiquement
  // R\u00e9sout : valeurs natives \u00e0 0 apr\u00e8s confirmation de commande
  // ==================================================================

  public void reloadLineFromDb(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      if (line.getId() == null) return;

      // 1. Recharger la ligne depuis la base
      SaleOrderLine lineDb =
          Beans.get(com.axelor.apps.sale.db.repo.SaleOrderLineRepository.class).find(line.getId());

      if (lineDb == null) return;

      // 2. R\u00e9cup\u00e9rer les valeurs LVME persist\u00e9es
      java.math.BigDecimal prixRevientNet =
          lineDb.getPrixRevientNet() != null
              ? lineDb.getPrixRevientNet()
              : java.math.BigDecimal.ZERO;
      java.math.BigDecimal fraisCong =
          lineDb.getFraisCongelation() != null
              ? lineDb.getFraisCongelation()
              : java.math.BigDecimal.ZERO;
      java.math.BigDecimal tauxRFA =
          lineDb.getTauxRFA() != null ? lineDb.getTauxRFA() : java.math.BigDecimal.ZERO;
      java.math.BigDecimal tauxComm =
          lineDb.getTauxCommission() != null
              ? lineDb.getTauxCommission()
              : java.math.BigDecimal.ZERO;
      java.math.BigDecimal exTaxTotal =
          lineDb.getExTaxTotal() != null ? lineDb.getExTaxTotal() : java.math.BigDecimal.ZERO;
      java.math.BigDecimal qty =
          lineDb.getQty() != null ? lineDb.getQty() : java.math.BigDecimal.ZERO;

      // 3. Afficher les champs LVME
      response.setValue("fraisCongelation", fraisCong);
      response.setValue("tauxRFA", tauxRFA);
      response.setValue("tauxCommission", tauxComm);
      response.setValue("prixRevientNet", prixRevientNet);

      // 4. Recalculer le PR depuis le lot (si lot pr\u00e9sent)
      java.math.BigDecimal pr = java.math.BigDecimal.ZERO;

      // \u2b50 REQU\u00caTE JPQL DIRECTE pour \u00e9viter les soucis de lazy loading
      java.util.List<com.axelor.apps.supplychain.db.SaleOrderLineLot> lotList =
          com.axelor
              .db
              .JPA
              .em()
              .createQuery(
                  "SELECT lot FROM SaleOrderLineLot lot WHERE lot.saleOrderLine.id = :solId",
                  com.axelor.apps.supplychain.db.SaleOrderLineLot.class)
              .setParameter("solId", lineDb.getId())
              .getResultList();

      System.out.println(
          "=== RELOAD LVME === Lots en BD pour ligne "
              + lineDb.getId()
              + " : "
              + (lotList != null ? lotList.size() : 0)
              + " lot(s)");

      if (lotList != null && !lotList.isEmpty()) {
        com.axelor.apps.stock.db.TrackingNumber tn = lotList.get(0).getTrackingNumber();
        if (tn != null) {
          // Strat\u00e9gie 1 : StockMoveLine d'entr\u00e9e
          java.util.List<com.axelor.apps.stock.db.StockMoveLine> sml =
              Beans.get(com.axelor.apps.stock.db.repo.StockMoveLineRepository.class)
                  .all()
                  .filter(
                      "self.trackingNumber.id = ?1 AND self.stockMove.typeSelect = 1 "
                          + "AND self.prKg IS NOT NULL AND self.prKg > 0",
                      tn.getId())
                  .order("-id")
                  .fetch();

          if (!sml.isEmpty()) {
            pr = sml.get(0).getPrKg().setScale(3, java.math.RoundingMode.HALF_UP);
          } else {
            // Strat\u00e9gie 2 : Fallback sans typeSelect
            sml =
                Beans.get(com.axelor.apps.stock.db.repo.StockMoveLineRepository.class)
                    .all()
                    .filter(
                        "self.trackingNumber.id = ?1 AND self.prKg IS NOT NULL AND self.prKg > 0",
                        tn.getId())
                    .order("-id")
                    .fetch();

            if (!sml.isEmpty()) {
              pr = sml.get(0).getPrKg().setScale(3, java.math.RoundingMode.HALF_UP);
            }
          }
        }
      }

      // Afficher le PR recalcul\u00e9
      response.setValue("subTotalCostPrice", pr);

      // \u2b50 4-bis : RECALCULER prixRevientNet \u00e0 partir du PR
      // r\u00e9cup\u00e9r\u00e9 du lot
      // (au lieu de lire la BD qui a une valeur fausse)
      java.math.BigDecimal coefficient =
          java.math.BigDecimal.ONE.add(
              tauxRFA
                  .add(tauxComm)
                  .divide(new java.math.BigDecimal("100"), 6, java.math.RoundingMode.HALF_UP));

      prixRevientNet =
          pr.add(fraisCong).multiply(coefficient).setScale(4, java.math.RoundingMode.HALF_UP);

      response.setValue("prixRevientNet", prixRevientNet);

      System.out.println("=== RELOAD LVME === PR Net recalcul\u00e9 : " + prixRevientNet);

      // 5. Recalculer la marge avec le PR Net + qty + exTaxTotal
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

      response.setValue("subTotalGrossMargin", margeBrute);
      response.setValue("subMarginRate", tauxMarge);
      response.setValue("subTotalMarkup", tauxMarkup);

      System.out.println(
          "=== RELOAD LVME === Ligne "
              + lineDb.getId()
              + " | PR="
              + pr
              + " | Frais="
              + fraisCong
              + " | PR Net="
              + prixRevientNet
              + " | HT="
              + exTaxTotal
              + " | Co\u00fbt="
              + coutTotal
              + " | Marge="
              + margeBrute
              + " ("
              + tauxMarge
              + "%)");

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 - Persistance explicite du lot s\u00e9lectionn\u00e9
  // R\u00e9sout : le lot disparait apr\u00e8s on-line-change natif Axelor
  // ==================================================================

  @com.google.inject.persist.Transactional(rollbackOn = {Exception.class})
  public void persistLotSelection(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      if (line.getId() == null) {
        System.out.println("=== PERSIST LOT === Ligne pas encore sauv\u00e9e, skip");
        return;
      }

      java.util.List<com.axelor.apps.supplychain.db.SaleOrderLineLot> lotListUI =
          line.getSaleOrderLineLotList();

      // R\u00e9cup\u00e9rer les IDs des trackingNumbers dans l'UI
      java.util.Set<Long> uiTnIds = new java.util.HashSet<>();
      if (lotListUI != null) {
        for (com.axelor.apps.supplychain.db.SaleOrderLineLot lot : lotListUI) {
          if (lot.getTrackingNumber() != null && lot.getTrackingNumber().getId() != null) {
            uiTnIds.add(lot.getTrackingNumber().getId());
          }
        }
      }

      System.out.println("=== PERSIST LOT === " + uiTnIds.size() + " lot(s) dans UI : " + uiTnIds);

      SaleOrderLine lineDb =
          Beans.get(com.axelor.apps.sale.db.repo.SaleOrderLineRepository.class).find(line.getId());

      if (lineDb == null) return;

      // R\u00e9cup\u00e9rer les lots actuellement en BD
      java.util.List<com.axelor.apps.supplychain.db.SaleOrderLineLot> lotListDb =
          com.axelor
              .db
              .JPA
              .em()
              .createQuery(
                  "SELECT lot FROM SaleOrderLineLot lot WHERE lot.saleOrderLine.id = :solId",
                  com.axelor.apps.supplychain.db.SaleOrderLineLot.class)
              .setParameter("solId", lineDb.getId())
              .getResultList();

      System.out.println("=== PERSIST LOT === " + lotListDb.size() + " lot(s) en BD");

      // \u2b50 1. SUPPRIMER les lots BD qui ne sont plus dans l'UI
      for (com.axelor.apps.supplychain.db.SaleOrderLineLot lotDb : lotListDb) {
        Long dbTnId = lotDb.getTrackingNumber() != null ? lotDb.getTrackingNumber().getId() : null;

        if (dbTnId == null || !uiTnIds.contains(dbTnId)) {
          // Ce lot BD n'est plus dans l'UI \u2192 le supprimer
          System.out.println(
              "=== PERSIST LOT === \ud83d\uddd1\ufe0f Suppression lot BD : id="
                  + lotDb.getId()
                  + " (tn="
                  + dbTnId
                  + ")");

          com.axelor
              .db
              .JPA
              .em()
              .createQuery("DELETE FROM SaleOrderLineLot lot WHERE lot.id = :id")
              .setParameter("id", lotDb.getId())
              .executeUpdate();
        }
      }

      // \u2b50 2. AJOUTER les lots UI qui ne sont pas en BD
      for (Long uiTnId : uiTnIds) {
        boolean dejaPresent = false;
        for (com.axelor.apps.supplychain.db.SaleOrderLineLot lotDb : lotListDb) {
          if (lotDb.getTrackingNumber() != null
              && lotDb.getTrackingNumber().getId().equals(uiTnId)) {
            dejaPresent = true;
            break;
          }
        }

        if (dejaPresent) {
          System.out.println("=== PERSIST LOT === Lot d\u00e9j\u00e0 pr\u00e9sent : tn=" + uiTnId);
          continue;
        }

        com.axelor.apps.stock.db.TrackingNumber tn =
            Beans.get(com.axelor.apps.stock.db.repo.TrackingNumberRepository.class).find(uiTnId);

        if (tn != null) {
          com.axelor.apps.supplychain.db.SaleOrderLineLot newLot =
              new com.axelor.apps.supplychain.db.SaleOrderLineLot();
          newLot.setTrackingNumber(tn);
          newLot.setSaleOrderLine(lineDb);

          lineDb.addSaleOrderLineLotListItem(newLot);

          System.out.println(
              "=== PERSIST LOT === \u2705 Lot ajout\u00e9 : " + tn.getTrackingNumberSeq());
        }
      }

      Beans.get(com.axelor.apps.sale.db.repo.SaleOrderLineRepository.class).save(lineDb);
      System.out.println("=== PERSIST LOT === \u2705 Synchronisation termin\u00e9e");

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 LVME - Persistance forc\u00e9e des calculs en BD
  // R\u00e9sout : Axelor natif \u00e9crase PR/Marge avec 0 au save
  // \u2192 Compta + stats fausses
  // ==================================================================

  @com.google.inject.persist.Transactional(rollbackOn = {Exception.class})
  public void persistCalculsLVME(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      if (line.getId() == null) {
        System.out.println("=== PERSIST CALCULS === Ligne pas encore sauv\u00e9e, skip");
        return;
      }

      // R\u00e9cup\u00e9rer les valeurs calcul\u00e9es du contexte UI
      java.math.BigDecimal pr =
          line.getSubTotalCostPrice() != null
              ? line.getSubTotalCostPrice()
              : java.math.BigDecimal.ZERO;
      java.math.BigDecimal prixRevientNet =
          line.getPrixRevientNet() != null ? line.getPrixRevientNet() : java.math.BigDecimal.ZERO;
      java.math.BigDecimal fraisCong =
          line.getFraisCongelation() != null
              ? line.getFraisCongelation()
              : java.math.BigDecimal.ZERO;
      java.math.BigDecimal margeBrute =
          line.getSubTotalGrossMargin() != null
              ? line.getSubTotalGrossMargin()
              : java.math.BigDecimal.ZERO;
      java.math.BigDecimal tauxMarge =
          line.getSubMarginRate() != null ? line.getSubMarginRate() : java.math.BigDecimal.ZERO;
      java.math.BigDecimal tauxMarkup =
          line.getSubTotalMarkup() != null ? line.getSubTotalMarkup() : java.math.BigDecimal.ZERO;

      // \u2b50 UPDATE SQL DIRECT (sans toucher \u00e0 la version Hibernate)
      int updated =
          com.axelor
              .db
              .JPA
              .em()
              .createNativeQuery(
                  "UPDATE sale_sale_order_line SET "
                      + "sub_total_cost_price = :pr, "
                      + "prix_revient_net = :prNet, "
                      + "frais_congelation = :frais, "
                      + "sub_total_gross_margin = :marge, "
                      + "sub_margin_rate = :tauxMarge, "
                      + "sub_total_markup = :markup "
                      + "WHERE id = :id")
              .setParameter("pr", pr)
              .setParameter("prNet", prixRevientNet)
              .setParameter("frais", fraisCong)
              .setParameter("marge", margeBrute)
              .setParameter("tauxMarge", tauxMarge)
              .setParameter("markup", tauxMarkup)
              .setParameter("id", line.getId())
              .executeUpdate();

      System.out.println(
          "=== PERSIST CALCULS === \u2705 SQL direct : "
              + updated
              + " ligne(s) mise(s) \u00e0 jour pour ligne "
              + line.getId()
              + " | PR="
              + pr
              + " | Marge="
              + margeBrute);

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

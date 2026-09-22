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
  // M2 - Calcul frais congélation (V3 - LVME)
  // Règles :
  // - Sans lot sélectionné -> affiche le taux société brut
  // - Avec lot et âge >= 3 mois -> (mois - 3) x taux société
  // - Avec lot et âge < 3 mois -> taux société brut (pas encore pénalisation)
  // ==================================================================

  public void setFraisCongelationFromLot(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      com.axelor.apps.sale.db.SaleOrder saleOrder =
          com.axelor.apps.sale.service.saleorderline.SaleOrderLineContextHelper.getSaleOrder(
              request.getContext(), line);

      if (saleOrder == null || saleOrder.getCompany() == null) {
        response.setValue("fraisCongelation", java.math.BigDecimal.ZERO);
        return;
      }

      com.axelor.apps.base.db.Company company =
          Beans.get(com.axelor.apps.base.db.repo.CompanyRepository.class)
              .find(saleOrder.getCompany().getId());

      java.math.BigDecimal tauxFraisCong = company.getFraisCongelation();
      if (tauxFraisCong == null) {
        tauxFraisCong = java.math.BigDecimal.ZERO;
      }
      tauxFraisCong = tauxFraisCong.setScale(4, java.math.RoundingMode.HALF_UP);

      java.util.List<com.axelor.apps.supplychain.db.SaleOrderLineLot> lotList =
          line.getSaleOrderLineLotList();

      if (lotList == null || lotList.isEmpty()) {
        response.setValue("fraisCongelation", tauxFraisCong);
        return;
      }

      com.axelor.apps.stock.db.TrackingNumber tn = lotList.get(0).getTrackingNumber();
      if (tn == null || tn.getDateArrivage() == null) {
        response.setValue("fraisCongelation", tauxFraisCong);
        return;
      }

      java.time.LocalDate dateArrivage = tn.getDateArrivage();
      java.time.LocalDate today = java.time.LocalDate.now();
      long moisAge = java.time.temporal.ChronoUnit.MONTHS.between(dateArrivage, today);

      java.math.BigDecimal frais;
      if (moisAge < 3) {
        frais = tauxFraisCong;
      } else {
        frais =
            new java.math.BigDecimal(moisAge - 3)
                .multiply(tauxFraisCong)
                .setScale(4, java.math.RoundingMode.HALF_UP);
      }

      response.setValue("fraisCongelation", frais);

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

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

        response.setValue("tauxRFA", tauxRFA);
        response.setValue("tauxCommission", tauxComm);
      }
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M9 - Récupérer le PR du lot sélectionné (3 stratégies en cascade)
  // Écrit dans prixRevient (champ LVME dédié, €/kg unitaire)
  // et non dans subTotalCostPrice qui appartient à Axelor.
  // ==================================================================

  public void setPrFromLot(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      java.util.List<com.axelor.apps.supplychain.db.SaleOrderLineLot> lotList =
          line.getSaleOrderLineLotList();

      if (lotList == null || lotList.isEmpty()) {
        return;
      }

      com.axelor.apps.stock.db.TrackingNumber tn = lotList.get(0).getTrackingNumber();
      if (tn == null) return;

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
            stockMoveLines.get(0).getPrKg().setScale(3, java.math.RoundingMode.HALF_UP);
        response.setValue("prixRevient", prKg);
        return;
      }

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
            stockMoveLines.get(0).getPrKg().setScale(3, java.math.RoundingMode.HALF_UP);
        response.setValue("prixRevient", prKg);
        return;
      }

      com.axelor.apps.base.db.Product product = line.getProduct();
      if (product != null && product.getId() != null) {
        product =
            Beans.get(com.axelor.apps.base.db.repo.ProductRepository.class).find(product.getId());
        java.math.BigDecimal pp = product.getPurchasePrice();
        if (pp != null && pp.signum() > 0) {
          pp = pp.setScale(3, java.math.RoundingMode.HALF_UP);
          response.setValue("prixRevient", pp);
          return;
        }
      }

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 - Calcul du Prix de Revient Net (formule N7 spec)
  // PR Net = (PR + FraisCong) x (1 + (RFA + Commission) / 100)
  // ==================================================================

  public void computePrixRevientNet(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      java.math.BigDecimal pr =
          line.getPrixRevient() != null ? line.getPrixRevient() : java.math.BigDecimal.ZERO;

      java.math.BigDecimal fraisCong =
          line.getFraisCongelation() != null
              ? line.getFraisCongelation()
              : java.math.BigDecimal.ZERO;

      java.math.BigDecimal tauxRFA =
          line.getTauxRFA() != null ? line.getTauxRFA() : java.math.BigDecimal.ZERO;
      java.math.BigDecimal tauxComm =
          line.getTauxCommission() != null ? line.getTauxCommission() : java.math.BigDecimal.ZERO;

      java.math.BigDecimal coefficient =
          java.math.BigDecimal.ONE.add(
              tauxRFA
                  .add(tauxComm)
                  .divide(new java.math.BigDecimal("100"), 6, java.math.RoundingMode.HALF_UP));

      java.math.BigDecimal prixRevientNet =
          pr.add(fraisCong).multiply(coefficient).setScale(4, java.math.RoundingMode.HALF_UP);

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

      response.setValue("subTotalGrossMargin", margeBrute);
      response.setValue("subMarginRate", tauxMarge);
      response.setValue("subTotalMarkup", tauxMarkup);

      if (line.getSaleOrderLineLotList() != null) {
        response.setValue("saleOrderLineLotList", line.getSaleOrderLineLotList());
      }

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 - Rechargement HYBRIDE des valeurs LVME au onLoad
  // ==================================================================

  public void reloadLineFromDb(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      if (line.getId() == null) return;

      SaleOrderLine lineDb =
          Beans.get(com.axelor.apps.sale.db.repo.SaleOrderLineRepository.class).find(line.getId());

      if (lineDb == null) return;

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

      response.setValue("fraisCongelation", fraisCong);
      response.setValue("tauxRFA", tauxRFA);
      response.setValue("tauxCommission", tauxComm);
      response.setValue("prixRevientNet", prixRevientNet);

      java.math.BigDecimal pr = java.math.BigDecimal.ZERO;

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

      if (lotList != null && !lotList.isEmpty()) {
        com.axelor.apps.stock.db.TrackingNumber tn = lotList.get(0).getTrackingNumber();
        if (tn != null) {
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

      response.setValue("prixRevient", pr);

      java.math.BigDecimal coefficient =
          java.math.BigDecimal.ONE.add(
              tauxRFA
                  .add(tauxComm)
                  .divide(new java.math.BigDecimal("100"), 6, java.math.RoundingMode.HALF_UP));

      prixRevientNet =
          pr.add(fraisCong).multiply(coefficient).setScale(4, java.math.RoundingMode.HALF_UP);

      response.setValue("prixRevientNet", prixRevientNet);

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

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 - Persistance explicite du lot sélectionné
  // ==================================================================

  @com.google.inject.persist.Transactional(rollbackOn = {Exception.class})
  public void persistLotSelection(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      if (line.getId() == null) {
        return;
      }

      java.util.List<com.axelor.apps.supplychain.db.SaleOrderLineLot> lotListUI =
          line.getSaleOrderLineLotList();

      java.util.Set<Long> uiTnIds = new java.util.HashSet<>();
      if (lotListUI != null) {
        for (com.axelor.apps.supplychain.db.SaleOrderLineLot lot : lotListUI) {
          if (lot.getTrackingNumber() != null && lot.getTrackingNumber().getId() != null) {
            uiTnIds.add(lot.getTrackingNumber().getId());
          }
        }
      }

      SaleOrderLine lineDb =
          Beans.get(com.axelor.apps.sale.db.repo.SaleOrderLineRepository.class).find(line.getId());

      if (lineDb == null) return;

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

      for (com.axelor.apps.supplychain.db.SaleOrderLineLot lotDb : lotListDb) {
        Long dbTnId = lotDb.getTrackingNumber() != null ? lotDb.getTrackingNumber().getId() : null;

        if (dbTnId == null || !uiTnIds.contains(dbTnId)) {
          com.axelor
              .db
              .JPA
              .em()
              .createQuery("DELETE FROM SaleOrderLineLot lot WHERE lot.id = :id")
              .setParameter("id", lotDb.getId())
              .executeUpdate();
        }
      }

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
        }
      }

      Beans.get(com.axelor.apps.sale.db.repo.SaleOrderLineRepository.class).save(lineDb);

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  // ==================================================================
  // M2 LVME - Persistance forcée des calculs en BD
  // + Recalcul du total de marge au niveau de la commande (FIX AJOUTÉ)
  // ==================================================================

  @com.google.inject.persist.Transactional(rollbackOn = {Exception.class})
  public void persistCalculsLVME(ActionRequest request, ActionResponse response) {
    try {
      SaleOrderLine line = request.getContext().asType(SaleOrderLine.class);

      if (line.getId() == null) {
        return;
      }

      java.math.BigDecimal pr =
          line.getPrixRevient() != null ? line.getPrixRevient() : java.math.BigDecimal.ZERO;
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

      // UPDATE SQL DIRECT de la ligne (sans toucher à la version Hibernate)
      int updated =
          com.axelor
              .db
              .JPA
              .em()
              .createNativeQuery(
                  "UPDATE sale_sale_order_line SET "
                      + "prix_revient = :pr, "
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

      // FIX MARGE COMMERCIALE : recalcul du total de la commande
      // (somme de toutes les lignes) -> car le service natif Axelor
      // se déclenche avant notre calcul custom, avec une valeur encore à 0.
      Long saleOrderId = line.getSaleOrder() != null ? line.getSaleOrder().getId() : null;
      if (saleOrderId == null) {
        Object result =
            com.axelor
                .db
                .JPA
                .em()
                .createNativeQuery("SELECT sale_order FROM sale_sale_order_line WHERE id = :id")
                .setParameter("id", line.getId())
                .getSingleResult();
        saleOrderId = result != null ? ((Number) result).longValue() : null;
      }

      if (saleOrderId != null) {
        com.axelor
            .db
            .JPA
            .em()
            .createNativeQuery(
                "UPDATE sale_sale_order SET total_gross_margin = "
                    + "(SELECT COALESCE(SUM(sub_total_gross_margin), 0) FROM sale_sale_order_line WHERE sale_order = :orderId) "
                    + "WHERE id = :orderId")
            .setParameter("orderId", saleOrderId)
            .executeUpdate();
      }

    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}
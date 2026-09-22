package com.axelor.apps.supplychain.service.saleorder;

import com.axelor.apps.base.service.CurrencyScaleService;
import com.axelor.apps.base.service.CurrencyService;
import com.axelor.apps.base.service.ProductCompanyService;
import com.axelor.apps.base.service.app.AppBaseService;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.service.app.AppSaleService;
import com.axelor.apps.sale.service.saleorder.SaleOrderMarginServiceImpl;
import com.google.inject.Inject;
import java.math.BigDecimal;
import java.math.RoundingMode;

public class SaleOrderMarginServiceLVMEImpl extends SaleOrderMarginServiceImpl {

  @Inject
  public SaleOrderMarginServiceLVMEImpl(
      AppSaleService appSaleService,
      CurrencyService currencyService,
      ProductCompanyService productCompanyService,
      CurrencyScaleService currencyScaleService) {
    super(appSaleService, currencyService, productCompanyService, currencyScaleService);
  }

  @Override
  public void computeMarginSaleOrder(SaleOrder saleOrder) {
    BigDecimal accountedRevenue = BigDecimal.ZERO;
    BigDecimal totalCostPrice = BigDecimal.ZERO;
    BigDecimal totalGrossMargin = BigDecimal.ZERO;

    if (saleOrder.getSaleOrderLineList() != null) {
      for (SaleOrderLine line : saleOrder.getSaleOrderLineList()) {
        BigDecimal marge =
            line.getSubTotalGrossMargin() != null ? line.getSubTotalGrossMargin() : BigDecimal.ZERO;
        BigDecimal prNet =
            line.getPrixRevientNet() != null ? line.getPrixRevientNet() : BigDecimal.ZERO;
        BigDecimal qty = line.getQty() != null ? line.getQty() : BigDecimal.ZERO;
        BigDecimal exTax =
            line.getCompanyExTaxTotal() != null ? line.getCompanyExTaxTotal() : BigDecimal.ZERO;

        totalGrossMargin = totalGrossMargin.add(marge);
        totalCostPrice = totalCostPrice.add(prNet.multiply(qty).setScale(2, RoundingMode.HALF_UP));
        accountedRevenue = accountedRevenue.add(exTax);
      }
    }

    BigDecimal marginRate = BigDecimal.ZERO;
    if (accountedRevenue.signum() != 0) {
      marginRate =
          totalGrossMargin
              .multiply(new BigDecimal("100"))
              .divide(
                  accountedRevenue, AppBaseService.DEFAULT_NB_DECIMAL_DIGITS, RoundingMode.HALF_UP);
    }

    BigDecimal markup = BigDecimal.ZERO;
    if (totalCostPrice.signum() != 0) {
      markup =
          totalGrossMargin
              .multiply(new BigDecimal("100"))
              .divide(
                  totalCostPrice, AppBaseService.DEFAULT_NB_DECIMAL_DIGITS, RoundingMode.HALF_UP);
    }

    saleOrder.setAccountedRevenue(accountedRevenue);
    saleOrder.setTotalCostPrice(totalCostPrice);
    saleOrder.setTotalGrossMargin(totalGrossMargin);
    saleOrder.setMarginRate(marginRate);
    saleOrder.setMarkup(markup);
  }
}

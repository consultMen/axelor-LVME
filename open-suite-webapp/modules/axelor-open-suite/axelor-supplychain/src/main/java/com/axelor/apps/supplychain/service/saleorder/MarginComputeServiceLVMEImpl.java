package com.axelor.apps.supplychain.service.saleorder;

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.base.service.CurrencyScaleService;
import com.axelor.apps.base.service.CurrencyService;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.interfaces.MarginLine;
import com.axelor.apps.sale.service.MarginComputeServiceImpl;
import com.axelor.apps.sale.service.app.AppSaleService;
import com.google.inject.Inject;
import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * LVME : la marge d'une ligne de commande client suit toujours la formule LVME, marge = total HT -
 * P.R. Net x qté. La marge commerciale de la commande (totalGrossMargin) est la somme de ces
 * marges (voir SaleOrderMarginServiceLVMEImpl).
 */
public class MarginComputeServiceLVMEImpl extends MarginComputeServiceImpl {

  private static final BigDecimal CENT = new BigDecimal("100");

  @Inject
  public MarginComputeServiceLVMEImpl(
      AppSaleService appSaleService,
      CurrencyService currencyService,
      CurrencyScaleService currencyScaleService) {
    super(appSaleService, currencyService, currencyScaleService);
  }

  @Override
  public void computeSubMargin(SaleOrder saleOrder, MarginLine marginLine, BigDecimal totalPrice)
      throws AxelorException {

    if (!(marginLine instanceof SaleOrderLine)) {
      super.computeSubMargin(saleOrder, marginLine, totalPrice);
      return;
    }

    SaleOrderLine line = (SaleOrderLine) marginLine;
    BigDecimal exTaxTotal = line.getExTaxTotal() != null ? line.getExTaxTotal() : BigDecimal.ZERO;
    BigDecimal prixRevientNet =
        line.getPrixRevientNet() != null ? line.getPrixRevientNet() : BigDecimal.ZERO;
    BigDecimal qty = line.getQty() != null ? line.getQty() : BigDecimal.ZERO;

    BigDecimal coutTotal = prixRevientNet.multiply(qty).setScale(2, RoundingMode.HALF_UP);
    BigDecimal margeBrute = exTaxTotal.subtract(coutTotal).setScale(2, RoundingMode.HALF_UP);

    BigDecimal tauxMarge = BigDecimal.ZERO;
    if (exTaxTotal.signum() != 0) {
      tauxMarge = margeBrute.multiply(CENT).divide(exTaxTotal, 2, RoundingMode.HALF_UP);
    }
    BigDecimal tauxMarkup = BigDecimal.ZERO;
    if (coutTotal.signum() != 0) {
      tauxMarkup = margeBrute.multiply(CENT).divide(coutTotal, 2, RoundingMode.HALF_UP);
    }

    line.setSubTotalCostPrice(coutTotal);
    setMarginInfo(line, margeBrute, tauxMarge, tauxMarkup);
  }
}

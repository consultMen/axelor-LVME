package com.axelor.apps.supplychain.service.saleorderline;

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.sale.db.SaleOrderLine;

public interface SaleOrderLineDuplicateLvmeService {

  /**
   * LVME : duplique une ligne de commande client juste sous la ligne d'origine, avec ses lots
   * sélectionnés. Les réservations (emplacements, arrivages) ne sont pas reprises. La commande est
   * recalculée.
   */
  SaleOrderLine duplicateLine(SaleOrderLine saleOrderLine) throws AxelorException;
}

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
package com.axelor.apps.supplychain.db.repo;

import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.StockMoveLine;
import com.axelor.apps.stock.db.repo.StockMoveManagementRepository;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import java.math.BigDecimal;

public class StockMoveSupplychainRepository extends StockMoveManagementRepository {

  @Override
  public StockMove copy(StockMove entity, boolean deep) {

    StockMove copy = super.copy(entity, deep);

    copy.setInvoiceSet(null);
    copy.setOrigin(null);
    if (copy.getStockMoveLineList() != null) {
      for (StockMoveLine stockMoveLine : copy.getStockMoveLineList()) {
        stockMoveLine.setReservedQty(BigDecimal.ZERO);
        stockMoveLine.setRequestedReservedQty(BigDecimal.ZERO);
        stockMoveLine.setIsQtyRequested(false);
        stockMoveLine.setReservationDateTime(null);
        stockMoveLine.setQtyInvoiced(null);
        stockMoveLine.setSaleOrderLine(null);
        stockMoveLine.setPurchaseOrderLine(null);
      }
    }
    copy.setInvoicingStatusSelect(StockMoveRepository.STATUS_NOT_INVOICED);

    return copy;
  }

  @Override
  public StockMove save(StockMove stockMove) {
    StockMove saved = super.save(stockMove);
    syncNatureToPurchaseOrders(saved);
    return saved;
  }

  /**
   * LVME : la commande fournisseur porte la Nature de son arrivage (En cours de production / Flottant
   * / Réel), recopiée à chaque enregistrement de la réception. Une réception annulée ne l'écrase pas.
   */
  protected void syncNatureToPurchaseOrders(StockMove stockMove) {
    if (stockMove == null
        || stockMove.getTypeSelect() == null
        || stockMove.getTypeSelect() != StockMoveRepository.TYPE_INCOMING
        || Boolean.TRUE.equals(stockMove.getIsReversion())
        || stockMove.getNature() == null
        || stockMove.getNature() == com.axelor.apps.stock.db.Nature.ANNULE
        || stockMove.getPurchaseOrderSet() == null) {
      return;
    }
    for (com.axelor.apps.purchase.db.PurchaseOrder purchaseOrder : stockMove.getPurchaseOrderSet()) {
      purchaseOrder.setNature(stockMove.getNature());
    }
  }
}

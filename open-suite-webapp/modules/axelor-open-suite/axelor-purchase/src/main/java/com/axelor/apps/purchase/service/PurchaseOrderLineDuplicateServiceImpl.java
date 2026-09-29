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
package com.axelor.apps.purchase.service;

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.base.db.repo.TraceBackRepository;
import com.axelor.apps.purchase.db.PurchaseOrder;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.purchase.db.repo.PurchaseOrderLineRepository;
import com.axelor.apps.purchase.db.repo.PurchaseOrderRepository;
import com.google.inject.Inject;
import com.google.inject.persist.Transactional;
import java.math.BigDecimal;

public class PurchaseOrderLineDuplicateServiceImpl implements PurchaseOrderLineDuplicateService {

  protected PurchaseOrderLineRepository purchaseOrderLineRepository;
  protected PurchaseOrderRepository purchaseOrderRepository;
  protected PurchaseOrderService purchaseOrderService;

  @Inject
  public PurchaseOrderLineDuplicateServiceImpl(
      PurchaseOrderLineRepository purchaseOrderLineRepository,
      PurchaseOrderRepository purchaseOrderRepository,
      PurchaseOrderService purchaseOrderService) {
    this.purchaseOrderLineRepository = purchaseOrderLineRepository;
    this.purchaseOrderRepository = purchaseOrderRepository;
    this.purchaseOrderService = purchaseOrderService;
  }

  @Override
  @Transactional(rollbackOn = {Exception.class})
  public PurchaseOrderLine duplicateLine(PurchaseOrderLine purchaseOrderLine)
      throws AxelorException {
    PurchaseOrder purchaseOrder = purchaseOrderLine.getPurchaseOrder();
    if (purchaseOrder == null
        || purchaseOrder.getStatusSelect() >= PurchaseOrderRepository.STATUS_VALIDATED) {
      throw new AxelorException(
          TraceBackRepository.CATEGORY_INCONSISTENCY,
          "Seules les lignes d'une commande non validée peuvent être dupliquées.");
    }

    PurchaseOrderLine copy = purchaseOrderLineRepository.copy(purchaseOrderLine, false);
    copy.setReceivedQty(BigDecimal.ZERO);

    // Insère la copie juste sous la ligne d'origine
    int sequence = purchaseOrderLine.getSequence();
    for (PurchaseOrderLine line : purchaseOrder.getPurchaseOrderLineList()) {
      if (line.getSequence() > sequence) {
        line.setSequence(line.getSequence() + 1);
      }
    }
    copy.setSequence(sequence + 1);
    purchaseOrder.addPurchaseOrderLineListItem(copy);

    purchaseOrderService.computePurchaseOrder(purchaseOrder);
    purchaseOrderRepository.save(purchaseOrder);
    return copy;
  }
}

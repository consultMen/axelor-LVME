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

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.base.service.app.AppBaseService;
import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.purchase.db.PurchaseOrder;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.purchase.db.repo.PurchaseOrderManagementRepository;
import com.axelor.apps.purchase.db.repo.PurchaseOrderRepository;
import com.axelor.apps.purchase.service.PurchaseOrderSequenceService;
import com.axelor.apps.supplychain.service.PurchaseOrderSupplychainService;
import com.axelor.inject.Beans;
import com.google.inject.Inject;
import javax.persistence.PersistenceException;

public class PurchaseOrderSupplychainRepository extends PurchaseOrderManagementRepository {

  @Inject
  public PurchaseOrderSupplychainRepository(
      AppBaseService appBaseService, PurchaseOrderSequenceService purchaseOrderSequenceService) {
    super(appBaseService, purchaseOrderSequenceService);
  }

  @Override
  public PurchaseOrder copy(PurchaseOrder entity, boolean deep) {

    PurchaseOrder copy = super.copy(entity, deep);

    if (!appBaseService.isApp("supplychain")) {
      return copy;
    }

    copy.setReceiptState(PurchaseOrderRepository.STATE_NOT_RECEIVED);
    copy.setAmountInvoiced(null);

    if (copy.getPurchaseOrderLineList() != null) {
      for (PurchaseOrderLine purchaseOrderLine : copy.getPurchaseOrderLineList()) {
        purchaseOrderLine.setReceiptState(null);
        purchaseOrderLine.setReceivedQty(null);
        purchaseOrderLine.setAmountInvoiced(null);
        purchaseOrderLine.setInvoiced(null);
      }
    }

    return copy;
  }

  @Override
  public PurchaseOrder save(PurchaseOrder purchaseOrder) {
    try {
      Beans.get(PurchaseOrderSupplychainService.class).checkAnalyticAxisByCompany(purchaseOrder);
    } catch (AxelorException e) {
      TraceBackService.traceExceptionFromSaveMethod(e);
      throw new PersistenceException(e.getMessage(), e);
    }
    purchaseOrder = super.save(purchaseOrder);
    // LVME : Kanban « Suivi des commandes d'achat » classé par n° de dossier, le plus récent en haut
    // (Axelor ne trie le Kanban que sur l'ordre des cartes) ; recalculé après la numérotation et
    // après chaque déplacement de carte
    purchaseOrder.setLvmeKanbanSeq(ordreKanban(purchaseOrder.getPurchaseOrderSeq()));
    return purchaseOrder;
  }

  /**
   * Ordre de carte = - n° de dossier. N° GESCOM « AAMM + numéro » (260926 = 2026, septembre, dossier
   * 26 ; quelques-uns sur 3 chiffres : 2106106) : classé par AAMM puis numéro, pour qu'un dossier à 7
   * chiffres de 2021 ne passe pas devant ceux de 2026. Autres numéros (« #52174 » d'un brouillon) :
   * leurs chiffres.
   */
  public static Integer ordreKanban(String numero) {
    String chiffres = numero == null ? "" : numero.replaceAll("\\D", "");
    if (chiffres.isEmpty() || chiffres.length() > 9) {
      return null;
    }
    if (!numero.startsWith("#") && (chiffres.length() == 6 || chiffres.length() == 7)) {
      return -(Integer.parseInt(chiffres.substring(0, 4)) * 1000
          + Integer.parseInt(chiffres.substring(4)));
    }
    return -Integer.parseInt(chiffres);
  }
}

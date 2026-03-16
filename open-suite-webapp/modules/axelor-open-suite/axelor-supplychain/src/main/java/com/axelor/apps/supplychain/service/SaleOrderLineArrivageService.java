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
package com.axelor.apps.supplychain.service;

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.supplychain.db.SaleOrderLineArrivage;
import java.math.BigDecimal;

public interface SaleOrderLineArrivageService {

  /**
   * Alloue une quantité depuis une ligne d'achat (arrivage) vers une ligne de vente. Utilise un
   * verrou pessimiste sur la POL pour éviter les allocations simultanées. Vérifie que la quantité
   * demandée ne dépasse pas l'ATP disponible.
   *
   * @param sol la ligne de vente
   * @param pol la ligne d'achat (arrivage)
   * @param qty la quantité à allouer
   * @throws AxelorException si qty > ATP ou si le total arrivage dépasse la qty de la SOL
   */
  void allocateFromPurchaseOrderLine(SaleOrderLine sol, PurchaseOrderLine pol, BigDecimal qty)
      throws AxelorException;

  /**
   * Supprime une allocation arrivage et restitue la quantité à la POL.
   *
   * @param arrivage l'allocation à supprimer
   * @throws AxelorException
   */
  void deallocate(SaleOrderLineArrivage arrivage) throws AxelorException;

  /**
   * Recalcule qtyFromArrivage sur la SOL (somme des qtyAllocated des arrivages) et met à jour les
   * compteurs dénormalisés de la POL.
   *
   * @param sol la ligne de vente
   */
  void recomputeQties(SaleOrderLine sol);

  /**
   * Retourne l'ATP (Available To Promise) d'une ligne d'achat.
   *
   * @param pol la ligne d'achat
   * @return qty - receivedQty - qtyAllocatedToSales
   */
  BigDecimal getAvailableToPromise(PurchaseOrderLine pol);

  /**
   * Vérifie que qtyFromStock + qtyFromArrivage == qty. Lance une AxelorException si la contrainte
   * n'est pas satisfaite.
   *
   * @param sol la ligne de vente
   * @throws AxelorException si la couverture est incomplète
   */
  void checkCoverageConstraint(SaleOrderLine sol) throws AxelorException;

  /**
   * Transfert FIFO des allocations arrivage vers des réservations stock réelles, lors de la
   * réception d'une commande achat.
   *
   * @param pol la ligne d'achat reçue
   * @param qtyReceived la quantité effectivement reçue
   * @throws AxelorException
   */
  void transferArrivagesToStockReservations(PurchaseOrderLine pol, BigDecimal qtyReceived)
      throws AxelorException;
}

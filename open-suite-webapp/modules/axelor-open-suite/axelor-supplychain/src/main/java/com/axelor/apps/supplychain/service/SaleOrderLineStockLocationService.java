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
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.stock.db.StockLocation;
import com.axelor.apps.supplychain.db.SaleOrderLineStockLocation;
import java.math.BigDecimal;

public interface SaleOrderLineStockLocationService {

  /**
   * Alloue une quantité depuis un emplacement de stock vers une ligne de vente. Vérifie que la
   * quantité demandée ne dépasse pas le stock disponible dans l'emplacement.
   *
   * @param sol la ligne de vente
   * @param stockLocation l'emplacement de stock (physique ou virtuel)
   * @param qty la quantité à allouer
   * @throws AxelorException si qty > stock disponible
   */
  void allocate(SaleOrderLine sol, StockLocation stockLocation, BigDecimal qty)
      throws AxelorException;

  /**
   * Supprime une allocation emplacement et met à jour qtyFromStock sur la SOL.
   *
   * @param item l'allocation à supprimer
   * @throws AxelorException
   */
  void deallocate(SaleOrderLineStockLocation item) throws AxelorException;

  /**
   * Retourne la quantité disponible dans un emplacement pour un produit donné.
   *
   * @param sol la ligne de vente (pour récupérer le produit)
   * @param stockLocation l'emplacement de stock
   * @return currentQty disponible dans l'emplacement
   */
  BigDecimal getAvailableQty(SaleOrderLine sol, StockLocation stockLocation);

  /**
   * Recalcule qtyFromStock sur la SOL (somme des qty de toutes les SaleOrderLineStockLocation).
   *
   * @param sol la ligne de vente
   */
  void recomputeQtyFromStock(SaleOrderLine sol);

  /**
   * Transfère les emplacements virtuels vers l'emplacement physique (Frigo) via un StockMove
   * INTERNAL, à la confirmation de la commande vente. Marque transferred=true après le transfert.
   *
   * @param sol la ligne de vente
   * @param stockLocationPhysique l'emplacement physique destination (Frigo)
   * @throws AxelorException
   */
  void transferVirtualToPhysical(SaleOrderLine sol, StockLocation stockLocationPhysique)
      throws AxelorException;
}

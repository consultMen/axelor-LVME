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
import com.axelor.apps.base.db.repo.TraceBackRepository;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.stock.db.repo.StockLocationLineStockRepository;
import com.axelor.apps.supplychain.db.SaleOrderLineArrivage;
import com.axelor.apps.supplychain.db.repo.SaleOrderLineArrivageSupplychainRepository;
import com.axelor.apps.supplychain.exception.SupplychainExceptionMessage;
import com.axelor.i18n.I18n;
import com.google.inject.Inject;
import com.google.inject.persist.Transactional;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import javax.persistence.EntityManager;
import javax.persistence.LockModeType;

public class SaleOrderLineArrivageServiceImpl implements SaleOrderLineArrivageService {

  protected SaleOrderLineArrivageSupplychainRepository saleOrderLineArrivageRepository;
  protected ReservedQtyService reservedQtyService;
  protected EntityManager entityManager;
  protected StockLocationLineStockRepository stockLocationLineRepository;

  @Inject
  public SaleOrderLineArrivageServiceImpl(
      SaleOrderLineArrivageSupplychainRepository saleOrderLineArrivageRepository,
      ReservedQtyService reservedQtyService,
      EntityManager entityManager,
      StockLocationLineStockRepository stockLocationLineRepository) {
    this.stockLocationLineRepository = stockLocationLineRepository;
    this.saleOrderLineArrivageRepository = saleOrderLineArrivageRepository;
    this.reservedQtyService = reservedQtyService;
    this.entityManager = entityManager;
  }

  @Override
  @Transactional(rollbackOn = {Exception.class})
  public void allocateFromPurchaseOrderLine(
      SaleOrderLine sol, PurchaseOrderLine pol, BigDecimal qty) throws AxelorException {

    // Verrou pessimiste anti-race condition
    entityManager.lock(pol, LockModeType.PESSIMISTIC_WRITE);

    // Vérification ATP
    BigDecimal atp = getAvailableToPromise(pol);
    if (qty.compareTo(atp) > 0) {
      throw new AxelorException(
          TraceBackRepository.CATEGORY_INCONSISTENCY,
          I18n.get(SupplychainExceptionMessage.ARRIVAGE_QTY_EXCEEDS_ATP),
          qty,
          atp);
    }

    // Vérification quantité SOL
    BigDecimal totalArrivage =
        sol.getQtyFromArrivage() == null ? BigDecimal.ZERO : sol.getQtyFromArrivage();
    if (totalArrivage.add(qty).compareTo(sol.getQty()) > 0) {
      throw new AxelorException(
          TraceBackRepository.CATEGORY_INCONSISTENCY,
          I18n.get(SupplychainExceptionMessage.ARRIVAGE_QTY_EXCEEDS_SOL_QTY));
    }

    // Création de l'allocation
    SaleOrderLineArrivage arrivage = new SaleOrderLineArrivage();
    arrivage.setSaleOrderLine(sol);
    arrivage.setPurchaseOrderLine(pol);
    arrivage.setQtyAllocated(qty);
    arrivage.setQtyReceived(BigDecimal.ZERO);
    saleOrderLineArrivageRepository.save(arrivage);

    // Mise à jour POL (compteurs dénormalisés)
    BigDecimal newAllocatedToSales =
        (pol.getQtyAllocatedToSales() == null ? BigDecimal.ZERO : pol.getQtyAllocatedToSales())
            .add(qty);
    pol.setQtyAllocatedToSales(newAllocatedToSales);
    pol.setQtyAvailableToPromise(
        pol.getQty()
            .subtract(pol.getReceivedQty() == null ? BigDecimal.ZERO : pol.getReceivedQty())
            .subtract(newAllocatedToSales)
            .max(BigDecimal.ZERO)
            .setScale(4, RoundingMode.HALF_UP));

    // Mise à jour SOL (recalcul depuis la liste)
    recomputeQties(sol);
  }

  @Override
  @Transactional(rollbackOn = {Exception.class})
  public void deallocate(SaleOrderLineArrivage arrivage) throws AxelorException {
    SaleOrderLine sol = arrivage.getSaleOrderLine();
    PurchaseOrderLine pol = arrivage.getPurchaseOrderLine();
    BigDecimal qtyToRestitute = arrivage.getQtyAllocated();

    // Restitution de la qty à la POL
    BigDecimal newAllocatedToSales =
        (pol.getQtyAllocatedToSales() == null ? BigDecimal.ZERO : pol.getQtyAllocatedToSales())
            .subtract(qtyToRestitute)
            .max(BigDecimal.ZERO);
    pol.setQtyAllocatedToSales(newAllocatedToSales);
    pol.setQtyAvailableToPromise(
        pol.getQty()
            .subtract(pol.getReceivedQty() == null ? BigDecimal.ZERO : pol.getReceivedQty())
            .subtract(newAllocatedToSales)
            .max(BigDecimal.ZERO)
            .setScale(4, RoundingMode.HALF_UP));

    saleOrderLineArrivageRepository.remove(arrivage);

    recomputeQties(sol);
  }

  @Override
  public void recomputeQties(SaleOrderLine sol) {
    List<SaleOrderLineArrivage> arrivages =
        saleOrderLineArrivageRepository.findBySaleOrderLine(sol);

    BigDecimal totalArrivage =
        arrivages.stream()
            .map(SaleOrderLineArrivage::getQtyAllocated)
            .reduce(BigDecimal.ZERO, BigDecimal::add);

    sol.setQtyFromArrivage(totalArrivage);
  }

  @Override
  public BigDecimal getAvailableToPromise(PurchaseOrderLine pol) {
    BigDecimal qty = pol.getQty() == null ? BigDecimal.ZERO : pol.getQty();
    BigDecimal receivedQty = pol.getReceivedQty() == null ? BigDecimal.ZERO : pol.getReceivedQty();
    BigDecimal allocatedToSales =
        pol.getQtyAllocatedToSales() == null ? BigDecimal.ZERO : pol.getQtyAllocatedToSales();
    return qty.subtract(receivedQty).subtract(allocatedToSales);
  }

  private BigDecimal getAvailableStockQty(SaleOrderLine sol) {
    List<com.axelor.apps.stock.db.StockLocationLine> lines =
        com.axelor.inject.Beans.get(
                com.axelor.apps.stock.db.repo.StockLocationLineStockRepository.class)
            .all()
            .filter(
                "self.product.id = :productId "
                    + "AND self.stockLocation.typeSelect != 3 "
                    + "AND (self.stockLocation.isNotInCalculStock = false "
                    + "OR self.stockLocation.isNotInCalculStock IS NULL)")
            .bind("productId", sol.getProduct().getId())
            .fetch();

    return lines.stream()
        .map(l -> l.getCurrentQty() == null ? BigDecimal.ZERO : l.getCurrentQty())
        .reduce(BigDecimal.ZERO, BigDecimal::add);
  }

  @Override
  public void checkCoverageConstraint(SaleOrderLine sol) throws AxelorException {
    BigDecimal qtyFromStock =
        sol.getQtyFromStock() == null ? BigDecimal.ZERO : sol.getQtyFromStock();
    BigDecimal qtyFromArrivage =
        sol.getQtyFromArrivage() == null ? BigDecimal.ZERO : sol.getQtyFromArrivage();
    BigDecimal qty = sol.getQty() == null ? BigDecimal.ZERO : sol.getQty();

    if (qtyFromStock.add(qtyFromArrivage).compareTo(qty) != 0) {
      throw new AxelorException(
          TraceBackRepository.CATEGORY_INCONSISTENCY,
          I18n.get(SupplychainExceptionMessage.ARRIVAGE_COVERAGE_CONSTRAINT),
          qtyFromStock,
          qtyFromArrivage,
          qty,
          sol.getProductName());
    }
    if (qtyFromStock.signum() > 0 && sol.getProduct() != null) {
      BigDecimal availableQty = getAvailableStockQty(sol);
      if (qtyFromStock.compareTo(availableQty) > 0) {
        throw new AxelorException(
            TraceBackRepository.CATEGORY_INCONSISTENCY,
            "La quantité depuis stock (%s kg) dépasse le stock physique disponible (%s kg) pour le produit %s",
            qtyFromStock,
            availableQty,
            sol.getProductName());
      }
    }
  }

  @Override
  @Transactional(rollbackOn = {Exception.class})
  public void transferArrivagesToStockReservations(PurchaseOrderLine pol, BigDecimal qtyReceived)
      throws AxelorException {

    // Récupération des arrivages triés FIFO
    List<SaleOrderLineArrivage> arrivages =
        saleOrderLineArrivageRepository.findByPOLOrderedFIFO(pol);

    BigDecimal disponible = qtyReceived;

    for (SaleOrderLineArrivage arrivage : arrivages) {
      if (disponible.signum() <= 0) {
        break;
      }

      BigDecimal qtyToTransfer =
          arrivage
              .getQtyAllocated()
              .subtract(
                  arrivage.getQtyReceived() == null ? BigDecimal.ZERO : arrivage.getQtyReceived())
              .min(disponible);

      if (qtyToTransfer.signum() <= 0) {
        continue;
      }

      SaleOrderLine sol = arrivage.getSaleOrderLine();

      // Réservation stock réelle : on incrémente requestedReservedQty puis on appelle requestQty
      // ✅ APRÈS
      try {
        BigDecimal currentRequested =
            sol.getRequestedReservedQty() == null ? BigDecimal.ZERO : sol.getRequestedReservedQty();
        reservedQtyService.updateRequestedReservedQty(sol, currentRequested.add(qtyToTransfer));
      } catch (Exception e) {
        // Pas de StockMoveLine planifiée — on continue quand même
      }

      // Mise à jour de l'arrivage
      arrivage.setQtyReceived(
          (arrivage.getQtyReceived() == null ? BigDecimal.ZERO : arrivage.getQtyReceived())
              .add(qtyToTransfer));

      // Transfert comptable sur la SOL
      sol.setQtyFromStock(
          (sol.getQtyFromStock() == null ? BigDecimal.ZERO : sol.getQtyFromStock())
              .add(qtyToTransfer));
      sol.setQtyFromArrivage(
          (sol.getQtyFromArrivage() == null ? BigDecimal.ZERO : sol.getQtyFromArrivage())
              .subtract(qtyToTransfer)
              .max(BigDecimal.ZERO));

      disponible = disponible.subtract(qtyToTransfer);
    }

    // Recompute POL
    BigDecimal totalAllocated =
        saleOrderLineArrivageRepository.findByPurchaseOrderLine(pol).stream()
            .map(SaleOrderLineArrivage::getQtyAllocated)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    pol.setQtyAllocatedToSales(totalAllocated);
    pol.setQtyAvailableToPromise(
        pol.getQty()
            .subtract(pol.getReceivedQty() == null ? BigDecimal.ZERO : pol.getReceivedQty())
            .subtract(totalAllocated)
            .max(BigDecimal.ZERO)
            .setScale(4, RoundingMode.HALF_UP));
  }
}

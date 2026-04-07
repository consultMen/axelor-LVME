package com.axelor.apps.supplychain.service;

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.base.db.repo.TraceBackRepository;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.stock.db.StockLocation;
import com.axelor.apps.stock.db.StockLocationLine;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.repo.StockLocationLineStockRepository;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.axelor.apps.stock.service.StockMoveLineService;
import com.axelor.apps.stock.service.StockMoveService;
import com.axelor.apps.supplychain.db.SaleOrderLineStockLocation;
import com.axelor.apps.supplychain.db.repo.SaleOrderLineStockLocationSupplychainRepository;
import com.axelor.inject.Beans;
import com.google.inject.Inject;
import com.google.inject.persist.Transactional;
import java.math.BigDecimal;
import java.util.List;

public class SaleOrderLineStockLocationServiceImpl implements SaleOrderLineStockLocationService {

  protected SaleOrderLineStockLocationSupplychainRepository repository;
  protected StockLocationLineStockRepository stockLocationLineRepository;

  @Inject
  public SaleOrderLineStockLocationServiceImpl(
      SaleOrderLineStockLocationSupplychainRepository repository,
      StockLocationLineStockRepository stockLocationLineRepository) {
    this.repository = repository;
    this.stockLocationLineRepository = stockLocationLineRepository;
  }

  @Override
  @Transactional(rollbackOn = {Exception.class})
  public void allocate(SaleOrderLine sol, StockLocation stockLocation, BigDecimal qty)
      throws AxelorException {

    BigDecimal availableQty = getAvailableQty(sol, stockLocation);
    if (qty.compareTo(availableQty) > 0) {
      throw new AxelorException(
          TraceBackRepository.CATEGORY_INCONSISTENCY,
          "La quantité demandée (%s) dépasse le stock disponible (%s) dans l'emplacement %s",
          qty,
          availableQty,
          stockLocation.getName());
    }

    BigDecimal totalStock = sol.getQtyFromStock() == null ? BigDecimal.ZERO : sol.getQtyFromStock();
    if (totalStock.add(qty).compareTo(sol.getQty()) > 0) {
      throw new AxelorException(
          TraceBackRepository.CATEGORY_INCONSISTENCY,
          "La quantité totale depuis stock (%s) dépasse la quantité commandée (%s)",
          totalStock.add(qty),
          sol.getQty());
    }

    SaleOrderLineStockLocation item = new SaleOrderLineStockLocation();
    item.setSaleOrderLine(sol);
    item.setStockLocation(stockLocation);
    item.setQty(qty);
    item.setTransferred(false);
    repository.save(item);

    recomputeQtyFromStock(sol);
  }

  @Override
  @Transactional(rollbackOn = {Exception.class})
  public void deallocate(SaleOrderLineStockLocation item) throws AxelorException {
    SaleOrderLine sol = item.getSaleOrderLine();
    repository.remove(item);
    recomputeQtyFromStock(sol);
  }

  @Override
  public BigDecimal getAvailableQty(SaleOrderLine sol, StockLocation stockLocation) {
    if (sol.getProduct() == null) return BigDecimal.ZERO;

    StockLocationLine line =
        stockLocationLineRepository
            .all()
            .filter("self.product.id = :productId " + "AND self.stockLocation.id = :locationId")
            .bind("productId", sol.getProduct().getId())
            .bind("locationId", stockLocation.getId())
            .fetchOne();

    if (line == null) return BigDecimal.ZERO;
    return line.getCurrentQty() == null ? BigDecimal.ZERO : line.getCurrentQty();
  }

  @Override
  public void recomputeQtyFromStock(SaleOrderLine sol) {
    List<SaleOrderLineStockLocation> items = repository.findBySaleOrderLine(sol);

    BigDecimal totalStock =
        items.stream()
            .map(SaleOrderLineStockLocation::getQty)
            .reduce(BigDecimal.ZERO, BigDecimal::add);

    sol.setQtyFromStock(totalStock);
  }

  @Override
  @Transactional(rollbackOn = {Exception.class})
  public void transferVirtualToPhysical(SaleOrderLine sol, StockLocation stockLocationPhysique)
      throws AxelorException {

    List<SaleOrderLineStockLocation> virtualItems = repository.findVirtualNotTransferred(sol);

    if (virtualItems.isEmpty()) return;

    for (SaleOrderLineStockLocation item : virtualItems) {
      StockLocation virtualLocation = item.getStockLocation();
      BigDecimal qty = item.getQty();

      // Créer StockMove INTERNAL
      StockMove stockMove =
          Beans.get(StockMoveService.class)
              .createStockMove(
                  null,
                  null,
                  sol.getSaleOrder().getCompany(),
                  virtualLocation,
                  stockLocationPhysique,
                  null,
                  null,
                  null,
                  StockMoveRepository.TYPE_INTERNAL);

      // Créer la ligne du StockMove
      Beans.get(StockMoveLineService.class)
          .createStockMoveLine(
              sol.getProduct(),
              sol.getProductName(),
              null,
              qty,
              BigDecimal.ZERO,
              BigDecimal.ZERO,
              sol.getProduct().getUnit(),
              stockMove,
              StockMoveLineService.TYPE_NULL,
              false,
              BigDecimal.ZERO,
              virtualLocation,
              stockLocationPhysique);

      // Planifier
      Beans.get(StockMoveService.class).planWithNoSplit(stockMove);

      // Réaliser
      Beans.get(StockMoveService.class).realize(stockMove);

      // Marquer comme transféré
      item.setTransferred(true);
      repository.save(item);
    }
  }
}

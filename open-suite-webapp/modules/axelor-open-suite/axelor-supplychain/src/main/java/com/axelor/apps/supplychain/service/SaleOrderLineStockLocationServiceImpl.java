package com.axelor.apps.supplychain.service;

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.base.db.repo.TraceBackRepository;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.db.repo.SaleOrderLineRepository;
import com.axelor.apps.sale.db.repo.SaleOrderRepository;
import com.axelor.apps.stock.db.StockLocation;
import com.axelor.apps.stock.db.StockLocationLine;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.repo.StockLocationLineStockRepository;
import com.axelor.apps.stock.db.repo.StockLocationRepository;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.axelor.apps.stock.service.StockMoveLineService;
import com.axelor.apps.stock.service.StockMoveService;
import com.axelor.apps.supplychain.db.SaleOrderLineStockLocation;
import com.axelor.apps.supplychain.db.repo.SaleOrderLineStockLocationSupplychainRepository;
import com.axelor.inject.Beans;
import com.google.inject.Inject;
import com.google.inject.persist.Transactional;
import java.math.BigDecimal;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

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

    if (qty == null || qty.signum() <= 0) {
      throw new AxelorException(
          TraceBackRepository.CATEGORY_INCONSISTENCY, "La quantité doit être positive");
    }

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
    // LVME : l'en-tête n'est plus enregistré ici (conflit de version).
    // Il est mis à jour dans le formulaire par SaleOrderStockLocationLvmeController.
  }

  @Override
  @Transactional(rollbackOn = {Exception.class})
  public void deallocate(SaleOrderLineStockLocation item) throws AxelorException {
    SaleOrderLine sol = item.getSaleOrderLine();
    repository.remove(item);
    recomputeQtyFromStock(sol);
  }

  /**
   * Disponible = stock physique de l'emplacement − quantités déjà allouées sur ce même emplacement
   * par d'autres lignes de commande actives (non transférées, non livrées).
   */
  @Override
  public BigDecimal getAvailableQty(SaleOrderLine sol, StockLocation stockLocation) {
    if (sol.getProduct() == null || stockLocation == null) {
      return BigDecimal.ZERO;
    }

    StockLocationLine line =
        stockLocationLineRepository
            .all()
            .filter("self.product.id = :productId AND self.stockLocation.id = :locationId")
            .bind("productId", sol.getProduct().getId())
            .bind("locationId", stockLocation.getId())
            .fetchOne();

    if (line == null) {
      return BigDecimal.ZERO;
    }
    BigDecimal current = line.getCurrentQty() == null ? BigDecimal.ZERO : line.getCurrentQty();

    BigDecimal alreadyAllocated =
        repository
            .all()
            .filter(
                "self.stockLocation.id = :locationId "
                    + "AND self.saleOrderLine.product.id = :productId "
                    + "AND self.saleOrderLine.id != :solId "
                    + "AND (self.transferred IS NULL OR self.transferred = false) "
                    + "AND self.saleOrderLine.saleOrder.statusSelect IN (:activeStatus) "
                    + "AND (self.saleOrderLine.deliveryState IS NULL "
                    + "     OR self.saleOrderLine.deliveryState != :delivered)")
            .bind("locationId", stockLocation.getId())
            .bind("productId", sol.getProduct().getId())
            .bind("solId", sol.getId() == null ? 0L : sol.getId())
            .bind(
                "activeStatus",
                Arrays.asList(
                    SaleOrderRepository.STATUS_DRAFT_QUOTATION,
                    SaleOrderRepository.STATUS_FINALIZED_QUOTATION,
                    SaleOrderRepository.STATUS_ORDER_CONFIRMED))
            .bind("delivered", SaleOrderLineRepository.DELIVERY_STATE_DELIVERED)
            .fetch()
            .stream()
            .map(SaleOrderLineStockLocation::getQty)
            .reduce(BigDecimal.ZERO, BigDecimal::add);

    return current.subtract(alreadyAllocated).max(BigDecimal.ZERO);
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

    if (virtualItems.isEmpty()) {
      return;
    }

    for (SaleOrderLineStockLocation item : virtualItems) {
      StockLocation virtualLocation = item.getStockLocation();
      BigDecimal qty = item.getQty();

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

      Beans.get(StockMoveService.class).planWithNoSplit(stockMove);
      Beans.get(StockMoveService.class).realize(stockMove);

      item.setTransferred(true);
      repository.save(item);
    }

    // LVME : après transfert, la marchandise est sur l'emplacement physique.
    // On modifie la commande déjà en cours de traitement (confirmation), sans la recharger.
    SaleOrder so = sol.getSaleOrder();
    StockLocation candidate = computeSaleOrderStockLocation(so.getId(), stockLocationPhysique);
    if (candidate != null) {
      so.setStockLocation(candidate);
    }
  }

  /**
   * LVME : renvoie l'emplacement physique unique alloué sur la commande (utilisable en vente), ou
   * null s'il n'y en a aucun ou plusieurs. Les comptes de réservation virtuels sont ignorés.
   */
  @Override
  public StockLocation computeSaleOrderStockLocation(
      Long saleOrderId, StockLocation extraPhysicalLocation) {
    if (saleOrderId == null) {
      return null;
    }
    Set<Long> locationIds = new LinkedHashSet<>();
    StockLocation candidate = null;

    List<SaleOrderLineStockLocation> physicalItems =
        repository
            .all()
            .filter(
                "self.saleOrderLine.saleOrder.id = :soId "
                    + "AND self.stockLocation.typeSelect != :virtual "
                    + "AND self.stockLocation.usableOnSaleOrder = true")
            .bind("soId", saleOrderId)
            .bind("virtual", StockLocationRepository.TYPE_VIRTUAL)
            .fetch();

    for (SaleOrderLineStockLocation item : physicalItems) {
      if (locationIds.add(item.getStockLocation().getId())) {
        candidate = item.getStockLocation();
      }
    }
    if (extraPhysicalLocation != null
        && Boolean.TRUE.equals(extraPhysicalLocation.getUsableOnSaleOrder())
        && locationIds.add(extraPhysicalLocation.getId())) {
      candidate = extraPhysicalLocation;
    }
    return locationIds.size() == 1 ? candidate : null;
  }
}

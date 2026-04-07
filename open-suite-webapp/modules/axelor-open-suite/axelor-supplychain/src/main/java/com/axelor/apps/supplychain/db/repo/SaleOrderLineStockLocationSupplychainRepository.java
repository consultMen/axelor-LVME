package com.axelor.apps.supplychain.db.repo;

import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.stock.db.StockLocation;
import com.axelor.apps.supplychain.db.SaleOrderLineStockLocation;
import java.util.List;

public class SaleOrderLineStockLocationSupplychainRepository
    extends SaleOrderLineStockLocationRepository {

  public List<SaleOrderLineStockLocation> findBySaleOrderLine(SaleOrderLine sol) {
    return all().filter("self.saleOrderLine.id = :solId").bind("solId", sol.getId()).fetch();
  }

  public List<SaleOrderLineStockLocation> findVirtualNotTransferred(SaleOrderLine sol) {
    return all()
        .filter(
            "self.saleOrderLine.id = :solId "
                + "AND self.stockLocation.typeSelect = 3 "
                + "AND self.transferred = false")
        .bind("solId", sol.getId())
        .fetch();
  }

  public SaleOrderLineStockLocation findBySolAndLocation(
      SaleOrderLine sol, StockLocation stockLocation) {
    return all()
        .filter("self.saleOrderLine.id = :solId " + "AND self.stockLocation.id = :locationId")
        .bind("solId", sol.getId())
        .bind("locationId", stockLocation.getId())
        .fetchOne();
  }
}

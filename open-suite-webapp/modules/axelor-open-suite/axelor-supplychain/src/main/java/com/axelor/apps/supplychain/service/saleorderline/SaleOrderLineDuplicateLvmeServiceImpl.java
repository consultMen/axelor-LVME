package com.axelor.apps.supplychain.service.saleorderline;

import com.axelor.apps.base.AxelorException;
import com.axelor.apps.base.db.repo.TraceBackRepository;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.db.repo.SaleOrderLineRepository;
import com.axelor.apps.sale.db.repo.SaleOrderRepository;
import com.axelor.apps.sale.service.saleorder.SaleOrderComputeService;
import com.axelor.apps.supplychain.db.SaleOrderLineLot;
import com.google.inject.Inject;
import com.google.inject.persist.Transactional;
import java.math.BigDecimal;

public class SaleOrderLineDuplicateLvmeServiceImpl implements SaleOrderLineDuplicateLvmeService {

  protected SaleOrderLineRepository saleOrderLineRepository;
  protected SaleOrderRepository saleOrderRepository;
  protected SaleOrderComputeService saleOrderComputeService;

  @Inject
  public SaleOrderLineDuplicateLvmeServiceImpl(
      SaleOrderLineRepository saleOrderLineRepository,
      SaleOrderRepository saleOrderRepository,
      SaleOrderComputeService saleOrderComputeService) {
    this.saleOrderLineRepository = saleOrderLineRepository;
    this.saleOrderRepository = saleOrderRepository;
    this.saleOrderComputeService = saleOrderComputeService;
  }

  @Override
  @Transactional(rollbackOn = {Exception.class})
  public SaleOrderLine duplicateLine(SaleOrderLine saleOrderLine) throws AxelorException {
    SaleOrder saleOrder = saleOrderLine.getSaleOrder();
    if (saleOrder == null
        || saleOrder.getStatusSelect() >= SaleOrderRepository.STATUS_ORDER_CONFIRMED) {
      throw new AxelorException(
          TraceBackRepository.CATEGORY_INCONSISTENCY,
          "Seules les lignes d'un devis (commande non confirmée) peuvent être dupliquées.");
    }

    // Copie simple : les listes (lots, réservations, arrivages) ne sont pas copiées par Axelor
    SaleOrderLine copy = saleOrderLineRepository.copy(saleOrderLine, false);

    // Réservations non reprises : elles seront refaites sur la nouvelle ligne
    copy.setQtyFromStock(BigDecimal.ZERO);
    copy.setQtyFromArrivage(BigDecimal.ZERO);
    copy.setReservedQty(BigDecimal.ZERO);
    copy.setRequestedReservedQty(BigDecimal.ZERO);

    // Lots sélectionnés : repris à l'identique
    if (saleOrderLine.getSaleOrderLineLotList() != null) {
      for (SaleOrderLineLot lot : saleOrderLine.getSaleOrderLineLotList()) {
        SaleOrderLineLot lotCopy = new SaleOrderLineLot();
        lotCopy.setTrackingNumber(lot.getTrackingNumber());
        lotCopy.setLotFournisseur(lot.getLotFournisseur());
        lotCopy.setQtyToShip(lot.getQtyToShip());
        lotCopy.setAvailableQty(lot.getAvailableQty());
        copy.addSaleOrderLineLotListItem(lotCopy);
      }
    }

    // Insère la copie juste sous la ligne d'origine
    int sequence = saleOrderLine.getSequence();
    for (SaleOrderLine line : saleOrder.getSaleOrderLineList()) {
      if (line.getSequence() > sequence) {
        line.setSequence(line.getSequence() + 1);
      }
    }
    copy.setSequence(sequence + 1);
    saleOrder.addSaleOrderLineListItem(copy);

    saleOrderComputeService.computeSaleOrder(saleOrder);
    saleOrderRepository.save(saleOrder);
    return copy;
  }
}

package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.db.repo.SaleOrderLineRepository;
import com.axelor.apps.sale.db.repo.SaleOrderRepository;
import com.axelor.apps.supplychain.service.saleorderline.SaleOrderLineDuplicateLvmeService;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.axelor.rpc.Context;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

public class SaleOrderLineDuplicateLvmeController {

  /** LVME : duplique la ligne de commande client cliquée, juste sous la ligne d'origine. */
  public void duplicateLine(ActionRequest request, ActionResponse response) {
    try {
      Context context = request.getContext();
      SaleOrderLine saleOrderLine = context.asType(SaleOrderLine.class);
      SaleOrderLine lineToCopy =
          saleOrderLine.getId() != null
              ? Beans.get(SaleOrderLineRepository.class).find(saleOrderLine.getId())
              : findSavedLine(context, saleOrderLine);
      if (lineToCopy == null) {
        response.setInfo("Enregistrez la commande puis dupliquez la ligne.");
        return;
      }
      Beans.get(SaleOrderLineDuplicateLvmeService.class).duplicateLine(lineToCopy);
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /**
   * LVME : ligne saisie mais pas encore enregistrée au moment du clic. Le bouton enregistre d'abord
   * la commande ; on retrouve alors la ligne dans la commande enregistrée (même article, même
   * libellé, même n° d'ordre s'il est connu ; la plus récente si plusieurs correspondent).
   */
  protected SaleOrderLine findSavedLine(Context context, SaleOrderLine line) {
    Context parent = context.getParent();
    if (parent == null || parent.get("id") == null) {
      return null;
    }
    SaleOrder saleOrder =
        Beans.get(SaleOrderRepository.class).find(Long.valueOf(parent.get("id").toString()));
    if (saleOrder == null || saleOrder.getSaleOrderLineList() == null) {
      return null;
    }
    Long productId = line.getProduct() != null ? line.getProduct().getId() : null;
    List<SaleOrderLine> candidates =
        saleOrder.getSaleOrderLineList().stream()
            .filter(
                l ->
                    Objects.equals(
                        l.getProduct() != null ? l.getProduct().getId() : null, productId))
            .filter(l -> Objects.equals(l.getProductName(), line.getProductName()))
            .collect(Collectors.toList());
    // n° d'ordre utilisé seulement s'il est déjà attribué à l'écran (les lignes de vente ne sont
    // numérotées qu'à l'enregistrement)
    if (line.getSequence() != null && line.getSequence() > 0) {
      List<SaleOrderLine> sameSequence =
          candidates.stream()
              .filter(l -> Objects.equals(l.getSequence(), line.getSequence()))
              .collect(Collectors.toList());
      if (!sameSequence.isEmpty()) {
        candidates = sameSequence;
      }
    }
    return candidates.stream().max(Comparator.comparing(SaleOrderLine::getId)).orElse(null);
  }
}

package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.purchase.db.PurchaseOrder;
import com.axelor.apps.purchase.db.repo.PurchaseOrderRepository;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.repo.SaleOrderRepository;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.axelor.apps.supplychain.service.LvmeDuplicationService;
import com.axelor.inject.Beans;
import com.axelor.meta.schema.actions.ActionView;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;

/**
 * LVME : bouton « Dupliquer » (fiche et liste) des commandes clients, commandes d'achat et
 * arrivages. La copie est enregistrée puis ouverte dans un nouvel onglet.
 */
public class LvmeDuplicationController {

  public void dupliquerCommandeClient(ActionRequest request, ActionResponse response) {
    try {
      Long id = request.getContext().asType(SaleOrder.class).getId();
      if (id == null) {
        response.setInfo("Enregistrez d'abord la commande.");
        return;
      }
      SaleOrder copie =
          Beans.get(LvmeDuplicationService.class)
              .dupliquerCommandeClient(Beans.get(SaleOrderRepository.class).find(id));
      response.setView(
          ActionView.define("Commande client")
              .model(SaleOrder.class.getName())
              .add("form", "sale-order-form")
              .add("grid", "sale-order-grid")
              .context("_showRecord", copie.getId())
              .map());
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void dupliquerCommandeAchat(ActionRequest request, ActionResponse response) {
    try {
      Long id = request.getContext().asType(PurchaseOrder.class).getId();
      if (id == null) {
        response.setInfo("Enregistrez d'abord la commande.");
        return;
      }
      PurchaseOrder copie =
          Beans.get(LvmeDuplicationService.class)
              .dupliquerCommandeAchat(Beans.get(PurchaseOrderRepository.class).find(id));
      response.setView(
          ActionView.define("Commande fournisseur")
              .model(PurchaseOrder.class.getName())
              .add("form", "purchase-order-form")
              .add("grid", "purchase-order-grid")
              .context("_showRecord", copie.getId())
              .map());
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void dupliquerArrivage(ActionRequest request, ActionResponse response) {
    try {
      Long id = request.getContext().asType(StockMove.class).getId();
      if (id == null) {
        response.setInfo("Enregistrez d'abord l'arrivage.");
        return;
      }
      StockMove copie =
          Beans.get(LvmeDuplicationService.class)
              .dupliquerArrivage(Beans.get(StockMoveRepository.class).find(id));
      response.setView(
          ActionView.define("Arrivage")
              .model(StockMove.class.getName())
              .add("form", "lvme-arrivage-form")
              .add("grid", "lvme-arrivage-grid")
              .context("_showRecord", copie.getId())
              .map());
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

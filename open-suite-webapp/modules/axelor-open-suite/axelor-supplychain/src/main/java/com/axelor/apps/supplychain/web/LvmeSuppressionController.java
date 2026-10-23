package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.purchase.db.PurchaseOrder;
import com.axelor.apps.purchase.db.repo.PurchaseOrderRepository;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.repo.SaleOrderRepository;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.StockMoveLine;
import com.axelor.apps.stock.db.TrackingNumber;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.axelor.apps.stock.db.repo.TrackingNumberRepository;
import com.axelor.db.JPA;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.google.inject.persist.Transactional;
import java.util.ArrayList;
import java.util.List;

/**
 * LVME : icône « Supprimer » des listes Commandes clients, Achats fournisseurs et Arrivages, comme
 * la suppression native d'Axelor : seulement une pièce en brouillon ou annulée (une commande
 * confirmée, une commande validée ou un arrivage planifié / réel s'annule d'abord dans sa fiche).
 * La suppression passe par le dépôt Axelor (mêmes contrôles que la corbeille native).
 */
public class LvmeSuppressionController {

  @Transactional(rollbackOn = {Exception.class})
  public void supprimerCommandeClient(ActionRequest request, ActionResponse response) {
    try {
      Long id = request.getContext().asType(SaleOrder.class).getId();
      SaleOrderRepository repo = Beans.get(SaleOrderRepository.class);
      SaleOrder commande = id != null ? repo.find(id) : null;
      if (commande == null) {
        return;
      }
      int status = commande.getStatusSelect();
      if (status != SaleOrderRepository.STATUS_DRAFT_QUOTATION
          && status != SaleOrderRepository.STATUS_FINALIZED_QUOTATION
          && status != SaleOrderRepository.STATUS_CANCELED) {
        response.setError(
            "Commande "
                + commande.getSaleOrderSeq()
                + " confirmée : annulez-la d'abord dans sa fiche, puis supprimez-la.");
        return;
      }
      String num = commande.getSaleOrderSeq();
      repo.remove(commande);
      response.setNotify("Commande " + num + " supprimée.");
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  @Transactional(rollbackOn = {Exception.class})
  public void supprimerCommandeAchat(ActionRequest request, ActionResponse response) {
    try {
      Long id = request.getContext().asType(PurchaseOrder.class).getId();
      PurchaseOrderRepository repo = Beans.get(PurchaseOrderRepository.class);
      PurchaseOrder commande = id != null ? repo.find(id) : null;
      if (commande == null) {
        return;
      }
      int status = commande.getStatusSelect();
      if (status != PurchaseOrderRepository.STATUS_DRAFT
          && status != PurchaseOrderRepository.STATUS_REQUESTED
          && status != PurchaseOrderRepository.STATUS_CANCELED) {
        response.setError(
            "Commande "
                + commande.getPurchaseOrderSeq()
                + " validée : annulez-la d'abord dans sa fiche, puis supprimez-la.");
        return;
      }
      String num = commande.getPurchaseOrderSeq();
      repo.remove(commande);
      response.setNotify("Commande " + num + " supprimée.");
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  @Transactional(rollbackOn = {Exception.class})
  public void supprimerArrivage(ActionRequest request, ActionResponse response) {
    try {
      Long id = request.getContext().asType(StockMove.class).getId();
      StockMoveRepository repo = Beans.get(StockMoveRepository.class);
      StockMove arrivage = id != null ? repo.find(id) : null;
      if (arrivage == null) {
        return;
      }
      int status = arrivage.getStatusSelect();
      if (status != StockMoveRepository.STATUS_DRAFT
          && status != StockMoveRepository.STATUS_CANCELED) {
        response.setError(
            "Arrivage "
                + arrivage.getStockMoveSeq()
                + (status == StockMoveRepository.STATUS_REALIZED
                    ? " réel : il est entré en stock, il ne peut plus être supprimé (annulez-le dans sa fiche)."
                    : " en cours : annulez-le d'abord dans sa fiche, puis supprimez-le."));
        return;
      }
      String num = arrivage.getStockMoveSeq();
      // les lots créés pour ses lignes (lot « d'origine » = ligne de l'arrivage) en sont détachés, sinon la
      // base refuse de supprimer les lignes ; un lot qui ne sert plus nulle part est supprimé avec l'arrivage
      TrackingNumberRepository lotRepo = Beans.get(TrackingNumberRepository.class);
      List<TrackingNumber> lots = new ArrayList<>();
      if (arrivage.getStockMoveLineList() != null) {
        for (StockMoveLine line : arrivage.getStockMoveLineList()) {
          if (line.getId() == null) {
            continue;
          }
          for (TrackingNumber lot :
              lotRepo.all().filter("self.originStockMoveLine.id = ?1", line.getId()).fetch()) {
            lot.setOriginStockMoveLine(null);
            lots.add(lot);
          }
        }
      }
      repo.remove(arrivage);
      JPA.flush();
      for (TrackingNumber lot : lots) {
        if (!lotUtilise(lot)) {
          lotRepo.remove(lot);
        }
      }
      response.setNotify("Arrivage " + (num != null ? num : "") + " supprimé.");
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /** Le lot est-il encore utilisé (mouvement de stock, ligne d'achat, stock, lot choisi en vente) ? */
  protected boolean lotUtilise(TrackingNumber lot) {
    String[] requetes = {
      "SELECT COUNT(x) FROM StockMoveLine x WHERE x.trackingNumber.id = :id",
      "SELECT COUNT(x) FROM PurchaseOrderLine x WHERE x.trackingNumber.id = :id",
      "SELECT COUNT(x) FROM StockLocationLine x WHERE x.trackingNumber.id = :id",
      "SELECT COUNT(x) FROM SaleOrderLineLot x WHERE x.trackingNumber.id = :id"
    };
    for (String requete : requetes) {
      Long n =
          JPA.em().createQuery(requete, Long.class).setParameter("id", lot.getId()).getSingleResult();
      if (n != null && n > 0) {
        return true;
      }
    }
    return false;
  }
}

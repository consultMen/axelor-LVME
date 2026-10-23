package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.purchase.db.PurchaseOrder;
import com.axelor.apps.purchase.db.repo.PurchaseOrderRepository;
import com.axelor.apps.purchase.service.PurchaseOrderWorkflowService;
import com.axelor.apps.stock.db.Nature;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.axelor.apps.stock.service.StockMoveService;
import com.axelor.inject.Beans;
import com.axelor.meta.schema.actions.ActionView;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.google.inject.persist.Transactional;

/**
 * LVME : déplacement d'une carte dans les Kanban « Suivi des arrivages » et « Suivi des commandes
 * d'achat ». Le déplacement lance la même action que le bouton de la fiche ; ce qui demande une
 * saisie (réel, motif d'annulation) ouvre la fiche. Un déplacement refusé remet la carte à sa place.
 */
public class LvmeKanbanController {

  // étapes des arrivages (lvme.arrivage.etape.select)
  protected static final int ARR_BROUILLON = 0;
  protected static final int ARR_A_EMBARQUER = 1;
  protected static final int ARR_FLOTTANT = 2;
  protected static final int ARR_REEL = 3;
  protected static final int ARR_ANNULE = 4;

  // étapes des commandes d'achat (lvme.achat.etape.select)
  protected static final int ACH_BROUILLON = 1;
  protected static final int ACH_VALIDEE = 2;
  protected static final int ACH_ANNULEE = 5;

  @Transactional(rollbackOn = {Exception.class})
  public void deplacerArrivage(ActionRequest request, ActionResponse response) {
    try {
      Object cible = request.getContext().get("lvmeEtapeArrivage");
      Long id = request.getContext().asType(StockMove.class).getId();
      StockMoveRepository repo = Beans.get(StockMoveRepository.class);
      StockMove arrivage = id != null ? repo.find(id) : null;
      if (arrivage == null || cible == null) {
        response.setReload(true);
        return;
      }
      int etape = Integer.parseInt(cible.toString());
      int status = arrivage.getStatusSelect();

      if (status == StockMoveRepository.STATUS_REALIZED || status == StockMoveRepository.STATUS_CANCELED) {
        response.setError(
            "Arrivage "
                + arrivage.getStockMoveSeq()
                + (status == StockMoveRepository.STATUS_REALIZED ? " déjà réel" : " annulé")
                + " : il ne change plus d'étape.");
        response.setReload(true);
        return;
      }
      switch (etape) {
        case ARR_BROUILLON:
          response.setError("Un arrivage ne revient pas en brouillon depuis le Kanban.");
          break;
        case ARR_A_EMBARQUER:
        case ARR_FLOTTANT:
          if (status == StockMoveRepository.STATUS_DRAFT) {
            Beans.get(StockMoveService.class).plan(arrivage);
          }
          arrivage.setNature(etape == ARR_FLOTTANT ? Nature.FLOTTANT : Nature.EN_COURS_DE_PRODUCTION);
          repo.save(arrivage);
          response.setNotify(
              "Arrivage "
                  + arrivage.getStockMoveSeq()
                  + (etape == ARR_FLOTTANT ? " : Flottant." : " : À embarquer."));
          break;
        case ARR_REEL:
        case ARR_ANNULE:
          // saisie du réel (quantités, poids) ou du motif d'annulation : dans la fiche
          response.setView(
              ActionView.define(
                      etape == ARR_REEL
                          ? "Arrivage : saisissez le réel puis « Saisie Réel »"
                          : "Arrivage : annulation (bouton Annuler)")
                  .model(StockMove.class.getName())
                  .add("form", "lvme-arrivage-form")
                  .param("popup", "reload")
                  .param("popup.maximized", "true")
                  .param("forceEdit", "true")
                  .context("_showRecord", arrivage.getId())
                  .map());
          break;
        default:
          break;
      }
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
      response.setReload(true);
    }
  }

  @Transactional(rollbackOn = {Exception.class})
  public void deplacerCommandeAchat(ActionRequest request, ActionResponse response) {
    try {
      Object cible = request.getContext().get("lvmeEtapeAchat");
      Long id = request.getContext().asType(PurchaseOrder.class).getId();
      PurchaseOrder commande = id != null ? Beans.get(PurchaseOrderRepository.class).find(id) : null;
      if (commande == null || cible == null) {
        response.setReload(true);
        return;
      }
      int etape = Integer.parseInt(cible.toString());
      int status = commande.getStatusSelect();
      PurchaseOrderWorkflowService workflow = Beans.get(PurchaseOrderWorkflowService.class);

      if (etape == ACH_VALIDEE
          && (status == PurchaseOrderRepository.STATUS_DRAFT
              || status == PurchaseOrderRepository.STATUS_REQUESTED)) {
        workflow.validatePurchaseOrder(commande);
        response.setNotify("Commande " + commande.getPurchaseOrderSeq() + " validée.");
      } else if (etape == ACH_ANNULEE
          && status != PurchaseOrderRepository.STATUS_CANCELED
          && status != PurchaseOrderRepository.STATUS_FINISHED) {
        workflow.cancelPurchaseOrder(commande);
        response.setNotify("Commande " + commande.getPurchaseOrderSeq() + " annulée.");
      } else if (etape != ACH_BROUILLON || status != PurchaseOrderRepository.STATUS_DRAFT) {
        response.setError(
            "Depuis ce Kanban, une commande d'achat se valide (Brouillon -> Validée) ou s'annule ;"
                + " Flottant et Réceptionnée suivent son arrivage (Kanban « Suivi des arrivages »).");
      }
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
      response.setReload(true);
    }
  }
}

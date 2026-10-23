package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.purchase.db.PurchaseOrder;
import com.axelor.apps.purchase.db.repo.PurchaseOrderRepository;
import com.axelor.apps.purchase.service.PurchaseOrderWorkflowService;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.repo.SaleOrderRepository;
import com.axelor.apps.sale.service.saleorder.status.SaleOrderConfirmService;
import com.axelor.apps.sale.service.saleorder.status.SaleOrderFinalizeService;
import com.axelor.apps.stock.db.Nature;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.axelor.apps.stock.service.StockMoveService;
import com.axelor.inject.Beans;
import com.axelor.meta.schema.actions.ActionView;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.google.inject.persist.Transactional;
import java.util.List;

/**
 * LVME : déplacement d'une carte dans les Kanban « Suivi des arrivages » et « Suivi des commandes
 * d'achat ». Le déplacement lance la même action que le bouton de la fiche ; ce qui demande une
 * saisie (réel, motif d'annulation) ouvre la fiche. Un déplacement refusé remet la carte à sa
 * place.
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
  protected static final int ACH_FLOTTANT = 3;
  protected static final int ACH_RECEPTIONNEE = 4;
  protected static final int ACH_ANNULEE = 5;

  /** Arrivages (réceptions fournisseur) non réalisés ni annulés de la commande d'achat. */
  protected List<StockMove> arrivagesEnCours(PurchaseOrder commande) {
    return Beans.get(StockMoveRepository.class)
        .all()
        .filter(
            "?1 MEMBER OF self.purchaseOrderSet AND self.typeSelect = 3 AND self.statusSelect IN (1, 2)",
            commande)
        .order("id")
        .fetch();
  }

  protected String libelle(int etapeAchat) {
    switch (etapeAchat) {
      case ACH_BROUILLON:
        return "Brouillon";
      case ACH_VALIDEE:
        return "à embarquer";
      case ACH_FLOTTANT:
        return "Flottant";
      case ACH_RECEPTIONNEE:
        return "En stock";
      default:
        return "Annulée";
    }
  }

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

      if (status == StockMoveRepository.STATUS_REALIZED
          || status == StockMoveRepository.STATUS_CANCELED) {
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
          arrivage.setNature(
              etape == ARR_FLOTTANT ? Nature.FLOTTANT : Nature.EN_COURS_DE_PRODUCTION);
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
      PurchaseOrder commande =
          id != null ? Beans.get(PurchaseOrderRepository.class).find(id) : null;
      if (commande == null || cible == null) {
        response.setReload(true);
        return;
      }
      int etape = Integer.parseInt(cible.toString());
      int status = commande.getStatusSelect();
      PurchaseOrderWorkflowService workflow = Beans.get(PurchaseOrderWorkflowService.class);

      boolean brouillon =
          status == PurchaseOrderRepository.STATUS_DRAFT
              || status == PurchaseOrderRepository.STATUS_REQUESTED;
      boolean validee = status == PurchaseOrderRepository.STATUS_VALIDATED;
      String num = "Commande " + commande.getPurchaseOrderSeq();

      if (etape == ACH_ANNULEE
          && status != PurchaseOrderRepository.STATUS_CANCELED
          && status != PurchaseOrderRepository.STATUS_FINISHED) {
        workflow.cancelPurchaseOrder(commande);
        response.setNotify(num + " annulée.");
      } else if (etape == ACH_VALIDEE && brouillon) {
        workflow.validatePurchaseOrder(commande);
        response.setNotify(num + " validée (arrivage à embarquer créé).");
      } else if ((etape == ACH_VALIDEE || etape == ACH_FLOTTANT) && validee) {
        // À embarquer <-> Flottant : l'étape est celle de son arrivage (recopiée sur la commande)
        List<StockMove> arrivages = arrivagesEnCours(commande);
        if (arrivages.isEmpty()) {
          response.setError(num + " : aucun arrivage en cours à passer " + libelle(etape) + ".");
        } else {
          StockMoveRepository repo = Beans.get(StockMoveRepository.class);
          for (StockMove arrivage : arrivages) {
            if (arrivage.getStatusSelect() == StockMoveRepository.STATUS_DRAFT) {
              Beans.get(StockMoveService.class).plan(arrivage);
            }
            arrivage.setNature(etape == ACH_FLOTTANT ? Nature.FLOTTANT : Nature.EN_COURS_DE_PRODUCTION);
            repo.save(arrivage);
          }
          response.setNotify(num + " : arrivage " + libelle(etape) + ".");
        }
      } else if (etape == ACH_RECEPTIONNEE && validee) {
        // la réception demande la saisie du réel : ouverture de l'arrivage de la commande
        List<StockMove> arrivages = arrivagesEnCours(commande);
        if (arrivages.isEmpty()) {
          response.setError(num + " : aucun arrivage en cours à mettre en stock.");
        } else {
          response.setView(
              ActionView.define("Arrivage : saisissez le réel puis « Saisie Réel »")
                  .model(StockMove.class.getName())
                  .add("form", "lvme-arrivage-form")
                  .param("popup", "reload")
                  .param("popup.maximized", "true")
                  .param("forceEdit", "true")
                  .context("_showRecord", arrivages.get(0).getId())
                  .map());
        }
      } else if (!(etape == ACH_BROUILLON && brouillon)) {
        response.setError(
            num
                + " : passage vers « "
                + libelle(etape)
                + " » impossible depuis son étape actuelle."
                + " Possible : Brouillon -> À embarquer <-> Flottant -> En stock"
                + " (ouvre l'arrivage pour le réel), ou -> Annulée.");
      }
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
      response.setReload(true);
    }
  }

  // étapes des commandes clients (lvme.cde.client.etape.select)
  protected static final int CDE_DEVIS = 1;
  protected static final int CDE_PREPARATION = 2;
  protected static final int CDE_EXPEDIEE = 3;
  protected static final int CDE_LIVREE = 4;
  protected static final int CDE_FACTUREE = 5;
  protected static final int CDE_ANNULEE = 6;

  /** BL (livraisons client) planifiés, ni réalisés ni annulés, de la commande client. */
  protected List<StockMove> blEnCours(SaleOrder commande) {
    return Beans.get(StockMoveRepository.class)
        .all()
        .filter(
            "?1 MEMBER OF self.saleOrderSet AND self.typeSelect = 2 AND self.statusSelect = 2", commande)
        .order("id")
        .fetch();
  }

  @Transactional(rollbackOn = {Exception.class})
  public void deplacerCommandeClient(ActionRequest request, ActionResponse response) {
    try {
      Object cible = request.getContext().get("lvmeEtapeCde");
      Long id = request.getContext().asType(SaleOrder.class).getId();
      SaleOrder commande = id != null ? Beans.get(SaleOrderRepository.class).find(id) : null;
      if (commande == null || cible == null) {
        response.setReload(true);
        return;
      }
      int etape = Integer.parseInt(cible.toString());
      int status = commande.getStatusSelect();
      String num = "Commande " + commande.getSaleOrderSeq();
      boolean devis =
          status == SaleOrderRepository.STATUS_DRAFT_QUOTATION
              || status == SaleOrderRepository.STATUS_FINALIZED_QUOTATION;
      boolean confirmee = status == SaleOrderRepository.STATUS_ORDER_CONFIRMED;

      if (etape == CDE_PREPARATION && devis) {
        // devis -> commande confirmée : le BL est créé « en cours de préparation »
        if (status == SaleOrderRepository.STATUS_DRAFT_QUOTATION) {
          Beans.get(SaleOrderFinalizeService.class).finalizeQuotation(commande);
        }
        String message = Beans.get(SaleOrderConfirmService.class).confirmSaleOrder(commande);
        response.setNotify(
            num + " confirmée." + (message != null && !message.isEmpty() ? " " + message : ""));
      } else if ((etape == CDE_PREPARATION || etape == CDE_EXPEDIEE) && confirmee) {
        // En préparation <-> Expédiée : case Flottant de ses BL
        List<StockMove> bls = blEnCours(commande);
        if (bls.isEmpty()) {
          response.setError(num + " : aucun BL en cours.");
        } else {
          StockMoveRepository repo = Beans.get(StockMoveRepository.class);
          for (StockMove bl : bls) {
            bl.setLvmeBlFlottant(etape == CDE_EXPEDIEE);
            repo.save(bl);
          }
          response.setNotify(
              num + (etape == CDE_EXPEDIEE ? " expédiée (BL Flottant)." : " : BL en cours de préparation."));
        }
      } else if (etape == CDE_LIVREE && confirmee) {
        // livraison = réaliser le BL (quantités, lots) : ouverture du BL
        List<StockMove> bls = blEnCours(commande);
        if (bls.isEmpty()) {
          response.setError(num + " : aucun BL en cours à livrer.");
        } else {
          response.setView(
              ActionView.define("BL : vérifiez puis « Réaliser »")
                  .model(StockMove.class.getName())
                  .add("form", "stock-move-form")
                  .param("popup", "reload")
                  .param("popup.maximized", "true")
                  .param("forceEdit", "true")
                  .context("_showRecord", bls.get(0).getId())
                  .map());
        }
      } else if (etape == CDE_ANNULEE && status != SaleOrderRepository.STATUS_CANCELED) {
        // l'annulation demande un motif : ouverture de la commande
        response.setView(
            ActionView.define("Commande client : annulation (bouton Annuler)")
                .model(SaleOrder.class.getName())
                .add("form", "sale-order-form")
                .param("popup", "reload")
                .param("popup.maximized", "true")
                .param("forceEdit", "true")
                .context("_showRecord", commande.getId())
                .map());
      } else if (etape == CDE_FACTUREE) {
        response.setError(num + " : la facture se fait depuis la commande ou le BL (bouton de facturation).");
      } else if (!(etape == CDE_DEVIS && devis)) {
        response.setError(
            num
                + " : passage impossible depuis son étape actuelle. Possible : Devis -> En préparation"
                + " (confirmer) <-> Expédiée -> Livrée (ouvre le BL), ou -> Annulée (ouvre la commande).");
      }
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
      response.setReload(true);
    }
  }
}

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
import com.axelor.rpc.Context;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;

/**
 * LVME : suppression dans les listes Commandes clients, Achats fournisseurs et Arrivages, comme la
 * suppression native d'Axelor : l'icône corbeille d'une ligne supprime cette ligne ; le bouton «
 * Supprimer la sélection » de la barre de la liste supprime les lignes cochées. Seulement une pièce
 * en brouillon ou annulée (une commande confirmée, une commande validée ou un arrivage planifié /
 * réel s'annule d'abord dans sa fiche) : les autres lignes cochées sont laissées et listées dans le
 * message.
 */
public class LvmeSuppressionController {

  public void supprimerCommandeClient(ActionRequest request, ActionResponse response) {
    supprimer(request, response, "commande(s) client", this::supprimerCommandeClient);
  }

  public void supprimerCommandeAchat(ActionRequest request, ActionResponse response) {
    supprimer(request, response, "commande(s) d'achat", this::supprimerCommandeAchat);
  }

  public void supprimerArrivage(ActionRequest request, ActionResponse response) {
    supprimer(request, response, "arrivage(s)", this::supprimerArrivage);
  }

  // ---------- corbeille native (en-tête de la liste) : contrôle avant la suppression par Axelor
  // ----------

  public void verifierSuppressionCommandeClient(ActionRequest request, ActionResponse response) {
    verifier(request, response, this::refusCommandeClient, false);
  }

  public void verifierSuppressionCommandeAchat(ActionRequest request, ActionResponse response) {
    verifier(request, response, this::refusCommandeAchat, false);
  }

  public void verifierSuppressionArrivage(ActionRequest request, ActionResponse response) {
    verifier(request, response, this::refusArrivage, true);
  }

  /**
   * Action onDelete de la liste, lancée par Axelor avant sa suppression native : si une ligne
   * cochée n'est ni brouillon ni annulée, erreur (rien n'est supprimé) avec la liste des pièces à
   * annuler d'abord. Arrivages : les lots créés pour leurs lignes en sont détachés (sinon la base
   * refuse).
   */
  protected void verifier(
      ActionRequest request,
      ActionResponse response,
      Function<Long, String> refus,
      boolean detacherLots) {
    try {
      List<Long> ids = new ArrayList<>();
      Object selection = request.getContext().get("_ids");
      if (selection instanceof List) {
        for (Object id : (List<?>) selection) {
          ids.add(Long.valueOf(id.toString()));
        }
      }
      List<String> refusees = new ArrayList<>();
      for (Long id : ids) {
        String raison = refus.apply(id);
        if (raison != null) {
          refusees.add(raison);
        }
      }
      if (!refusees.isEmpty()) {
        response.setError(
            "Rien n'a été supprimé : seules les pièces en brouillon ou annulées se suppriment.<br/>- "
                + String.join("<br/>- ", refusees));
        return;
      }
      if (detacherLots) {
        JPA.runInTransaction(
            () -> {
              for (Long id : ids) {
                detacherLots(Beans.get(StockMoveRepository.class).find(id));
              }
            });
      }
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  protected String refusCommandeClient(Long id) {
    SaleOrder commande = Beans.get(SaleOrderRepository.class).find(id);
    if (commande == null) {
      return null;
    }
    int status = commande.getStatusSelect();
    return status == SaleOrderRepository.STATUS_DRAFT_QUOTATION
            || status == SaleOrderRepository.STATUS_FINALIZED_QUOTATION
            || status == SaleOrderRepository.STATUS_CANCELED
        ? null
        : "Commande " + commande.getSaleOrderSeq() + " confirmée : l'annuler d'abord dans sa fiche";
  }

  protected String refusCommandeAchat(Long id) {
    PurchaseOrder commande = Beans.get(PurchaseOrderRepository.class).find(id);
    if (commande == null) {
      return null;
    }
    int status = commande.getStatusSelect();
    return status == PurchaseOrderRepository.STATUS_DRAFT
            || status == PurchaseOrderRepository.STATUS_REQUESTED
            || status == PurchaseOrderRepository.STATUS_CANCELED
        ? null
        : "Commande "
            + commande.getPurchaseOrderSeq()
            + " validée : l'annuler d'abord dans sa fiche";
  }

  protected String refusArrivage(Long id) {
    StockMove arrivage = Beans.get(StockMoveRepository.class).find(id);
    if (arrivage == null) {
      return null;
    }
    int status = arrivage.getStatusSelect();
    if (status == StockMoveRepository.STATUS_DRAFT
        || status == StockMoveRepository.STATUS_CANCELED) {
      return null;
    }
    return "Arrivage "
        + arrivage.getStockMoveSeq()
        + (status == StockMoveRepository.STATUS_REALIZED
            ? " réel : entré en stock, ne peut plus être supprimé"
            : " en cours : l'annuler d'abord dans sa fiche");
  }

  /** Lots dont la ligne d'origine est une ligne de l'arrivage : lien retiré ; renvoie ces lots. */
  protected List<TrackingNumber> detacherLots(StockMove arrivage) {
    List<TrackingNumber> lots = new ArrayList<>();
    if (arrivage == null || arrivage.getStockMoveLineList() == null) {
      return lots;
    }
    TrackingNumberRepository lotRepo = Beans.get(TrackingNumberRepository.class);
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
    return lots;
  }

  /**
   * Lignes cochées (_ids, bouton de la barre) ou ligne cliquée (id, icône de la ligne) ; chaque
   * pièce est supprimée dans sa propre transaction, les refus sont listés.
   */
  protected void supprimer(
      ActionRequest request,
      ActionResponse response,
      String libelle,
      Function<Long, String> suppression) {
    try {
      Context context = request.getContext();
      List<Long> ids = new ArrayList<>();
      Object selection = context.get("_ids");
      if (selection instanceof List && !((List<?>) selection).isEmpty()) {
        for (Object id : (List<?>) selection) {
          ids.add(Long.valueOf(id.toString()));
        }
      } else if (context.get("id") != null) {
        ids.add(Long.valueOf(context.get("id").toString()));
      }
      if (ids.isEmpty()) {
        response.setInfo("Cochez au moins une ligne de la liste.");
        return;
      }
      int supprimees = 0;
      List<String> refus = new ArrayList<>();
      for (Long id : ids) {
        String[] resultat = new String[1];
        try {
          JPA.runInTransaction(() -> resultat[0] = suppression.apply(id));
        } catch (Exception e) {
          resultat[0] = "#" + id + " : " + e.getMessage();
        }
        if (resultat[0] == null) {
          supprimees++;
        } else {
          refus.add(resultat[0]);
        }
      }
      if (refus.isEmpty()) {
        response.setNotify(supprimees + " " + libelle + " supprimé(e)(s).");
      } else {
        String message =
            (supprimees > 0 ? supprimees + " " + libelle + " supprimé(e)(s).<br/>" : "")
                + "Non supprimé(e)(s) :<br/>- "
                + String.join("<br/>- ", refus);
        response.setError(message);
      }
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /** null si la commande est supprimée, sinon la raison du refus. */
  protected String supprimerCommandeClient(Long id) {
    SaleOrderRepository repo = Beans.get(SaleOrderRepository.class);
    SaleOrder commande = repo.find(id);
    if (commande == null) {
      return null;
    }
    int status = commande.getStatusSelect();
    if (status != SaleOrderRepository.STATUS_DRAFT_QUOTATION
        && status != SaleOrderRepository.STATUS_FINALIZED_QUOTATION
        && status != SaleOrderRepository.STATUS_CANCELED) {
      return "Commande "
          + commande.getSaleOrderSeq()
          + " confirmée : l'annuler d'abord dans sa fiche";
    }
    repo.remove(commande);
    return null;
  }

  protected String supprimerCommandeAchat(Long id) {
    PurchaseOrderRepository repo = Beans.get(PurchaseOrderRepository.class);
    PurchaseOrder commande = repo.find(id);
    if (commande == null) {
      return null;
    }
    int status = commande.getStatusSelect();
    if (status != PurchaseOrderRepository.STATUS_DRAFT
        && status != PurchaseOrderRepository.STATUS_REQUESTED
        && status != PurchaseOrderRepository.STATUS_CANCELED) {
      return "Commande "
          + commande.getPurchaseOrderSeq()
          + " validée : l'annuler d'abord dans sa fiche";
    }
    repo.remove(commande);
    return null;
  }

  protected String supprimerArrivage(Long id) {
    StockMoveRepository repo = Beans.get(StockMoveRepository.class);
    StockMove arrivage = repo.find(id);
    if (arrivage == null) {
      return null;
    }
    int status = arrivage.getStatusSelect();
    if (status != StockMoveRepository.STATUS_DRAFT
        && status != StockMoveRepository.STATUS_CANCELED) {
      return "Arrivage "
          + arrivage.getStockMoveSeq()
          + (status == StockMoveRepository.STATUS_REALIZED
              ? " réel : entré en stock, ne peut plus être supprimé"
              : " en cours : l'annuler d'abord dans sa fiche");
    }
    // les lots créés pour ses lignes (lot « d'origine » = ligne de l'arrivage) en sont détachés,
    // sinon
    // la base refuse de supprimer les lignes ; un lot qui ne sert plus nulle part est supprimé
    // aussi
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
    return null;
  }

  /**
   * Le lot est-il encore utilisé (mouvement de stock, ligne d'achat, stock, lot choisi en vente) ?
   */
  protected boolean lotUtilise(TrackingNumber lot) {
    String[] requetes = {
      "SELECT COUNT(x) FROM StockMoveLine x WHERE x.trackingNumber.id = :id",
      "SELECT COUNT(x) FROM PurchaseOrderLine x WHERE x.trackingNumber.id = :id",
      "SELECT COUNT(x) FROM StockLocationLine x WHERE x.trackingNumber.id = :id",
      "SELECT COUNT(x) FROM SaleOrderLineLot x WHERE x.trackingNumber.id = :id"
    };
    for (String requete : requetes) {
      Long n =
          JPA.em()
              .createQuery(requete, Long.class)
              .setParameter("id", lot.getId())
              .getSingleResult();
      if (n != null && n > 0) {
        return true;
      }
    }
    return false;
  }
}

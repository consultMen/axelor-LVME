package com.axelor.apps.stock.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.stock.db.StockLocation;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.StockMoveLine;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.axelor.apps.stock.service.StockMoveService;
import com.axelor.db.JPA;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import java.util.List;

/**
 * LVME : bouton « Appliquer à toutes les lignes » de la fiche Arrivage (sauf arrivage réalisé). Met
 * le frigo de l'en-tête sur toutes les lignes ; pour un arrivage planifié, le stock prévisionnel des
 * frigos est recalculé (même mécanisme qu'Axelor à l'enregistrement d'un arrivage planifié).
 */
public class LvmeArrivageFrigoController {

  public void appliquerFrigo(ActionRequest request, ActionResponse response) {
    try {
      StockMove context = request.getContext().asType(StockMove.class);
      if (context.getId() == null) {
        return;
      }
      Long stockMoveId = context.getId();

      // contexte de l'écran écarté (l'arrivage vient d'être enregistré par le bouton)
      JPA.em().clear();
      StockMove stockMove = Beans.get(StockMoveRepository.class).find(stockMoveId);
      StockLocation frigo = stockMove.getToStockLocation();
      if (frigo == null) {
        response.setInfo("Choisissez d'abord le frigo de l'arrivage.");
        return;
      }
      int status = stockMove.getStatusSelect();
      if (status == StockMoveRepository.STATUS_REALIZED) {
        response.setInfo("Le frigo ne peut plus être changé : l'arrivage est réalisé.");
        return;
      }

      List<StockMoveLine> lines = stockMove.getStockMoveLineList();
      int changed = 0;
      if (lines != null) {
        for (StockMoveLine line : lines) {
          if (!frigo.equals(line.getToStockLocation())) {
            line.setToStockLocation(frigo);
            changed++;
          }
        }
      }
      if (changed == 0) {
        response.setNotify("Toutes les lignes sont déjà dans le frigo " + frigo.getName() + ".");
        return;
      }

      if (status == StockMoveRepository.STATUS_PLANNED) {
        // enregistre les lignes et recalcule le stock prévisionnel des frigos
        Beans.get(StockMoveService.class).updateStocks(stockMove);
      } else {
        JPA.runInTransaction(() -> Beans.get(StockMoveRepository.class).save(stockMove));
      }

      response.setNotify(changed + " ligne(s) passée(s) dans le frigo " + frigo.getName() + ".");
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

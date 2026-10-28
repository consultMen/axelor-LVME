package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.db.PrintingTemplate;
import com.axelor.apps.base.db.repo.PrintingTemplateRepository;
import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.sale.db.SaleOrder;
import com.axelor.apps.sale.db.repo.SaleOrderRepository;
import com.axelor.apps.sale.service.saleorder.SaleOrderService;
import com.axelor.apps.sale.service.saleorder.print.SaleOrderPrintService;
import com.axelor.inject.Beans;
import com.axelor.meta.schema.actions.ActionView;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;

/**
 * Bouton « Imprimer commande » de la fiche Commande client : imprime directement le modèle interne
 * LVME (LvmeCommandeClient.rptdesign, copie de la fiche avec ses lignes, PR et marges). Ce modèle
 * n'est pas celui de la configuration des ventes, pour qu'il ne parte jamais en pièce jointe chez
 * le client.
 */
public class LvmeImpressionController {

  public static final String MODELE_COMMANDE_CLIENT = "LVME Commande client";

  public void imprimerCommandeClient(ActionRequest request, ActionResponse response) {
    try {
      Object id = request.getContext().get("id");
      if (id == null) {
        response.setInfo("Enregistrez la commande avant de l'imprimer.");
        return;
      }
      SaleOrder saleOrder = Beans.get(SaleOrderRepository.class).find(Long.valueOf(id.toString()));
      PrintingTemplate modele =
          Beans.get(PrintingTemplateRepository.class)
              .all()
              .filter("self.name = :nom")
              .bind("nom", MODELE_COMMANDE_CLIENT)
              .fetchOne();
      if (modele == null) {
        response.setError("Modèle d'impression « " + MODELE_COMMANDE_CLIENT + " » introuvable.");
        return;
      }
      String lien = Beans.get(SaleOrderPrintService.class).printSaleOrder(saleOrder, false, modele);
      String titre = Beans.get(SaleOrderService.class).getFileName(saleOrder);
      response.setView(ActionView.define(titre).add("html", lien).map());
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

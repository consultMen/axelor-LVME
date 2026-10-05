/*
 * Axelor Business Solutions
 *
 * Copyright (C) 2005-2025 Axelor (<http://axelor.com>).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.stock.db.TrackingNumber;
import com.axelor.apps.supplychain.db.EtatStockLot;
import com.axelor.db.JPA;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * LVME : archiver / désarchiver les lots (numéros de suivi) cochés dans « État des stocks par
 * lots ». Les lignes de la liste sont lot × frigo : c'est le lot lui-même qui est archivé.
 */
public class LvmeArchivageLotController {

  public void archiver(ActionRequest request, ActionResponse response) {
    appliquer(request, response, true);
  }

  public void desarchiver(ActionRequest request, ActionResponse response) {
    appliquer(request, response, false);
  }

  protected void appliquer(ActionRequest request, ActionResponse response, boolean archive) {
    try {
      Object selection = request.getContext().get("_ids");
      if (!(selection instanceof List) || ((List<?>) selection).isEmpty()) {
        response.setInfo("Cochez au moins une ligne de la liste.");
        return;
      }
      Set<Long> lots = new LinkedHashSet<>();
      for (Object id : (List<?>) selection) {
        EtatStockLot ligne = JPA.find(EtatStockLot.class, Long.valueOf(id.toString()));
        if (ligne != null && ligne.getTrackingNumber() != null) {
          lots.add(ligne.getTrackingNumber().getId());
        }
      }
      JPA.runInTransaction(
          () -> {
            for (Long id : lots) {
              TrackingNumber lot = JPA.find(TrackingNumber.class, id);
              if (lot != null) {
                lot.setArchived(archive);
                JPA.save(lot);
              }
            }
          });
      response.setNotify(lots.size() + " lot(s) " + (archive ? "archivé(s)." : "désarchivé(s)."));
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

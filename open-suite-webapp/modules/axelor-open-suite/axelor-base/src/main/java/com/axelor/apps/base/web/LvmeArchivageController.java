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
package com.axelor.apps.base.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.db.JPA;
import com.axelor.db.Model;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.axelor.rpc.Context;
import java.util.ArrayList;
import java.util.List;

/**
 * LVME : archiver / désarchiver depuis une liste (arrivages, clients, fournisseurs, articles). Les
 * boutons de la barre de la liste agissent sur les lignes cochées ; l'icône d'une ligne sur cette
 * ligne seule.
 */
public class LvmeArchivageController {

  public void archiver(ActionRequest request, ActionResponse response) {
    appliquer(request, response, Boolean.TRUE);
  }

  public void desarchiver(ActionRequest request, ActionResponse response) {
    appliquer(request, response, Boolean.FALSE);
  }

  /** Icône de ligne : inverse l'archivage de la ligne cliquée. */
  public void basculerArchivage(ActionRequest request, ActionResponse response) {
    appliquer(request, response, null);
  }

  @SuppressWarnings("unchecked")
  protected void appliquer(ActionRequest request, ActionResponse response, Boolean archive) {
    try {
      Context context = request.getContext();
      Class<? extends Model> klass = (Class<? extends Model>) context.getContextClass();
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
      JPA.runInTransaction(
          () -> {
            for (Long id : ids) {
              Model record = JPA.find(klass, id);
              if (record != null) {
                record.setArchived(
                    archive != null ? archive : !Boolean.TRUE.equals(record.getArchived()));
                JPA.save(record);
              }
            }
          });
      if (ids.size() > 1) {
        response.setNotify(ids.size() + " fiche(s) mise(s) à jour.");
      }
      response.setReload(true);
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }
}

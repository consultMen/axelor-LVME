package com.axelor.apps.account.web;

import com.axelor.apps.ReportFactory;
import com.axelor.apps.account.db.CoditourWizard;
import com.axelor.apps.base.AxelorException;
import com.axelor.apps.report.engine.ReportSettings;
import com.axelor.meta.schema.actions.ActionView;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.axelor.rpc.Context;

public class CoditourWizardController {

  public void print(ActionRequest request, ActionResponse response) throws AxelorException {
    Context context = request.getContext();
    CoditourWizard wizard = context.asType(CoditourWizard.class);

    String fileLink =
        ReportFactory.createReport("CoditourExport.rptdesign", "CoditourExport-${date}")
            .addParam("Mois", wizard.getMois())
            .addParam("Annee", wizard.getAnnee())
            .addParam("__locale", ReportSettings.getPrintingLocale(null))
            .addFormat("xls")
            .generate()
            .getFileLink();

    response.setView(
        ActionView.define("Export Coditour").add("html", fileLink).param("download", "true").map());
  }
}

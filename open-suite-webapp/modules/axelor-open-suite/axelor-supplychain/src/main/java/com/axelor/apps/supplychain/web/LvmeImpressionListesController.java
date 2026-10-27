package com.axelor.apps.supplychain.web;

import com.axelor.apps.ReportFactory;
import com.axelor.apps.base.db.Partner;
import com.axelor.apps.base.db.Product;
import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.report.engine.ReportSettings;
import com.axelor.db.JPA;
import com.axelor.meta.schema.actions.ActionView;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import java.util.Map;

/**
 * Boutons d'impression des listes, comme GESCOM : « Imprimer » (achats fournisseurs, commandes
 * clients, historique prix, état des stocks par lots), « Synthèse » (synthèse des arrivages),
 * « Editer » (arrivages), « Liste des Rotations » (rotation des stocks par lot). Chaque impression
 * reprend les filtres de l'écran (mêmes règles que la liste affichée) ; modèles LvmeListeAchats /
 * LvmeListeCommandesClients / LvmeListeArrivages / LvmeListeRotations / LvmeHistoriquePrix /
 * LvmeEtatStockLots / LvmeSyntheseArrivages.rptdesign.
 */
public class LvmeImpressionListesController {

  private static final String DEBUT = "1900-01-01";
  private static final String FIN = "2999-12-31";

  public void imprimerAchats(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      Partner fouDu = JPA.find(Partner.class, id(c.get("fournisseurDu")));
      Partner fouAu = JPA.find(Partner.class, id(c.get("fournisseurAu")));
      Object nature = c.get("natureAchat");
      String alerte = texte(c.get("alerteAchat"));
      StringBuilder filtres = new StringBuilder(alerte.isEmpty() ? "" : "Alerte " + alerte);
      ajouterPeriode(filtres, "Date", c.get("dateDu"), c.get("dateAu"));
      ajouterPeriode(filtres, "Arrivée", c.get("arriveeDu"), c.get("arriveeAu"));
      String fouDuNom = fouDu != null ? fouDu.getName() : "";
      String fouAuNom = fouAu != null ? fouAu.getName() : fouDuNom;
      ajouter(filtres, fouDuNom.isEmpty() ? "" : "Fournisseur " + fouDuNom + " à " + fouAuNom);
      ouvrir(
          response,
          ReportFactory.createReport("LvmeListeAchats.rptdesign", "Liste des achats-${date}")
              .addParam("Alerte", alerte)
              .addParam("DateFiltre", filtre(c.get("dateDu"), c.get("dateAu")))
              .addParam("DateDu", date(c.get("dateDu"), DEBUT))
              .addParam("DateAu", date(c.get("dateAu"), FIN))
              .addParam("ArrFiltre", filtre(c.get("arriveeDu"), c.get("arriveeAu")))
              .addParam("ArrDu", date(c.get("arriveeDu"), DEBUT))
              .addParam("ArrAu", date(c.get("arriveeAu"), FIN))
              .addParam("FouDu", fouDuNom)
              .addParam("FouAu", fouAuNom)
              .addParam("Transport", String.valueOf(id(c.get("typeTransport"))))
              .addParam("Nature", nature != null ? nature.toString() : "3")
              .addParam("Filtres", filtres.length() == 0 ? "Tous les achats" : filtres.toString()),
          "Liste des achats fournisseurs");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void imprimerArrivages(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      Partner fournisseur = JPA.find(Partner.class, id(c.get("fournisseur")));
      String numero = texte(c.get("numeroArrivage")).trim().toLowerCase();
      Object nature = c.get("natureFiltre");
      StringBuilder filtres = new StringBuilder();
      ajouter(filtres, fournisseur != null ? "Fournisseur " + fournisseur.getName() : "");
      ajouter(filtres, numero.isEmpty() ? "" : "N° Arrivage " + numero);
      ajouterPeriode(filtres, "Date", c.get("dateDu"), c.get("dateAu"));
      ajouterPeriode(filtres, "Arrivée", c.get("arriveeDu"), c.get("arriveeAu"));
      ouvrir(
          response,
          ReportFactory.createReport("LvmeListeArrivages.rptdesign", "Arrivages-${date}")
              .addParam("Numero", "%" + numero + "%")
              .addParam(
                  "Fournisseur", String.valueOf(fournisseur != null ? fournisseur.getId() : 0L))
              .addParam("DateFiltre", filtre(c.get("dateDu"), c.get("dateAu")))
              .addParam("DateDu", date(c.get("dateDu"), DEBUT))
              .addParam("DateAu", date(c.get("dateAu"), FIN))
              .addParam("ArrFiltre", filtre(c.get("arriveeDu"), c.get("arriveeAu")))
              .addParam("ArrDu", date(c.get("arriveeDu"), DEBUT))
              .addParam("ArrAu", date(c.get("arriveeAu"), FIN))
              .addParam("Nature", nature != null ? nature.toString() : "1")
              .addParam(
                  "Filtres", filtres.length() == 0 ? "Tous les arrivages" : filtres.toString()),
          "Arrivages");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void imprimerRotations(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      Product artDu = JPA.find(Product.class, id(c.get("articleDu")));
      Product artAu = JPA.find(Product.class, id(c.get("articleAu")));
      Partner fouDu = JPA.find(Partner.class, id(c.get("fournisseurDu")));
      Partner fouAu = JPA.find(Partner.class, id(c.get("fournisseurAu")));
      String artDuCode = artDu != null ? artDu.getCode() : "";
      String artAuCode = artAu != null ? artAu.getCode() : artDuCode;
      String fouDuNom = fouDu != null ? fouDu.getFullName() : "";
      String fouAuNom = fouAu != null ? fouAu.getFullName() : fouDuNom;
      String transport = texte(c.get("transport"));
      transport =
          "CAMION".equals(transport) ? "Camion" : "BATEAU".equals(transport) ? "Bateau" : "";
      StringBuilder filtres = new StringBuilder();
      ajouter(filtres, artDuCode.isEmpty() ? "" : "Article " + artDuCode + " à " + artAuCode);
      ajouter(filtres, fouDuNom.isEmpty() ? "" : "Fournisseur " + fouDuNom + " à " + fouAuNom);
      ajouterPeriode(filtres, "Entrée", c.get("entreeDu"), c.get("entreeAu"));
      ajouter(filtres, transport.isEmpty() ? "" : "Transport " + transport);
      ouvrir(
          response,
          ReportFactory.createReport("LvmeListeRotations.rptdesign", "Liste des rotations-${date}")
              .addParam("ArtDu", artDuCode)
              .addParam("ArtAu", artAuCode)
              .addParam("FouDu", fouDuNom)
              .addParam("FouAu", fouAuNom)
              .addParam("Famille", String.valueOf(id(c.get("famille"))))
              .addParam("Frigo", String.valueOf(id(c.get("frigo"))))
              .addParam("Origine", texte(c.get("origine")))
              .addParam("EntreeFiltre", filtre(c.get("entreeDu"), c.get("entreeAu")))
              .addParam("EntreeDu", date(c.get("entreeDu"), DEBUT))
              .addParam("EntreeAu", date(c.get("entreeAu"), FIN))
              .addParam("Transport", transport)
              .addParam("Filtres", filtres.length() == 0 ? "Tous les lots" : filtres.toString()),
          "Liste des Rotations");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  public void imprimerCommandesClients(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      Partner client = JPA.find(Partner.class, id(c.get("client")));
      long commercial = id(c.get("commercialFiltre"));
      String etat = texte(c.get("etatCommande"));
      String alerte = texte(c.get("alerte"));
      String etatTexte =
          "2".equals(etat)
              ? "Commandes soldées"
              : "3".equals(etat)
                  ? "Toutes commandes"
                  : "4".equals(etat) ? "Réservations" : "Commandes en cours";
      StringBuilder filtres = new StringBuilder(alerte.isEmpty() ? etatTexte : "Alerte " + alerte);
      ajouter(filtres, client != null ? "Client " + client.getName() : "");
      ajouterPeriode(filtres, "Date", c.get("dateDu"), c.get("dateAu"));
      ajouterPeriode(filtres, "Livraison", c.get("livraisonDu"), c.get("livraisonAu"));
      ouvrir(
          response,
          ReportFactory.createReport(
                  "LvmeListeCommandesClients.rptdesign", "Liste des commandes clients-${date}")
              .addParam("Alerte", alerte)
              .addParam("Etat", etat.isEmpty() ? "1" : etat)
              .addParam("Client", String.valueOf(client != null ? client.getId() : 0L))
              .addParam("Commercial", String.valueOf(commercial))
              .addParam("DateFiltre", filtre(c.get("dateDu"), c.get("dateAu")))
              .addParam("DateDu", date(c.get("dateDu"), DEBUT))
              .addParam("DateAu", date(c.get("dateAu"), FIN))
              .addParam("LivFiltre", filtre(c.get("livraisonDu"), c.get("livraisonAu")))
              .addParam("LivDu", date(c.get("livraisonDu"), DEBUT))
              .addParam("LivAu", date(c.get("livraisonAu"), FIN))
              .addParam("Filtres", filtres.toString()),
          "Listes Commandes Clients");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /** « Imprimer » de l'écran Historique prix (F1 de la ligne de commande client). */
  public void imprimerHistoriquePrix(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      Partner client = JPA.find(Partner.class, id(c.get("client")));
      Product produit = JPA.find(Product.class, id(c.get("produit")));
      StringBuilder filtres = new StringBuilder();
      ajouter(filtres, client != null ? "Client " + client.getName() : "");
      ajouter(
          filtres,
          produit != null ? "Produit " + produit.getCode() + " " + produit.getName() : "");
      ajouterPeriode(filtres, "Période", c.get("dateDu"), c.get("dateAu"));
      ouvrir(
          response,
          ReportFactory.createReport("LvmeHistoriquePrix.rptdesign", "Historique prix-${date}")
              .addParam("Produit", String.valueOf(produit != null ? produit.getId() : 0L))
              .addParam("Client", String.valueOf(client != null ? client.getId() : 0L))
              .addParam("DateDu", date(c.get("dateDu"), DEBUT))
              .addParam("DateAu", date(c.get("dateAu"), FIN))
              .addParam("Filtres", filtres.length() == 0 ? "Toutes les ventes" : filtres.toString()),
          "Historique prix");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /** « Imprimer » de l'écran État des stocks par lots. */
  public void imprimerEtatStock(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      Product artDu = JPA.find(Product.class, id(c.get("articleDu")));
      Product artAu = JPA.find(Product.class, id(c.get("articleAu")));
      Partner fouDu = JPA.find(Partner.class, id(c.get("fournisseurDu")));
      Partner fouAu = JPA.find(Partner.class, id(c.get("fournisseurAu")));
      String artDuCode = artDu != null ? artDu.getCode() : "";
      String artAuCode = artAu != null ? artAu.getCode() : artDuCode;
      String fouDuNom = fouDu != null ? fouDu.getFullName() : "";
      String fouAuNom = fouAu != null ? fouAu.getFullName() : fouDuNom;
      String lot = texte(c.get("numeroLot")).trim().toLowerCase();
      String etat = texte(c.get("etatLot"));
      etat = etat.isEmpty() ? "1" : etat;
      String dluo = texte(c.get("dluoFiltre"));
      boolean dispoNegatif = Boolean.TRUE.equals(c.get("dispoNegatif"));
      StringBuilder filtres =
          new StringBuilder(
              "2".equals(etat)
                  ? "Lots soldés"
                  : "3".equals(etat)
                      ? "Lots négatifs"
                      : "4".equals(etat)
                          ? "Lots non soldés + négatifs"
                          : "5".equals(etat) ? "Lots archivés" : "Lots non soldés");
      ajouter(filtres, artDuCode.isEmpty() ? "" : "Article " + artDuCode + " à " + artAuCode);
      ajouter(filtres, fouDuNom.isEmpty() ? "" : "Fournisseur " + fouDuNom + " à " + fouAuNom);
      ajouter(filtres, lot.isEmpty() ? "" : "N° Lot " + lot);
      ajouterPeriode(filtres, "Entrée", c.get("entreeDu"), c.get("entreeAu"));
      ajouterPeriode(filtres, "D.D.M.", c.get("ddmDu"), c.get("ddmAu"));
      ajouterPeriode(filtres, "Livraison", c.get("livrDu"), c.get("livrAu"));
      ajouter(
          filtres,
          "1".equals(dluo)
              ? "DLUO dépassées (périmés)"
              : "2".equals(dluo)
                  ? "DLUO dans moins de 30 jours"
                  : "3".equals(dluo) ? "DLUO dépassées + moins de 30 jours" : "");
      ajouter(filtres, dispoNegatif ? "Dispo négatifs" : "");
      Object nature = c.get("natureArrivage");
      ouvrir(
          response,
          ReportFactory.createReport("LvmeEtatStockLots.rptdesign", "Etat des stocks par lots-${date}")
              .addParam("ArtDu", artDuCode)
              .addParam("ArtAu", artAuCode)
              .addParam("FouDu", fouDuNom)
              .addParam("FouAu", fouAuNom)
              .addParam("Famille", String.valueOf(id(c.get("famille"))))
              .addParam("Frigo", String.valueOf(id(c.get("frigo"))))
              .addParam("Origine", texte(c.get("origine")))
              .addParam("Lot", "%" + lot + "%")
              .addParam("EntreeFiltre", filtre(c.get("entreeDu"), c.get("entreeAu")))
              .addParam("EntreeDu", date(c.get("entreeDu"), DEBUT))
              .addParam("EntreeAu", date(c.get("entreeAu"), FIN))
              .addParam("DdmFiltre", filtre(c.get("ddmDu"), c.get("ddmAu")))
              .addParam("DdmDu", date(c.get("ddmDu"), DEBUT))
              .addParam("DdmAu", date(c.get("ddmAu"), FIN))
              .addParam("LivrFiltre", filtre(c.get("livrDu"), c.get("livrAu")))
              .addParam("LivrDu", date(c.get("livrDu"), DEBUT))
              .addParam("LivrAu", date(c.get("livrAu"), FIN))
              .addParam("Nature", nature != null ? nature.toString() : "0")
              .addParam("Etat", etat)
              .addParam("DispoNeg", dispoNegatif ? "1" : "0")
              .addParam("Dluo", dluo.isEmpty() ? "0" : dluo)
              .addParam("Filtres", filtres.toString()),
          "État des stocks par lots");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /** « Synthèse » de l'écran Synthèse des Arrivages. */
  public void imprimerSyntheseArrivages(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      String numDu = texte(c.get("arrivageDu")).trim();
      String numAu = texte(c.get("arrivageAu")).trim();
      StringBuilder filtres = new StringBuilder();
      ajouter(
          filtres,
          numDu.isEmpty() && numAu.isEmpty()
              ? ""
              : "Arrivage N° du " + (numDu.isEmpty() ? "…" : numDu) + " au "
                  + (numAu.isEmpty() ? "…" : numAu));
      ajouterPeriode(filtres, "Arrivée", c.get("arriveeDu"), c.get("arriveeAu"));
      ouvrir(
          response,
          ReportFactory.createReport(
                  "LvmeSyntheseArrivages.rptdesign", "Synthese des arrivages-${date}")
              .addParam("NumDu", numDu)
              .addParam("NumAu", numAu.isEmpty() ? "zzzzzzzzzzzz" : numAu)
              .addParam("Du", date(c.get("arriveeDu"), DEBUT))
              .addParam("Au", date(c.get("arriveeAu"), FIN))
              .addParam("Filtres", filtres.length() == 0 ? "Tous les arrivages" : filtres.toString()),
          "Synthèse des Arrivages");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  private static void ouvrir(ActionResponse response, ReportSettings rapport, String titre)
      throws Exception {
    String lien =
        rapport
            .addParam("__locale", ReportSettings.getPrintingLocale(null))
            .addFormat("pdf")
            .generate()
            .getFileLink();
    response.setView(ActionView.define(titre).add("html", lien).map());
  }

  /** id d'un champ many-to-one du contexte (Map avec « id ») ; 0 si vide. */
  private static long id(Object valeur) {
    if (valeur instanceof Map && ((Map<?, ?>) valeur).get("id") != null) {
      return Long.parseLong(((Map<?, ?>) valeur).get("id").toString());
    }
    return 0L;
  }

  private static String texte(Object valeur) {
    return valeur == null ? "" : valeur.toString();
  }

  private static String date(Object valeur, String defaut) {
    return valeur == null || valeur.toString().length() < 10
        ? defaut
        : valeur.toString().substring(0, 10);
  }

  private static String filtre(Object du, Object au) {
    return du != null || au != null ? "1" : "0";
  }

  private static void ajouter(StringBuilder filtres, String texte) {
    if (!texte.isEmpty()) {
      filtres.append(filtres.length() == 0 ? "" : " — ").append(texte);
    }
  }

  private static void ajouterPeriode(StringBuilder filtres, String libelle, Object du, Object au) {
    if (du != null || au != null) {
      ajouter(filtres, libelle + " du " + jour(du) + " au " + jour(au));
    }
  }

  private static String jour(Object valeur) {
    String d = date(valeur, "");
    return d.isEmpty()
        ? "…"
        : d.substring(8, 10) + "/" + d.substring(5, 7) + "/" + d.substring(0, 4);
  }
}

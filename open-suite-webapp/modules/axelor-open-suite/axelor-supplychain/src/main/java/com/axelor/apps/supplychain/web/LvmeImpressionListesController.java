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
 * clients, historique prix, état des stocks par lots, RFA par produit / facture), « Synthèse »
 * (synthèse des arrivages), « Editer » (arrivages), « Liste des Rotations » (rotation des stocks
 * par lot). Chaque impression reprend les filtres de l'écran (mêmes règles que la liste affichée) ;
 * modèles LvmeListeAchats / LvmeListeCommandesClients / LvmeListeArrivages / LvmeListeRotations /
 * LvmeHistoriquePrix / LvmeEtatStockLots / LvmeSyntheseArrivages / LvmeListeRfa /
 * LvmePalmaresClientsProduits / LvmeEtatBesoins.rptdesign.
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
          filtres, produit != null ? "Produit " + produit.getCode() + " " + produit.getName() : "");
      ajouterPeriode(filtres, "Période", c.get("dateDu"), c.get("dateAu"));
      ouvrir(
          response,
          ReportFactory.createReport("LvmeHistoriquePrix.rptdesign", "Historique prix-${date}")
              .addParam("Produit", String.valueOf(produit != null ? produit.getId() : 0L))
              .addParam("Client", String.valueOf(client != null ? client.getId() : 0L))
              .addParam("DateDu", date(c.get("dateDu"), DEBUT))
              .addParam("DateAu", date(c.get("dateAu"), FIN))
              .addParam(
                  "Filtres", filtres.length() == 0 ? "Toutes les ventes" : filtres.toString()),
          "Historique prix");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /** « Etat des Stocks » de l'écran État des stocks par lots : une ligne par lot. */
  public void imprimerEtatStock(ActionRequest request, ActionResponse response) {
    imprimerEtatStock(
        request,
        response,
        "LvmeEtatStockLots.rptdesign",
        "Etat des stocks par lots-${date}",
        "État des stocks par lots");
  }

  /** « Etat des Stocks / Fournisseur » : les lots regroupés par fournisseur, sous-totaux. */
  public void imprimerEtatStockFournisseur(ActionRequest request, ActionResponse response) {
    imprimerEtatStock(
        request,
        response,
        "LvmeEtatStockFournisseur.rptdesign",
        "Etat des stocks par fournisseur-${date}",
        "État des stocks par fournisseur");
  }

  /** « Etat des Stocks sur une ligne » : une ligne par article. */
  public void imprimerEtatStockLigne(ActionRequest request, ActionResponse response) {
    imprimerEtatStock(
        request,
        response,
        "LvmeEtatStockLigne.rptdesign",
        "Etat des stocks sur une ligne-${date}",
        "État des stocks sur une ligne");
  }

  /** Impressions de l'État des stocks par lots, avec les filtres de l'écran. */
  private void imprimerEtatStock(
      ActionRequest request, ActionResponse response, String modele, String fichier, String titre) {
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
          ReportFactory.createReport(modele, fichier)
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
          titre);
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
              : "Arrivage N° du "
                  + (numDu.isEmpty() ? "…" : numDu)
                  + " au "
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
              .addParam(
                  "Filtres", filtres.length() == 0 ? "Tous les arrivages" : filtres.toString()),
          "Synthèse des Arrivages");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /** « Imprimer » de l'écran Liste des RFA par produit / facture. */
  public void imprimerRfa(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      StringBuilder filtres = new StringBuilder();
      ajouterPeriode(filtres, "Factures", c.get("factureDu"), c.get("factureAu"));
      ouvrir(
          response,
          ReportFactory.createReport("LvmeListeRfa.rptdesign", "Liste des RFA-${date}")
              .addParam("Du", date(c.get("factureDu"), DEBUT))
              .addParam("Au", date(c.get("factureAu"), FIN))
              .addParam(
                  "Filtres", filtres.length() == 0 ? "Toutes les factures" : filtres.toString()),
          "Liste des RFA par produit / facture");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /**
   * « Valider » de l'écran Palmarès Client / Produits par tonnage : impression « Palmarès Clients
   * par Produits », avec la phrase des filtres de GESCOM (« Pour le client … pour toutes les
   * familles … »).
   */
  public void imprimerPalmaresClients(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      ouvrir(
          response,
          filtresClientsProduits(
                  ReportFactory.createReport(
                      "LvmePalmaresClientsProduits.rptdesign",
                      "Palmares clients par produits-${date}"),
                  c)
              .addParam("Du", date(c.get("dateDu"), DEBUT))
              .addParam("Au", date(c.get("dateAu"), FIN)),
          "Palmarès Clients par Produits");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /**
   * « Valider » de l'écran État des besoins : impression « Aides aux Réapprovisionnements » de
   * GESCOM (Année N, Année N-1 pour le % d'évolution, Année N-1 période réappro), mêmes filtres
   * client / produit que le Palmarès.
   */
  public void imprimerEtatBesoins(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      String periodes =
          "Année N : Du "
              + jour(c.get("dateDu"))
              + " au "
              + jour(c.get("dateAu"))
              + "     Année N-1 : Du "
              + jour(c.get("dateDuN1"))
              + " au "
              + jour(c.get("dateAuN1"))
              + "     Année N-1 période Réappro : du "
              + jour(c.get("dateDuReappro"))
              + " au "
              + jour(c.get("dateAuReappro"));
      ouvrir(
          response,
          filtresClientsProduits(
                  ReportFactory.createReport(
                      "LvmeEtatBesoins.rptdesign", "Etat des besoins-${date}"),
                  c)
              .addParam("NDu", date(c.get("dateDu"), DEBUT))
              .addParam("NAu", date(c.get("dateAu"), FIN))
              .addParam("NunDu", date(c.get("dateDuN1"), DEBUT))
              .addParam("NunAu", date(c.get("dateAuN1"), DEBUT))
              .addParam("RDu", date(c.get("dateDuReappro"), DEBUT))
              .addParam("RAu", date(c.get("dateAuReappro"), DEBUT))
              .addParam("Periodes", periodes),
          "Aides aux Réapprovisionnements");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /** « Imprimer » de l'écran Prix négociés (PRIX_NEGOC de GESCOM) : par client, filtres de l'écran. */
  public void imprimerPrixNegocies(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      Partner client = JPA.find(Partner.class, id(c.get("client")));
      Product produit = JPA.find(Product.class, id(c.get("produit")));
      boolean enVigueur = Boolean.TRUE.equals(c.get("enVigueur"));
      String dateVigueur = date(c.get("dateVigueur"), java.time.LocalDate.now().toString());
      StringBuilder filtres = new StringBuilder();
      ajouter(filtres, client != null ? "Client " + client.getName() : "Tous les clients");
      ajouter(filtres, produit != null ? "Produit " + produit.getCode() : "");
      ajouter(filtres, enVigueur ? "Prix en vigueur le " + jour(dateVigueur) : "");
      ajouterPeriode(filtres, "Période étudiée", c.get("statsDu"), c.get("statsAu"));
      ouvrir(
          response,
          ReportFactory.createReport("LvmePrixNegocies.rptdesign", "Prix negocies-${date}")
              .addParam("Client", String.valueOf(client != null ? client.getId() : 0L))
              .addParam("Produit", String.valueOf(produit != null ? produit.getId() : 0L))
              .addParam("Vigueur", enVigueur ? "1" : "0")
              .addParam("DateVigueur", dateVigueur)
              .addParam("StatsFiltre", filtre(c.get("statsDu"), c.get("statsAu")))
              .addParam("StatsDu", date(c.get("statsDu"), DEBUT))
              .addParam("StatsAu", date(c.get("statsAu"), FIN))
              .addParam("Filtres", filtres.toString()),
          "Prix négociés");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  /**
   * Filtres client / produit des écrans Palmarès et État des besoins (paramètres du rapport et
   * phrase de GESCOM « Pour le client … pour toutes les familles … »).
   */
  private static ReportSettings filtresClientsProduits(
      ReportSettings rapport, Map<String, Object> c) {
    Partner client = JPA.find(Partner.class, id(c.get("client")));
    Product produit = JPA.find(Product.class, id(c.get("produit")));
    Partner fournisseur = JPA.find(Partner.class, id(c.get("fournisseur")));
    com.axelor.auth.db.User comDu =
        JPA.find(com.axelor.auth.db.User.class, id(c.get("commercialDu")));
    com.axelor.auth.db.User comAu =
        JPA.find(com.axelor.auth.db.User.class, id(c.get("commercialAu")));
    com.axelor.apps.purchase.db.Conditionnement cond =
        JPA.find(com.axelor.apps.purchase.db.Conditionnement.class, id(c.get("conditionnement")));
    String comDuCode = comDu != null ? comDu.getCode() : "";
    String comAuCode = comAu != null ? comAu.getCode() : comDuCode;
    String origine = texte(c.get("origine")).trim();
    String filtres =
        String.join(
            " ",
            client != null ? "Pour le client " + client.getName() : "Pour tous les clients",
            nomOuTous(
                c.get("familleClient"),
                "pour la famille clients ",
                "pour toutes les familles clients"),
            comDu != null
                ? "pour les commerciaux de "
                    + comDu.getName()
                    + " à "
                    + (comAu != null ? comAu.getName() : comDu.getName())
                : "pour tous les commerciaux",
            nomOuTous(c.get("groupement"), "pour le groupement ", "pour tous les groupements"),
            nomOuTous(c.get("pays"), "pour le pays ", "pour tous les pays"),
            produit != null ? "pour le produit " + produit.getCode() : "pour tous les produits",
            nomOuTous(
                c.get("familleProduit"),
                "pour la famille produits ",
                "pour toutes les familles produits"),
            fournisseur != null
                ? "pour le fournisseur " + fournisseur.getName()
                : "pour tous les fournisseurs",
            origine.isEmpty() ? "" : "origine " + origine,
            cond != null ? "conditionnement " + cond.getCode() : "",
            "sur le Tonnage");
    return rapport
        .addParam("Client", String.valueOf(client != null ? client.getId() : 0L))
        .addParam("FamilleClient", String.valueOf(id(c.get("familleClient"))))
        .addParam("ComDu", comDuCode)
        .addParam("ComAu", comAuCode)
        .addParam("Pays", String.valueOf(id(c.get("pays"))))
        .addParam("Groupement", String.valueOf(id(c.get("groupement"))))
        .addParam("Produit", String.valueOf(produit != null ? produit.getId() : 0L))
        .addParam("FamilleProduit", String.valueOf(id(c.get("familleProduit"))))
        .addParam("Fournisseur", String.valueOf(fournisseur != null ? fournisseur.getId() : 0L))
        .addParam("Origine", origine)
        .addParam("Conditionnement", cond != null ? cond.getCode() : "")
        .addParam("Filtres", filtres.replaceAll("\\s+", " ").trim());
  }

  /**
   * Nom d'un choix many-to-one du contexte (Map avec « name ») précédé de son libellé, sinon « tous
   * ».
   */
  private static String nomOuTous(Object valeur, String libelle, String tous) {
    if (valeur instanceof Map && ((Map<?, ?>) valeur).get("name") != null) {
      return libelle + ((Map<?, ?>) valeur).get("name");
    }
    return valeur instanceof Map && ((Map<?, ?>) valeur).get("id") != null ? libelle.trim() : tous;
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

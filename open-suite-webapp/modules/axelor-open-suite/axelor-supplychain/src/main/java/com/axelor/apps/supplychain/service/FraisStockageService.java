package com.axelor.apps.supplychain.service;

import com.axelor.apps.base.db.Company;
import com.axelor.apps.purchase.db.PurchaseOrderLine;
import com.axelor.apps.purchase.db.repo.PurchaseOrderLineRepository;
import com.axelor.apps.sale.db.SaleOrderLine;
import com.axelor.apps.sale.db.repo.SaleOrderLineRepository;
import com.axelor.apps.stock.db.CessionStock;
import com.axelor.apps.stock.db.StockMoveLine;
import com.axelor.apps.stock.db.TrackingNumber;
import com.axelor.apps.stock.db.repo.CessionStockRepository;
import com.axelor.apps.stock.db.repo.StockMoveLineRepository;
import com.axelor.apps.stock.db.repo.TrackingNumberRepository;
import com.google.inject.Inject;
import com.google.inject.persist.Transactional;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;

/**
 * Service LVME - UC-17 Application des frais de stockage/congélation.
 *
 * <p>Appelé depuis le bouton "Appliquer le recalcul" sur une Cession de type FRAIS_STOCKAGE.
 *
 * <p>Le taux appliqué est celui saisi sur la cession (prKg). Company.fraisCongelation est mis à
 * jour par le service pour rester cohérent : ne pas le saisir manuellement.
 *
 * <p>Formule PR Net (spec N7) : prixRevientNet = (PR + Frais Congélation) × (1 + (RFA + Commission)
 * / 100)
 */
public class FraisStockageService {

  /** Échelle imposée par le domaine (precision 20, scale 4). */
  protected static final int SCALE = 4;

  @Inject protected TrackingNumberRepository trackingRepo;
  @Inject protected SaleOrderLineRepository saleOrderLineRepo;
  @Inject protected CessionStockRepository cessionRepo;
  @Inject protected StockMoveLineRepository stockMoveLineRepo;
  @Inject protected PurchaseOrderLineRepository purchaseOrderLineRepo;

  /**
   * Applique le recalcul des PR pour une Cession type FRAIS_STOCKAGE.
   *
   * @param cession la cession à appliquer
   * @return message de résultat
   */
  @Transactional
  public String appliquerCession(CessionStock cession) {
    if (cession == null || cession.getId() == null) {
      return "Cession introuvable.";
    }

    // Recharger la cession depuis la BD (évite les proxies ByteBuddy)
    cession = cessionRepo.find(cession.getId());
    if (cession == null) {
      return "Cession introuvable en base.";
    }

    if (Boolean.TRUE.equals(cession.getCessionRealisee())) {
      return "Cette cession a déjà été appliquée le " + cession.getDateRealisation() + ".";
    }

    BigDecimal nouveauTaux = cession.getPrKg();
    if (nouveauTaux == null || nouveauTaux.compareTo(BigDecimal.ZERO) == 0) {
      return "Veuillez saisir un taux à appliquer.";
    }
    // Normalisation : évite les violations @Digits en cascade
    nouveauTaux = nouveauTaux.setScale(SCALE, RoundingMode.HALF_UP);

    LocalDate today = LocalDate.now();

    // Aligner Company sur le taux appliqué
    Company company = cession.getCompany();
    if (company != null) {
      company.setFraisCongelation(nouveauTaux);
    }

    // 1. Mettre à jour la cession
    cession.setPrKg(nouveauTaux);
    cession.setCessionRealisee(true);
    cession.setDateRealisation(today);

    // 2. Recalculer TrackingNumbers (lots)
    // 2a. Recalculer TrackingNumbers
    // 2. Recalculer TrackingNumbers + propager sur StockMoveLine
    List<TrackingNumber> lots = trackingRepo.all().fetch();
    int nbLots = 0;
    for (TrackingNumber lot : lots) {
      BigDecimal prBase = BigDecimal.ZERO;
      if (lot.getOriginStockMoveLine() != null && lot.getOriginStockMoveLine().getPrKg() != null) {
        prBase = lot.getOriginStockMoveLine().getPrKg();
      }

      BigDecimal prixRevientReel = prBase.add(nouveauTaux);

      // Mettre à jour le lot (TrackingNumber)
      lot.setPrixRevientReel(prixRevientReel);
      trackingRepo.save(lot);

      // Propager sur la StockMoveLine d'origine
      if (lot.getOriginStockMoveLine() != null) {
        lot.getOriginStockMoveLine().setPrixRevientReel(prixRevientReel);
      }

      nbLots++;
    }

    // 2b. Recalculer TOUTES les StockMoveLines avec prKg > 0
    List<StockMoveLine> smls = stockMoveLineRepo.all().filter("self.prKg > 0").fetch();
    int nbSMLs = 0;
    for (StockMoveLine sml : smls) {
      BigDecimal prBase = sml.getPrKg() != null ? sml.getPrKg() : BigDecimal.ZERO;
      BigDecimal prixReel = prBase.add(nouveauTaux);
      sml.setPrixRevientReel(prixReel);

      // Calculer montant réel = qty × prixRevientReel
      BigDecimal qty = sml.getQty() != null ? sml.getQty() : BigDecimal.ZERO;
      sml.setMontantReel(qty.multiply(prixReel).setScale(4, RoundingMode.HALF_UP));

      stockMoveLineRepo.save(sml);
      nbSMLs++;
    }

    // 2c. Recalculer TOUTES les PurchaseOrderLines avec prKg > 0
    List<PurchaseOrderLine> pols = purchaseOrderLineRepo.all().filter("self.prKg > 0").fetch();
    int nbPOLs = 0;

    for (PurchaseOrderLine pol : pols) {
      BigDecimal prBase = pol.getPrKg() != null ? pol.getPrKg() : BigDecimal.ZERO;
      BigDecimal prixReel = prBase.add(nouveauTaux);
      pol.setPrixRevientReel(prixReel);

      // Calculer montant réel = qty × prixRevientReel
      BigDecimal qty = pol.getQty() != null ? pol.getQty() : BigDecimal.ZERO;
      pol.setMontantReel(qty.multiply(prixReel).setScale(4, RoundingMode.HALF_UP));

      purchaseOrderLineRepo.save(pol);
      nbPOLs++;
    }

    // 3. Recalculer SaleOrderLines
    List<SaleOrderLine> lines = saleOrderLineRepo.all().fetch();
    int nbLines = 0;
    for (SaleOrderLine line : lines) {
      line.setFraisCongelation(nouveauTaux);

      BigDecimal pr = line.getPrice() != null ? line.getPrice() : BigDecimal.ZERO;
      BigDecimal tauxRFA = line.getTauxRFA() != null ? line.getTauxRFA() : BigDecimal.ZERO;
      BigDecimal tauxCom =
          line.getTauxCommission() != null ? line.getTauxCommission() : BigDecimal.ZERO;

      BigDecimal coeff =
          BigDecimal.ONE.add(
              tauxRFA.add(tauxCom).divide(new BigDecimal("100"), 6, RoundingMode.HALF_UP));
      BigDecimal prNet = pr.add(nouveauTaux).multiply(coeff).setScale(SCALE, RoundingMode.HALF_UP);

      line.setPrixRevientNet(prNet);
      saleOrderLineRepo.save(line);
      nbLines++;
    }

    // 4. Sauvegarder la cession
    cessionRepo.save(cession);

    return "Recalcul appliqué : "
        + nbLots
        + " lot(s), "
        + nbSMLs
        + " ligne(s) d'arrivage, "
        + nbPOLs
        + " ligne(s) de commande d'achat, "
        + nbLines
        + " ligne(s) de vente recalculés (taux : "
        + nouveauTaux
        + " €/kg)";
  }
}

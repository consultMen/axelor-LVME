package com.axelor.apps.supplychain.service;

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
import java.time.LocalDate;
import java.util.List;

/**
 * Service LVME - UC-16 Type 2 MODIF_PR Modification du prix de revient d'un lot spécifique. Spec :
 * STK-040 - "La modification de prix d'achat est tracée comme un type de mouvement de cession de
 * stock dédié."
 */
public class ModifPRService {

  @Inject protected TrackingNumberRepository trackingRepo;
  @Inject protected StockMoveLineRepository stockMoveLineRepo;
  @Inject protected SaleOrderLineRepository saleOrderLineRepo;
  @Inject protected CessionStockRepository cessionRepo;

  /** Applique la modification de PR sur le lot sélectionné. */
  @Transactional
  public String appliquerModifPR(CessionStock cession) {
    if (cession == null || cession.getId() == null) {
      return "Cession introuvable.";
    }

    // Recharger la cession depuis la BD (évite les proxies ByteBuddy)
    cession = cessionRepo.find(cession.getId());
    if (cession == null) {
      return "Cession introuvable en base.";
    }

    // Vérifications
    TrackingNumber lot = cession.getLotSource();
    if (lot == null) {
      return "Veuillez sélectionner un lot.";
    }

    BigDecimal nouveauPR = cession.getPrKg();
    if (nouveauPR == null || nouveauPR.compareTo(BigDecimal.ZERO) <= 0) {
      return "Veuillez saisir un nouveau PR valide (> 0).";
    }

    if (cession.getMotif() == null || cession.getMotif().trim().isEmpty()) {
      return "Le motif de la modification est obligatoire.";
    }

    // Récupérer l'ancien PR pour trace
    BigDecimal ancienPR =
        lot.getPrixRevientReel() != null ? lot.getPrixRevientReel() : BigDecimal.ZERO;

    // 1. Modifier le lot (TrackingNumber)
    lot.setPrixRevientReel(nouveauPR);
    trackingRepo.save(lot);

    // 2. Modifier la StockMoveLine d'origine (prKg + prixRevientReel)
    if (lot.getOriginStockMoveLine() != null) {
      lot.getOriginStockMoveLine().setPrKg(nouveauPR);
      lot.getOriginStockMoveLine().setPrixRevientReel(nouveauPR);
    }

    // 3. Modifier toutes les StockMoveLines liées à ce lot
    List<StockMoveLine> smls =
        stockMoveLineRepo.all().filter("self.trackingNumber = ?", lot).fetch();
    for (StockMoveLine sml : smls) {
      sml.setPrKg(nouveauPR);
      sml.setPrixRevientReel(nouveauPR);
      stockMoveLineRepo.save(sml);
    }

    // 4. Marquer la cession réalisée + trace
    cession.setAncienPR(ancienPR);
    cession.setCessionRealisee(true);
    cession.setDateRealisation(LocalDate.now());

    cessionRepo.save(cession);

    return "Modification PR appliquée : "
        + lot.getTrackingNumberSeq()
        + " - Ancien PR = "
        + ancienPR
        + " → Nouveau PR = "
        + nouveauPR
        + " €/kg"
        + " ("
        + smls.size()
        + " ligne(s) d'arrivage mise(s) à jour)";
  }

  /** Charge le PR actuel du lot dans le champ ancienPR (auto-remplissage). */
  public BigDecimal getAncienPRFromLot(TrackingNumber lot) {
    if (lot == null || lot.getId() == null) {
      return BigDecimal.ZERO;
    }
    TrackingNumber lotDB = trackingRepo.find(lot.getId());
    if (lotDB == null) {
      return BigDecimal.ZERO;
    }
    return lotDB.getPrixRevientReel() != null ? lotDB.getPrixRevientReel() : BigDecimal.ZERO;
  }
}

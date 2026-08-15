package com.axelor.apps.supplychain.service;

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
 * Service LVME - UC-16 Type 2 MODIF_PR Spec STK-040 : modification de prix d'achat tracée comme
 * cession dédiée.
 */
public class ModifPRService {

  @Inject protected TrackingNumberRepository trackingRepo;
  @Inject protected StockMoveLineRepository stockMoveLineRepo;
  @Inject protected CessionStockRepository cessionRepo;

  /** Applique la modification de prKg pour le lot sélectionné. */
  @Transactional
  public String appliquerModifPR(CessionStock cession) {
    if (cession == null || cession.getId() == null) {
      return "Cession introuvable.";
    }

    // Recharger la cession depuis la BD (évite proxy ByteBuddy)
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

    // Recharger le lot depuis la BD
    lot = trackingRepo.find(lot.getId());
    BigDecimal ancienPR = BigDecimal.ZERO;
    if (lot.getOriginStockMoveLine() != null && lot.getOriginStockMoveLine().getPrKg() != null) {
      ancienPR = lot.getOriginStockMoveLine().getPrKg();
    }

    // 1. Modifier toutes les StockMoveLines liées à ce lot
    List<StockMoveLine> smls =
        stockMoveLineRepo.all().filter("self.trackingNumber = ?", lot).fetch();
    for (StockMoveLine sml : smls) {
      sml.setPrKg(nouveauPR);
      sml.setPrixRevientReel(nouveauPR);
      stockMoveLineRepo.save(sml);
    }

    // 2. Modifier le lot (TrackingNumber.prixRevientReel)
    lot.setPrixRevientReel(nouveauPR);
    trackingRepo.save(lot);

    // 3. Marquer la cession réalisée + trace
    cession.setAncienPR(ancienPR.setScale(4, java.math.RoundingMode.HALF_UP));
    cession.setCessionRealisee(true);
    cession.setDateRealisation(LocalDate.now());
    cessionRepo.save(cession);

    return "Modification PR appliquée : lot "
        + lot.getTrackingNumberSeq()
        + " (ancien PR : "
        + ancienPR
        + " → nouveau PR : "
        + nouveauPR
        + " €/kg, "
        + smls.size()
        + " ligne(s) mise(s) à jour)";
  }

  /** Charge l'ancien PR depuis le lot (pour auto-remplissage). */
  public BigDecimal getAncienPRFromLot(TrackingNumber lot) {
    if (lot == null || lot.getId() == null) {
      return BigDecimal.ZERO;
    }
    TrackingNumber lotDB = trackingRepo.find(lot.getId());
    if (lotDB == null) {
      return BigDecimal.ZERO;
    }
    // On prend le prKg de la StockMoveLine d'origine
    if (lotDB.getOriginStockMoveLine() != null
        && lotDB.getOriginStockMoveLine().getPrKg() != null) {
      return lotDB.getOriginStockMoveLine().getPrKg();
    }
    return BigDecimal.ZERO;
  }
}

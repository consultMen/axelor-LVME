package com.axelor.apps.stock.web;

import com.axelor.apps.base.db.Product;
import com.axelor.apps.stock.db.CessionStock;
import com.axelor.apps.stock.db.StockLocationLine;
import com.axelor.apps.stock.db.StockMoveLine;
import com.axelor.apps.stock.db.TrackingNumber;
import com.axelor.apps.stock.db.repo.CessionStockRepository;
import com.axelor.apps.stock.db.repo.StockLocationLineRepository;
import com.axelor.apps.stock.db.repo.StockMoveLineRepository;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.google.inject.Singleton;
import com.google.inject.persist.Transactional;
import java.lang.reflect.Method;
import java.math.BigDecimal;
import java.time.LocalDate;

@Singleton
public class CessionStockController {

  public void loadFromProduct(ActionRequest request, ActionResponse response) {
    try {
      CessionStock cession = request.getContext().asType(CessionStock.class);
      Product product = cession.getProduct();

      if (product == null) {
        return;
      }

      StockMoveLineRepository smlRepo = Beans.get(StockMoveLineRepository.class);
      StockMoveLine lastReception =
          smlRepo
              .all()
              .filter(
                  "self.product = :product "
                      + "AND self.stockMove.typeSelect = 3 "
                      + "AND self.stockMove.statusSelect = 3")
              .bind("product", product)
              .order("-stockMove.realDate")
              .fetchOne();

      if (lastReception == null) {
        response.setNotify("Aucune réception fournisseur réalisée trouvée pour ce produit.");
        return;
      }

      response.setValue("articleCode", product.getCode());
      response.setValue("designation", product.getName());

      if (lastReception.getTrackingNumber() != null) {
        response.setValue("lotSource", lastReception.getTrackingNumber());
        response.setValue("dluo", lastReception.getTrackingNumber().getPerishableExpirationDate());
      }

      response.setValue("uniteVente", lastReception.getUnit());
      response.setValue("prixRevient", lastReception.getUnitPriceUntaxed());
      response.setValue("paKg", lastReception.getPaDevise());
      response.setValue("prKg", lastReception.getPrKg());
      response.setValue("origine", lastReception.getOrigine());
      response.setValue("marque", lastReception.getMarque());
      response.setValue("zonePeche", lastReception.getZonePeche());
      response.setValue("nbColis", lastReception.getNbColis());
      response.setValue("pdsColis", lastReception.getPoidsParColis());
      response.setValue("dateCongelation", lastReception.getDateCongelation());

      String conditionnement = getConditionnementViaReflection(lastReception);
      if (conditionnement != null) {
        response.setValue("conditionnement", conditionnement);
      }

      if (lastReception.getStockMove() != null) {
        response.setValue("frigo", lastReception.getStockMove().getToStockLocation());
      }

    } catch (Exception e) {
      response.setException(e);
    }
  }

  @Transactional
  public void executeSplit(ActionRequest request, ActionResponse response) {
    try {
      CessionStock cession = request.getContext().asType(CessionStock.class);
      CessionStockRepository cessionRepo = Beans.get(CessionStockRepository.class);
      StockLocationLineRepository sllRepo = Beans.get(StockLocationLineRepository.class);

      cession = cessionRepo.find(cession.getId());

      if (Boolean.TRUE.equals(cession.getCessionRealisee())) {
        response.setError("Cette cession a déjà été réalisée.");
        return;
      }
      if (cession.getPoidsKg() == null || cession.getPoidsKg().compareTo(BigDecimal.ZERO) <= 0) {
        response.setError("Veuillez saisir une quantité valide (> 0).");
        return;
      }
      if (cession.getLotSource() == null) {
        response.setError("Veuillez sélectionner un lot source.");
        return;
      }
      if (cession.getNouveauLot() == null) {
        response.setError("Veuillez choisir un lot destination.");
        return;
      }
      if (cession.getFrigo() == null) {
        response.setError("Frigo non défini.");
        return;
      }
      if (cession.getLotSource().getId().equals(cession.getNouveauLot().getId())) {
        response.setError("Le lot source et le lot destination doivent être différents.");
        return;
      }

      TrackingNumber lotSource = cession.getLotSource();
      TrackingNumber lotDestination = cession.getNouveauLot();

      StockLocationLine sourceLine =
          sllRepo
              .all()
              .filter("self.trackingNumber = :tn AND self.detailsStockLocation = :loc")
              .bind("tn", lotSource)
              .bind("loc", cession.getFrigo())
              .fetchOne();

      if (sourceLine == null || sourceLine.getCurrentQty() == null) {
        response.setError(
            "Aucun stock trouvé pour le lot source "
                + lotSource.getTrackingNumberSeq()
                + " dans le frigo "
                + cession.getFrigo().getName());
        return;
      }

      BigDecimal qtyDispo = sourceLine.getCurrentQty();
      if (cession.getPoidsKg().compareTo(qtyDispo) > 0) {
        response.setError(
            "Quantité demandée ("
                + cession.getPoidsKg()
                + ") supérieure au stock disponible ("
                + qtyDispo
                + ")");
        return;
      }

      sourceLine.setCurrentQty(qtyDispo.subtract(cession.getPoidsKg()));
      sllRepo.save(sourceLine);

      StockLocationLine destLine =
          sllRepo
              .all()
              .filter("self.trackingNumber = :tn AND self.detailsStockLocation = :loc")
              .bind("tn", lotDestination)
              .bind("loc", cession.getFrigo())
              .fetchOne();

      if (destLine != null) {
        BigDecimal qtyActuelle =
            destLine.getCurrentQty() != null ? destLine.getCurrentQty() : BigDecimal.ZERO;
        destLine.setCurrentQty(qtyActuelle.add(cession.getPoidsKg()));
      } else {
        destLine = new StockLocationLine();
        destLine.setProduct(cession.getProduct());
        destLine.setTrackingNumber(lotDestination);
        destLine.setDetailsStockLocation(cession.getFrigo());
        destLine.setCurrentQty(cession.getPoidsKg());
      }
      sllRepo.save(destLine);

      cession.setCessionRealisee(true);
      cession.setDateRealisation(LocalDate.now());
      cessionRepo.save(cession);

      response.setReload(true);
      response.setNotify(
          "Cession réalisée : "
              + cession.getPoidsKg()
              + " prélevés du lot "
              + lotSource.getTrackingNumberSeq()
              + " → ajoutés au lot "
              + lotDestination.getTrackingNumberSeq());

    } catch (Exception e) {
      response.setException(e);
    }
  }

  public void computeCalculs(ActionRequest request, ActionResponse response) {
    try {
      CessionStock cession = request.getContext().asType(CessionStock.class);

      BigDecimal nbColis = cession.getNbColis();
      BigDecimal pdsColis = cession.getPdsColis();
      BigDecimal prKg = cession.getPrKg();

      BigDecimal pdsTotal = BigDecimal.ZERO;
      if (nbColis != null && pdsColis != null) {
        pdsTotal = nbColis.multiply(pdsColis).setScale(3, java.math.RoundingMode.HALF_UP);
      }
      response.setValue("pdsTotal", pdsTotal);

      if (prKg != null) {
        BigDecimal montantHT = pdsTotal.multiply(prKg).setScale(2, java.math.RoundingMode.HALF_UP);
        response.setValue("montantHT", montantHT);
      }

    } catch (Exception e) {
      response.setException(e);
    }
  }

  private String getConditionnementViaReflection(StockMoveLine line) {
    try {
      Method getPurchaseOrderLine = line.getClass().getMethod("getPurchaseOrderLine");
      Object purchaseOrderLine = getPurchaseOrderLine.invoke(line);
      if (purchaseOrderLine == null) {
        return null;
      }
      Method getConditionnement = purchaseOrderLine.getClass().getMethod("getConditionnement");
      Object conditionnement = getConditionnement.invoke(purchaseOrderLine);
      if (conditionnement == null) {
        return null;
      }
      try {
        Method getLabel = conditionnement.getClass().getMethod("getLabel");
        Object label = getLabel.invoke(conditionnement);
        if (label != null && !label.toString().isEmpty()) {
          return label.toString();
        }
      } catch (NoSuchMethodException ignore) {
      }
      try {
        Method getName = conditionnement.getClass().getMethod("getName");
        Object name = getName.invoke(conditionnement);
        if (name != null && !name.toString().isEmpty()) {
          return name.toString();
        }
      } catch (NoSuchMethodException ignore) {
      }
      try {
        Method getCode = conditionnement.getClass().getMethod("getCode");
        Object code = getCode.invoke(conditionnement);
        if (code != null) {
          return code.toString();
        }
      } catch (NoSuchMethodException ignore) {
      }
      return null;
    } catch (NoSuchMethodException e) {
      return null;
    } catch (Exception e) {
      return null;
    }
  }

  public void computeDest(ActionRequest request, ActionResponse response) {
    try {
      CessionStock cession = request.getContext().asType(CessionStock.class);

      BigDecimal nbColisDest = cession.getNbColisDest();
      BigDecimal pdsColisDest = cession.getPdsColisDest();

      BigDecimal pdsTotalDest = BigDecimal.ZERO;
      if (nbColisDest != null && pdsColisDest != null) {
        pdsTotalDest =
            nbColisDest.multiply(pdsColisDest).setScale(3, java.math.RoundingMode.HALF_UP);
      }
      response.setValue("pdsTotalDest", pdsTotalDest);

    } catch (Exception e) {
      response.setException(e);
    }
  }

  public void copyPoidsToDest(ActionRequest request, ActionResponse response) {
    try {
      CessionStock cession = request.getContext().asType(CessionStock.class);
      BigDecimal poidsKg = cession.getPoidsKg();

      if (poidsKg != null) {
        response.setValue("poidsKgDest", poidsKg);
      }

    } catch (Exception e) {
      response.setException(e);
    }
  }

  public void syncFraisCongelation(ActionRequest request, ActionResponse response) {
    try {
      CessionStock cession = request.getContext().asType(CessionStock.class);
      if ("FRAIS_STOCKAGE".equals(cession.getTypeCession()) && cession.getCompany() != null) {
        com.axelor.apps.base.db.Company company =
            Beans.get(com.axelor.apps.base.db.repo.CompanyRepository.class)
                .find(cession.getCompany().getId());
        response.setValue("prKg", company.getFraisCongelation());
      }
    } catch (Exception e) {
      response.setException(e);
    }
  }
}

package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.db.Company;
import com.axelor.apps.base.db.Product;
import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.apps.stock.db.StockLocation;
import com.axelor.apps.stock.db.StockLocationLine;
import com.axelor.apps.stock.db.StockMove;
import com.axelor.apps.stock.db.StockMoveLine;
import com.axelor.apps.stock.db.TrackingNumber;
import com.axelor.apps.stock.db.repo.StockLocationLineRepository;
import com.axelor.apps.stock.db.repo.StockLocationRepository;
import com.axelor.apps.stock.db.repo.StockMoveRepository;
import com.axelor.apps.stock.db.repo.TrackingNumberRepository;
import com.axelor.apps.stock.service.StockLocationLineService;
import com.axelor.apps.stock.service.StockMoveToolService;
import com.axelor.inject.Beans;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.google.inject.persist.Transactional;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * LVME : écran « Opérations Diverses sur les Stocks / Lots » (GESCOM) — entrée ou sortie de poids
 * sur un lot (casse, perte, DLC dépassée, régularisation…). Crée un mouvement de stock réalisé à la
 * date OD entre le frigo du lot et l'emplacement virtuel « OPERATIONS DIVERSES » (PROD_99) et met à
 * jour le stock du lot. Comme GESCOM, un lot peut passer en négatif (lots flottants, lots négatifs
 * repris de GESCOM) : pas de contrôle de stock minimum.
 */
public class LvmeOperationDiverseController {

  /** Types d'OD d'entrée (table_base GESCOM STKMVT, sens E) ; les autres types sont des sorties. */
  private static final List<String> TYPES_ENTREE = Arrays.asList("ED", "RE");

  private static final String EMPLACEMENT_OD = "LVME-OD";

  @Transactional(rollbackOn = {Exception.class})
  public void valider(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> ctx = request.getContext();
      Object lot = ctx.get("lotOd");
      if (!(lot instanceof Map) || ((Map<?, ?>) lot).get("id") == null) {
        response.setInfo("Choisissez le N° Lot.");
        return;
      }
      String type = ctx.get("typeMouvement") == null ? null : ctx.get("typeMouvement").toString();
      if (type == null || type.isEmpty()) {
        response.setInfo("Choisissez le type de mouvement.");
        return;
      }
      BigDecimal poids =
          ctx.get("poidsOd") == null
              ? BigDecimal.ZERO
              : new BigDecimal(ctx.get("poidsOd").toString());
      if (poids.signum() <= 0) {
        response.setInfo("Saisissez le poids (Kg) du mouvement.");
        return;
      }
      LocalDate dateOd =
          ctx.get("dateOd") == null
              ? LocalDate.now()
              : LocalDate.parse(ctx.get("dateOd").toString().substring(0, 10));
      String libelle = ctx.get("libelleMvt") == null ? "" : ctx.get("libelleMvt").toString().trim();
      boolean entree = TYPES_ENTREE.contains(type);

      TrackingNumber trackingNumber =
          Beans.get(TrackingNumberRepository.class)
              .find(Long.valueOf(((Map<?, ?>) lot).get("id").toString()));
      Product product = trackingNumber.getProduct();

      // frigo du lot : ligne de lot d'un emplacement interne (la plus grosse quantité)
      StockLocationLine ligneLot =
          Beans.get(StockLocationLineRepository.class)
              .all()
              .filter(
                  "self.trackingNumber = :lot AND self.detailsStockLocation.typeSelect = :interne")
              .bind("lot", trackingNumber)
              .bind("interne", StockLocationRepository.TYPE_INTERNAL)
              .order("-currentQty")
              .fetchOne();
      if (ligneLot == null) {
        response.setInfo(
            "Le lot " + trackingNumber.getTrackingNumberSeq() + " n'est dans aucun frigo.");
        return;
      }
      StockLocation frigo = ligneLot.getDetailsStockLocation();
      StockLocation emplacementOd =
          Beans.get(StockLocationRepository.class)
              .all()
              .filter("self.importId = :cle")
              .bind("cle", EMPLACEMENT_OD)
              .fetchOne();
      if (emplacementOd == null) {
        response.setInfo("Emplacement « OPERATIONS DIVERSES » absent : lancer PROD_99.");
        return;
      }
      Company company = frigo.getCompany();
      StockLocation depuis = entree ? emplacementOd : frigo;
      StockLocation vers = entree ? frigo : emplacementOd;

      StockMove stockMove = new StockMove();
      stockMove.setCompany(company);
      stockMove.setTypeSelect(StockMoveRepository.TYPE_INTERNAL);
      stockMove.setStatusSelect(StockMoveRepository.STATUS_REALIZED);
      stockMove.setFromStockLocation(depuis);
      stockMove.setToStockLocation(vers);
      stockMove.setEstimatedDate(dateOd);
      stockMove.setRealDate(dateOd);
      stockMove.setOrigin("OD " + type);
      stockMove.setNote(
          "Opération diverse "
              + type
              + (libelle.isEmpty() ? "" : " : " + libelle)
              + " — lot "
              + trackingNumber.getTrackingNumberSeq());
      stockMove.setStockMoveSeq(
          Beans.get(StockMoveToolService.class)
              .getSequenceStockMove(StockMoveRepository.TYPE_INTERNAL, company, stockMove));
      stockMove.setName(stockMove.getStockMoveSeq() + " - OD " + type);

      StockMoveLine line = new StockMoveLine();
      line.setStockMove(stockMove);
      line.setSequence(1);
      line.setProduct(product);
      line.setProductName(product.getName());
      line.setProductTypeSelect(product.getProductTypeSelect());
      line.setUnit(ligneLot.getUnit() != null ? ligneLot.getUnit() : product.getUnit());
      line.setQty(poids);
      line.setRealQty(poids);
      line.setTrackingNumber(trackingNumber);
      line.setFromStockLocation(depuis);
      line.setToStockLocation(vers);
      line.setName(libelle.isEmpty() ? "OD " + type : libelle);
      line.setDescription(libelle);
      BigDecimal prix =
          trackingNumber.getPrixRevientReel() != null
              ? trackingNumber.getPrixRevientReel()
              : BigDecimal.ZERO;
      line.setUnitPriceUntaxed(prix);
      line.setCompanyUnitPriceUntaxed(prix);
      stockMove.addStockMoveLineListItem(line);
      Beans.get(StockMoveRepository.class).save(stockMove);

      // stock : frigo (ligne du produit et ligne du lot) et emplacement OD, sans contrôle de stock
      // négatif
      BigDecimal mouvement = entree ? poids : poids.negate();
      StockLocationLineService lineService = Beans.get(StockLocationLineService.class);
      StockLocationLineRepository lineRepo = Beans.get(StockLocationLineRepository.class);
      ajouter(lineRepo, lineService.getOrCreateStockLocationLine(frigo, product), mouvement);
      ajouter(lineRepo, ligneLot, mouvement);
      ajouter(
          lineRepo,
          lineService.getOrCreateStockLocationLine(emplacementOd, product),
          mouvement.negate());
      ajouter(
          lineRepo,
          lineService.getOrCreateDetailLocationLine(emplacementOd, product, trackingNumber),
          mouvement.negate());

      response.setValue("lotOd", null);
      response.setValue("typeMouvement", null);
      response.setValue("libelleMvt", null);
      response.setValue("sensMvt", null);
      response.setValue("uniteOd", null);
      response.setValue("poidsOd", BigDecimal.ZERO);
      response.setAttr("lotsDashlet", "refresh", true);
      response.setNotify(
          "OD enregistrée : "
              + (entree ? "entrée de " : "sortie de ")
              + poids.stripTrailingZeros().toPlainString()
              + " sur le lot "
              + trackingNumber.getTrackingNumberSeq()
              + " ("
              + frigo.getName()
              + "), mouvement "
              + stockMove.getStockMoveSeq()
              + ".");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  private void ajouter(StockLocationLineRepository repo, StockLocationLine ligne, BigDecimal qty) {
    ligne.setCurrentQty(
        (ligne.getCurrentQty() == null ? BigDecimal.ZERO : ligne.getCurrentQty()).add(qty));
    ligne.setFutureQty(
        (ligne.getFutureQty() == null ? BigDecimal.ZERO : ligne.getFutureQty()).add(qty));
    repo.save(ligne);
  }
}

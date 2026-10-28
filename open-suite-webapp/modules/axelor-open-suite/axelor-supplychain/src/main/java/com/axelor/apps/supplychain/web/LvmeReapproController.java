package com.axelor.apps.supplychain.web;

import com.axelor.apps.base.service.exception.TraceBackService;
import com.axelor.auth.AuthUtils;
import com.axelor.auth.db.User;
import com.axelor.db.JPA;
import com.axelor.rpc.ActionRequest;
import com.axelor.rpc.ActionResponse;
import com.google.inject.persist.Transactional;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import javax.persistence.Query;

/**
 * LVME : écran « Aides aux Réapprovisionnements » (GESCOM). « Lancer Traitement » recalcule, pour
 * l'utilisateur, une ligne par produit vendu (période de statistiques) ou commandé :
 *
 * <ul>
 *   <li>vendues période stats : lignes des commandes clients confirmées ou terminées, à la date du
 *       BL (sinon de la commande), comme le Palmarès ;
 *   <li>Cdes clients : reste à livrer des commandes confirmées ; Vtes art. en cdes : la part à
 *       livrer pendant la période de réappro ;
 *   <li>Arr. réels / flottants : stock des lots réels / flottants (règles de l'état des stocks par
 *       lots) ; Stock DLC courte : stock réel dont la DLC tombe avant la fin de la période de
 *       réappro ;
 *   <li>à commander = ventes stats ramenées à la durée de la période de réappro + Cdes clients -
 *       (Arr. réels - DLC courte) - Arr. flottants, chaque terme selon les cases « Tenir compte » ;
 *       affiché seulement s'il est positif, sauf « Affichage des A commander négatif ».
 * </ul>
 */
public class LvmeReapproController {

  private static final String SQL =
      "INSERT INTO lvme_reappro_ligne (id, version, created_on, utilisateur, fournisseur_name, ref_fournisseur,"
          + " product, product_code, product_name, unite, qte_vendues, qte_cdes, qte_vtes_cdes, qte_arr_reels,"
          + " qte_dlc_courte, qte_arr_flottants, poids_vendus, poids_cdes, poids_vtes_cdes, poids_arr_reels,"
          + " poids_dlc_courte, poids_arr_flottants, qte_commander, poids_commander)"
          + " WITH ventes AS ("
          + "   SELECT sol.product, so.status_select AS statut, sol.qty,"
          + "     COALESCE(sol.poids_total_net, sol.qty) AS poids,"
          + "     sol.qty - COALESCE(sol.delivered_qty, 0) AS reste_qty,"
          + "     CASE WHEN sol.qty <> 0 THEN COALESCE(sol.poids_total_net, sol.qty)"
          + "       * (sol.qty - COALESCE(sol.delivered_qty, 0)) / sol.qty ELSE 0 END AS reste_poids,"
          + "     COALESCE(sol.estimated_shipping_date, so.estimated_shipping_date, so.order_date) AS livraison,"
          + "     COALESCE((SELECT COALESCE(sm.real_date, sm.estimated_date) FROM stock_stock_move sm"
          + "       WHERE sm.id = (SELECT max(sml.stock_move) FROM stock_stock_move_line sml"
          + "         WHERE sml.sale_order_line = sol.id AND sml.stock_move IN ("
          + "           SELECT s.id FROM stock_stock_move s WHERE s.status_select <> 4))),"
          + "       so.order_date, so.creation_date) AS dt"
          + "   FROM sale_sale_order_line sol JOIN sale_sale_order so ON so.id = sol.sale_order"
          + "   WHERE so.template = false AND so.status_select IN (3, 4) AND sol.product IS NOT NULL),"
          + " v AS ("
          + "   SELECT product,"
          + "     sum(qty) FILTER (WHERE dt BETWEEN :sdu AND :sau) AS qv,"
          + "     sum(poids) FILTER (WHERE dt BETWEEN :sdu AND :sau) AS pv,"
          + "     sum(reste_qty) FILTER (WHERE statut = 3 AND reste_qty > 0) AS qc,"
          + "     sum(reste_poids) FILTER (WHERE statut = 3 AND reste_qty > 0) AS pc,"
          + "     sum(reste_qty) FILTER (WHERE statut = 3 AND reste_qty > 0 AND livraison BETWEEN :du AND :au) AS qvc,"
          + "     sum(reste_poids) FILTER (WHERE statut = 3 AND reste_qty > 0 AND livraison BETWEEN :du AND :au)"
          + "       AS pvc"
          + "   FROM ventes GROUP BY product),"
          + " s AS ("
          + "   SELECT product_id AS product,"
          + "     sum(stock_qty) FILTER (WHERE nature_arrivage = 1 AND stock_qty > 0) AS qr,"
          + "     sum(stock_qty) FILTER (WHERE nature_arrivage = 1 AND stock_qty > 0 AND dluo <= :au) AS qd,"
          + "     sum(stock_qty) FILTER (WHERE nature_arrivage = 2 AND stock_qty > 0) AS qf"
          + "   FROM lvme_etat_stock_lot GROUP BY product_id),"
          + " c AS ("
          + "   SELECT p.id AS product, p.code, p.name, p.ref_fournisseur, f.name AS fournisseur, u.name AS unite,"
          + "     v.qv, v.pv, v.qc, v.pc, v.qvc, v.pvc, s.qr, s.qd, s.qf,"
          + "     COALESCE(v.qv, 0) * :ratio + CASE WHEN :cdes THEN COALESCE(v.qc, 0) ELSE 0 END"
          + "       - CASE WHEN :reels THEN COALESCE(s.qr, 0) - COALESCE(s.qd, 0) ELSE 0 END"
          + "       - CASE WHEN :flottants THEN COALESCE(s.qf, 0) ELSE 0 END AS qcmd,"
          + "     COALESCE(v.pv, 0) * :ratio + CASE WHEN :cdes THEN COALESCE(v.pc, 0) ELSE 0 END"
          + "       - CASE WHEN :reels THEN COALESCE(s.qr, 0) - COALESCE(s.qd, 0) ELSE 0 END"
          + "       - CASE WHEN :flottants THEN COALESCE(s.qf, 0) ELSE 0 END AS pcmd"
          + "   FROM v JOIN base_product p ON p.id = v.product"
          + "   LEFT JOIN s ON s.product = v.product"
          + "   LEFT JOIN base_partner f ON f.id = p.default_supplier_partner"
          + "   LEFT JOIN base_unit u ON u.id = p.unit"
          + "   WHERE (COALESCE(v.qv, 0) <> 0 OR COALESCE(v.qc, 0) <> 0)"
          + "     AND (:four = 0 OR p.default_supplier_partner = :four)"
          + "     AND (:prod = 0 OR p.id = :prod)"
          + "     AND (:fam = 0 OR p.product_category = :fam))"
          + " SELECT nextval('lvme_reappro_ligne_seq'), 0, now(), :user, fournisseur, ref_fournisseur, product, code,"
          + "   name, unite, NULLIF(qv, 0), NULLIF(qc, 0), NULLIF(qvc, 0), NULLIF(qr, 0), NULLIF(qd, 0), NULLIF(qf, 0),"
          + "   NULLIF(pv, 0), NULLIF(pc, 0), NULLIF(pvc, 0), NULLIF(qr, 0), NULLIF(qd, 0), NULLIF(qf, 0),"
          + "   CASE WHEN qcmd > 0 OR :negatif THEN round(qcmd, 3) END,"
          + "   CASE WHEN pcmd > 0 OR :negatif THEN round(pcmd, 3) END"
          + " FROM c";

  @Transactional(rollbackOn = {Exception.class})
  public void lancer(ActionRequest request, ActionResponse response) {
    try {
      Map<String, Object> c = request.getContext();
      LocalDate du = date(c.get("reapproDu"));
      LocalDate au = date(c.get("reapproAu"));
      LocalDate sdu = date(c.get("statsDu"));
      LocalDate sau = date(c.get("statsAu"));
      if (du == null || au == null || sdu == null || sau == null) {
        response.setInfo("Saisissez les périodes de réapprovisionnement et de statistiques.");
        return;
      }
      double joursStats = ChronoUnit.DAYS.between(sdu, sau) + 1;
      double joursReappro = ChronoUnit.DAYS.between(du, au) + 1;
      if (joursStats <= 0 || joursReappro <= 0) {
        response.setInfo("Les dates « au » doivent suivre les dates « du ».");
        return;
      }
      User user = AuthUtils.getUser();
      JPA.em()
          .createNativeQuery("DELETE FROM lvme_reappro_ligne WHERE utilisateur = :user")
          .setParameter("user", user.getId())
          .executeUpdate();
      Query q = JPA.em().createNativeQuery(SQL);
      q.setParameter("user", user.getId());
      q.setParameter("du", du);
      q.setParameter("au", au);
      q.setParameter("sdu", sdu);
      q.setParameter("sau", sau);
      q.setParameter("ratio", joursReappro / joursStats);
      q.setParameter("cdes", vrai(c.get("tenirCdes")));
      q.setParameter("reels", vrai(c.get("tenirReels")));
      q.setParameter("flottants", vrai(c.get("tenirFlottants")));
      q.setParameter("negatif", vrai(c.get("afficherNegatif")));
      q.setParameter("four", id(c.get("fournisseur")));
      q.setParameter("prod", id(c.get("produit")));
      q.setParameter("fam", id(c.get("familleProduit")));
      int lignes = q.executeUpdate();
      response.setAttr("reapproDashlet", "refresh", true);
      response.setNotify(lignes + " produit(s) traité(s).");
    } catch (Exception e) {
      TraceBackService.trace(response, e);
    }
  }

  private static LocalDate date(Object o) {
    return o == null || o.toString().isEmpty()
        ? null
        : LocalDate.parse(o.toString().substring(0, 10));
  }

  private static boolean vrai(Object o) {
    return o != null && Boolean.parseBoolean(o.toString());
  }

  private static long id(Object o) {
    if (o instanceof Map && ((Map<?, ?>) o).get("id") != null) {
      return Long.parseLong(((Map<?, ?>) o).get("id").toString());
    }
    return 0L;
  }
}

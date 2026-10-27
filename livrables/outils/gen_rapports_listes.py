"""Impressions LVME des listes, comme les boutons de GESCOM : « Imprimer » (liste des achats fournisseurs),
« Editer » (liste des arrivages), « Liste des Rotations » (rotation des stocks par lot). Chaque impression reprend les
filtres de l'écran (passés par LvmeImpressionListesController) et les colonnes de la liste, aux couleurs GESCOM, avec
le logo LVME en haut à gauche.

Écrit LvmeListeAchats.rptdesign, LvmeListeArrivages, LvmeListeRotations, LvmeListeCommandesClients,
LvmeHistoriquePrix et LvmeEtatStockLots.rptdesign dans
axelor-supplychain/src/main/resources/reports (recompiler). Boutons : PROD_87, 88 et 89.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from birt_lvme import entete, jeu, prop, rapport, tableau  # noqa: E402

NATURE = ("CASE %s WHEN 0 THEN 'Brouillon' WHEN 1 THEN 'Flottant' WHEN 2 THEN 'Flottant' WHEN 3 THEN 'Réel' "
          "WHEN 4 THEN 'Annulé' ELSE '' END")
FILTRES = 'params["Filtres"].value'

# ---------- liste des achats fournisseurs (mêmes filtres que l'écran, y compris les alertes) ----------
SQL_ACHATS = '''SELECT po.purchase_order_seq AS numero, sp.partner_seq AS fournisseur, sp.name AS nom,
  (SELECT string_agg(sm.stock_move_seq, ', ') FROM stock_stock_move sm WHERE sm.type_select = 3 AND sm.id IN (
    SELECT x.stock_stock_move FROM stock_stock_move_purchase_order_set x WHERE x.purchase_order_set = po.id))
    AS numero_arrivage,
  ''' + NATURE % 'po.nature' + ''' AS nature, po.order_date AS date_arrivage, po.estimated_receipt_date AS date_arrivee,
  po.qty_total AS nb_unites, po.poids_total AS tonnage, po.ex_tax_total AS montant,
  CASE WHEN po.nature = 1 THEN 'Oui' ELSE '' END AS a_embarquer
FROM purchase_purchase_order po
LEFT JOIN base_partner sp ON sp.id = po.supplier_partner
WHERE (:Alerte = '' AND po.status_select IN (3, 4)
    AND (:DateFiltre = '0' OR po.order_date BETWEEN CAST(:DateDu AS date) AND CAST(:DateAu AS date))
    AND (:ArrFiltre = '0' OR po.estimated_receipt_date BETWEEN CAST(:ArrDu AS date) AND CAST(:ArrAu AS date))
    AND (:FouDu = '' OR sp.name >= :FouDu) AND (:FouAu = '' OR sp.name <= :FouAu)
    AND (CAST(:Transport AS bigint) = 0 OR po.shipment_mode = CAST(:Transport AS bigint))
    AND ((CAST(:Nature AS integer) = 1 AND po.nature = 3) OR (CAST(:Nature AS integer) = 2 AND po.nature IN (1, 2))
      OR CAST(:Nature AS integer) = 3))
  OR (:Alerte = 'retard' AND po.status_select = 3 AND (po.nature IS NULL OR po.nature NOT IN (3, 4))
    AND po.estimated_receipt_date < current_date)
  OR (:Alerte = 'brouillons' AND po.status_select IN (1, 2) AND po.order_date < current_date - 15)
  OR (:Alerte = 'a-embarquer' AND po.status_select = 3 AND po.nature = 1 AND po.order_date < current_date - 30)
ORDER BY po.order_date DESC, po.id DESC'''
COLS_ACHATS = [('numero', 'string'), ('fournisseur', 'string'), ('nom', 'string'), ('numero_arrivage', 'string'),
               ('nature', 'string'), ('date_arrivage', 'date'), ('date_arrivee', 'date'), ('nb_unites', 'decimal'),
               ('tonnage', 'decimal'), ('montant', 'decimal'), ('a_embarquer', 'string')]
LIGNES_ACHATS = [
    ('N°', 'numero', 2.2, None, None), ('Fournisseur', 'fournisseur', 2.0, None, None),
    ('Nom', 'nom', 6.0, None, None), ('Numéro Arrivage', 'numero_arrivage', 2.6, None, None),
    ('Nature', 'nature', 1.6, None, None), ('Date Arrivage', 'date_arrivage', 2.0, 'date', None),
    ('Date Arrivée', 'date_arrivee', 2.0, 'date', None), ('Nb unités', 'nb_unites', 2.0, '#,##0.00', None),
    ('Tonnage en kg', 'tonnage', 2.2, '#,##0.00', None), ('Mt Arrivage H.T.', 'montant', 2.4, '#,##0', None),
    ('À embarquer', 'a_embarquer', 1.5, None, None),
]
jeu_a, p_a = jeu('AchatsDS', SQL_ACHATS, COLS_ACHATS)
rapport('LvmeListeAchats.rptdesign', p_a | {'Filtres'}, [jeu_a],
        entete('Liste des achats fournisseurs', FILTRES)
        + tableau('AchatsDS', COLS_ACHATS, LIGNES_ACHATS, ('#FFFF99', '#F4F7FF'),
                  prop('backgroundColor', '#DBE8FB'), sommes=('nb_unites', 'tonnage', 'montant')))

# ---------- liste des arrivages ----------
SQL_ARRIVAGES = '''SELECT COALESCE(p.simple_full_name, p.name) AS fournisseur, sm.stock_move_seq AS numero,
  ''' + NATURE % 'sm.nature' + ''' AS nature, CASE WHEN sm.nature = 1 THEN 'Oui' ELSE '' END AS a_embarquer,
  sm.supplier_shipment_date AS date_depart, sm.estimated_date AS arrivee_prevue, sm.real_date AS arrivee_le,
  shm.name AS transport, bt.name AS bateau,
  (SELECT string_agg(c.name, ', ') FROM stock_stock_move_container_set cs JOIN stock_container c ON c.id = cs.container_set
    WHERE cs.stock_stock_move = sm.id) AS containers,
  sm.nb_colis_total AS nb_colis, sm.poids_total AS poids, sm.ex_tax_total AS montant, p.fixed_phone AS telephone,
  city.name AS ville, pays.name AS pays, fr.name AS frigo
FROM stock_stock_move sm
LEFT JOIN base_partner p ON p.id = sm.partner
LEFT JOIN stock_shipment_mode shm ON shm.id = sm.shipment_mode
LEFT JOIN stock_bateau bt ON bt.id = sm.bateau
LEFT JOIN base_address adr ON adr.id = sm.from_address
LEFT JOIN base_city city ON city.id = adr.city
LEFT JOIN base_country pays ON pays.id = adr.country
LEFT JOIN stock_stock_location fr ON fr.id = sm.to_stock_location
WHERE sm.type_select = 3 AND sm.is_reversion = false
  AND LOWER(COALESCE(sm.stock_move_seq, '')) LIKE :Numero
  AND (CAST(:Fournisseur AS bigint) = 0 OR sm.partner = CAST(:Fournisseur AS bigint))
  AND (:DateFiltre = '0' OR CAST(sm.created_on AS date) BETWEEN CAST(:DateDu AS date) AND CAST(:DateAu AS date))
  AND (:ArrFiltre = '0' OR sm.real_date BETWEEN CAST(:ArrDu AS date) AND CAST(:ArrAu AS date)
    OR (sm.real_date IS NULL AND sm.estimated_date BETWEEN CAST(:ArrDu AS date) AND CAST(:ArrAu AS date)))
  AND ((CAST(:Nature AS integer) = 4 AND sm.archived = true)
    OR (CAST(:Nature AS integer) <> 4 AND (sm.archived IS NULL OR sm.archived = false)
      AND ((CAST(:Nature AS integer) = 1 AND sm.nature IN (0, 1, 2, 3)) OR (CAST(:Nature AS integer) = 2 AND sm.nature = 3)
        OR (CAST(:Nature AS integer) = 3 AND sm.nature IN (1, 2)))))
ORDER BY sm.estimated_date DESC NULLS LAST, sm.id DESC'''
COLS_ARRIVAGES = [('fournisseur', 'string'), ('numero', 'string'), ('nature', 'string'), ('a_embarquer', 'string'),
                  ('date_depart', 'date'), ('arrivee_prevue', 'date'), ('arrivee_le', 'date'),
                  ('transport', 'string'), ('bateau', 'string'), ('containers', 'string'), ('nb_colis', 'decimal'),
                  ('poids', 'decimal'), ('montant', 'decimal'), ('telephone', 'string'), ('ville', 'string'),
                  ('pays', 'string'), ('frigo', 'string')]
LIGNES_ARRIVAGES = [
    ('Fournisseur', 'fournisseur', 3.6, None, None), ('N° Arrivage', 'numero', 1.8, None, None),
    ('Nature', 'nature', 1.2, None, None), ('À embarquer', 'a_embarquer', 1.1, None, None),
    ('Date Départ', 'date_depart', 1.5, 'date', None), ('Arrivée prévue', 'arrivee_prevue', 1.5, 'date', None),
    ('Arrivée le', 'arrivee_le', 1.5, 'date', None), ('Type transport', 'transport', 1.4, None, None),
    ('Bateau', 'bateau', 1.6, None, None), ('Containers', 'containers', 1.8, None, None),
    ('Nb Colis', 'nb_colis', 1.2, '#,##0', None), ('Poids Total', 'poids', 1.5, '#,##0.00', None),
    ('Montant Achat HT', 'montant', 1.8, '#,##0.00', None), ('Téléphone', 'telephone', 1.7, None, None),
    ('Ville', 'ville', 1.5, None, None), ('Pays', 'pays', 1.3, None, None), ('Frigo', 'frigo', 1.2, None, None),
]
jeu_r, p_r = jeu('ArrivagesDS', SQL_ARRIVAGES, COLS_ARRIVAGES)
rapport('LvmeListeArrivages.rptdesign', p_r | {'Filtres'}, [jeu_r],
        entete('Arrivages', FILTRES)
        + tableau('ArrivagesDS', COLS_ARRIVAGES, LIGNES_ARRIVAGES, ('#FFFFFF', '#E9F0FA'),
                  prop('backgroundColor', '#DCDCDC'), sommes=('nb_colis', 'poids', 'montant')))

# ---------- liste des rotations (par lot, totaux par produit comme GESCOM) ----------
SQL_ROTATIONS = '''SELECT r.product_code AS produit, r.product_name AS designation, r.supplier_name AS fournisseur,
  loc.name AS frigo, t.transport, r.lot_number AS lot, r.arrival_number AS arrivage, r.origine, r.conditionnement,
  r.marque, r.gencode, r.arrival_date AS arrivee_le, r.dluo, r.prix_revient, r.poids_colis, r.poids_entrees,
  r.nb_colis_in AS colis_entrees, r.nb_colis_stock AS colis_stock, r.poids_stock, r.stock_value AS valeur_stock,
  r.stock_days AS jours_stock, r.last_sale_date AS derniere_sortie, r.rotation_days AS jours_rotation
FROM lvme_rotation_lot r
LEFT JOIN stock_stock_location loc ON loc.id = r.stock_location_id
LEFT JOIN LATERAL (SELECT (SELECT shm.name FROM stock_shipment_mode shm WHERE shm.id = (
    SELECT COALESCE(sm.shipment_mode, (SELECT MAX(po.shipment_mode) FROM purchase_purchase_order po WHERE po.id IN (
      SELECT x.purchase_order_set FROM stock_stock_move_purchase_order_set x WHERE x.stock_stock_move = sm.id)))
    FROM stock_stock_move sm WHERE sm.id = (SELECT sml.stock_move FROM stock_stock_move_line sml WHERE sml.id = (
      SELECT tn.origin_stock_move_line FROM stock_tracking_number tn WHERE tn.id = r.tracking_number_id)))) AS transport) t
  ON true
WHERE (:ArtDu = '' OR r.product_code >= :ArtDu) AND (:ArtAu = '' OR r.product_code <= :ArtAu)
  AND (:FouDu = '' OR r.supplier_name >= :FouDu) AND (:FouAu = '' OR r.supplier_name <= :FouAu)
  AND (CAST(:Famille AS bigint) = 0 OR r.product_category_id = CAST(:Famille AS bigint))
  AND (CAST(:Frigo AS bigint) = 0 OR r.stock_location_id = CAST(:Frigo AS bigint))
  AND (:Origine = '' OR r.origine = :Origine)
  AND (:EntreeFiltre = '0' OR r.arrival_date BETWEEN CAST(:EntreeDu AS date) AND CAST(:EntreeAu AS date))
  AND (:Transport = '' OR t.transport = :Transport)
ORDER BY r.product_code, r.arrival_date, r.lot_number'''
COLS_ROTATIONS = [('produit', 'string'), ('designation', 'string'), ('fournisseur', 'string'), ('frigo', 'string'),
                  ('transport', 'string'), ('lot', 'string'), ('arrivage', 'string'), ('origine', 'string'),
                  ('conditionnement', 'string'), ('marque', 'string'), ('gencode', 'string'), ('arrivee_le', 'date'),
                  ('dluo', 'date'), ('prix_revient', 'decimal'), ('poids_colis', 'decimal'),
                  ('poids_entrees', 'decimal'), ('colis_entrees', 'decimal'), ('colis_stock', 'decimal'),
                  ('poids_stock', 'decimal'), ('valeur_stock', 'decimal'), ('jours_stock', 'integer'),
                  ('derniere_sortie', 'date'), ('jours_rotation', 'integer')]
LIGNES_ROTATIONS = [
    ('Produit', 'produit', 1.5, None, None), ('Désignation', 'designation', 2.8, None, None),
    ('Fournisseur', 'fournisseur', 1.9, None, None), ('Frigo', 'frigo', 0.9, None, None),
    ('Type transport', 'transport', 1.0, None, None), ('N° Lot', 'lot', 1.4, None, None),
    ('N° Arrivage', 'arrivage', 1.2, None, None), ('Origine', 'origine', 0.8, None, None),
    ('Conditionnement', 'conditionnement', 1.4, None, None), ('Marque', 'marque', 0.8, None, None),
    ('Gencode', 'gencode', 1.2, None, None), ('Arrivée le', 'arrivee_le', 1.2, 'date', None),
    ('D.L.C.', 'dluo', 1.2, 'date', None), ('Prix Revient', 'prix_revient', 0.9, '#,##0.00', None),
    ('Poids Colis', 'poids_colis', 0.8, '#,##0.##', None), ('Poids Entrées', 'poids_entrees', 1.2, '#,##0.000', None),
    ('Nb Colis Entrées', 'colis_entrees', 0.9, '#,##0', None),
    ('Nb colis Stock', 'colis_stock', 0.9, '#,##0', '#FFFF99'), ('Poids Stock', 'poids_stock', 1.1, '#,##0.000', None),
    ('Valeur stock', 'valeur_stock', 1.2, '#,##0.00', None), ('Jours en stock', 'jours_stock', 0.8, '#,##0', None),
    ('Date dernière Sortie', 'derniere_sortie', 1.2, 'date', None),
    ('Nbre Jours Rotation', 'jours_rotation', 0.9, '#,##0', '#FFBE4E'),
]
SOMMES_ROT = ('poids_entrees', 'colis_entrees', 'colis_stock', 'poids_stock', 'valeur_stock')
jeu_o, p_o = jeu('RotationsDS', SQL_ROTATIONS, COLS_ROTATIONS)
rapport('LvmeListeRotations.rptdesign', p_o | {'Filtres'}, [jeu_o],
        entete('Liste des Rotations', FILTRES)
        + tableau('RotationsDS', COLS_ROTATIONS, LIGNES_ROTATIONS, ('#FFFFFF', '#FFFFFF'),
                  prop('backgroundColor', '#DCDCDC'), sommes=SOMMES_ROT,
                  groupe=('produit', 'Totaux', '#FFFF99', SOMMES_ROT)))

# ---------- liste des commandes clients (mêmes filtres que l'écran, y compris les alertes) ----------
SQL_CDES = '''SELECT so.sale_order_seq AS numero, CASE WHEN so.is_reservation THEN 'Oui' ELSE '' END AS reservation,
  CASE WHEN so.is_reservation THEN current_date - DATE(COALESCE(so.confirmation_date_time, so.created_on)) END
    AS age_resa,
  so.order_date AS date_cde, cli.name AS client, cli.partner_seq AS code,
  (SELECT string_agg(sm.stock_move_seq, ', ') FROM stock_stock_move sm WHERE sm.type_select = 2 AND sm.status_select <> 4
    AND sm.id IN (SELECT x.stock_stock_move FROM stock_stock_move_sale_order_set x WHERE x.sale_order_set = so.id))
    AS numero_bl,
  city.name AS ville, cli.fixed_phone AS telephone, so.ex_tax_total AS montant, so.total_gross_margin AS marge,
  so.margin_rate AS pct_marge, com.code AS commercial, com.name AS responsable,
  so.estimated_delivery_date AS date_livraison, prep.name AS preparateur, so.external_reference AS ref_client
FROM sale_sale_order so
LEFT JOIN base_partner cli ON cli.id = so.client_partner
LEFT JOIN base_address adr ON adr.id = so.main_invoicing_address
LEFT JOIN base_city city ON city.id = adr.city
LEFT JOIN auth_user com ON com.id = so.commercial
LEFT JOIN auth_user prep ON prep.id = so.lvme_preparateur
WHERE so.template = false AND (
  (:Alerte = '' AND so.status_select IN (3, 4)
    AND ((CAST(:Etat AS integer) = 1 AND so.status_select = 3 AND so.delivery_state <> 3
          AND (so.is_reservation IS NULL OR so.is_reservation = false))
      OR (CAST(:Etat AS integer) = 2 AND (so.status_select = 4 OR so.delivery_state = 3)) OR CAST(:Etat AS integer) = 3
      OR (CAST(:Etat AS integer) = 4 AND so.is_reservation = true AND so.status_select = 3))
    AND (CAST(:Client AS bigint) = 0 OR so.client_partner = CAST(:Client AS bigint))
    AND (CAST(:Commercial AS bigint) = 0 OR so.commercial = CAST(:Commercial AS bigint))
    AND (:DateFiltre = '0' OR COALESCE(so.order_date, so.creation_date) BETWEEN CAST(:DateDu AS date) AND CAST(:DateAu AS date))
    AND (:LivFiltre = '0' OR so.estimated_delivery_date BETWEEN CAST(:LivDu AS date) AND CAST(:LivAu AS date)))
  OR (:Alerte = 'retard' AND so.status_select = 3 AND (so.delivery_state IS NULL OR so.delivery_state <> 3)
    AND so.estimated_delivery_date < current_date)
  OR (:Alerte = 'marge-negative' AND so.status_select = 3 AND (so.delivery_state IS NULL OR so.delivery_state <> 3)
    AND so.total_gross_margin < 0)
  OR (:Alerte = 'marge-faible' AND so.status_select IN (3, 4)
    AND so.order_date BETWEEN date_trunc('month', current_date)::date AND current_date AND so.margin_rate < 10)
  OR (:Alerte = 'devis' AND so.status_select IN (1, 2) AND so.creation_date < current_date - 15))
ORDER BY so.order_date DESC NULLS LAST, so.id DESC'''
COLS_CDES = [('numero', 'string'), ('reservation', 'string'), ('age_resa', 'integer'), ('date_cde', 'date'),
             ('client', 'string'), ('code', 'string'), ('numero_bl', 'string'), ('ville', 'string'),
             ('telephone', 'string'), ('montant', 'decimal'), ('marge', 'decimal'), ('pct_marge', 'decimal'),
             ('commercial', 'string'), ('responsable', 'string'), ('date_livraison', 'date'),
             ('preparateur', 'string'), ('ref_client', 'string')]
LIGNES_CDES = [
    ('N° Commande', 'numero', 1.7, None, None), ('Réservation', 'reservation', 1.1, None, None),
    ('Âge résa (j)', 'age_resa', 0.9, '#,##0', None), ('Date', 'date_cde', 1.4, 'date', None),
    ('Client', 'client', 3.6, None, None), ('Code', 'code', 1.3, None, None), ('N° BL', 'numero_bl', 1.4, None, None),
    ('Ville', 'ville', 1.8, None, None), ('Téléphone', 'telephone', 1.8, None, None),
    ('Montant HT', 'montant', 1.6, '#,##0.00', None), ('Marge ht', 'marge', 1.4, '#,##0.00', None),
    ('% Marge', 'pct_marge', 1.0, '#,##0.00', None), ('Commercial', 'commercial', 1.4, None, None),
    ('Nom responsable', 'responsable', 1.8, None, None), ('Date livraison', 'date_livraison', 1.4, 'date', None),
    ('Préparateur', 'preparateur', 1.5, None, None), ('Ref Cde Client', 'ref_client', 1.6, None, None),
]
jeu_c, p_c = jeu('CommandesDS', SQL_CDES, COLS_CDES)
rapport('LvmeListeCommandesClients.rptdesign', p_c | {'Filtres'}, [jeu_c],
        entete('Listes Commandes Clients', FILTRES)
        + tableau('CommandesDS', COLS_CDES, LIGNES_CDES, ('#FFFFFF', '#F4F4F4'),
                  prop('backgroundColor', '#DCDCDC'), sommes=('montant', 'marge')))

# ---------- historique prix (F1 de la ligne de commande client, mêmes filtres que l'écran) ----------
SQL_HISTO_PRIX = '''SELECT p.code AS reference,
  COALESCE('B.L. N° ' || bl.stock_move_seq || ' Du ' || to_char(COALESCE(bl.real_date, bl.estimated_date), 'YYYYMMDD'),
    'Cde N° ' || COALESCE(so.sale_order_seq, '') || ' Du ' || to_char(COALESCE(so.order_date, so.creation_date), 'YYYYMMDD'))
    || '/' || COALESCE(cli.partner_seq, '') AS piece,
  COALESCE(bl.real_date, bl.estimated_date, so.order_date, so.creation_date) AS date_piece,
  (SELECT string_agg(DISTINCT sml.origine, ', ') FROM stock_stock_move_line sml WHERE sml.id IN (
    SELECT tn.origin_stock_move_line FROM stock_tracking_number tn WHERE tn.id IN (
      SELECT x.tracking_number FROM supplychain_sale_order_line_lot x WHERE x.sale_order_line = l.id))) AS origine,
  l.conditionnement, l.poids_par_colis AS poids_unitaire, l.nb_colis, l.poids_total_net AS poids,
  l.price_discounted AS prix_net, l.ex_tax_total AS montant
FROM sale_sale_order_line l
JOIN sale_sale_order so ON so.id = l.sale_order
JOIN base_product p ON p.id = l.product
LEFT JOIN base_partner cli ON cli.id = so.client_partner
LEFT JOIN stock_stock_move bl ON bl.id = (SELECT max(sml.stock_move) FROM stock_stock_move_line sml
    WHERE sml.sale_order_line = l.id AND sml.stock_move IN (SELECT s.id FROM stock_stock_move s WHERE s.status_select <> 4))
WHERE so.template = false AND so.status_select <> 5
  AND (CAST(:Produit AS bigint) = 0 OR l.product = CAST(:Produit AS bigint))
  AND (CAST(:Client AS bigint) = 0 OR so.client_partner = CAST(:Client AS bigint))
  AND COALESCE(so.order_date, so.creation_date) BETWEEN CAST(:DateDu AS date) AND CAST(:DateAu AS date)
ORDER BY so.order_date DESC NULLS LAST, l.id DESC'''
COLS_HISTO_PRIX = [('reference', 'string'), ('piece', 'string'), ('date_piece', 'date'), ('origine', 'string'),
                   ('conditionnement', 'string'), ('poids_unitaire', 'decimal'), ('nb_colis', 'decimal'),
                   ('poids', 'decimal'), ('prix_net', 'decimal'), ('montant', 'decimal')]
LIGNES_HISTO_PRIX = [
    ('Référence', 'reference', 1.6, None, None), ('Désignation', 'piece', 4.2, None, None),
    ('Date', 'date_piece', 1.3, 'date', None), ('Origine', 'origine', 1.2, None, None),
    ('Conditionnement', 'conditionnement', 3.0, None, None),
    ('Poids Unitaire', 'poids_unitaire', 1.1, '#,##0.000', None), ('Nbre Colis', 'nb_colis', 1.0, '#,##0', None),
    ('Poids', 'poids', 1.1, '#,##0.000', None), ('P.Vente Net', 'prix_net', 1.2, '#,##0.00', None),
    ('Montant H.T.', 'montant', 1.4, '#,##0.00', None),
]
jeu_h, p_h = jeu('HistoriquePrixDS', SQL_HISTO_PRIX, COLS_HISTO_PRIX)
rapport('LvmeHistoriquePrix.rptdesign', p_h | {'Filtres'}, [jeu_h],
        entete('Historique prix', FILTRES)
        + tableau('HistoriquePrixDS', COLS_HISTO_PRIX, LIGNES_HISTO_PRIX, ('#FFFFFF', '#F4F4F4'),
                  prop('backgroundColor', '#DCDCDC'), sommes=('nb_colis', 'poids', 'montant')))

# ---------- état des stocks par lots (mêmes filtres que l'écran) ----------
SQL_ETAT_STOCK = '''SELECT e.product_code AS produit, e.product_name AS designation, e.supplier_name AS fournisseur,
  loc.name AS frigo, e.lot_number AS lot, e.arrival_number AS arrivage, e.origine, e.arrival_date AS livree_le,
  e.conditionnement, e.dluo, e.prix_revient, e.qty_per_colis AS poids_colis, e.nb_colis_in AS colis_entrees,
  e.nb_colis_out AS colis_sorties, e.nb_colis_cdes AS colis_cdes, e.nb_colis_stock AS colis_stock,
  e.stock_qty AS poids_stock, e.stock_value AS valeur_stock,
  COALESCE(e.nb_colis_stock, 0) - COALESCE(e.nb_colis_cdes, 0) AS colis_dispo,
  e.dispo_qty AS poids_dispo, e.nature_label AS nature
FROM lvme_etat_stock_lot e
LEFT JOIN stock_stock_location loc ON loc.id = e.stock_location_id
WHERE (:ArtDu = '' OR e.product_code >= :ArtDu) AND (:ArtAu = '' OR e.product_code <= :ArtAu)
  AND (:FouDu = '' OR e.supplier_name >= :FouDu) AND (:FouAu = '' OR e.supplier_name <= :FouAu)
  AND (CAST(:Famille AS bigint) = 0 OR e.product_category_id = CAST(:Famille AS bigint))
  AND (CAST(:Frigo AS bigint) = 0 OR e.stock_location_id = CAST(:Frigo AS bigint))
  AND (:Origine = '' OR e.origine = :Origine)
  AND LOWER(COALESCE(e.lot_number, '')) LIKE :Lot
  AND (:EntreeFiltre = '0' OR e.entry_date BETWEEN CAST(:EntreeDu AS date) AND CAST(:EntreeAu AS date))
  AND (:DdmFiltre = '0' OR e.dluo BETWEEN CAST(:DdmDu AS date) AND CAST(:DdmAu AS date))
  AND (:LivrFiltre = '0' OR e.arrival_date BETWEEN CAST(:LivrDu AS date) AND CAST(:LivrAu AS date))
  AND (CAST(:Nature AS integer) = 0 OR e.nature_arrivage = CAST(:Nature AS integer))
  AND ((CAST(:Etat AS integer) = 1 AND e.stock_qty > 0) OR (CAST(:Etat AS integer) = 2 AND e.stock_qty = 0)
    OR (CAST(:Etat AS integer) = 3 AND e.stock_qty < 0) OR (CAST(:Etat AS integer) = 4 AND e.stock_qty <> 0)
    OR CAST(:Etat AS integer) = 5)
  AND ((CAST(:Etat AS integer) = 5 AND e.lot_archive = true) OR (CAST(:Etat AS integer) <> 5 AND e.lot_archive = false))
  AND (:DispoNeg = '0' OR e.dispo_qty < 0)
  AND (CAST(:Dluo AS integer) = 0 OR (CAST(:Dluo AS integer) = 1 AND e.dluo < current_date)
    OR (CAST(:Dluo AS integer) = 2 AND e.dluo BETWEEN current_date AND current_date + 30)
    OR (CAST(:Dluo AS integer) = 3 AND e.dluo <= current_date + 30))
ORDER BY e.product_code, e.arrival_date, e.lot_number'''
COLS_ETAT_STOCK = [('produit', 'string'), ('designation', 'string'), ('fournisseur', 'string'), ('frigo', 'string'),
                   ('lot', 'string'), ('arrivage', 'string'), ('origine', 'string'), ('livree_le', 'date'),
                   ('conditionnement', 'string'), ('dluo', 'date'), ('prix_revient', 'decimal'),
                   ('poids_colis', 'decimal'), ('colis_entrees', 'decimal'), ('colis_sorties', 'decimal'),
                   ('colis_cdes', 'decimal'), ('colis_stock', 'decimal'), ('poids_stock', 'decimal'),
                   ('valeur_stock', 'decimal'), ('colis_dispo', 'decimal'), ('poids_dispo', 'decimal'),
                   ('nature', 'string')]
LIGNES_ETAT_STOCK = [
    ('Produit', 'produit', 1.4, None, None), ('Désignation', 'designation', 2.8, None, None),
    ('Fournisseur', 'fournisseur', 1.9, None, None), ('Frigo', 'frigo', 0.9, None, None),
    ('N° Lot', 'lot', 1.4, None, None), ('N°Arrivage', 'arrivage', 1.2, None, None),
    ('Origine', 'origine', 0.8, None, None), ('Livrée le', 'livree_le', 1.2, 'date', None),
    ('Conditionnement', 'conditionnement', 1.5, None, None), ('D. L. C.', 'dluo', 1.2, 'date', None),
    ('Prix Revient', 'prix_revient', 0.9, '#,##0.00', None), ('Un/Poids Colis', 'poids_colis', 0.9, '#,##0.##', None),
    ('Nb Colis Entrées', 'colis_entrees', 0.9, '#,##0', None), ('Nb Colis Sorties', 'colis_sorties', 0.9, '#,##0', None),
    ('Nb colis Cdes', 'colis_cdes', 0.9, '#,##0', None), ('Nb colis Stock', 'colis_stock', 0.9, '#,##0', '#FFFF99'),
    ('Unt/Poids Stock', 'poids_stock', 1.1, '#,##0.000', None),
    ('Montant ht Stock', 'valeur_stock', 1.2, '#,##0.00', None),
    ('Nb colis Dispo', 'colis_dispo', 0.9, '#,##0', None), ('Unt/Poids Dispo', 'poids_dispo', 1.1, '#,##0.000', None),
    ('Arrivage', 'nature', 1.0, None, None),
]
jeu_e, p_e = jeu('EtatStockDS', SQL_ETAT_STOCK, COLS_ETAT_STOCK)
rapport('LvmeEtatStockLots.rptdesign', p_e | {'Filtres'}, [jeu_e],
        entete('État des stocks par lots', FILTRES)
        + tableau('EtatStockDS', COLS_ETAT_STOCK, LIGNES_ETAT_STOCK, ('#FFFFFF', '#F4F4F4'),
                  prop('backgroundColor', '#DCDCDC'),
                  sommes=('colis_entrees', 'colis_sorties', 'colis_cdes', 'colis_stock', 'poids_stock',
                          'valeur_stock', 'colis_dispo', 'poids_dispo')))

# ---------- synthèse des arrivages (bouton « Synthèse » GESCOM : en-tête par arrivage, lignes cyan, totaux) ----------
SQL_SYNTHESE = '''SELECT s.arrivage, s.fournisseur, s.code_fournisseur, s.date_embarquement, s.date_arrivee,
  s.product_code AS produit, s.designation, s.origine, s.conditionnement, s.frigo, s.lot_number AS lot, s.dlc,
  s.unite, s.nb_colis, s.poids_colis, s.poids_total, s.pa
FROM lvme_synthese_arrivage s
WHERE s.arrivage >= :NumDu AND s.arrivage <= :NumAu
  AND s.date_arrivee BETWEEN CAST(:Du AS date) AND CAST(:Au AS date)
ORDER BY s.arrivage, s.product_code, s.lot_number'''
COLS_SYNTHESE = [('arrivage', 'string'), ('fournisseur', 'string'), ('code_fournisseur', 'string'),
                 ('date_embarquement', 'date'), ('date_arrivee', 'date'), ('produit', 'string'),
                 ('designation', 'string'), ('origine', 'string'), ('conditionnement', 'string'), ('frigo', 'string'),
                 ('lot', 'string'), ('dlc', 'date'), ('unite', 'string'), ('nb_colis', 'decimal'),
                 ('poids_colis', 'decimal'), ('poids_total', 'decimal'), ('pa', 'decimal')]
LIGNES_SYNTHESE = [
    ('N°Arrivage', 'arrivage', 1.3, None, None), ('Fournisseur', 'fournisseur', 2.4, None, None),
    ('Code Fournisseur', 'code_fournisseur', 1.2, None, None), ('Date Embarq.', 'date_embarquement', 1.2, 'date', None),
    ('Date Arrivée', 'date_arrivee', 1.2, 'date', None), ('Produit', 'produit', 1.5, None, None),
    ('Désignation', 'designation', 3.2, None, None), ('Origine', 'origine', 1.1, None, None),
    ('Conditionnement', 'conditionnement', 1.6, None, None), ('Frigo', 'frigo', 1.0, None, None),
    ('N° Lot', 'lot', 1.4, None, None), ('D. L. C.', 'dlc', 1.2, 'date', None), ('Unité', 'unite', 0.7, None, None),
    ('Nb Colis Entrées', 'nb_colis', 0.9, '#,##0', None), ('Poids Colis', 'poids_colis', 0.8, '#,##0.##', None),
    ('Poids Total', 'poids_total', 1.1, '#,##0', None), ('pa', 'pa', 0.8, '#,##0.00', None),
]
jeu_s, p_s = jeu('SyntheseDS', SQL_SYNTHESE, COLS_SYNTHESE)
rapport('LvmeSyntheseArrivages.rptdesign', p_s | {'Filtres'}, [jeu_s],
        entete('Synthèse des Arrivages', FILTRES)
        + tableau('SyntheseDS', COLS_SYNTHESE, LIGNES_SYNTHESE, ('#A0F8F8', '#A0F8F8'),
                  prop('backgroundColor', '#DCDCDC'), sommes=('nb_colis', 'poids_total'),
                  groupe=('arrivage', 'Totaux', '#A0F8F8', ('nb_colis', 'poids_total'),
                          ('arrivage', 'fournisseur', 'code_fournisseur', 'date_embarquement', 'date_arrivee')),
                  extra_ligne=prop('color', '#8B2BC9')))

# ---------- liste des RFA par produit / facture (même période que l'écran, somme HT et remise) ----------
SQL_RFA = '''SELECT r.groupement_code, r.groupement_nom, r.client_code, r.client_nom, r.numero_facture, r.date_facture,
  r.produit, r.montant_ht, r.pourc_rfa, r.montant_rfa
FROM lvme_rfa_facture r
WHERE r.date_facture BETWEEN CAST(:Du AS date) AND CAST(:Au AS date)
ORDER BY r.groupement_code, r.client_code, r.date_facture, r.numero_facture'''
COLS_RFA = [('groupement_code', 'string'), ('groupement_nom', 'string'), ('client_code', 'string'),
            ('client_nom', 'string'), ('numero_facture', 'string'), ('date_facture', 'date'), ('produit', 'string'),
            ('montant_ht', 'decimal'), ('pourc_rfa', 'decimal'), ('montant_rfa', 'decimal')]
LIGNES_RFA = [
    ('Groupement', 'groupement_code', 1.4, None, None), ('Nom Groupement', 'groupement_nom', 2.8, None, None),
    ('Client', 'client_code', 1.5, None, None), ('Nom', 'client_nom', 3.8, None, None),
    ('Numéro Facture', 'numero_facture', 1.6, None, None), ('Date Facture', 'date_facture', 1.4, 'date', None),
    ('Produit', 'produit', 4.4, None, None), ('Montant H.T.', 'montant_ht', 1.6, '#,##0.00', None),
    ('% Remise', 'pourc_rfa', 1.0, '#,##0.00', None), ('Montant Remise', 'montant_rfa', 1.6, '#,##0.00', None),
]
jeu_f, p_f = jeu('RfaDS', SQL_RFA, COLS_RFA)
rapport('LvmeListeRfa.rptdesign', p_f | {'Filtres'}, [jeu_f],
        entete('Liste des RFA par produit / facture', FILTRES)
        + tableau('RfaDS', COLS_RFA, LIGNES_RFA, ('#FFFFFF', '#EEF4FC'),
                  prop('backgroundColor', '#CFE3FB'), sommes=('montant_ht', 'montant_rfa')))

# ---------- palmarès clients par produits (par tonnage, écran « Palmarès Client / Produits » de GESCOM) ----------
SQL_PALMARES = '''WITH lignes AS (
  SELECT so.client_partner AS client, sol.product, sol.nb_colis, sol.qty, sol.unit, sol.poids_total_net AS poids,
         sol.ex_tax_total AS ca,
         COALESCE((SELECT COALESCE(sm.real_date, sm.estimated_date) FROM stock_stock_move sm
                   WHERE sm.id = (SELECT max(sml.stock_move) FROM stock_stock_move_line sml
                                  WHERE sml.sale_order_line = sol.id AND sml.stock_move IN (
                                    SELECT s.id FROM stock_stock_move s WHERE s.status_select <> 4))),
                  so.order_date, so.creation_date) AS dt
  FROM sale_sale_order_line sol
  JOIN sale_sale_order so ON so.id = sol.sale_order
  JOIN base_partner cli ON cli.id = so.client_partner
  JOIN base_product pr ON pr.id = sol.product
  LEFT JOIN base_address adr ON adr.id = cli.main_address
  LEFT JOIN auth_user com ON com.id = cli.commercial
  WHERE so.template = false AND so.status_select IN (3, 4)
    AND (CAST(:Client AS bigint) = 0 OR so.client_partner = CAST(:Client AS bigint))
    AND (CAST(:FamilleClient AS bigint) = 0 OR cli.partner_category = CAST(:FamilleClient AS bigint))
    AND (:ComDu = '' OR coalesce(com.code, '') >= :ComDu) AND (:ComAu = '' OR coalesce(com.code, '') <= :ComAu)
    AND (CAST(:Pays AS bigint) = 0 OR adr.country = CAST(:Pays AS bigint))
    AND (CAST(:Groupement AS bigint) = 0 OR cli.groupement = CAST(:Groupement AS bigint))
    AND (CAST(:Produit AS bigint) = 0 OR sol.product = CAST(:Produit AS bigint))
    AND (CAST(:FamilleProduit AS bigint) = 0 OR pr.product_category = CAST(:FamilleProduit AS bigint))
    AND (CAST(:Fournisseur AS bigint) = 0 OR pr.default_supplier_partner = CAST(:Fournisseur AS bigint))
    AND (:Conditionnement = '' OR EXISTS (SELECT 1 FROM purchase_conditionnement pc WHERE pc.id = sol.conditionnement
           AND lower(coalesce(pc.code, '') || ' ' || coalesce(pc.label, '')) LIKE '%' || lower(:Conditionnement) || '%'))
    AND (:Origine = '' OR EXISTS (SELECT 1 FROM supplychain_sale_order_line_lot x
           JOIN stock_tracking_number tn ON tn.id = x.tracking_number
           JOIN stock_stock_move_line oml ON oml.id = tn.origin_stock_move_line
           WHERE x.sale_order_line = sol.id AND oml.origine = :Origine))),
agg AS (
  SELECT client, product, sum(nb_colis) AS nb_colis, sum(qty) AS qte_uv, max(unit) AS unite, sum(poids) AS poids,
         sum(ca) AS ca, max(dt) AS derniere_date
  FROM lignes WHERE dt BETWEEN CAST(:Du AS date) AND CAST(:Au AS date) GROUP BY client, product),
tot AS (SELECT client, sum(poids) AS poids_client FROM agg GROUP BY client)
SELECT cli.partner_seq AS client_code, cli.name AS client_nom, pr.code AS produit, pr.name AS designation,
       a.nb_colis, a.qte_uv, u.name AS unite, a.poids, a.ca, a.derniere_date,
       round(a.ca / NULLIF(a.qte_uv, 0), 2) AS prix_uv,
       rank() OVER (PARTITION BY a.client ORDER BY a.poids DESC NULLS LAST, a.ca DESC) AS rang_produit,
       dense_rank() OVER (ORDER BY t.poids_client DESC NULLS LAST, a.client) AS rang_client,
       lpad(dense_rank() OVER (ORDER BY t.poids_client DESC NULLS LAST, a.client)::text, 6, '0') AS cle_client
FROM agg a
JOIN tot t ON t.client = a.client
JOIN base_partner cli ON cli.id = a.client
JOIN base_product pr ON pr.id = a.product
LEFT JOIN base_unit u ON u.id = a.unite
ORDER BY rang_client, rang_produit'''
COLS_PALMARES = [('client_code', 'string'), ('client_nom', 'string'), ('produit', 'string'), ('designation', 'string'),
                 ('nb_colis', 'decimal'), ('qte_uv', 'decimal'), ('unite', 'string'), ('poids', 'decimal'),
                 ('ca', 'decimal'), ('derniere_date', 'date'), ('prix_uv', 'decimal'), ('rang_produit', 'integer'),
                 ('rang_client', 'integer'), ('cle_client', 'string')]
LIGNES_PALMARES = [
    ('Client', 'client_code', 1.6, None, None), ('Nom', 'client_nom', 3.4, None, None),
    ('Produit', 'produit', 1.8, None, None), ('Désignation', 'designation', 4.6, None, None),
    ('Nb colis', 'nb_colis', 1.0, '#,##0', None), ('Qtés en UV', 'qte_uv', 1.1, '#,##0', None),
    ('Unité', 'unite', 0.8, None, None), ('Poids KG', 'poids', 1.2, '#,##0', None),
    ('C.A. HT', 'ca', 1.4, '#,##0', None), ('Dern. Date', 'derniere_date', 1.3, 'date', None),
    ('Prix à U.V', 'prix_uv', 1.0, '#,##0.00', None), ('Rang', 'rang_produit', 0.7, '#,##0', None),
    ('Rang', 'rang_client', 0.7, '#,##0', None),
]
SOMMES_PALM = ('nb_colis', 'qte_uv', 'poids', 'ca')
jeu_m, p_m = jeu('PalmaresDS', SQL_PALMARES, COLS_PALMARES)
rapport('LvmePalmaresClientsProduits.rptdesign', p_m | {'Filtres'}, [jeu_m],
        entete('Palmarès Clients par Produits', FILTRES)
        + tableau('PalmaresDS', COLS_PALMARES, LIGNES_PALMARES, ('#FFFFFF', '#FFFFFF'),
                  prop('backgroundColor', '#DCDCDC'), sommes=SOMMES_PALM,
                  groupe=('cle_client', 'Total client', '#F0F0F0', SOMMES_PALM,
                          ('client_code', 'client_nom', 'rang_client'))))

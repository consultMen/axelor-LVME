-- =====================================================================
-- PROD étape 63 : fiche Commande client copiée sur la « Fiche Commande client » GESCOM
--   - en-tête sur une rangée : Client (encadré bleu : client, commercial, adresse, contact, téléphone,
--     règlement, échéance, % Rem/Fact., % RFA, % Frais Commission) | Commande (n°, opérateur, date commande,
--     date livraison, réservation, ref cde, transporteur, port payé, coût port/kg, commentaire) | Totaux
--     (Nb Colis, Poids, Total HT, Total TTC, % Marge Totale, Total marge) | boutons (Imprimer commande,
--     Confirmer, Annuler, livraisons, facture…)
--   - barre de statuts et onglets du bas conservés ; plus de barre latérale (onglet « Suivi ») ;
--     Réservation, Livraison et Paramètres repliés sous l'en-tête. Aucun champ retiré.
--   - Nb Colis / Poids calculés par le serveur sur toutes les lignes, à l'ouverture et à chaque changement
-- Source : livrables/ui/commande-client-form.xml (fiche admin sale-order-form, priorité 30).
--   - champs Préparateur et % Frais Cong. (code de ce lot), Port HT / Port TVA (poids x coût port/kg si le port
--     n'est pas payé, TVA 20 %), couleurs GESCOM (css du code de ce lot)
--   - tableau des lignes dans l'ordre GESCOM : Référence, Désignation, Taux TVA, Numéro Arrivage, Fourn., Ori.,
--     Frigo, Date Livraison, N° Lot, D.D.M., Unit/Pds du Colis, Prix Achat, Colis Rsv, Colis Dispo, Colis Cdes,
--     Unité Vente, Poids en KG, Nb unités ou Poids cdés, Prix Revient, Prix Vente, promo, Montant, % Marge
--     (colonnes du lot calculées par le code de ce lot ; case promo = nouvelle colonne)
-- À lancer depuis la racine du dépôt, avant le redémarrage. Relançable.
-- =====================================================================
\set fiche `cat livrables/ui/commande-client-form.xml`
SELECT set_config('lvme.fiche_client', :'fiche', false) IS NOT NULL AS fiche_lue;
\set grille `cat livrables/ui/sale-order-line-grid.xml`
SELECT set_config('lvme.grille_lignes', :'grille', false) IS NOT NULL AS grille_lue;

BEGIN;

-- champs GESCOM de la commande (code de ce lot)
ALTER TABLE sale_sale_order ADD COLUMN IF NOT EXISTS lvme_preparateur bigint;
ALTER TABLE sale_sale_order ADD COLUMN IF NOT EXISTS lvme_frais_congelation numeric(5,2);
ALTER TABLE sale_sale_order_line ADD COLUMN IF NOT EXISTS lvme_promo boolean;

DELETE FROM meta_action WHERE module IS NULL AND name = 'action-lvme-commande-client-attrs-somme';
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-commande-client-attrs-somme', 'action-attrs', 'com.axelor.apps.sale.db.SaleOrder',
'<action-attrs name="action-lvme-commande-client-attrs-somme" model="com.axelor.apps.sale.db.SaleOrder">
  <attribute name="value" for="$sommeColis" expr="eval: (saleOrderLineList ?: []).sum(0.0) { it.nbColis ?: 0.0 }"/>
  <attribute name="value" for="$sommePoids" expr="eval: (saleOrderLineList ?: []).sum(0.0) { it.poidsTotalNet ?: 0.0 }"/>
  <attribute name="value" for="$portHt" expr="eval: portPaye ? 0 : (saleOrderLineList ?: []).sum(0.0) { it.poidsTotalNet ?: 0.0 } * (coutPortKg ?: 0.0)"/>
  <attribute name="value" for="$portTva" expr="eval: portPaye ? 0 : (saleOrderLineList ?: []).sum(0.0) { it.poidsTotalNet ?: 0.0 } * (coutPortKg ?: 0.0) * 0.20"/>
</action-attrs>', false, false, 0);

DO $$
DECLARE v_id bigint; v_xml text;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30;
  IF v_id IS NULL THEN RAISE EXCEPTION 'sale-order-form (admin) introuvable : arrêt'; END IF;
  IF position('name="lvmeClientPanel"' IN v_xml) = 0 OR position('name="mainPanelTab"' IN v_xml) = 0 THEN
    RAISE EXCEPTION 'fiche commande client non reconnue : arrêt, rien n''est modifié';
  END IF;
  UPDATE meta_view SET xml = current_setting('lvme.fiche_client'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE id = v_id AND xml IS DISTINCT FROM current_setting('lvme.fiche_client');
  -- tableau des lignes : couleurs GESCOM (colonnes jaune pâle / jaune vif)
  UPDATE meta_view SET xml = current_setting('lvme.grille_lignes'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE name = 'sale-order-line-grid' AND module IS NULL AND priority = 30
     AND xml IS DISTINCT FROM current_setting('lvme.grille_lignes');
END $$;

COMMIT;

SELECT position('name="lvmeGescomPanel"' IN xml) > 0 AS fiche_gescom, position('sidebar="true"' IN xml) = 0 AS sans_barre_laterale
FROM meta_view WHERE name = 'sale-order-form' AND module IS NULL AND priority = 30;

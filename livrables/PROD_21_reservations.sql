-- =====================================================================
-- PROD étape 21 : REC-009 commandes de réservation
--   - colonnes : commande (réservation, validée par/le, convertie le), client (sous contrat)
--   - actions : contrôle des droits (client sous contrat = seul son commercial modifie),
--     « Valider la réservation », « Convertir en commande ferme »
--   - Listes Commandes Clients : état « Réservations » + colonnes Réservation / Âge
--   - fiche client : case « Sous contrat » sous le Commercial
--   - menu « Comptes de réservation » (inutilisé : 0 stock, 0 mouvement) masqué
-- Prérequis : PROD_7 relancé juste avant (panneau Réservation de la fiche commande).
-- À lancer depuis la racine du dépôt, AVANT le redémarrage d'Axelor. Relançable. Une seule transaction.
-- =====================================================================
BEGIN;

-- ---------- Colonnes ----------
ALTER TABLE sale_sale_order ADD COLUMN IF NOT EXISTS is_reservation boolean;
ALTER TABLE sale_sale_order ADD COLUMN IF NOT EXISTS reservation_validated_by bigint;
ALTER TABLE sale_sale_order ADD COLUMN IF NOT EXISTS reservation_validated_on timestamp;
ALTER TABLE sale_sale_order ADD COLUMN IF NOT EXISTS reservation_converted_on timestamp;
ALTER TABLE base_partner ADD COLUMN IF NOT EXISTS sous_contrat boolean;

-- ---------- Actions ----------
DELETE FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-reservation-check-droits',
  'action-lvme-reservation-valider', 'action-lvme-reservation-group-valider',
  'action-lvme-reservation-confirm-convertir', 'action-lvme-reservation-convertir',
  'action-lvme-reservation-group-convertir');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom) VALUES
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-check-droits', 'action-validate', NULL,
'<action-validate name="action-lvme-reservation-check-droits">
  <error message="Client sous contrat : seul son commercial référent peut modifier cette réservation."
    if="isReservation &amp;&amp; clientPartner?.sousContrat &amp;&amp; clientPartner?.commercial != null &amp;&amp; clientPartner.commercial.id != __user__.id"/>
</action-validate>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-valider', 'action-record', 'com.axelor.apps.sale.db.SaleOrder',
'<action-record name="action-lvme-reservation-valider" model="com.axelor.apps.sale.db.SaleOrder">
  <field name="reservationValidatedBy" expr="eval: __user__"/>
  <field name="reservationValidatedOn" expr="eval: __datetime__"/>
</action-record>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-group-valider', 'action-group', NULL,
'<action-group name="action-lvme-reservation-group-valider">
  <action name="action-lvme-reservation-valider"/>
  <action name="save"/>
</action-group>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-confirm-convertir', 'action-validate', NULL,
'<action-validate name="action-lvme-reservation-confirm-convertir">
  <alert message="Convertir cette réservation en commande ferme ? Le BL pourra alors être réalisé."/>
</action-validate>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-convertir', 'action-record', 'com.axelor.apps.sale.db.SaleOrder',
'<action-record name="action-lvme-reservation-convertir" model="com.axelor.apps.sale.db.SaleOrder">
  <field name="isReservation" expr="eval: false"/>
  <field name="reservationConvertedOn" expr="eval: __datetime__"/>
</action-record>', false, false),
(nextval('meta_action_seq'), 0, now(), 'action-lvme-reservation-group-convertir', 'action-group', NULL,
'<action-group name="action-lvme-reservation-group-convertir">
  <action name="action-lvme-reservation-check-droits"/>
  <action name="action-lvme-reservation-confirm-convertir"/>
  <action name="action-lvme-reservation-convertir"/>
  <action name="save"/>
</action-group>', false, false);

-- ---------- Listes Commandes Clients : état « Réservations » ----------
INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq)
SELECT nextval('meta_select_item_seq'), 0, s.id, '4', 'Réservations', 4
FROM meta_select s
WHERE s.name = 'lvme.commande.client.etat.select'
  AND NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND i.value = '4');

DO $$
DECLARE v_id bigint; v_xml text; a text; b text; n int;
BEGIN
  -- domaine de la liste : les réservations sortent des « en cours » et ont leur propre état
  SELECT id, xml INTO v_id, v_xml FROM meta_action WHERE name = 'action-lvme-cde-client-dashlet' AND module IS NULL;
  IF v_id IS NULL THEN RAISE EXCEPTION 'action-lvme-cde-client-dashlet introuvable (PROD_10 non passé ?) : arrêt'; END IF;
  IF position(':_etat = 4' IN v_xml) = 0 THEN
    a := '(:_etat = 1 AND self.statusSelect = 3 AND self.deliveryState != 3)';
    b := 'OR :_etat = 3)';
    IF position(a IN v_xml) = 0 OR position(b IN v_xml) = 0 THEN
      RAISE EXCEPTION 'domaine des commandes clients non reconnu : arrêt, rien n''est modifié';
    END IF;
    v_xml := replace(v_xml, a, '(:_etat = 1 AND self.statusSelect = 3 AND self.deliveryState != 3 AND (self.isReservation IS NULL OR self.isReservation = false))');
    v_xml := replace(v_xml, b, 'OR :_etat = 3
         OR (:_etat = 4 AND self.isReservation = true AND self.statusSelect = 3))');
    UPDATE meta_action SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
    RAISE NOTICE 'Liste : état Réservations ajouté';
  ELSE
    RAISE NOTICE 'Liste : état Réservations déjà présent';
  END IF;

  -- colonnes de la grille
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'lvme-commande-client-grid' AND module IS NULL;
  IF v_id IS NULL THEN RAISE EXCEPTION 'lvme-commande-client-grid introuvable : arrêt'; END IF;
  IF position('isReservation' IN v_xml) = 0 THEN
    SELECT count(*) INTO n FROM regexp_matches(v_xml, '<field name="saleOrderSeq"[^>]*/>', 'g');
    IF n <> 1 THEN RAISE EXCEPTION 'colonne N° Commande trouvée % fois (1 attendu) : arrêt', n; END IF;
    v_xml := regexp_replace(v_xml, '(<field name="saleOrderSeq"[^>]*/>)',
      '<hilite color="warning" if="isReservation"/>
  ' || chr(92) || '1
  <field name="isReservation" title="Réservation" width="95"/>
  <field name="reservationAge" title="Âge résa (j)" width="90"/>');
    UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
    RAISE NOTICE 'Grille : colonnes Réservation / Âge ajoutées';
  ELSE
    RAISE NOTICE 'Grille : colonnes déjà présentes';
  END IF;
END $$;

-- ---------- Fiche client : « Sous contrat » sous le Commercial ----------
DO $$
DECLARE src text; res text; p text; n int;
BEGIN
  -- source : la vue de module (jamais une vue déjà transformée)
  SELECT xml INTO src FROM meta_view
   WHERE name = 'partner-form' AND module IS NOT NULL AND COALESCE(extension, false) = false
     AND xml NOT LIKE '%sousContrat%'
   ORDER BY priority DESC, COALESCE(computed, false) DESC LIMIT 1;
  IF src IS NULL THEN RAISE EXCEPTION 'partner-form introuvable'; END IF;
  p := '(<field (?:[^"/>]|"[^"]*")*name="commercial"(?:[^"/>]|"[^"]*")*/>)';
  SELECT count(*) INTO n FROM regexp_matches(src, p, 'g');
  IF n <> 1 THEN RAISE EXCEPTION 'Champ commercial trouvé % fois (1 attendu) : arrêt', n; END IF;
  res := regexp_replace(src, p, chr(92) || '1<field name="sousContrat" title="Sous contrat" colSpan="6" widget="boolean-switch" help="Réservations modifiables uniquement par le commercial du client"/>');

  DELETE FROM meta_view WHERE name = 'partner-form' AND module IS NULL AND priority = 30;
  INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed)
  SELECT nextval('meta_view_seq'), 0, now(), name, title, type, model, 30, res, false, false
  FROM meta_view WHERE name = 'partner-form' AND module IS NOT NULL AND COALESCE(extension, false) = false
    AND xml NOT LIKE '%sousContrat%'
  ORDER BY priority DESC, COALESCE(computed, false) DESC LIMIT 1;
  RAISE NOTICE 'Fiche client : Sous contrat ajouté';
END $$;

-- ---------- Menu « Comptes de réservation » masqué ----------
UPDATE meta_menu SET hidden = true WHERE name = 'sale-menu-comptes-reservation';

COMMIT;

SELECT s.name, i.value, i.title FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
WHERE s.name = 'lvme.commande.client.etat.select' ORDER BY i.order_seq;
SELECT name, priority, position('sousContrat' IN xml) > 0 AS sous_contrat FROM meta_view WHERE name = 'partner-form' AND module IS NULL;

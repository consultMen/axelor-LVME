-- =====================================================================
-- PROD étape 54 : fiche Tiers (Fournisseur / Client) : informations principales en haut
--   - « Adresses postales » et « Coordonnées » (téléphone, mobile, email, site, assigné à, sociétés)
--     sortent de l'onglet Informations et passent en haut, côte à côte, sous le nom du tiers
--   - « Détails du tiers » (catégorie, secteur, SIRET, CA, NAF…) replié par défaut
--   - les onglets (Informations, Facturation/Paiement, Fournisseur, Livraison…) restent en dernier
--   Aucun champ retiré. Après PROD_52.
-- Relançable. Pas de redémarrage nécessaire.
-- =====================================================================
BEGIN;

DO $$
DECLARE v_id bigint; v_xml text; t_postal text; t_contact text; t_employe text; t_props text; t_details text;
        p_debut int; p_fin int; bloc text;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'partner-form' AND module IS NULL AND priority = 30;
  IF v_id IS NULL THEN RAISE EXCEPTION 'partner-form (admin) introuvable : arrêt'; END IF;
  IF position('lvme-infos-en-haut' IN v_xml) > 0 THEN
    RAISE NOTICE 'déjà passé';
    RETURN;
  END IF;

  -- balises d'ouverture des panneaux concernés (chacune doit exister une seule fois)
  t_postal  := (regexp_match(v_xml, '<panel[^<]*?name="postalAddressesPanel"[^<]*?>'))[1];
  t_contact := (regexp_match(v_xml, '<panel[^<]*?name="generalContactDetailsPanel"[^<]*?>'))[1];
  t_employe := (regexp_match(v_xml, '<panel[^<]*?name="employeePanel"[^<]*?>'))[1];
  t_props   := (regexp_match(v_xml, '<panel[^<]*?name="propertiesPanel"[^<]*?>'))[1];
  t_details := (regexp_match(v_xml, '<panel[^<]*?name="partnerDetailsPanel"[^<]*?>'))[1];
  IF t_postal IS NULL OR t_contact IS NULL OR t_employe IS NULL OR t_props IS NULL OR t_details IS NULL THEN
    RAISE EXCEPTION 'panneaux de la fiche tiers non reconnus : arrêt, rien n''est modifié';
  END IF;
  p_debut := position(t_postal IN v_xml);
  p_fin := position(t_employe IN v_xml);
  -- les deux panneaux se suivent dans l'onglet Informations, juste avant employeePanel
  IF NOT (p_debut < position(t_contact IN v_xml) AND position(t_contact IN v_xml) < p_fin)
     OR position(t_props IN v_xml) > p_debut THEN
    RAISE EXCEPTION 'ordre des panneaux de la fiche tiers inattendu : arrêt, rien n''est modifié';
  END IF;

  bloc := substring(v_xml FROM p_debut FOR p_fin - p_debut);
  v_xml := overlay(v_xml PLACING '' FROM p_debut FOR p_fin - p_debut);
  -- côte à côte en haut
  bloc := replace(bloc, t_postal, replace(t_postal, 'colSpan="12"', 'colSpan="6"'));
  bloc := replace(bloc, t_contact, replace(t_contact, 'colSpan="12"', 'colSpan="6"'));
  v_xml := replace(v_xml, t_props,
    '<!-- LVME lvme-infos-en-haut : adresses et coordonnées du tiers en haut de la fiche -->' || chr(10) || '  '
    || bloc || t_props);
  -- détails replié
  IF position('canCollapse' IN t_details) = 0 THEN
    v_xml := replace(v_xml, t_details, regexp_replace(t_details, '>$', ' canCollapse="true" collapseIf="true">'));
  END IF;

  UPDATE meta_view SET xml = v_xml, updated_on = now(), version = COALESCE(version, 0) + 1 WHERE id = v_id;
END $$;

COMMIT;

SELECT position('lvme-infos-en-haut' IN xml) > 0 AS infos_en_haut,
       position('name="postalAddressesPanel"' IN xml) < position('name="mainPanelTab"' IN xml) AS adresses_avant_onglets
FROM meta_view WHERE name = 'partner-form' AND module IS NULL AND priority = 30;

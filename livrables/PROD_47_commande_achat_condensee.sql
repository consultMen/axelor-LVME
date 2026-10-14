-- =====================================================================
-- PROD étape 47 : fiche Commande d'achat condensée comme la fiche Arrivage (copie GESCOM)
--   - en-tête sur une rangée : Fournisseur (encadré bleu) | Commande (opérateur, frigo, n°, date,
--     nature, départ, arrivée, transport) | Devise (devises, cours, couvert, flottant, réel, totaux)
--     | Actions (boutons A embarquer / Flottant / En Stock / Annuler…)
--   - plus de barre latérale ni de bloc « Paramètres » (société, liste de prix, position fiscale…
--     restent remplis automatiquement, en champs cachés)
--   - onglets du bas inchangés (Contenu, Livraison, Echéancier, Impression…) ; l'ancienne barre
--     latérale (suivi, dates, références, note interne) passe dans un dernier onglet « Suivi »
--   Mêmes champs, actions et calculs qu'avant : disposition seulement.
-- Source : livrables/ui/commande-achat-form.xml (fiche admin purchase-order-form, priorité 30).
-- Prérequis : PROD_45 (fiche ligne de commande d'achat). À lancer depuis la racine du dépôt.
-- Pas de redémarrage nécessaire (recharger la page). Relançable.
-- =====================================================================
\set fiche `cat livrables/ui/commande-achat-form.xml`
SELECT set_config('lvme.fiche_achat', :'fiche', false) IS NOT NULL AS fiche_lue;

BEGIN;

DO $$
DECLARE v_id bigint; v_xml text;
BEGIN
  SELECT id, xml INTO v_id, v_xml FROM meta_view WHERE name = 'purchase-order-form' AND module IS NULL AND priority = 30;
  IF v_id IS NULL THEN RAISE EXCEPTION 'purchase-order-form (admin) introuvable : arrêt'; END IF;
  IF position('form-view="lvme-commande-achat-line-form"' IN v_xml) = 0 THEN
    RAISE EXCEPTION 'PROD_45 non passé (fiche ligne de commande d''achat) : arrêt';
  END IF;
  UPDATE meta_view SET xml = current_setting('lvme.fiche_achat'), updated_on = now(), version = COALESCE(version, 0) + 1
   WHERE id = v_id AND xml IS DISTINCT FROM current_setting('lvme.fiche_achat');
END $$;

COMMIT;

SELECT position('name="lvmeCommandePanel"' IN xml) > 0 AS commande_condensee,
       position('sidebar="true"' IN xml) = 0 AS sans_barre_laterale
FROM meta_view WHERE name = 'purchase-order-form' AND module IS NULL AND priority = 30;

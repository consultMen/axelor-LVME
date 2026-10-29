-- =====================================================================
-- PROD étape 110 : commandes clients reprises de GESCOM, durée de période à 1 (correctif du 29/10/2026)
--   Les commandes de MIG_06 ont la « durée de période » Axelor vide : Axelor la lit 0 et refuse d'enregistrer
--   (« numberOfPeriods doit être supérieur ou égal à 1 ») : bouton Dupliquer en erreur, et modification d'une
--   commande reprise impossible à enregistrer. Valeur Axelor par défaut : 1. Aucun montant ni statut modifié.
--   Avec le code corrigé (LvmeDuplicationService) : la copie part en devis brouillon, sans le n° de facture GESCOM.
-- Pas de redémarrage nécessaire (données seulement). Relançable.
-- =====================================================================
BEGIN;

UPDATE sale_sale_order SET number_of_periods = 1
WHERE number_of_periods IS NULL OR number_of_periods < 1;

COMMIT;

-- contrôle : 0 commande sans durée de période
SELECT count(*) AS commandes_sans_duree FROM sale_sale_order WHERE number_of_periods IS NULL OR number_of_periods < 1;

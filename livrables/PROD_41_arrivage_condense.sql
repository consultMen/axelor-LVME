-- =====================================================================
-- PROD étape 41 : fiche Arrivage condensée comme GESCOM (demande client)
--   Copie de l'écran « Arrivages » GESCOM (même ordre, mêmes blocs), tout visible sans défiler :
--   - Fournisseur : fournisseur, code ; adresse, code postal ; ville, pays ; contact ; tél., email ;
--     règlement, échéance (de la commande fournisseur, à défaut du fournisseur)
--   - Arrivage : opérateur, frigo ; n°, du ; à embarquer, nature ; départ, arrivée ; type transport,
--     bateau ; containers, transitaire
--   - Devise, cours, couvert, flottant, réel + tableau GESCOM Flottant => / Réel => (Mt Achat HT,
--     Nb Colis, Poids Total, Frais Appr, cases jaunes)
--   - Actions à droite ; champs absents de GESCOM retirés de l'écran (gardés cachés pour le fonctionnement)
--   Champs calculés du code (Contact, Règlement, Echéance, Frais) : à déployer avec ce script.
-- Relance PROD_9 depuis sa source à jour (livrables/ui/arrivage-form.xml).
-- À lancer depuis la racine du dépôt, après PROD_38. Relançable.
-- =====================================================================

\i livrables/PROD_9_arrivages.sql

SELECT name,
       position('lvmeFournisseurPanel" colSpan="4"' IN xml) > 0 AS bloc_fournisseur,
       position('lvmeDevisePanel' IN xml) > 0 AS tableau_flottant_reel,
       position('lvmeAppliquerFrigoBtn' IN xml) > 0 AS bouton_frigo
FROM meta_view WHERE module IS NULL AND name = 'lvme-arrivage-form';

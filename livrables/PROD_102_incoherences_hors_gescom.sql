-- =====================================================================
-- PROD étape 102 : « Rapport d'incohérences » sans l'historique repris de GESCOM
--   Les factures clients et fournisseurs de GESCOM ne sont pas recréées dans Axelor (décision du 28/10/2026, n° de
--   facture noté sur la commande) : les écarts « BL : livré ≠ facturé » et « Réception : reçu ≠ facturé » ne portent
--   plus sur les commandes et arrivages repris de GESCOM (import_origin = 'GESCOM').
--   Vue lvme_incoherence (sql/lvme_incoherence.sql), mêmes colonnes : pas de redémarrage nécessaire.
-- À lancer depuis la racine du dépôt. Relançable.
-- =====================================================================
BEGIN;
\i open-suite-webapp/modules/axelor-open-suite/axelor-supplychain/src/main/resources/sql/lvme_incoherence.sql
COMMIT;

SELECT type_label, count(*) AS ecarts FROM lvme_incoherence GROUP BY type_label ORDER BY 1;

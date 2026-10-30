-- =====================================================================
-- MIG_10 : comptes de réservation GESCOM (table CLIENT_RESERV)
--   Dans GESCOM, une réservation est une commande passée au nom d'un compte de réservation (client « CASINO
--   RESERVATIONS », « SYSCO - RESERVATION »…) pour un groupe de clients livrés. CLIENT_RESERV dit quel client livré
--   dépend de quel compte (239 liens, 53 comptes).
--   - repère « Compte de réservation » sur les 53 comptes (Partner.lvmeEstCompteReservation) ;
--   - compte de réservation de chaque client livré (Partner.lvmeCompteReservation).
--   Rapprochement par le code client GESCOM (référence du tiers). Consultation : Ventes > Réservations (PROD_119).
-- Prérequis : MIG_02 (tiers). Colonnes créées si besoin (avant le premier démarrage du code). Tomcat arrêté.
-- Relançable.
-- =====================================================================
BEGIN;

ALTER TABLE base_partner
  ADD COLUMN IF NOT EXISTS lvme_est_compte_reservation boolean,
  ADD COLUMN IF NOT EXISTS lvme_compte_reservation bigint;

CREATE TEMP TABLE mig_resa ON COMMIT DROP AS
SELECT DISTINCT ON (upper(btrim(r.client_livr))) upper(btrim(r.client_livr)) AS livre, upper(btrim(r.client_reserv)) AS compte
FROM gescom.client_reserv r
WHERE gescom.txt(r.client_livr) IS NOT NULL AND gescom.txt(r.client_reserv) IS NOT NULL
ORDER BY upper(btrim(r.client_livr)), gescom.num(r.idclient_reserv) DESC;

-- comptes de réservation
UPDATE base_partner p SET lvme_est_compte_reservation = true, version = p.version + 1, updated_on = now()
WHERE p.partner_seq IN (SELECT compte FROM mig_resa) AND p.lvme_est_compte_reservation IS NOT TRUE;

-- client livré -> son compte de réservation
UPDATE base_partner p SET lvme_compte_reservation = c.id, version = p.version + 1, updated_on = now()
FROM mig_resa m
JOIN base_partner c ON c.partner_seq = m.compte
WHERE p.partner_seq = m.livre AND p.id <> c.id AND p.lvme_compte_reservation IS DISTINCT FROM c.id;

COMMIT;

-- contrôles : liens GESCOM, comptes repérés, clients rattachés
SELECT (SELECT count(*) FROM gescom.client_reserv) AS liens_gescom,
  (SELECT count(*) FROM base_partner WHERE lvme_est_compte_reservation) AS comptes_reservation,
  (SELECT count(*) FROM base_partner WHERE lvme_compte_reservation IS NOT NULL) AS clients_rattaches;
-- liens GESCOM non repris (client livré ou compte absent de LVME, ou client lié à lui-même)
SELECT btrim(r.client_livr) AS client_livre, btrim(r.nom_clt_livre) AS nom, btrim(r.client_reserv) AS compte
FROM gescom.client_reserv r
WHERE NOT EXISTS (SELECT 1 FROM base_partner p JOIN base_partner c ON c.id = p.lvme_compte_reservation
                  WHERE p.partner_seq = upper(btrim(r.client_livr)) AND c.partner_seq = upper(btrim(r.client_reserv)));

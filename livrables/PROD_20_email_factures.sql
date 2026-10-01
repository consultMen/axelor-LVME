-- =====================================================================
-- PROD étape 20 : REC-011 — envoi automatique des factures clients par email à la ventilation
--   Circuit : facture Validée (impression de contrôle) -> Ventilée (approbation) -> email automatique
--   1. Modèle d'email « Facture client LVME » (facture PDF en pièce jointe)
--      >>> PHASE DE TEST : destinataire forcé à zakarialaachiri2@gmail.com (aucun email aux vrais clients) <<<
--      Passage en réel : relancer avec la variable destinataire (voir en bas du fichier).
--   2. Configuration comptable de la société : envoi automatique à la ventilation + ce modèle
--   3. Situation comptable de chaque client : idem (Axelor recopie ces réglages client par client)
-- Prérequis : un compte email d'envoi (SMTP) créé dans Administration > Comptes email (par vous :
-- il contient un mot de passe). Sans compte, la ventilation passe mais l'email n'est pas envoyé.
-- Relançable. Une seule transaction. Pas de redémarrage nécessaire.
-- =====================================================================
\if :{?destinataire}
\else
  \set destinataire 'zakarialaachiri2@gmail.com'
\endif
SELECT set_config('lvme.destinataire', :'destinataire', false);

BEGIN;

DO $$
DECLARE v_tpl bigint; v_model bigint; v_print bigint;
BEGIN
  SELECT id INTO v_model FROM meta_model WHERE full_name = 'com.axelor.apps.account.db.Invoice';
  IF v_model IS NULL THEN RAISE EXCEPTION 'modèle Invoice introuvable : arrêt'; END IF;

  -- 1. Modèle d'email
  SELECT id INTO v_tpl FROM message_template WHERE name = 'Facture client LVME';
  IF v_tpl IS NULL THEN
    v_tpl := nextval('message_template_seq');
    INSERT INTO message_template (id, version, created_on, name, media_type_select, template_engine_select,
                                  meta_model, is_default, is_json, is_system, add_signature)
    VALUES (v_tpl, 0, now(), 'Facture client LVME', 2, 1, v_model, false, false, false, false);
  END IF;
  UPDATE message_template SET
    to_recipients = current_setting('lvme.destinataire'),
    subject = 'LVME Sofrimar - Facture n° $Invoice.invoiceId$',
    content = '<p>Bonjour,</p>'
      || '<p>Veuillez trouver ci-joint notre facture n° <b>$Invoice.invoiceId$</b>'
      || ' (client : $Invoice.partner.fullName$).</p>'
      || '<p>Montant TTC : <b>$Invoice.inTaxTotal$ $Invoice.currency.symbol$</b><br/>'
      || 'Échéance : $Invoice.dueDate$</p>'
      || '<p>Nous restons à votre disposition pour toute question.</p>'
      || '<p>Cordialement,<br/>Le service facturation LVME Sofrimar</p>',
    updated_on = now(), version = COALESCE(version, 0) + 1
  WHERE id = v_tpl;

  -- facture PDF en pièce jointe : modèle d'impression des factures de la configuration comptable
  SELECT invoice_print_template INTO v_print FROM account_account_config WHERE invoice_print_template IS NOT NULL LIMIT 1;
  IF v_print IS NOT NULL AND NOT EXISTS (SELECT 1 FROM message_template_print_template_set
                                         WHERE message_template = v_tpl AND print_template_set = v_print) THEN
    INSERT INTO message_template_print_template_set (message_template, print_template_set) VALUES (v_tpl, v_print);
  END IF;
  IF v_print IS NULL THEN RAISE NOTICE 'Attention : pas de modèle d''impression des factures, l''email partira sans PDF'; END IF;

  -- 2. Configuration comptable
  UPDATE account_account_config SET invoice_automatic_mail = true, invoice_message_template = v_tpl;

  -- 3. Situations comptables des clients
  UPDATE account_accounting_situation s SET invoice_automatic_mail = true, invoice_message_template = v_tpl
  FROM base_partner p WHERE p.id = s.partner AND p.is_customer = true;

  RAISE NOTICE 'Modèle « Facture client LVME » (id %) : destinataire %', v_tpl, current_setting('lvme.destinataire');
END $$;

COMMIT;

SELECT (SELECT count(*) FROM account_accounting_situation s JOIN base_partner p ON p.id = s.partner
        WHERE p.is_customer AND s.invoice_automatic_mail) AS clients_envoi_auto,
       (SELECT count(*) FROM message_email_account) AS comptes_email,
       (SELECT to_recipients FROM message_template WHERE name = 'Facture client LVME') AS destinataire;

-- Passage en réel (après validation des tests) : envoi à l'adresse email du client
--   psql -U axelor axelor -v ON_ERROR_STOP=1 -v destinataire='$Invoice.partner.emailAddress.address$' -f livrables/PROD_20_email_factures.sql

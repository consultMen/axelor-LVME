-- =====================================================================
-- PROD étape 115 : impressions des listes en PDF ET en Excel (demande du 29/10/2026)
--   Chaque bouton d'impression redevient PDF (ouvert à l'écran comme avant) ; un bouton vert « Excel » à côté
--   télécharge la même impression en .xlsx, une seule feuille, mêmes filtres. 14 impressions : liste des achats,
--   Arrivages (Editer), Listes Commandes Clients, État des besoins, les 3 États des stocks, Historique prix,
--   Historique produit, Palmarès, Prix négociés, RFA, Liste des Rotations, Synthèse des arrivages.
--   Boutons Excel placés sans ajouter de hauteur (à côté du bouton, ou dans l'espace vide de la barre).
--   Les actions « …-excel » appellent la même méthode Java : le format suit le nom de l'action
--   (LvmeImpressionListesController.ouvrir). Devis, commandes et bons d'arrivage : inchangés (PDF).
-- Prérequis : code avec ouvrir(request, …) (recompiler). À lancer Tomcat arrêté, puis redémarrer. Relançable.
-- =====================================================================
BEGIN;

-- actions Excel : copies des actions d'impression, nom suivi de « -excel »
DELETE FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-%-excel'
  AND regexp_replace(name, '-excel$', '') IN ('action-lvme-achat-imprimer-liste', 'action-lvme-arrivage-imprimer-liste', 'action-lvme-cde-client-imprimer-liste', 'action-lvme-etat-besoins-imprimer', 'action-lvme-etat-stock-lot-imprimer', 'action-lvme-etat-stock-lot-imprimer-fournisseur', 'action-lvme-etat-stock-lot-imprimer-ligne', 'action-lvme-historique-prix-imprimer', 'action-lvme-historique-produit-imprimer', 'action-lvme-palmares-clients-imprimer', 'action-lvme-prix-negocie-imprimer', 'action-lvme-rfa-facture-imprimer', 'action-lvme-rotation-imprimer-liste', 'action-lvme-synthese-arrivage-imprimer');
INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority)
SELECT nextval('meta_action_seq'), 0, now(), a.name || '-excel', a.type, a.model,
  replace(a.xml, 'name="' || a.name || '"', 'name="' || a.name || '-excel"'), a.home, a.is_custom, a.priority
FROM meta_action a
WHERE a.module IS NULL AND a.name IN ('action-lvme-achat-imprimer-liste', 'action-lvme-arrivage-imprimer-liste', 'action-lvme-cde-client-imprimer-liste', 'action-lvme-etat-besoins-imprimer', 'action-lvme-etat-stock-lot-imprimer', 'action-lvme-etat-stock-lot-imprimer-fournisseur', 'action-lvme-etat-stock-lot-imprimer-ligne', 'action-lvme-historique-prix-imprimer', 'action-lvme-historique-produit-imprimer', 'action-lvme-palmares-clients-imprimer', 'action-lvme-prix-negocie-imprimer', 'action-lvme-rfa-facture-imprimer', 'action-lvme-rotation-imprimer-liste', 'action-lvme-synthese-arrivage-imprimer');

-- boutons Excel à côté des boutons d'impression
UPDATE meta_view SET xml = replace(xml,
    $a$<button name="imprimerListeBtn" title="Imprimer" icon="printer" onClick="action-lvme-achat-imprimer-liste"/>$a$,
    $n$<button colSpan="8" name="imprimerListeBtn" title="Imprimer" icon="printer" onClick="action-lvme-achat-imprimer-liste"/>
    <button name="imprimerListeBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="4" onClick="action-lvme-achat-imprimer-liste-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-achat-search-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(xml,
    $a$<button name="editerListeBtn" title="Editer" icon="printer" onClick="action-lvme-arrivage-imprimer-liste"/>$a$,
    $n$<button colSpan="8" name="editerListeBtn" title="Editer" icon="printer" onClick="action-lvme-arrivage-imprimer-liste"/>
    <button name="editerListeBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="4" onClick="action-lvme-arrivage-imprimer-liste-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-arrivage-search-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(xml,
    $a$<button name="imprimerListeBtn" title="Imprimer" icon="printer" onClick="action-lvme-cde-client-imprimer-liste"/>$a$,
    $n$<button colSpan="8" name="imprimerListeBtn" title="Imprimer" icon="printer" onClick="action-lvme-cde-client-imprimer-liste"/>
    <button name="imprimerListeBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="4" onClick="action-lvme-cde-client-imprimer-liste-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-commande-client-search-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(xml,
    $a$<button name="imprimerBtn" title="Imprimer" icon="printer" onClick="action-lvme-historique-prix-imprimer"/>$a$,
    $n$<button colSpan="8" name="imprimerBtn" title="Imprimer" icon="printer" onClick="action-lvme-historique-prix-imprimer"/>
    <button name="imprimerBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="4" onClick="action-lvme-historique-prix-imprimer-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-historique-prix-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(xml,
    $a$<button name="imprimerBtn" title="Imprimer" icon="printer" onClick="action-lvme-prix-negocie-imprimer"/>$a$,
    $n$<button colSpan="8" name="imprimerBtn" title="Imprimer" icon="printer" onClick="action-lvme-prix-negocie-imprimer"/>
    <button name="imprimerBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="4" onClick="action-lvme-prix-negocie-imprimer-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-prix-negocie-search-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(xml,
    $a$<button name="listeRotationsBtn" title="Liste des Rotations" icon="printer" onClick="action-lvme-rotation-imprimer-liste"/>$a$,
    $n$<button colSpan="8" name="listeRotationsBtn" title="Liste des Rotations" icon="printer" onClick="action-lvme-rotation-imprimer-liste"/>
    <button name="listeRotationsBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="4" onClick="action-lvme-rotation-imprimer-liste-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-rotation-stock-dashboard-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(xml,
    $a$<button name="validerBtn" title="Valider" icon="check_circle" onClick="action-lvme-etat-besoins-imprimer"/>$a$,
    $n$<button colSpan="8" name="validerBtn" title="Valider" icon="check_circle" onClick="action-lvme-etat-besoins-imprimer"/>
    <button name="validerBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="4" onClick="action-lvme-etat-besoins-imprimer-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-etat-besoins-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(replace(replace(xml,
    $a$<spacer colSpan="3"/>
    <button name="imprimerEtatLigneBtn" title="Etat des Stocks sur une ligne" icon="printer" colSpan="3"
      onClick="action-lvme-etat-stock-lot-imprimer-ligne"/>$a$,
    $n$<button colSpan="3" name="imprimerEtatLigneBtn" title="Etat des Stocks sur une ligne" icon="printer"
      onClick="action-lvme-etat-stock-lot-imprimer-ligne"/>
    <button name="imprimerEtatLigneBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="1" onClick="action-lvme-etat-stock-lot-imprimer-ligne-excel"/>$n$),
    $a$<button name="imprimerEtatFournisseurBtn" title="Etat des Stocks / Fournisseur" icon="printer" colSpan="3"
      onClick="action-lvme-etat-stock-lot-imprimer-fournisseur"/>$a$,
    $n$<button colSpan="3" name="imprimerEtatFournisseurBtn" title="Etat des Stocks / Fournisseur" icon="printer"
      onClick="action-lvme-etat-stock-lot-imprimer-fournisseur"/>
    <button name="imprimerEtatFournisseurBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="1" onClick="action-lvme-etat-stock-lot-imprimer-fournisseur-excel"/>$n$),
    $a$<button name="imprimerEtatBtn" title="Etat des Stocks" icon="printer" colSpan="3"
      onClick="action-lvme-etat-stock-lot-imprimer"/>$a$,
    $n$<button colSpan="3" name="imprimerEtatBtn" title="Etat des Stocks" icon="printer"
      onClick="action-lvme-etat-stock-lot-imprimer"/>
    <button name="imprimerEtatBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="1" onClick="action-lvme-etat-stock-lot-imprimer-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-etat-stock-lot-search-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(xml,
    $a$<button name="imprimerBtn" title="Imprimer" icon="printer" colSpan="2" onClick="action-lvme-historique-produit-imprimer"/>$a$,
    $n$<button colSpan="1" name="imprimerBtn" title="Imprimer" icon="printer" onClick="action-lvme-historique-produit-imprimer"/>
    <button name="imprimerBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="1" onClick="action-lvme-historique-produit-imprimer-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-historique-produit-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(xml,
    $a$<spacer colSpan="10"/>
      <button name="validerBtn" title="Valider" icon="check_circle" colSpan="2" onClick="action-lvme-palmares-clients-imprimer"/>$a$,
    $n$<spacer colSpan="8"/>
    <button colSpan="2" name="validerBtn" title="Valider" icon="check_circle" onClick="action-lvme-palmares-clients-imprimer"/>
    <button name="validerBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="2" onClick="action-lvme-palmares-clients-imprimer-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-palmares-clients-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(xml,
    $a$<spacer colSpan="10"/>
    <button name="syntheseBtn" title="Synthèse" icon="printer" colSpan="2" onClick="action-lvme-synthese-arrivage-imprimer"/>$a$,
    $n$<spacer colSpan="8"/>
    <button colSpan="2" name="syntheseBtn" title="Synthèse" icon="printer" onClick="action-lvme-synthese-arrivage-imprimer"/>
    <button name="syntheseBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="2" onClick="action-lvme-synthese-arrivage-imprimer-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-synthese-arrivage-form' AND xml NOT LIKE '%-excel"%';

UPDATE meta_view SET xml = replace(xml,
    $a$<spacer colSpan="9"/>
      <button name="imprimerBtn" title="Imprimer" icon="printer" colSpan="3" onClick="action-lvme-rfa-facture-imprimer"/>$a$,
    $n$<spacer colSpan="6"/>
    <button colSpan="3" name="imprimerBtn" title="Imprimer" icon="printer" onClick="action-lvme-rfa-facture-imprimer"/>
    <button name="imprimerBtnExcel" title="Excel" icon="file-earmark-excel" css="btn-success" colSpan="3" onClick="action-lvme-rfa-facture-imprimer-excel"/>$n$),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name = 'lvme-rfa-facture-form' AND xml NOT LIKE '%-excel"%';

COMMIT;

-- contrôle : 14 actions Excel ; 14 boutons Excel dans 12 écrans
SELECT (SELECT count(*) FROM meta_action WHERE module IS NULL AND name LIKE 'action-lvme-%-excel') AS actions_excel,
  (SELECT sum((length(xml) - length(replace(xml, 'icon="file-earmark-excel"', ''))) / length('icon="file-earmark-excel"'))
   FROM meta_view WHERE module IS NULL AND type = 'form') AS boutons_excel;

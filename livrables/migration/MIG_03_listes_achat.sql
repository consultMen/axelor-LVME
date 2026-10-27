-- =====================================================================
-- MIGRATION GESCOM — étape 03 : listes des lignes d'achat / d'arrivage
--   Source : archive gescom.* (MIG_00). Rien n'est supprimé ; ce qui existe déjà n'est pas recréé.
--   - conditionnements (CONDITIONNEMENT) : la liste Axelor est complétée (code, libellé)
--   - marques (MARQUE), origines (ORIGINE), zones de pêche (ZONE_PECHE), modes de pêche (MODEPECHE) : listes de
--     choix des champs Marque / Origine / Zone de pêche / Mode de pêche des lignes (jusqu'ici en texte libre) ;
--     valeur enregistrée = libellé GESCOM (ex. VIETNAM, CHALUTS) ; l'origine sert aussi aux filtres « Origine »
--   - noms scientifiques (NOMSCIENTIFIQUE) : complètent les articles qui n'en ont pas
-- Relançable.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

-- ---------- conditionnements ----------
INSERT INTO purchase_conditionnement (id, version, created_on, code, label, active, import_id, import_origin)
SELECT nextval('purchase_conditionnement_seq'), 0, now(), c.code, coalesce(gescom.txt(c.nom), c.code), true,
  'GESCOM-COND-' || c.code, 'GESCOM'
FROM (SELECT DISTINCT ON (upper(btrim(code))) btrim(code) AS code, nom FROM gescom.conditionnement
      WHERE gescom.txt(code) IS NOT NULL ORDER BY upper(btrim(code)), gescom.num(n_enr)) c
WHERE NOT EXISTS (SELECT 1 FROM purchase_conditionnement p WHERE upper(p.code) = upper(c.code));

-- ---------- listes de choix : marques, origines, zones de pêche, modes de pêche ----------
CREATE TEMP TABLE mig_liste ON COMMIT DROP AS
SELECT 'purchase.purchase.order.line.marque.select'::text AS liste, btrim(desi) AS libelle, gescom.num(n_enr) AS ordre
FROM gescom.marque WHERE gescom.txt(desi) IS NOT NULL AND btrim(desi) <> '???'
UNION ALL
SELECT 'purchase.purchase.order.line.origine.select', btrim(libelle), gescom.num(n_enr)
FROM gescom.origine WHERE gescom.txt(libelle) IS NOT NULL AND btrim(libelle) <> '???'
UNION ALL
SELECT 'lvme.origine.select', btrim(libelle), gescom.num(n_enr)
FROM gescom.origine WHERE gescom.txt(libelle) IS NOT NULL AND btrim(libelle) <> '???'
UNION ALL
SELECT 'purchase.purchase.order.line.zonePeche.select', btrim(libelle), gescom.num(n_enr)
FROM gescom.zone_peche WHERE gescom.txt(libelle) IS NOT NULL
UNION ALL
SELECT 'purchase.purchase.order.line.modePeche.select', btrim(libelle), gescom.num(n_enr)
FROM gescom.modepeche WHERE gescom.txt(libelle) IS NOT NULL;

INSERT INTO meta_select (id, version, name, priority, is_custom)
SELECT nextval('meta_select_seq'), 0, l.liste, 0, true
FROM (SELECT DISTINCT liste FROM mig_liste) l
WHERE NOT EXISTS (SELECT 1 FROM meta_select s WHERE s.name = l.liste);

INSERT INTO meta_select_item (id, version, select_id, value, title, order_seq, import_origin)
SELECT nextval('meta_select_item_seq'), 0, s.id, l.libelle, l.libelle,
  (SELECT coalesce(max(i.order_seq), 0) FROM meta_select_item i WHERE i.select_id = s.id) + l.rang, 'GESCOM'
FROM (SELECT DISTINCT ON (liste, upper(libelle)) liste, libelle,
             dense_rank() OVER (PARTITION BY liste ORDER BY libelle) AS rang
      FROM mig_liste ORDER BY liste, upper(libelle), ordre) l
JOIN meta_select s ON s.name = l.liste
WHERE NOT EXISTS (SELECT 1 FROM meta_select_item i WHERE i.select_id = s.id AND upper(i.value) = upper(l.libelle));

-- ---------- noms scientifiques des articles ----------
UPDATE base_product p SET nom_scientifique = n.nom
FROM (SELECT DISTINCT ON (upper(btrim(art_code))) upper(btrim(art_code)) AS code, btrim(nom_scientique) AS nom
      FROM gescom.nomscientifique WHERE gescom.txt(art_code) IS NOT NULL AND gescom.txt(nom_scientique) IS NOT NULL
      ORDER BY upper(btrim(art_code)), gescom.num(n_enr)) n
WHERE upper(p.code) = n.code AND p.import_origin = 'GESCOM' AND p.nom_scientifique IS NULL;

COMMIT;

-- ---------- contrôle ----------
SELECT (SELECT count(*) FROM purchase_conditionnement) AS conditionnements,
       (SELECT count(*) FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
         WHERE s.name = 'purchase.purchase.order.line.marque.select') AS marques,
       (SELECT count(*) FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
         WHERE s.name = 'purchase.purchase.order.line.origine.select') AS origines,
       (SELECT count(*) FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
         WHERE s.name = 'purchase.purchase.order.line.zonePeche.select') AS zones_peche,
       (SELECT count(*) FROM meta_select_item i JOIN meta_select s ON s.id = i.select_id
         WHERE s.name = 'purchase.purchase.order.line.modePeche.select') AS modes_peche,
       (SELECT count(*) FROM base_product WHERE import_origin = 'GESCOM' AND nom_scientifique IS NOT NULL)
         AS articles_avec_nom_scientifique;

-- =====================================================================
-- PROD étape 80 : plus d'emojis dans les écrans LVME (rendu propre, professionnel)
--   - KPI des commandes clients et des achats : pastilles rondes avec emoji retirées (titres et chiffres gardés)
--   - boutons d'alerte : « Aucune alerte », « Retirer le filtre alerte », alertes sans ⚠ ni ⏳
--   - cartes des Kanban (arrivages, achats, commandes clients) : texte à la place des emojis (« En retard »,
--     « Commande : », « Livraison : », « 12 colis · 340 kg », « Marge 18 % »…)
-- Sources mises à jour : livrables/ui (kanbans, écrans de recherche), gen_prod68 / gen_prod70. Relançable.
-- =====================================================================
BEGIN;

UPDATE meta_view SET xml = regexp_replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(xml,
  $q$'⚠ ' + $q$, $q$$q$),
  $q$'⏳ ' + $q$, $q$$q$),
  $q$✔ Aucune alerte$q$, $q$Aucune alerte$q$),
  $q$✖ Retirer le filtre alerte$q$, $q$Retirer le filtre alerte$q$),
  $q$⏰ En retard$q$, $q$En retard$q$),
  $q$(shipmentMode.name == 'Bateau' ? '🚢 ' : '🚚 ') + $fmt('shipmentMode')$q$, $q$$fmt('shipmentMode')$q$),
  $q$⚓ {$fmt('bateau')}$q$, $q${$fmt('bateau')}$q$),
  $q$📅 Arrivée prévue :$q$, $q$Arrivée prévue :$q$),
  $q$📦 {$fmt('nbColisTotal')} · ⚖ {$fmt('poidsTotal')} kg$q$, $q${$fmt('nbColisTotal')} colis · {$fmt('poidsTotal')} kg$q$),
  $q$📝 Commande :$q$, $q$Commande :$q$),
  $q$📅 Réception :$q$, $q$Réception :$q$),
  $q$🚚 Livraison :$q$, $q$Livraison :$q$),
  $q$📈 {$fmt('marginRate')} %$q$, $q$Marge {$fmt('marginRate')} %$q$),
  $q$\n?[ \t]*<Box style=\{\{ width: 40, height: 40, borderRadius: 20, background: 'rgba\(255,255,255,\.25\)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 \}\}>[^<]{1,3}</Box>$q$, '', 'g'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name IN ('lvme-achat-kanban', 'lvme-arrivage-kanban', 'lvme-commande-client-kanban', 'lvme-achat-search-form', 'lvme-commande-client-search-form');

UPDATE meta_action SET xml = regexp_replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(xml,
  $q$'⚠ ' + $q$, $q$$q$),
  $q$'⏳ ' + $q$, $q$$q$),
  $q$✔ Aucune alerte$q$, $q$Aucune alerte$q$),
  $q$✖ Retirer le filtre alerte$q$, $q$Retirer le filtre alerte$q$),
  $q$⏰ En retard$q$, $q$En retard$q$),
  $q$(shipmentMode.name == 'Bateau' ? '🚢 ' : '🚚 ') + $fmt('shipmentMode')$q$, $q$$fmt('shipmentMode')$q$),
  $q$⚓ {$fmt('bateau')}$q$, $q${$fmt('bateau')}$q$),
  $q$📅 Arrivée prévue :$q$, $q$Arrivée prévue :$q$),
  $q$📦 {$fmt('nbColisTotal')} · ⚖ {$fmt('poidsTotal')} kg$q$, $q${$fmt('nbColisTotal')} colis · {$fmt('poidsTotal')} kg$q$),
  $q$📝 Commande :$q$, $q$Commande :$q$),
  $q$📅 Réception :$q$, $q$Réception :$q$),
  $q$🚚 Livraison :$q$, $q$Livraison :$q$),
  $q$📈 {$fmt('marginRate')} %$q$, $q$Marge {$fmt('marginRate')} %$q$),
  $q$\n?[ \t]*<Box style=\{\{ width: 40, height: 40, borderRadius: 20, background: 'rgba\(255,255,255,\.25\)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 \}\}>[^<]{1,3}</Box>$q$, '', 'g'),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name IN ('action-lvme-achat-kpi', 'action-lvme-cde-client-kpi');

COMMIT;

-- contrôle : nombre de vues / actions LVME qui contiennent encore un emoji (doit être 0)
SELECT (SELECT count(*) FROM meta_view WHERE module IS NULL AND name IN ('lvme-achat-kanban', 'lvme-arrivage-kanban', 'lvme-commande-client-kanban', 'lvme-achat-search-form', 'lvme-commande-client-search-form')
          AND xml ~ '[\U0001F000-\U0001FFFF\u2600-\u27BF]') AS vues_avec_emoji,
       (SELECT count(*) FROM meta_action WHERE module IS NULL AND name IN ('action-lvme-achat-kpi', 'action-lvme-cde-client-kpi')
          AND xml ~ '[\U0001F000-\U0001FFFF\u2600-\u27BF]') AS actions_avec_emoji;

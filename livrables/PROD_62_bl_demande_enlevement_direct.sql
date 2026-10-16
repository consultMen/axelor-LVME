-- =====================================================================
-- PROD étape 62 : « Imprimer le BL » d'une livraison client imprime directement la Demande d'enlèvement
--   Axelor ouvre la fenêtre « Sélectionner le modèle » quand plusieurs modèles d'impression sont actifs
--   pour les mouvements de stock (ici : Arrivage LVME et Demande d'Enlèvement). Le modèle « Arrivage LVME »
--   passe en brouillon : il ne sert qu'au bouton « Editer » de la fiche Arrivage, qui le retrouve par son nom
--   (actif ou non) ; il ne s'affiche plus dans le choix des BL.
--   Pas de redémarrage. Relançable. Retour arrière : remettre status_select = 2 sur « Arrivage LVME ».
-- =====================================================================
BEGIN;

UPDATE base_printing_template SET status_select = 1, updated_on = now(), version = COALESCE(version, 0) + 1
 WHERE name = 'Arrivage LVME' AND status_select = 2;

COMMIT;

-- modèles d'impression encore actifs pour les mouvements de stock : il doit n'en rester qu'un
-- (Demande d'Enlèvement) pour une impression directe
SELECT pt.id, pt.name, pt.status_select AS statut_2_actif
FROM base_printing_template pt JOIN meta_model mm ON mm.id = pt.meta_model
WHERE mm.name = 'StockMove'
ORDER BY pt.status_select DESC, pt.id;

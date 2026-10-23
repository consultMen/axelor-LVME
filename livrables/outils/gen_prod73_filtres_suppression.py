"""Écrit livrables/PROD_73_filtres_suivi_suppression.sql :
  1. filtres tout prêts (menu ▾ de la recherche) des 3 Kanban de suivi (livrables/ui/*-kanban-filtres.xml) ;
  2. les boutons « Suivi des … » ouvrent le Kanban avec les filtres saisis au-dessus de la liste (fournisseur /
     client, n°, périodes, transport…) ;
  3. corbeille native dans l'en-tête des listes intégrées (panel-dashlet canDelete) de tous les écrans de recherche ;
     contrôle avant suppression des commandes et arrivages (onDelete, LvmeSuppressionController).
Usage : python livrables/outils/gen_prod73_filtres_suppression.py   (depuis la racine du dépôt)
"""
import os

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UI = os.path.join(RACINE, 'livrables', 'ui')
DST = os.path.join(RACINE, 'livrables', 'PROD_73_filtres_suivi_suppression.sql')

DATE = "java.time.LocalDate.parse({0}.toString().substring(0, 10))"


def ctx_date(nom, champ, defaut):
    return '  <context name="%s" expr="eval: %s ? %s : %s"/>' % (nom, champ, DATE.format(champ), defaut)


KANBANS = {
    'action-lvme-arrivage-kanban': ('Suivi des arrivages', 'com.axelor.apps.stock.db.StockMove', 'lvme-arrivage-kanban',
                                    'lvme-arrivage-grid', 'lvme-arrivage-form', 'lvme-arrivage-kanban-filters', '''
  <domain>self.typeSelect = 3 AND self.isReversion = FALSE AND (self.archived IS NULL OR self.archived = false)
    AND LOWER(COALESCE(self.stockMoveSeq, '')) LIKE :_num
    AND (:_fou = 0 OR self.partner.id = :_fou)
    AND (:_dateFiltre = false OR self.createdOn BETWEEN :_dateDu AND :_dateAu)
    AND (:_arrFiltre = false OR (self.realDate BETWEEN :_arrDu AND :_arrAu)
         OR (self.realDate IS NULL AND self.estimatedDate BETWEEN :_arrDu AND :_arrAu))</domain>
  <context name="_num" expr="eval: numeroArrivage ? '%' + numeroArrivage.toString().trim().toLowerCase() + '%' : '%'"/>
  <context name="_fou" expr="eval: (fournisseur?.id ?: 0) as Long"/>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
  <context name="_dateDu" expr="eval: dateDu ? java.time.LocalDate.parse(dateDu.toString().substring(0, 10)).atStartOfDay() : java.time.LocalDateTime.of(1900, 1, 1, 0, 0)"/>
  <context name="_dateAu" expr="eval: dateAu ? java.time.LocalDate.parse(dateAu.toString().substring(0, 10)).atTime(23, 59, 59) : java.time.LocalDateTime.of(2999, 12, 31, 0, 0)"/>
  <context name="_arrFiltre" expr="eval: arriveeDu != null || arriveeAu != null"/>
''' + ctx_date('_arrDu', 'arriveeDu', 'java.time.LocalDate.of(1900, 1, 1)') + '\n'
        + ctx_date('_arrAu', 'arriveeAu', 'java.time.LocalDate.of(2999, 12, 31)')),
    'action-lvme-achat-kanban': ("Suivi des commandes d'achat", 'com.axelor.apps.purchase.db.PurchaseOrder', 'lvme-achat-kanban',
                                 'lvme-achat-grid', 'purchase-order-form', 'lvme-achat-kanban-filters', '''
  <domain>(:_dateFiltre = false OR self.orderDate BETWEEN :_dateDu AND :_dateAu)
    AND (:_arrFiltre = false OR self.estimatedReceiptDate BETWEEN :_arrDu AND :_arrAu)
    AND (:_fouDu = '' OR self.supplierPartner.name &gt;= :_fouDu) AND (:_fouAu = '' OR self.supplierPartner.name &lt;= :_fouAu)
    AND (:_transport = 0 OR self.shipmentMode.id = :_transport)</domain>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
''' + ctx_date('_dateDu', 'dateDu', 'java.time.LocalDate.of(1900, 1, 1)') + '\n'
        + ctx_date('_dateAu', 'dateAu', 'java.time.LocalDate.of(2999, 12, 31)') + '''
  <context name="_arrFiltre" expr="eval: arriveeDu != null || arriveeAu != null"/>
''' + ctx_date('_arrDu', 'arriveeDu', 'java.time.LocalDate.of(1900, 1, 1)') + '\n'
        + ctx_date('_arrAu', 'arriveeAu', 'java.time.LocalDate.of(2999, 12, 31)') + '''
  <context name="_fouDu" expr="eval: fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.name ?: '') : ''"/>
  <context name="_fouAu" expr="eval: fournisseurAu?.id ? (__repo__(Partner).find(fournisseurAu.id as Long)?.name ?: '') : (fournisseurDu?.id ? (__repo__(Partner).find(fournisseurDu.id as Long)?.name ?: '') : '')"/>
  <context name="_transport" expr="eval: (typeTransport?.id ?: 0) as Long"/>'''),
    'action-lvme-cde-client-kanban': ('Suivi des commandes clients', 'com.axelor.apps.sale.db.SaleOrder', 'lvme-commande-client-kanban',
                                      'lvme-commande-client-grid', 'sale-order-form', 'lvme-commande-client-kanban-filters', '''
  <domain>self.template = false
    AND (:_client = 0 OR self.clientPartner.id = :_client)
    AND (:_commercial = 0 OR self.commercial.id = :_commercial)
    AND (:_dateFiltre = false OR COALESCE(self.orderDate, self.creationDate) BETWEEN :_dateDu AND :_dateAu)
    AND (:_livFiltre = false OR self.estimatedDeliveryDate BETWEEN :_livDu AND :_livAu)</domain>
  <context name="_client" expr="eval: (client?.id ?: 0) as Long"/>
  <context name="_commercial" expr="eval: (commercialFiltre?.id ?: 0) as Long"/>
  <context name="_dateFiltre" expr="eval: dateDu != null || dateAu != null"/>
''' + ctx_date('_dateDu', 'dateDu', 'java.time.LocalDate.of(1900, 1, 1)') + '\n'
        + ctx_date('_dateAu', 'dateAu', 'java.time.LocalDate.of(2999, 12, 31)') + '''
  <context name="_livFiltre" expr="eval: livraisonDu != null || livraisonAu != null"/>
''' + ctx_date('_livDu', 'livraisonDu', 'java.time.LocalDate.of(1900, 1, 1)') + '\n'
        + ctx_date('_livAu', 'livraisonAu', 'java.time.LocalDate.of(2999, 12, 31)')),
}


def q(s):
    return s.replace("'", "''")


actions = []
for nom, (titre, modele, kanban, grille, fiche, filtres, corps) in KANBANS.items():
    xml = ('<action-view name="%s" title="%s" model="%s">\n'
           '  <view type="kanban" name="%s"/>\n  <view type="grid" name="%s"/>\n  <view type="form" name="%s"/>\n'
           '  <view-param name="search-filters" value="%s"/>\n'
           '  <!-- LVME : mêmes filtres que ceux saisis au-dessus de la liste -->%s\n</action-view>'
           % (nom, titre, modele, kanban, grille, fiche, filtres, corps))
    actions.append((nom, 'action-view', "'%s'" % modele, xml))

# corbeille native dans l'en-tête de la liste intégrée (panel-dashlet canDelete) de tous les écrans de recherche ;
# pour les 3 listes de pièces, contrôle avant suppression (onDelete : brouillon / annulé seulement, lots détachés)
ON_DELETE = [('lvme-commande-client-grid', 'action-lvme-verifier-suppression-cde-client', 'verifierSuppressionCommandeClient'),
             ('lvme-achat-grid', 'action-lvme-verifier-suppression-cde-achat', 'verifierSuppressionCommandeAchat'),
             ('lvme-arrivage-grid', 'action-lvme-verifier-suppression-arrivage', 'verifierSuppressionArrivage')]
for grille, act, meth in ON_DELETE:
    actions.append((act, 'action-method', 'NULL',
                    '<action-method name="%s">\n  <call class="com.axelor.apps.supplychain.web.LvmeSuppressionController" method="%s"/>\n</action-method>'
                    % (act, meth)))
NOMS_GRILLES = ', '.join("'%s'" % g for g, a, m in ON_DELETE)
maj_grilles = ''.join(
    r"""UPDATE meta_view SET xml = regexp_replace(regexp_replace(regexp_replace(xml,
    '\n\s*<button name="lvmeSupprimerSelBtn"[^>]*/>', '', 'g'),
    '\s+onDelete="[^"]*"', '', 'g'),
    '^(<grid\s)', '\1onDelete="%s" ', ''),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE name = '%s' AND module IS NULL;
""" % (act, grille) for grille, act, meth in ON_DELETE)
# barre d'outils restée vide après le retrait du bouton : retirée
maj_grilles += r"""UPDATE meta_view SET xml = regexp_replace(xml, '\n\s*<toolbar>\s*</toolbar>', '', 'g'), updated_on = now()
WHERE module IS NULL AND name IN (%s) AND xml ~ '<toolbar>\s*</toolbar>';
""" % NOMS_GRILLES
FORMS = ['lvme-commande-client-search-form', 'lvme-achat-search-form', 'lvme-arrivage-search-form', 'lvme-client-search-form',
         'lvme-fournisseur-search-form', 'lvme-article-search-form', 'lvme-article-achat-search-form']
NOMS_FORMS = ', '.join("'%s'" % f for f in FORMS)
maj_formulaires = r"""UPDATE meta_view SET xml = regexp_replace(xml, '\n\s*<button name="lvmeSelectionBtn"[^>]*/>', '', 'g'), updated_on = now()
WHERE module IS NULL AND name IN (%s) AND xml LIKE '%%lvmeSelectionBtn%%';
UPDATE meta_view SET xml = replace(xml, '<panel-dashlet ', '<panel-dashlet canDelete="true" '),
  updated_on = now(), version = COALESCE(version, 0) + 1
WHERE module IS NULL AND name IN (%s) AND xml NOT LIKE '%%panel-dashlet canDelete=%%';
UPDATE meta_view SET xml = replace(xml, 'title="Archiver / Supprimer"', 'title="Archiver / Désarchiver"'), updated_on = now()
WHERE module IS NULL AND name = 'lvme-arrivage-search-form' AND xml LIKE '%%title="Archiver / Supprimer"%%';
""" % (NOMS_FORMS, NOMS_FORMS)

FILTRES = ['arrivage-kanban-filtres', 'achat-kanban-filtres', 'commande-client-kanban-filtres']
NOMS_FILTRES = ['lvme-arrivage-kanban-filters', 'lvme-achat-kanban-filters', 'lvme-commande-client-kanban-filters']
MODELES = ['com.axelor.apps.stock.db.StockMove', 'com.axelor.apps.purchase.db.PurchaseOrder', 'com.axelor.apps.sale.db.SaleOrder']

sql = ['''-- =====================================================================
-- PROD étape 73 : filtres des écrans « Suivi des … » (Kanban) et suppression de plusieurs pièces
--   - menu ▾ de la recherche des 3 Kanban : filtres tout prêts (en retard, bateau / camion, du mois, livraison
--     aujourd'hui, marge négative)
--   - les boutons « Suivi des … » ouvrent le Kanban avec les filtres saisis au-dessus de la liste
--   - corbeille native dans l'en-tête de la liste de chaque écran de recherche (commandes clients, achats,
--     arrivages, clients, fournisseurs, articles) : supprime les lignes cochées ; pour les
--     commandes et arrivages, contrôle avant (brouillons et annulés seulement, sinon rien n'est supprimé)
-- Sources : livrables/ui/*-kanban-filtres.xml ; écrit par livrables/outils/gen_prod73_filtres_suppression.py
-- Prérequis : PROD_68 à PROD_71 ; code avec LvmeSuppressionController (suppression de plusieurs lignes, recompiler).
-- Depuis la racine du dépôt. Relançable.
-- =====================================================================''']
for i, f in enumerate(FILTRES):
    sql.append("\\set f%d `cat livrables/ui/%s.xml`\nSELECT set_config('lvme.filtres%d', :'f%d', false) IS NOT NULL AS filtres_lus;"
               % (i, f, i, i))
sql.append('\nBEGIN;\n')
sql.append("DELETE FROM meta_view WHERE module IS NULL AND name IN (%s);" % ', '.join("'%s'" % n for n in NOMS_FILTRES))
sql.append("INSERT INTO meta_view (id, version, created_on, name, title, type, model, priority, xml, extension, computed) VALUES\n"
           + ',\n'.join("(nextval('meta_view_seq'), 0, now(), '%s', '%s', 'search-filters', '%s', 20, current_setting('lvme.filtres%d'), false, false)"
                        % (n, n, m, i) for i, (n, m) in enumerate(zip(NOMS_FILTRES, MODELES))) + ';\n')
sql.append("DELETE FROM meta_action WHERE module IS NULL AND name IN (%s);" % ', '.join("'%s'" % a[0] for a in actions))
sql.append("INSERT INTO meta_action (id, version, created_on, name, type, model, xml, home, is_custom, priority) VALUES\n"
           + ',\n'.join("(nextval('meta_action_seq'), 0, now(), '%s', '%s', %s,\n'%s', false, false, 0)" % (n, t, m, q(x))
                        for n, t, m, x in actions) + ';\n')
sql.append('-- contrôle avant la corbeille native (3 listes de pièces) ; ancien bouton « Supprimer la sélection » retiré')
sql.append(maj_grilles)
sql.append("-- corbeille native dans l'en-tête des listes intégrées des écrans de recherche")
sql.append(maj_formulaires)
sql.append("""
COMMIT;

SELECT name, type FROM meta_view WHERE module IS NULL AND name LIKE '%kanban-filters';
SELECT name, substring(xml from 'onDelete="([^"]*)"') AS controle FROM meta_view
WHERE module IS NULL AND name IN ('lvme-commande-client-grid', 'lvme-achat-grid', 'lvme-arrivage-grid');
SELECT name, position('panel-dashlet canDelete="true"' IN xml) > 0 AS corbeille FROM meta_view
WHERE module IS NULL AND name LIKE 'lvme-%search-form' ORDER BY name;
""")
open(DST, 'w', encoding='utf-8', newline='\n').write('\n'.join(sql))
print('ok', DST)

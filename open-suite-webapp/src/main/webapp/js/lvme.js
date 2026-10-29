/*
 * LVME : raccourcis clavier des écrans façon GESCOM (ajouté à la page Axelor par build.gradle, tâche copyWebapp).
 *   F1 : « F1 : Historique Prix » de la fenêtre Lignes Commandes ouverte, à la place de l'aide du navigateur.
 *   Liste « Articles » (loupe Article des lignes) : un clic choisit l'article et ferme la liste.
 *   F2 : nouvelle ligne (bouton « + » de la liste des lignes) de la fiche ou de la fenêtre ouverte.
 *   F12 : bouton « Fermer », « Fermer(F12) » ou « Quitter » affiché (fenêtre ouverte d'abord, sinon l'écran).
 * Axelor n'écrit pas le nom du bouton dans la page : le bouton est retrouvé par son libellé.
 */
(function () {
  var LIBELLE_F1 = 'Historique Prix';

  function boutonVisible(libelle) {
    var boutons = document.querySelectorAll('button');
    for (var i = boutons.length - 1; i >= 0; i--) {
      var b = boutons[i];
      if (b.offsetParent !== null && !b.disabled && (b.textContent || '').indexOf(libelle) >= 0) {
        return b;
      }
    }
    return null;
  }

  window.addEventListener('keydown', function (e) {
    if (e.key !== 'F1' || e.ctrlKey || e.altKey || e.metaKey) {
      return;
    }
    // toujours bloquer l'aide du navigateur (page support Google) dans Axelor
    e.preventDefault();
    e.stopPropagation();
    var b = boutonVisible(LIBELLE_F1);
    if (b) {
      b.click();
    }
  }, true);

  // bouton Fermer / Fermer(F12) / Quitter affiché : celui de la fenêtre ouverte (la dernière) en priorité, sinon celui
  // de l'écran ; le libellé est la dernière ligne du bouton (l'icône peut écrire son nom avant)
  var FERMER = /^(Fermer|Quitter)\s*(\(F12\))?$/i;
  function boutonFermer() {
    var fenetres = document.querySelectorAll('[class*="_modal-content"]');
    var zones = fenetres.length ? [fenetres[fenetres.length - 1], document] : [document];
    for (var z = 0; z < zones.length; z++) {
      var boutons = zones[z].querySelectorAll('button');
      for (var i = boutons.length - 1; i >= 0; i--) {
        var b = boutons[i];
        var lignes = (b.innerText || '').trim().split('\n');
        if (b.offsetParent !== null && !b.disabled && FERMER.test(lignes[lignes.length - 1].trim())) {
          return b;
        }
      }
    }
    return null;
  }

  // F12 : bouton Fermer / Quitter affiché, comme GESCOM ; sans ce bouton, F12 garde son effet
  window.addEventListener('keydown', function (e) {
    if (e.key !== 'F12' || e.ctrlKey || e.altKey || e.metaKey || e.shiftKey) {
      return;
    }
    var b = boutonFermer();
    if (b) {
      e.preventDefault();
      e.stopPropagation();
      b.click();
    }
  }, true);

  // F2 : nouvelle ligne (bouton « + » de la liste des lignes) de la fiche affichée, ou de la fenêtre ouverte : commande
  // client, commande d'achat, arrivage, et toute fiche avec une liste de lignes. La liste dont le titre parle de
  // « ligne » passe en premier (ex. « Lignes d'arrivage »), sinon la première liste de la fiche.
  var NOUVEAU = /^(add|New|Nouveau|Nouvelle ligne|Ajouter)$/i;
  function boutonNouvelleLigne() {
    var fenetres = document.querySelectorAll('[class*="_modal-content"]');
    var zone = fenetres.length ? fenetres[fenetres.length - 1] : document;
    var boutons = zone.querySelectorAll('button');
    var premier = null;
    for (var i = 0; i < boutons.length; i++) {
      var b = boutons[i];
      if (b.offsetParent === null || b.disabled) {
        continue;
      }
      var texte = (b.innerText || '').trim();
      if (!NOUVEAU.test(texte) && !NOUVEAU.test(b.title || '') && !NOUVEAU.test(b.getAttribute('aria-label') || '')) {
        continue;
      }
      // le bouton doit appartenir à un panneau qui contient une liste (lignes), pas à la barre d'outils de la fiche
      var panneau = b.closest('[class*="_panel"]');
      if (!panneau || !panneau.querySelector('[class*="_grid"], [role="grid"], table')) {
        continue;
      }
      var titre = panneau.querySelector('[class*="_title"]');
      if (titre && /ligne/i.test(titre.textContent || '')) {
        return b;
      }
      if (!premier) {
        premier = b;
      }
    }
    return premier;
  }

  window.addEventListener('keydown', function (e) {
    if (e.key !== 'F2' || e.ctrlKey || e.altKey || e.metaKey || e.shiftKey) {
      return;
    }
    var b = boutonNouvelleLigne();
    if (b) {
      e.preventDefault();
      e.stopPropagation();
      b.click();
    }
  }, true);

  // Sélect Arrivage (fenêtre Lignes Commandes) : le bouton ouvre la liste « Sélection Arrivage » comme GESCOM,
  // c'est-à-dire la recherche (loupe) du champ caché « Sélection Arrivage » (css lvme-sel-arrivage-cache) ;
  // la ligne choisie dans la liste est ajoutée aux lots sélectionnés de la ligne de commande.
  document.addEventListener('click', function (e) {
    var b = e.target && e.target.closest ? e.target.closest('button') : null;
    if (!b || (b.textContent || '').indexOf('Sélect Arrivage') < 0) {
      return;
    }
    var fenetre = b.closest('[class*="_modal-content"]') || document;
    var champ = fenetre.querySelector('.lvme-sel-arrivage-cache');
    if (!champ) {
      return;
    }
    var icones = champ.querySelectorAll('*');
    for (var i = 0; i < icones.length; i++) {
      if (icones[i].children.length === 0 && (icones[i].textContent || '').trim() === 'search') {
        icones[i].click();
        return;
      }
    }
    // sinon : l'élément « Sélectionner » (titre) de la recherche
    var sel = champ.querySelector('[title="Sélectionner"], [title="Select"]');
    if (sel) {
      (sel.firstElementChild || sel).click();
    }
  }, true);

  // fenêtres GESCOM (ligne de commande client, ligne d'arrivage, ligne de commande d'achat) : Axelor ne reprend pas le css d'une liste ouverte en
  // recherche, la fenêtre est donc marquée par son titre (classe lvme-fenetre-gescom, couleurs dans lvme.css)
  var TITRES_GESCOM = ['Sélection Arrivage', 'Liste des Mouvements de Stock', 'Commandes Clients', 'Historique Prix',
    "Ligne d'arrivage", "Ligne de commande d'achat"];
  function marquerFenetres() {
    var fenetres = document.querySelectorAll('[class*="_modal-content"]:not(.lvme-fenetre-gescom)');
    for (var i = 0; i < fenetres.length; i++) {
      var entete = fenetres[i].querySelector('[class*="_modal-header"]') || fenetres[i];
      var titre = (entete.textContent || '').trim();
      for (var j = 0; j < TITRES_GESCOM.length; j++) {
        if (titre.indexOf(TITRES_GESCOM[j]) === 0) {
          fenetres[i].classList.add('lvme-fenetre-gescom');
          break;
        }
      }
    }
  }
  new MutationObserver(marquerFenetres).observe(document.documentElement, { childList: true, subtree: true });

  // listes « Articles », « Fournisseurs » et « Clients » ouvertes par la loupe (lignes de commande, champs fournisseur
  // et client des écrans) : présentées comme GESCOM (classe lvme-fenetre-articles, lvme.css) et un clic sur une ligne
  // la choisit et ferme la liste, comme un double-clic (la case à cocher garde son effet). Titre seul, suivi du
  // compteur « 1 à 40 sur … » : pas les autres fenêtres dont le titre commence par ces mots.
  var LISTES_GESCOM = /^(Articles|Fournisseurs|Clients)(?![A-Za-zÀ-ÿ '’])/;
  function fenetreArticles(el) {
    var f = el && el.closest ? el.closest('[class*="_modal-content"]') : null;
    if (!f) {
      return null;
    }
    var entete = f.querySelector('[class*="_modal-header"]') || f;
    return LISTES_GESCOM.test((entete.textContent || '').trim()) ? f : null;
  }
  new MutationObserver(function () {
    var fenetres = document.querySelectorAll('[class*="_modal-content"]:not(.lvme-fenetre-articles)');
    for (var i = 0; i < fenetres.length; i++) {
      if (fenetreArticles(fenetres[i])) {
        fenetres[i].classList.add('lvme-fenetre-articles');
      }
    }
  }).observe(document.documentElement, { childList: true, subtree: true });
  document.addEventListener('click', function (e) {
    var t = e.target;
    if (!t || !t.closest || t.closest('input, button, [role="checkbox"]') || !fenetreArticles(t)) {
      return;
    }
    var ligne = t.closest('[class*="_body_"] [class*="_row_"]');
    if (!ligne) {
      return;
    }
    var cellule = t.closest('[class*="_column_"]') || t;
    cellule.dispatchEvent(new MouseEvent('dblclick', { bubbles: true, cancelable: true, view: window }));
  }, true);

  // certains navigateurs ouvrent l'aide sur l'évènement « help » : bloqué aussi
  window.addEventListener('help', function (e) {
    e.preventDefault();
  }, true);
})();

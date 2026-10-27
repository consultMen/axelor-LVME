/*
 * LVME : raccourcis clavier des écrans façon GESCOM (ajouté à la page Axelor par build.gradle, tâche copyWebapp).
 *   F1 : « F1 : Historique Prix » de la fenêtre Lignes Commandes ouverte, à la place de l'aide du navigateur.
 *   F12 : bouton « Fermer(F12) » affiché (Historique Produit).
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

  // F12 : bouton « Fermer(F12) » affiché (Historique Produit), comme GESCOM ; sans ce bouton, F12 garde son effet
  window.addEventListener('keydown', function (e) {
    if (e.key !== 'F12' || e.ctrlKey || e.altKey || e.metaKey || e.shiftKey) {
      return;
    }
    var b = boutonVisible('Fermer(F12)');
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

  // certains navigateurs ouvrent l'aide sur l'évènement « help » : bloqué aussi
  window.addEventListener('help', function (e) {
    e.preventDefault();
  }, true);
})();

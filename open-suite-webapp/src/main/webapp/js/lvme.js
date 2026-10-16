/*
 * LVME : raccourcis clavier des écrans façon GESCOM (ajouté à la page Axelor par build.gradle, tâche copyWebapp).
 *   F1 : « F1 : Historique Prix » de la fenêtre Ligne de commande ouverte (bouton lvmeHistoriquePrixBtn),
 *        à la place de l'aide du navigateur.
 */
(function () {
  function boutonVisible(nom) {
    var boutons = document.querySelectorAll('[name="' + nom + '"], [data-name="' + nom + '"]');
    for (var i = boutons.length - 1; i >= 0; i--) {
      var b = boutons[i];
      if (b.offsetParent !== null && !b.disabled) {
        return b.tagName === 'BUTTON' ? b : (b.querySelector('button') || b);
      }
    }
    return null;
  }
  window.addEventListener('keydown', function (e) {
    if (e.key !== 'F1' || e.ctrlKey || e.altKey || e.metaKey) {
      return;
    }
    var b = boutonVisible('lvmeHistoriquePrixBtn');
    if (b) {
      e.preventDefault();
      e.stopPropagation();
      b.click();
    }
  }, true);
})();

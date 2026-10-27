// Choisit le serveur ouvert par l'application LVME, puis met à jour le projet Android (npx cap sync android).
//   node serveur.js prod                  -> https://lvme-erp.com (version à distribuer)
//   node serveur.js local 192.168.1.20    -> http://192.168.1.20:8080/axelor-erp (test sur le PC, même Wi-Fi)
// Reconstruire ensuite l'APK dans Android Studio.
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const [mode, ip] = process.argv.slice(2);
const fichier = path.join(__dirname, 'capacitor.config.json');
const config = JSON.parse(fs.readFileSync(fichier, 'utf8'));

if (mode === 'prod') {
  config.server = { url: 'https://lvme-erp.com', cleartext: false, allowNavigation: ['lvme-erp.com'] };
} else if (mode === 'local' && ip) {
  // http autorisé seulement pour ce test : le serveur local n'a pas de https
  config.server = { url: `http://${ip}:8080/axelor-erp`, cleartext: true, allowNavigation: [ip] };
} else {
  console.error('Usage : node serveur.js prod   ou   node serveur.js local <adresse IP du PC>');
  process.exit(1);
}

fs.writeFileSync(fichier, JSON.stringify(config, null, 2) + '\n');
console.log('Serveur de l\'application : ' + config.server.url);
execSync('npx cap sync android', { cwd: __dirname, stdio: 'inherit' });

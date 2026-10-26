# Application Android LVME

Application « LVME » pour téléphone et tablette Android. Elle ouvre l'ERP LVME (`https://lvme-erp.com`) en plein
écran, sans Chrome : c'est toute l'application Axelor LVME (commandes, arrivages, stocks, impressions). Les
impressions (PDF) sont téléchargées dans « Téléchargements » et s'ouvrent depuis la notification.

Gratuit : pas de Play Store, on envoie le fichier APK aux utilisateurs.

- Adresse ouverte : `capacitor.config.json` (`server.url`)
- Nom et identifiant : `LVME`, `com.lvme.sofrimar`
- Icône et écran de démarrage : logo LVME (`android/app/src/main/res`)

## 1. Installer les outils Android (une seule fois, gratuit)

1. Installer **Android Studio** : https://developer.android.com/studio (environ 3 Go, contient le SDK Android).
2. Au premier lancement, accepter l'installation standard (SDK, outils).

## 2. Construire l'APK

1. Android Studio > **Open** > choisir le dossier `lvme-mobile/android`.
2. Attendre la fin de la synchronisation (barre du bas).
3. Menu **Build > Build App Bundle(s) / APK(s) > Build APK(s)**.
4. Le fichier est `lvme-mobile/android/app/build/outputs/apk/debug/app-debug.apk`.

## 3. Installer sur un téléphone

1. Envoyer `app-debug.apk` sur le téléphone (WhatsApp, e-mail, câble USB…).
2. L'ouvrir sur le téléphone ; Android demande d'autoriser « l'installation d'applications inconnues » pour
   l'application qui ouvre le fichier : accepter.
3. L'icône LVME apparaît avec les autres applications. Se connecter avec son identifiant LVME.

## Après une modification de `capacitor.config.json` ou de `www/`

```
cd lvme-mobile
npx cap sync android
```

puis reconstruire l'APK (étape 2). Les modifications faites dans Axelor (écrans, impressions) n'ont pas besoin
d'une nouvelle APK : l'application affiche toujours la version du serveur.

## Mise à jour de l'application sur les téléphones

Une nouvelle APK s'installe par-dessus l'ancienne seulement si elle est construite **sur le même PC** (elle est
signée avec la clé de débogage d'Android Studio de ce PC, `~/.android/debug.keystore`). Garder ce fichier : sans
lui, il faudrait désinstaller LVME des téléphones avant d'installer la nouvelle version.

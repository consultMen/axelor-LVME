package com.lvme.sofrimar;

import android.app.DownloadManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.webkit.CookieManager;
import android.webkit.URLUtil;
import android.widget.Toast;
import com.getcapacitor.BridgeActivity;

/**
 * Application LVME : ouvre l'ERP LVME (https://lvme-erp.com, voir capacitor.config.json) en plein écran.
 *
 * <p>Les impressions d'Axelor (PDF de la commande client, de l'arrivage…) ne s'affichent pas dans l'écran de
 * l'application : elles sont téléchargées dans « Téléchargements » avec la session de l'utilisateur, et une
 * notification permet de les ouvrir.
 */
public class MainActivity extends BridgeActivity {

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    getBridge()
        .getWebView()
        .setDownloadListener(
            (url, userAgent, contentDisposition, mimeType, contentLength) -> {
              String nom = URLUtil.guessFileName(url, contentDisposition, mimeType);
              DownloadManager.Request demande = new DownloadManager.Request(Uri.parse(url));
              demande.addRequestHeader("Cookie", CookieManager.getInstance().getCookie(url));
              demande.addRequestHeader("User-Agent", userAgent);
              demande.setMimeType(mimeType);
              demande.setTitle(nom);
              demande.setNotificationVisibility(
                  DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
              demande.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, nom);
              DownloadManager telechargements = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
              telechargements.enqueue(demande);
              Toast.makeText(this, "Téléchargement : " + nom, Toast.LENGTH_SHORT).show();
            });
  }
}
